<?php

use App\Http\Controllers\AuthController;
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

Route::prefix('admin-api/v1/projects/pangu2')->middleware(['auth:web', 'rbac:dashboard.read'])->group(function () {
    Route::get('/dashboard',  [AdminDashboardController::class, 'dashboard']);
    Route::get('/contracts',  [AdminDashboardController::class, 'contracts']);
    Route::get('/jobs',       [AdminJobsController::class, 'index']);
    Route::post('/jobs/{taskName}/retry', [AdminJobsController::class, 'retry']);
    Route::get('/audit-logs',       [AdminAuditController::class, 'index']);
    Route::get('/audit-logs/{id}',  [AdminAuditController::class, 'show']);
});
