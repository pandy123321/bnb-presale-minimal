<?php

declare(strict_types=1);

use App\Http\ApiEnvelope;
use App\Modules\Core\Auth\Controllers\WalletAuthController;
use App\Http\Controllers\SystemController;
use App\Http\Controllers\TradeController;
use App\Modules\Pangu2\Dividend\Controllers\DividendController;
use App\Modules\Pangu2\Buyback\Controllers\BuybackController;
use App\Modules\Pangu2\Staking\Controllers\StakingController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1/projects/pangu2')->group(function () {
    // ── System (public, no auth) ──
    Route::get('/config',        [SystemController::class, 'config']);
    Route::get('/system-status', [SystemController::class, 'systemStatus']);
    Route::get('/contracts',     [SystemController::class, 'contracts']);

    // ── Auth ──
    Route::get('/auth/csrf', function () {
        return ApiEnvelope::success(['csrf_initialized' => true], 'LIVE');
    });

    Route::post('/auth/nonce',  [WalletAuthController::class, 'nonce']);
    Route::post('/auth/verify', [WalletAuthController::class, 'verify']);
    Route::post('/auth/logout', [WalletAuthController::class, 'logout']);

    // ── Trade (public) ──
    Route::post('/quotes/buy',                     [TradeController::class, 'buyQuote'])->withoutMiddleware(\Illuminate\Foundation\Http\Middleware\VerifyCsrfToken::class);
    Route::post('/quotes/sell',                    [TradeController::class, 'sellQuote'])->withoutMiddleware(\Illuminate\Foundation\Http\Middleware\VerifyCsrfToken::class);
    Route::get('/wallets/{address}/transactions',  [TradeController::class, 'transactions']);

    // ── Dividend (public) ──
    Route::get('/dividend/epochs/current',                        [DividendController::class, 'current']);
    Route::get('/dividend/epochs/{epochId}',                      [DividendController::class, 'show']);
    Route::get('/dividend/epochs/{epochId}/proof/{address}',      [DividendController::class, 'proof']);

    // ── Support (public) ──
    Route::get('/buybacks',                      [BuybackController::class, 'index']);
    Route::get('/locker/batches',                [BuybackController::class, 'lockerBatches']);

    // ── Staking (public) ──
    Route::get('/staking/earned',               [StakingController::class, 'earned']);
    Route::get('/staking/positions',            [StakingController::class, 'positions']);
    Route::get('/staking/status',               [StakingController::class, 'status']);
});
