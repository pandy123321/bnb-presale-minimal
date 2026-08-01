<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class RoleMiddleware
{
    public function handle(Request $request, Closure $next, string ...$roles): mixed
    {
        $admin = $request->user();

        if (!$admin || !$admin->is_active) {
            return response()->json(['message' => 'Unauthenticated.'], 401);
        }

        if (!in_array($admin->role, $roles, true)) {
            return response()->json(['message' => 'Forbidden. Insufficient permissions.'], 403);
        }

        return $next($request);
    }
}
