<?php

namespace App\Http\Controllers;

use App\Models\Admin;
use Illuminate\Contracts\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;
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

        $key = 'login:' . strtolower($request->email) . '|' . $request->ip();
        $maxAttempts = 5;

        if (RateLimiter::tooManyAttempts($key, $maxAttempts)) {
            $seconds = RateLimiter::availableIn($key);
            throw ValidationException::withMessages([
                'email' => [__('auth.throttle', ['seconds' => $seconds])],
            ]);
        }

        $admin = Admin::where('email', strtolower($request->email))->first();

        if (!$admin || !Hash::check($request->password, $admin->password)) {
            RateLimiter::hit($key, 60);
            throw ValidationException::withMessages([
                'email' => [__('auth.failed')],
            ]);
        }

        if (!$admin->is_active) {
            return back()->withErrors(['email' => 'Account is deactivated.']);
        }

        RateLimiter::clear($key);

        Auth::guard('web')->login($admin);
        $request->session()->regenerate();

        $admin->last_login_at = now();
        $admin->save();

        return redirect()->intended(route('admin.dashboard'));
    }

    public function logout(Request $request): RedirectResponse
    {
        Auth::guard('web')->logout();

        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('login');
    }
}
