<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class RoleMiddleware
{
    public function handle(Request $request, Closure $next, string ...$roles): mixed
    {
        $admin = $request->user();

        if (!$admin) {
            return redirect()->route('login');
        }

        if (!$admin->is_active) {
            Auth::guard('web')->logout();

            $request->session()->invalidate();
            $request->session()->regenerateToken();

            return redirect()->route('login')->withErrors(['email' => 'Account is deactivated.']);
        }

        if (!in_array($admin->role, $roles, true)) {
            abort(403, 'Forbidden. Insufficient permissions.');
        }

        return $next($request);
    }
}
