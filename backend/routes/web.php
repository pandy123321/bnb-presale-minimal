<?php

use App\Http\Controllers\AuthController;
use App\Modules\Core\ContractRegistry\Controllers\ContractRegistryController;
use App\Modules\Pangu2\Admin\Controllers\AdminDashboardController;
use App\Modules\Pangu2\Admin\Controllers\AdminJobsController;
use App\Modules\Pangu2\Admin\Controllers\AdminAuditController;
use Illuminate\Support\Facades\Route;

Route::middleware('guest')->group(function () {
    Route::get('/login', [AuthController::class, 'showLoginForm'])->name('login');
    Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:login');
});

Route::middleware('auth:web')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout'])->name('logout');
    Route::get('/admin/dashboard', fn () => view('admin.dashboard'))->name('admin.dashboard');
});

Route::prefix('admin-api/v1/projects/pangu2')->group(function () {
    // CSRF token — accessible to guest (needed before login)
    Route::get('/csrf-token', function (\Illuminate\Http\Request $request) {
        return \App\Http\ApiEnvelope::success([
            'csrf_token' => $request->session()->token(),
        ], 'LIVE');
    });

    // Auth — JSON endpoints (no RBAC, guest for login, web guard for me/logout)
    Route::post('/auth/login', [AuthController::class, 'apiLogin']);
    Route::middleware('auth:web')->group(function () {
        Route::get('/auth/me', fn (\Illuminate\Http\Request $r) => \App\Http\ApiEnvelope::success([
            'admin' => ['id' => $r->user()->id, 'name' => $r->user()->name, 'email' => $r->user()->email, 'role' => $r->user()->role],
        ], 'LIVE'));
        Route::post('/auth/logout', [AuthController::class, 'logout']);
    });

    // Dashboard + Contracts — all admin roles
    Route::middleware(['auth:web', 'rbac:dashboard.read'])->group(function () {
        Route::get('/dashboard', [AdminDashboardController::class, 'dashboard']);
    });
    Route::middleware('rbac:contracts.read')->group(function () {
        Route::get('/contracts', [AdminDashboardController::class, 'contracts']);
    });
    // Jobs — view all, retry SUPER_ADMIN+OPERATOR only
    Route::middleware('rbac:jobs.read')->group(function () {
        Route::get('/jobs', [AdminJobsController::class, 'index']);
    });
    Route::middleware('rbac:jobs.retry')->group(function () {
        Route::post('/jobs/{taskName}/retry', [AdminJobsController::class, 'retry'])->where('taskName', '[a-zA-Z0-9_-]+');
    });
    // Audit — SUPER_ADMIN+AUDITOR only
    Route::middleware('rbac:audit.read')->group(function () {
        Route::get('/audit-logs', [AdminAuditController::class, 'index']);
        Route::get('/audit-logs/{id}', [AdminAuditController::class, 'show'])->whereNumber('id');
    });

    // ── Staking (admin) ──
    Route::middleware(['auth:web', 'rbac:staking.manage'])->group(function () {
        Route::post('/staking/fund-rewards', [\App\Modules\Pangu2\Staking\Controllers\StakingController::class, 'fundRewards']);
        Route::post('/staking/set-reward-rate', [\App\Modules\Pangu2\Staking\Controllers\StakingController::class, 'setRewardRate']);
    });
    Route::middleware('rbac:staking.read')->group(function () {
        Route::get('/staking/coverage', [\App\Modules\Pangu2\Staking\Controllers\StakingController::class, 'coverage']);
    });

    // ── Contract Registry CRUD (SUPER_ADMIN only) ──
    Route::middleware(['auth:web', 'rbac:contracts.manage'])->group(function () {
        Route::get('/contract-registry', [ContractRegistryController::class, 'index']);
        Route::post('/contract-registry', [ContractRegistryController::class, 'store']);
        Route::delete('/contract-registry/{id}', [ContractRegistryController::class, 'destroy'])->whereNumber('id');
        Route::post('/contract-registry/resync', [ContractRegistryController::class, 'resync']);
    });
});
