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
     */
    public function nonce(Request $request): JsonResponse
    {
        $this->rateLimitNonce($request);

        $validated = $request->validate([
            'wallet_address' => ['required', 'string'],
            'domain'         => ['required', 'string', 'max:255'],
            'chain_id'       => ['required', 'integer', 'min:1'],
        ]);

        try {
            $walletLower = $this->eip191->normalizeAddress($validated['wallet_address']);
        } catch (RuntimeException $e) {
            return ApiEnvelope::error('INVALID_ADDRESS', $e->getMessage(), false, [], 422);
        }

        // Remove expired nonces for this wallet
        \App\Modules\Core\Auth\Models\Nonce::where('wallet_address', $walletLower)
            ->where('expires_at', '<', now())
            ->delete();

        $nonce = $this->eip191->generateNonce(
            $walletLower,
            $validated['domain'],
            (int) $validated['chain_id'],
        );

        return ApiEnvelope::success([
            'nonce'          => $nonce->nonce,
            'message'        => $nonce->message,
            'wallet_address' => $nonce->wallet_address,
            'expires_at'     => $nonce->expires_at->toIso8601String(),
        ], 'NONCE_ISSUED');
    }

    /**
     * POST /api/v1/projects/pangu2/auth/verify
     *
     * Verify EIP-191 signature and create authenticated session.
     */
    public function verify(Request $request): JsonResponse
    {
        $this->rateLimitVerify($request);

        $validated = $request->validate([
            'wallet_address' => ['required', 'string'],
            'nonce'          => ['required', 'string'],
            'signature'      => ['required', 'string'],
            'domain'         => ['required', 'string', 'max:255'],
            'chain_id'       => ['required', 'integer', 'min:1'],
        ]);

        try {
            $this->eip191->verify(
                $validated['wallet_address'],
                $validated['nonce'],
                $validated['signature'],
                $validated['domain'],
                (int) $validated['chain_id'],
            );
        } catch (RuntimeException $e) {
            return ApiEnvelope::error('VERIFICATION_FAILED', $e->getMessage(), false, [], 401);
        }

        $walletLower = $this->eip191->normalizeAddress($validated['wallet_address']);
        $now = now();

        $request->session()->regenerate();
        $request->session()->put('auth.wallet_address', $walletLower);
        $request->session()->put('auth.authenticated_at', $now->toIso8601String());

        DB::table('admin_audit_logs')->insert([
            'action'      => 'WALLET_AUTHENTICATED',
            'target_type' => 'wallet',
            'ip_address'  => $request->ip(),
            'user_agent'  => $request->userAgent(),
            'after_data'  => json_encode([
                'wallet_address'   => $walletLower,
                'chain_id'         => (int) $validated['chain_id'],
                'authenticated_at' => $now->toIso8601String(),
            ]),
            'result'     => 'SUCCESS',
            'created_at' => $now,
        ]);

        return ApiEnvelope::success([
            'wallet_address'   => $walletLower,
            'authenticated_at' => $now->toIso8601String(),
        ], 'AUTHENTICATED');
    }

    /**
     * POST /api/v1/projects/pangu2/auth/logout
     */
    public function logout(Request $request): JsonResponse
    {
        $walletAddress = $request->session()->get('auth.wallet_address');
        $now = now();

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

        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return ApiEnvelope::success([
            'logged_out' => true,
        ], 'LOGGED_OUT');
    }

    private function rateLimitNonce(Request $request): void
    {
        $executed = RateLimiter::attempt(
            'auth-nonce:' . $request->ip(),
            maxAttempts: 30,
            callback: fn () => true,
            decaySeconds: 60,
        );

        if (!$executed) {
            abort(429, 'Too many nonce requests. Please wait.');
        }
    }

    private function rateLimitVerify(Request $request): void
    {
        $wallet = $request->input('wallet_address', 'unknown');
        $executed = RateLimiter::attempt(
            'auth-verify:' . md5(strtolower($wallet)),
            maxAttempts: 5,
            callback: fn () => true,
            decaySeconds: 60,
        );

        if (!$executed) {
            abort(429, 'Too many verification attempts. Please wait.');
        }
    }
}
