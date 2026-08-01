<?php

declare(strict_types=1);

namespace App\Modules\Core\Wallet\Middleware;

use App\Http\ApiEnvelope;
use Closure;
use Illuminate\Http\Request;

class WalletAuthMiddleware
{
    public function handle(Request $request, Closure $next): mixed
    {
        $walletAddress = $request->session()->get('auth.wallet_address');
        $expiresAt     = $request->session()->get('auth.expires_at');
        $sessionChainId = $request->session()->get('auth.chain_id');

        if (!$walletAddress) {
            return ApiEnvelope::error(
                'UNAUTHENTICATED',
                'Wallet authentication required.',
                false,
                [],
                401,
            );
        }

        // Check session expiry
        if ($expiresAt && now()->gte($expiresAt)) {
            $request->session()->invalidate();
            $request->session()->regenerateToken();

            return ApiEnvelope::error(
                'SESSION_EXPIRED',
                'Wallet session has expired. Please re-authenticate.',
                false,
                [],
                401,
            );
        }

        // Verify chain context still matches current environment
        $currentChainId = (int) config('pangu2.chain_id', 31337);
        if ($sessionChainId !== null && $sessionChainId !== $currentChainId) {
            $request->session()->invalidate();
            $request->session()->regenerateToken();

            return ApiEnvelope::error(
                'CHAIN_MISMATCH',
                'Chain configuration changed. Please re-authenticate.',
                false,
                [],
                401,
            );
        }

        return $next($request);
    }
}
