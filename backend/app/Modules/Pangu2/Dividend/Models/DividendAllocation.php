<?php

declare(strict_types=1);

namespace App\Modules\Pangu2\Dividend\Models;

use Illuminate\Database\Eloquent\Model;

class DividendAllocation extends Model
{
    protected $fillable = [
        'chain_id', 'epoch_id', 'wallet_address',
        'balance_raw', 'rank', 'tier', 'share_percent',
        'allocated_raw', 'proof_hash',
        'claimed', 'claimed_at',
    ];

    protected $casts = [
        'chain_id'   => 'integer',
        'epoch_id'   => 'integer',
        'rank'       => 'integer',
        'claimed'    => 'boolean',
        'claimed_at' => 'datetime',
    ];
}
