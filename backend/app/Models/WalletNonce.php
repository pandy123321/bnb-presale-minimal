<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class WalletNonce extends Model
{
    protected $table = 'wallet_nonces';

    protected $fillable = [
        'wallet_address',
        'nonce',
        'message',
        'domain',
        'chain_id',
        'expires_at',
        'used_at',
    ];

    protected $casts = [
        'expires_at' => 'datetime',
        'used_at' => 'datetime',
    ];
}
