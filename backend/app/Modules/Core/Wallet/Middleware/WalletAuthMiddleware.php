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

        if (!$walletAddress) {
            return ApiEnvelope::error(
                'UNAUTHENTICATED',
                'Wallet authentication required.',
                false,
                [],
                401,
            );
        }

        return $next($request);
    }
}
