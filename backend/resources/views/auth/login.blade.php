<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>BNB Presale - Admin Login</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: system-ui, -apple-system, sans-serif; background: #f5f5f5; display: flex; align-items: center; justify-content: center; min-height: 100vh; }
        .login-box { background: #fff; padding: 2.5rem; border-radius: 8px; box-shadow: 0 2px 12px rgba(0,0,0,0.1); width: 100%; max-width: 400px; }
        h1 { font-size: 1.5rem; margin-bottom: 0.5rem; color: #1a1a1a; }
        p.subtitle { color: #666; margin-bottom: 1.5rem; font-size: 0.9rem; }
        label { display: block; margin-bottom: 0.35rem; font-weight: 500; font-size: 0.9rem; }
        input { width: 100%; padding: 0.6rem 0.75rem; border: 1px solid #ddd; border-radius: 4px; font-size: 0.95rem; margin-bottom: 0.75rem; }
        input:focus { outline: none; border-color: #3b82f6; box-shadow: 0 0 0 3px rgba(59,130,246,0.1); }
        button { width: 100%; padding: 0.65rem; background: #3b82f6; color: #fff; border: none; border-radius: 4px; font-size: 0.95rem; cursor: pointer; font-weight: 500; }
        button:hover { background: #2563eb; }
        .error { color: #dc2626; font-size: 0.85rem; margin-bottom: 0.5rem; }
        .error-list { background: #fef2f2; border: 1px solid #fecaca; padding: 0.75rem; border-radius: 4px; margin-bottom: 1rem; }
    </style>
</head>
<body>
    <div class="login-box">
        <h1>BNB Presale Admin</h1>
        <p class="subtitle">Sign in to manage the presale system</p>

        @if ($errors->any())
            <div class="error-list">
                @foreach ($errors->all() as $error)
                    <div class="error">{{ $error }}</div>
                @endforeach
            </div>
        @endif

        <form method="POST" action="{{ route('login') }}">
            @csrf
            <label for="email">Email</label>
            <input type="email" name="email" id="email" value="{{ old('email') }}" required autofocus>

            <label for="password">Password</label>
            <input type="password" name="password" id="password" required>

            <button type="submit">Sign In</button>
        </form>
    </div>
</body>
</html>
