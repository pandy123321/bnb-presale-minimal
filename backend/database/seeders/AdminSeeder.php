<?php

namespace Database\Seeders;

use App\Models\Admin;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;

class AdminSeeder extends Seeder
{
    public function run(): void
    {
        $env = config('app.env', 'local');
        $isSafe = in_array($env, ['local', 'ci', 'testing'], true);

        $password = env('SEED_ADMIN_PASSWORD');

        if (empty($password) && !$isSafe) {
            Log::critical('SEED_ADMIN_PASSWORD is empty. Refusing to seed default admin on non-local environment.');
            return;
        }

        if (empty($password)) {
            $password = bin2hex(random_bytes(16));
            Log::info('Generated random admin password for local/CI environment.');
        }

        $email = Admin::normalizeEmail(env('SEED_ADMIN_EMAIL', 'admin@pangu2.local'));

        Admin::firstOrCreate(
            ['email' => $email],
            [
                'name'      => env('SEED_ADMIN_NAME', 'Super Admin'),
                'password'  => Hash::make($password),
                'role'      => 'SUPER_ADMIN',
                'is_active' => true,
            ],
        );
    }
}
