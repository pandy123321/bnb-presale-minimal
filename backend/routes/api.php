<?php

declare(strict_types=1);

use App\Http\ApiEnvelope;
use App\Modules\Core\Auth\Controllers\WalletAuthController;
use App\Http\Controllers\SystemController;
use App\Http\Controllers\TradeController;
use App\Modules\Pangu2\Dividend\Controllers\DividendController;
use App\Modules\Pangu2\Buyback\Controllers\BuybackController;
use App\Modules\Pangu2\Admin\Controllers\AdminDashboardController;
use App\Modules\Pangu2\Admin\Controllers\AdminJobsController;
use App\Modules\Pangu2\Admin\Controllers\AdminAuditController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1/projects/pangu2')->group(function () {
    // ── System (public, no auth) ──
    Route::get('/config',        [SystemController::class, 'config']);
    Route::get('/system-status', [SystemController::class, 'systemStatus']);
    Route::get('/contracts',     [SystemController::class, 'contracts']);

    // ── Auth ──
    Route::get('/auth/csrf', function () {
        return ApiEnvelope::success(['csrf_initialized' => true], 'MOCK_DATA');
    });

    Route::post('/auth/nonce',  [WalletAuthController::class, 'nonce']);
    Route::post('/auth/verify', [WalletAuthController::class, 'verify']);
    Route::post('/auth/logout', [WalletAuthController::class, 'logout']);

    // ── Trade (public, return MOCK_DATA until ABI available) ──
    Route::post('/quotes/buy',                     [TradeController::class, 'buyQuote']);
    Route::post('/quotes/sell',                    [TradeController::class, 'sellQuote']);
    Route::get('/wallets/{address}/transactions',  [TradeController::class, 'transactions']);

    // ── Dividend (public) ──
    Route::get('/dividend/epochs/current',                        [DividendController::class, 'current']);
    Route::get('/dividend/epochs/{epochId}',                      [DividendController::class, 'show']);
    Route::get('/dividend/epochs/{epochId}/proof/{address}',      [DividendController::class, 'proof']);

    // ── Support (public) ──
    Route::get('/buybacks',                      [BuybackController::class, 'index']);
    Route::get('/locker/batches',                [BuybackController::class, 'lockerBatches']);
});

// ═══ Admin API ═══════════════════════════════════════════
Route::prefix('admin-api/v1/projects/pangu2')
    ->middleware(['auth:sanctum', 'rbac:dashboard.read'])
    ->group(function () {
        // Dashboard + Contracts (all admin roles)
        Route::get('/dashboard', [AdminDashboardController::class, 'dashboard']);
        Route::get('/contracts', [AdminDashboardController::class, 'contracts']);
    });

Route::prefix('admin-api/v1/projects/pangu2')
    ->middleware(['auth:sanctum', 'rbac:jobs.read'])
    ->group(function () {
        // Jobs — view
        Route::get('/jobs', [AdminJobsController::class, 'index']);
    });

Route::prefix('admin-api/v1/projects/pangu2')
    ->middleware(['auth:sanctum', 'rbac:jobs.retry'])
    ->group(function () {
        // Jobs — retry (SUPER_ADMIN + OPERATOR)
        Route::post('/jobs/{taskName}/retry', [AdminJobsController::class, 'retry']);
    });

Route::prefix('admin-api/v1/projects/pangu2')
    ->middleware(['auth:sanctum', 'rbac:audit.read'])
    ->group(function () {
        // Audit — read (SUPER_ADMIN + AUDITOR)
        Route::get('/audit-logs', [AdminAuditController::class, 'index']);
        Route::get('/audit-logs/{id}', [AdminAuditController::class, 'show']);
    });
