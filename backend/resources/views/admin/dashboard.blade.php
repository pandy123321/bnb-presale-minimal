<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>BNB Presale - Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: system-ui, -apple-system, sans-serif; background: #f5f5f5; min-height: 100vh; }
        .header { background: #1a1a1a; color: #fff; padding: 1rem 2rem; display: flex; justify-content: space-between; align-items: center; }
        .header h1 { font-size: 1.2rem; }
        .user-info { display: flex; align-items: center; gap: 1rem; }
        .logout-btn { background: transparent; border: 1px solid #fff; color: #fff; padding: 0.4rem 1rem; border-radius: 4px; cursor: pointer; font-size: 0.85rem; }
        .logout-btn:hover { background: #fff; color: #1a1a1a; }
        .content { max-width: 1200px; margin: 2rem auto; padding: 0 1rem; }
        .card { background: #fff; border-radius: 8px; box-shadow: 0 1px 6px rgba(0,0,0,0.08); padding: 1.5rem; margin-bottom: 1.5rem; }
        .card h2 { font-size: 1.1rem; margin-bottom: 1rem; color: #1a1a1a; }
        .placeholder { color: #999; font-size: 0.9rem; }
    </style>
</head>
<body>
    <div class="header">
        <h1>BNB Presale Admin</h1>
        <div class="user-info">
            <span>{{ Auth::user()->name }} ({{ Auth::user()->role }})</span>
            <form method="POST" action="{{ route('logout') }}" style="display:inline">
                @csrf
                <button type="submit" class="logout-btn">Sign Out</button>
            </form>
        </div>
    </div>

    <div class="content">
        <div class="card">
            <h2>Dashboard</h2>
            <p class="placeholder">Contract status and purchase data will appear here once the event sync service is implemented.</p>
        </div>
    </div>
</body>
</html>
