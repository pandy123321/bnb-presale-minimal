<?php

declare(strict_types=1);

namespace App\Modules\Core\Auth\Controllers;

use App\Http\ApiEnvelope;
use App\Modules\Core\Auth\Services\Eip191VerificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\RateLimiter;
use RuntimeException;
use Symfony\Component\HttpKernel\Exception\TooManyRequestsHttpException;

class WalletAuthController extends Controller
{
    public function __construct(
        private readonly Eip191VerificationService $eip191,
    ) {}

    /**
     * POST /api/v1/projects/pangu2/auth/nonce
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

        $authDomain = config('pangu2.auth_domain', 'localhost');
        $chainId    = (int) config('pangu2.chain_id', 31337);

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
        ]);
    }

    /**
     * POST /api/v1/projects/pangu2/auth/verify
     *
     * Flow:
     * 1. Rate limit check (outside any DB transaction)
     * 2. Validate nonce record + signature recovery (outside DB transaction, CPU work)
     * 3. Atomic nonce consumption + audit insert (inside ONE DB transaction)
     * 4. Session creation (after transaction commit)
     */
    public function verify(Request $request): JsonResponse
    {
        $this->rateLimitVerify($request);

        $validated = $request->validate([
            'wallet_address' => ['required', 'string', 'max:42'],
            'nonce'          => ['required', 'string', 'max:128'],
            'signature'      => ['required', 'string', 'max:256'],
        ]);

        $authDomain = config('pangu2.auth_domain', 'localhost');
        $chainId    = (int) config('pangu2.chain_id', 31337);

        // ---- Phase 1 (outside transaction): validate + crypto ----

        try {
            $walletLower = $this->eip191->normalizeAddress($validated['wallet_address']);
            $this->eip191->validateSignatureFormat($validated['signature']);

            $record = $this->eip191->validateNonceRecord(
                $walletLower,
                $validated['nonce'],
                $authDomain,
                $chainId,
            );

            $recovered = $this->eip191->recoverSigner($record->message, $validated['signature']);
        } catch (RuntimeException $e) {
            return ApiEnvelope::error('VERIFICATION_FAILED', $e->getMessage(), false, [], 401);
        }

        if ($recovered !== $walletLower) {
            return ApiEnvelope::error('VERIFICATION_FAILED', 'Signature verification failed.', false, [], 401);
        }

        // ---- Phase 2 (inside transaction): atomic consume + audit ----

        $authenticatedAt = now();
        $sessionExpiry   = $authenticatedAt->copy()->addMinutes((int) config('pangu2.session_ttl_minutes', 120));

        $consumed = DB::transaction(function () use ($record, $request, $walletLower, $chainId, $authDomain, $authenticatedAt): bool {
            $ok = $this->eip191->consumeNonceAtomic($record->id);

            if (!$ok) {
                return false;
            }

            DB::table('admin_audit_logs')->insert([
                'action'      => 'WALLET_AUTHENTICATED',
                'target_type' => 'wallet',
                'ip_address'  => $request->ip(),
                'user_agent'  => $request->userAgent(),
                'after_data'  => json_encode([
                    'wallet_address'   => $walletLower,
                    'chain_id'         => $chainId,
                    'domain'           => $authDomain,
                    'authenticated_at' => $authenticatedAt->toIso8601String(),
                ]),
                'result'     => 'SUCCESS',
                'created_at' => $authenticatedAt,
            ]);

            return true;
        });

        if (!$consumed) {
            return ApiEnvelope::error(
                'NONCE_ALREADY_USED',
                'This nonce was already consumed.',
                false,
                [],
                409,
            );
        }

        // ---- Phase 3 (after commit): create session ----

        $request->session()->regenerate();
        $request->session()->put('auth.wallet_address', $walletLower);
        $request->session()->put('auth.chain_id', $chainId);
        $request->session()->put('auth.domain', $authDomain);
        $request->session()->put('auth.authenticated_at', $authenticatedAt->toIso8601String());
        $request->session()->put('auth.expires_at', $sessionExpiry->toIso8601String());

        return ApiEnvelope::success([
            'auth_status'      => 'AUTHENTICATED',
            'wallet_address'   => $walletLower,
            'chain_id'         => $chainId,
            'domain'           => $authDomain,
            'authenticated_at' => $authenticatedAt->toIso8601String(),
            'expires_at'       => $sessionExpiry->toIso8601String(),
        ]);
    }

    /**
     * POST /api/v1/projects/pangu2/auth/logout
     */
    public function logout(Request $request): JsonResponse
    {
        $walletAddress = $request->session()->get('auth.wallet_address');

        try {
            if ($walletAddress) {
                DB::table('admin_audit_logs')->insert([
                    'action'      => 'WALLET_LOGGED_OUT',
                    'target_type' => 'wallet',
                    'ip_address'  => $request->ip(),
                    'user_agent'  => $request->userAgent(),
                    'after_data'  => json_encode([
                        'wallet_address' => $walletAddress,
                        'logged_out_at'  => now()->toIso8601String(),
                    ]),
                    'result'     => 'SUCCESS',
                    'created_at' => now(),
                ]);
            }
        } catch (\Throwable $e) {
            Log::warning('Wallet logout audit failed', [
                'wallet_address'   => $walletAddress,
                'exception_class'  => $e::class,
            ]);
        } finally {
            $request->session()->invalidate();
            $request->session()->regenerateToken();
        }

        return ApiEnvelope::success([
            'auth_status' => 'LOGGED_OUT',
            'logged_out'  => true,
        ]);
    }

    // ── Helpers ──────────────────────────────────────────

    private function rateLimitNonce(Request $request): void
    {
        $executed = RateLimiter::attempt(
            'auth-nonce:' . $request->ip(),
            maxAttempts: 30,
            callback: fn () => true,
            decaySeconds: 60,
        );

        if (!$executed) {
            throw new TooManyRequestsHttpException(60, 'Too many nonce requests.');
        }
    }

    private function rateLimitVerify(Request $request): void
    {
        $wallet = $request->input('wallet_address', 'unknown');
        $walletLower = strtolower(trim((string) $wallet));
        if (!str_starts_with($walletLower, '0x')) {
            $walletLower = '0x' . $walletLower;
        }

        $key = 'auth-verify:' . md5($walletLower) . ':' . $request->ip();

        $executed = RateLimiter::attempt(
            $key,
            maxAttempts: 5,
            callback: fn () => true,
            decaySeconds: 60,
        );

        if (!$executed) {
            throw new TooManyRequestsHttpException(60, 'Too many verification attempts.');
        }
    }
}
