<?php

namespace Database\Seeders;

use App\Models\Admin;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class AdminSeeder extends Seeder
{
    public function run(): void
    {
        Admin::create([
            'name' => env('SEED_ADMIN_NAME', 'Super Admin'),
            'email' => Admin::normalizeEmail(env('SEED_ADMIN_EMAIL', 'admin@bnb-presale.local')),
            'password' => Hash::make(env('SEED_ADMIN_PASSWORD', 'admin123')),
            'role' => 'SUPER_ADMIN',
            'is_active' => true,
        ]);
    }
}
