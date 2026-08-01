<?php

declare(strict_types=1);

namespace App\Modules\Core\Auth\Controllers;

use App\Http\ApiEnvelope;
use App\Modules\Core\Auth\Services\AuthenticationException;
use App\Modules\Core\Auth\Services\Eip191VerificationService;
use App\Modules\Core\Auth\Services\InvalidSignatureException;
use App\Modules\Core\Auth\Services\NonceAlreadyUsedException;
use App\Modules\Core\Auth\Services\NonceExpiredException;
use App\Modules\Core\Auth\Services\NonceNotFoundException;
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

        $domain  = config('pangu2.auth_domain', 'localhost');
        $chainId = (int) config('pangu2.chain_id', 31337);

        \App\Modules\Core\Auth\Models\Nonce::where('wallet_address', $walletLower)
            ->where('expires_at', '<', now())
            ->delete();

        $nonce = $this->eip191->generateNonce($walletLower, $domain, $chainId);

        return ApiEnvelope::success([
            'nonce'          => $nonce->nonce,
            'message'        => $nonce->message,
            'wallet_address' => $nonce->wallet_address,
            'domain'         => $domain,
            'chain_id'       => $chainId,
            'expires_at'     => $nonce->expires_at->toIso8601String(),
        ], 'LIVE');
    }

    public function verify(Request $request): JsonResponse
    {
        $this->rateLimitVerify($request);

        $validated = $request->validate([
            'wallet_address' => ['required', 'string', 'max:42'],
            'nonce'          => ['required', 'string', 'max:128'],
            'signature'      => ['required', 'string', 'max:256'],
        ]);

        $domain  = config('pangu2.auth_domain', 'localhost');
        $chainId = (int) config('pangu2.chain_id', 31337);

        try {
            $walletLower = $this->eip191->normalizeAddress($validated['wallet_address']);
            $this->eip191->validateSignatureFormat($validated['signature']);
            $record    = $this->eip191->validateNonceRecord($walletLower, $validated['nonce'], $domain, $chainId);
            $recovered = $this->eip191->recoverSigner($record->message, $validated['signature']);
        } catch (NonceExpiredException $e) {
            return ApiEnvelope::error('NONCE_EXPIRED', 'Nonce has expired. Request a new one.', false, [], 401);
        } catch (NonceAlreadyUsedException $e) {
            return ApiEnvelope::error('NONCE_ALREADY_USED', 'Nonce has already been used.', false, [], 409);
        } catch (NonceNotFoundException $e) {
            return ApiEnvelope::error('NONCE_INVALID', 'Nonce not found or does not belong to wallet.', false, [], 401);
        } catch (InvalidSignatureException $e) {
            return ApiEnvelope::error('INVALID_SIGNATURE', 'Signature verification failed.', false, [], 401);
        } catch (AuthenticationException $e) {
            return ApiEnvelope::error('AUTHENTICATION_FAILED', 'Wallet authentication failed.', false, [], 401);
        }
        // Infrastructure exceptions NOT caught here — handled by global exception handler as 500.

        if ($recovered !== $walletLower) {
            return ApiEnvelope::error('VERIFICATION_FAILED', 'Signature verification failed.', false, [], 401);
        }

        $authenticatedAt = now();
        $sessionExpiry   = $authenticatedAt->copy()->addMinutes((int) config('pangu2.session_ttl_minutes', 120));

        $result = DB::transaction(function () use ($record, $request, $walletLower, $chainId, $domain, $authenticatedAt): array {
            $status = $this->eip191->consumeNonceAtomic($record->id);

            if ($status === 'consumed') {
                DB::table('admin_audit_logs')->insert([
                    'action'      => 'WALLET_AUTHENTICATED',
                    'target_type' => 'wallet',
                    'ip_address'  => $request->ip(),
                    'user_agent'  => $request->userAgent(),
                    'after_data'  => json_encode([
                        'wallet_address'   => $walletLower,
                        'chain_id'         => $chainId,
                        'domain'           => $domain,
                        'authenticated_at' => $authenticatedAt->toIso8601String(),
                    ]),
                    'result'     => 'SUCCESS',
                    'created_at' => $authenticatedAt,
                ]);

                return ['consumed' => true];
            }

            return ['consumed' => false, 'status' => $status];
        });

        if (!$result['consumed']) {
            $status  = $result['status'] ?? 'already_used';
            $code    = $status === 'expired' ? 'NONCE_EXPIRED' : 'NONCE_ALREADY_USED';
            $message = $status === 'expired'
                ? 'Nonce expired during verification. Request a new one.'
                : 'Nonce was already consumed.';
            $http    = $status === 'expired' ? 401 : 409;

            return ApiEnvelope::error($code, $message, false, [], $http);
        }

        try {
            $request->session()->regenerate();
            $request->session()->put('auth.wallet_address', $walletLower);
            $request->session()->put('auth.chain_id', $chainId);
            $request->session()->put('auth.domain', $domain);
            $request->session()->put('auth.authenticated_at', $authenticatedAt->toIso8601String());
            $request->session()->put('auth.expires_at', $sessionExpiry->toIso8601String());
            $request->session()->save();
        } catch (\Throwable $e) {
            $request->session()->invalidate();
            Log::error('Wallet auth session creation failed', [
                'wallet_address'  => $walletLower,
                'exception_class' => $e::class,
            ]);

            return ApiEnvelope::error(
                'SESSION_FAILED',
                'Authentication succeeded but session could not be created. Please request a new nonce.',
                false,
                ['next_action' => 'REQUEST_NEW_NONCE'],
                503,
            );
        }

        return ApiEnvelope::success([
            'auth_status'      => 'AUTHENTICATED',
            'wallet_address'   => $walletLower,
            'chain_id'         => $chainId,
            'domain'           => $domain,
            'authenticated_at' => $authenticatedAt->toIso8601String(),
            'expires_at'       => $sessionExpiry->toIso8601String(),
        ], 'LIVE');
    }

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
                'wallet_address'  => $walletAddress,
                'exception_class' => $e::class,
            ]);
        } finally {
            $request->session()->invalidate();
            $request->session()->regenerateToken();
        }

        return ApiEnvelope::success([
            'auth_status' => 'LOGGED_OUT',
            'logged_out'  => true,
        ], 'LIVE');
    }

    private function rateLimitNonce(Request $request): void
    {
        $ok = RateLimiter::attempt(
            'auth-nonce:' . $request->ip(),
            maxAttempts: 30,
            callback: fn () => true,
            decaySeconds: 60,
        );

        if (!$ok) {
            throw new TooManyRequestsHttpException(60, 'Too many nonce requests.');
        }
    }

    private function rateLimitVerify(Request $request): void
    {
        $w = strtolower(trim((string) $request->input('wallet_address', 'unknown')));
        if (!str_starts_with($w, '0x')) {
            $w = '0x' . $w;
        }

        $ok = RateLimiter::attempt(
            'auth-verify:' . md5($w) . ':' . $request->ip(),
            maxAttempts: 5,
            callback: fn () => true,
            decaySeconds: 60,
        );

        if (!$ok) {
            throw new TooManyRequestsHttpException(60, 'Too many verification attempts.');
        }
    }
}
