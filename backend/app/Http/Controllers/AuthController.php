<?php

namespace App\Http\Controllers;

use App\Models\Admin;
use Illuminate\Contracts\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function showLoginForm(): View
    {
        return view('auth.login');
    }

    public function login(Request $request): RedirectResponse
    {
        $request->validate([
            'email' => 'required|email',
            'password' => 'required|string',
        ]);

        $admin = Admin::where('email', Admin::normalizeEmail($request->email))->first();

        if (!$admin || !Hash::check($request->password, $admin->password)) {
            throw ValidationException::withMessages([
                'email' => [__('auth.failed')],
            ]);
        }

        if (!$admin->is_active) {
            return back()->withErrors(['email' => 'Account is deactivated.']);
        }

        Auth::guard('web')->login($admin);
        $request->session()->regenerate();

        $admin->last_login_at = now();
        $admin->save();

        return redirect()->intended(route('admin.dashboard'));
    }

    public function logout(Request $request): RedirectResponse|\Illuminate\Http\JsonResponse
    {
        Auth::guard('web')->logout();

        $request->session()->invalidate();
        $request->session()->regenerateToken();

        if ($request->expectsJson() || $request->is('admin-api/*')) {
            return \App\Http\ApiEnvelope::success(['logged_out' => true], 'LIVE');
        }

        return redirect()->route('login');
    }

    /**
     * POST /admin-api/v1/projects/pangu2/auth/login — JSON login.
     */
    public function apiLogin(Request $request): \Illuminate\Http\JsonResponse
    {
        $request->validate([
            'email' => 'required|email',
            'password' => 'required|string',
        ]);

        $admin = Admin::where('email', Admin::normalizeEmail($request->email))->first();

        if (!$admin || !Hash::check($request->password, $admin->password)) {
            return \App\Http\ApiEnvelope::error('AUTH_FAILED', 'Invalid credentials.', false, [], 401);
        }

        if (!$admin->is_active) {
            return \App\Http\ApiEnvelope::error('AUTH_FORBIDDEN', 'Account is deactivated.', false, [], 403);
        }

        Auth::guard('web')->login($admin);
        $request->session()->regenerate();

        $admin->last_login_at = now();
        $admin->save();

        return \App\Http\ApiEnvelope::success([
            'admin' => ['id' => $admin->id, 'name' => $admin->name, 'email' => $admin->email, 'role' => $admin->role],
        ], 'LIVE');
    }
}
