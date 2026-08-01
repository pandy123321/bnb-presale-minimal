<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;

class Admin extends Authenticatable
{
    use HasFactory;

    protected $fillable = [
        'name',
        'email',
        'password',
        'role',
        'is_active',
    ];

    protected $hidden = [
        'password',
    ];

    protected $casts = [
        'is_active' => 'boolean',
        'last_login_at' => 'datetime',
    ];

    public function setEmailAttribute(string $value): void
    {
        $this->attributes['email'] = static::normalizeEmail($value);
    }

    public static function normalizeEmail(string $value): string
    {
        return mb_strtolower(trim($value));
    }

    public function isSuperAdmin(): bool
    {
        return $this->role === 'SUPER_ADMIN';
    }

    public function isAdmin(): bool
    {
        return $this->role === 'ADMIN';
    }
}
