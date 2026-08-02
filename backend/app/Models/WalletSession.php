<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class WalletSession extends Model
{
    protected $table = 'wallet_sessions';

    protected $fillable = [
        'wallet_address',
        'token',
        'expires_at',
        'last_activity_at',
    ];

    protected $casts = [
        'expires_at' => 'datetime',
        'last_activity_at' => 'datetime',
    ];

    protected $hidden = [
        'token',
    ];
}
