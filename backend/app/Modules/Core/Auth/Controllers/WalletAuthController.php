<?php

declare(strict_types=1);

namespace App\Modules\Core\Auth\Controllers;

use App\Http\ApiEnvelope;
use App\Modules\Core\Auth\Services\Eip191VerificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\RateLimiter;
use RuntimeException;

class WalletAuthController extends Controller
{
    public function __construct(
        private readonly Eip191VerificationService $eip191,
    ) {}

    /**
     * POST /api/v1/projects/pangu2/auth/nonce
     *
     * Generate a time-limited nonce for EIP-191 signing.
     * Domain and chain_id are taken from server config, NOT from the client.
     */
    public function nonce(Request $request): JsonResponse
    {
        $this->rateLimitNonce($request);

        $validated = $request->validate([
            'wallet_address' => ['required', 'string', 'max:42'],
        ]);

        try {
            $walletLower = $this->eip191->normalizeAddress($validated['wallet_address']);
        } catch (RuntimeException $e) {
            return ApiEnvelope::error('INVALID_ADDRESS', $e->getMessage(), false, [], 422);
        }

        $authDomain = $this->getAuthDomain();
        $chainId    = $this->getChainId();

        // Clean expired nonces for this wallet
        \App\Modules\Core\Auth\Models\Nonce::where('wallet_address', $walletLower)
            ->where('expires_at', '<', now())
            ->delete();

        $nonce = $this->eip191->generateNonce($walletLower, $authDomain, $chainId);

        return ApiEnvelope::success([
            'nonce'          => $nonce->nonce,
            'message'        => $nonce->message,
            'wallet_address' => $nonce->wallet_address,
            'domain'         => $authDomain,
            'chain_id'       => $chainId,
            'expires_at'     => $nonce->expires_at->toIso8601String(),
        ], 'NONCE_ISSUED');
    }

    /**
     * POST /api/v1/projects/pangu2/auth/verify
     *
     * Verify EIP-191 signature with atomic nonce consumption,
     * create authenticated session, and write audit log.
     */
    public function verify(Request $request): JsonResponse
    {
        $this->rateLimitVerify($request);

        $validated = $request->validate([
            'wallet_address' => ['required', 'string', 'max:42'],
            'nonce'          => ['required', 'string', 'max:128'],
            'signature'      => ['required', 'string', 'max:256'],
        ]);

        $authDomain = $this->getAuthDomain();
        $chainId    = $this->getChainId();

        $walletLower = $this->eip191->normalizeAddress($validated['wallet_address']);

        $now = now();

        // Step 1: Verify signature & atomically consume nonce inside a transaction
        $nonceRecord = DB::transaction(function () use (
            $validated, $walletLower, $authDomain, $chainId
        ) {
            return $this->eip191->verify(
                $walletLower,
                $validated['nonce'],
                $validated['signature'],
                $authDomain,
                $chainId,
            );
        });

        if ($nonceRecord === null) {
            return ApiEnvelope::error(
                'NONCE_ALREADY_USED',
                'This nonce was already consumed by a concurrent request.',
                false,
                [],
                409,
            );
        }

        // Step 2: Write audit log inside the same or a separate transaction
        DB::table('admin_audit_logs')->insert([
            'action'      => 'WALLET_AUTHENTICATED',
            'target_type' => 'wallet',
            'ip_address'  => $request->ip(),
            'user_agent'  => $request->userAgent(),
            'after_data'  => json_encode([
                'wallet_address'   => $walletLower,
                'chain_id'         => $chainId,
                'domain'           => $authDomain,
                'authenticated_at' => $now->toIso8601String(),
            ]),
            'result'     => 'SUCCESS',
            'created_at' => $now,
        ]);

        // Step 3: Create session (after nonce consumption and audit are confirmed)
        $sessionExpiry = $now->addMinutes(config('pangu2.session_ttl_minutes', 120));

        $request->session()->regenerate();
        $request->session()->put('auth.wallet_address', $walletLower);
        $request->session()->put('auth.chain_id', $chainId);
        $request->session()->put('auth.domain', $authDomain);
        $request->session()->put('auth.authenticated_at', $now->toIso8601String());
        $request->session()->put('auth.expires_at', $sessionExpiry->toIso8601String());

        return ApiEnvelope::success([
            'wallet_address'   => $walletLower,
            'chain_id'         => $chainId,
            'domain'           => $authDomain,
            'authenticated_at' => $now->toIso8601String(),
            'expires_at'       => $sessionExpiry->toIso8601String(),
        ], 'AUTHENTICATED');
    }

    /**
     * POST /api/v1/projects/pangu2/auth/logout
     *
     * Destroy the wallet session. Audit failure does NOT block logout.
     */
    public function logout(Request $request): JsonResponse
    {
        $walletAddress = $request->session()->get('auth.wallet_address');
        $now = now();

        // Write audit log best-effort; session cleanup is guaranteed
        try {
            if ($walletAddress) {
                DB::table('admin_audit_logs')->insert([
                    'action'      => 'WALLET_LOGGED_OUT',
                    'target_type' => 'wallet',
                    'ip_address'  => $request->ip(),
                    'user_agent'  => $request->userAgent(),
                    'after_data'  => json_encode([
                        'wallet_address' => $walletAddress,
                        'logged_out_at'  => $now->toIso8601String(),
                    ]),
                    'result'     => 'SUCCESS',
                    'created_at' => $now,
                ]);
            }
        } catch (\Throwable) {
            // Audit failure must not prevent session destruction
        } finally {
            $request->session()->invalidate();
            $request->session()->regenerateToken();
        }

        return ApiEnvelope::success([
            'logged_out' => true,
        ], 'LOGGED_OUT');
    }

    // ─── Helpers ─────────────────────────────────────────────

    private function getAuthDomain(): string
    {
        return config('pangu2.auth_domain', 'localhost');
    }

    private function getChainId(): int
    {
        return (int) config('pangu2.chain_id', 31337);
    }

    // ─── Rate Limiting ────────────────────────────────────────

    /**
     * Nonce endpoint: 30 requests per minute per IP.
     */
    private function rateLimitNonce(Request $request): void
    {
        $key = 'auth-nonce:' . $request->ip();

        $executed = RateLimiter::attempt(
            $key,
            maxAttempts: 30,
            callback: fn () => true,
            decaySeconds: 60,
        );

        if (!$executed) {
            throw new \Symfony\Component\HttpKernel\Exception\TooManyRequestsHttpException(
                60,
                'Too many nonce requests. Please wait.'
            );
        }
    }

    /**
     * Verify endpoint: 5 attempts per minute per (normalized wallet + IP).
     * Using wallet+IP prevents locking a target wallet across all IPs.
     */
    private function rateLimitVerify(Request $request): void
    {
        $wallet = $request->input('wallet_address', 'unknown');
        $walletLower = strtolower(trim($wallet));
        $walletLower = str_starts_with($walletLower, '0x') ? $walletLower : '0x' . $walletLower;

        $key = 'auth-verify:' . md5($walletLower) . ':' . $request->ip();

        $executed = RateLimiter::attempt(
            $key,
            maxAttempts: 5,
            callback: fn () => true,
            decaySeconds: 60,
        );

        if (!$executed) {
            throw new \Symfony\Component\HttpKernel\Exception\TooManyRequestsHttpException(
                60,
                'Too many verification attempts. Please wait.'
            );
        }
    }
}
