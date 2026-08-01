<?php

declare(strict_types=1);

use App\Http\ApiEnvelope;
use App\Modules\Core\Auth\Controllers\WalletAuthController;
use App\Modules\Core\Wallet\Middleware\WalletAuthMiddleware;
use Illuminate\Support\Facades\Route;

Route::prefix('v1/projects/pangu2')->group(function () {
    Route::get('/auth/csrf', function () {
        return ApiEnvelope::success(['csrf_initialized' => true], 'LIVE');
    });

    Route::post('/auth/nonce', [WalletAuthController::class, 'nonce']);
    Route::post('/auth/verify', [WalletAuthController::class, 'verify']);

    Route::middleware(WalletAuthMiddleware::class)->group(function () {
        Route::post('/auth/logout', [WalletAuthController::class, 'logout']);

        Route::get('/auth/session', function (\Illuminate\Http\Request $request) {
            return ApiEnvelope::success([
                'auth_status'      => 'SESSION_ACTIVE',
                'wallet_address'   => $request->session()->get('auth.wallet_address'),
                'chain_id'         => $request->session()->get('auth.chain_id'),
                'domain'           => $request->session()->get('auth.domain'),
                'authenticated_at' => $request->session()->get('auth.authenticated_at'),
                'expires_at'       => $request->session()->get('auth.expires_at'),
            ], 'LIVE');
        });
    });
});
