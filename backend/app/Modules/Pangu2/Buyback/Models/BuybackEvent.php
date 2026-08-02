<?php

declare(strict_types=1);

namespace App\Modules\Pangu2\Buyback\Models;

use Illuminate\Database\Eloquent\Model;

class BuybackEvent extends Model
{
    protected $fillable = [
        'chain_id', 'buyback_id', 'trigger_address',
        'bnb_amount_wei', 'token_amount_raw',
        'locker_address', 'pool_address',
        'block_number', 'event_timestamp',
    ];

    protected $casts = [
        'chain_id'   => 'integer',
        'buyback_id' => 'integer',
        'block_number' => 'integer',
        'event_timestamp' => 'datetime',
    ];
}
