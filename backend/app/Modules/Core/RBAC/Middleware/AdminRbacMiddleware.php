<?php

declare(strict_types=1);

namespace App\Modules\Core\RBAC\Middleware;

use App\Http\ApiEnvelope;
use App\Modules\Core\RBAC\RbacMatrix;
use Closure;
use Illuminate\Http\Request;

/**
 * API-oriented RBAC middleware.
 *
 * Unlike the web-oriented RoleMiddleware, this returns JSON via ApiEnvelope
 * and uses the formal RbacMatrix for permission checks.
 *
 * Usage: Route::middleware('rbac:jobs.retry')->group(...)
 */
class AdminRbacMiddleware
{
    public function handle(Request $request, Closure $next, string $permission): mixed
    {
        $admin = $request->user();

        if (!$admin) {
            return ApiEnvelope::error(
                'AUTH_UNAUTHORIZED',
                'Not authenticated. Please log in.',
                false,
                [],
                401,
            );
        }

        if (!$admin->is_active) {
            return ApiEnvelope::error(
                'AUTH_FORBIDDEN',
                'Account is deactivated.',
                false,
                [],
                403,
            );
        }

        if (!RbacMatrix::can($admin->role, $permission)) {
            return ApiEnvelope::error(
                'AUTH_FORBIDDEN',
                "Insufficient permissions. Required: {$permission}.",
                false,
                ['required_permission' => $permission, 'your_role' => $admin->role],
                403,
            );
        }

        return $next($request);
    }
}
