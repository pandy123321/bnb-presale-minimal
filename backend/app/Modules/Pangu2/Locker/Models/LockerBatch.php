<?php

declare(strict_types=1);

namespace App\Modules\Pangu2\Locker\Models;

use Illuminate\Database\Eloquent\Model;

class LockerBatch extends Model
{
    protected $fillable = [
        'chain_id', 'batch_id', 'tokens_raw',
        'source_block_number', 'lock_until_block',
        'locked_until', 'duration_days', 'status',
    ];

    protected $casts = [
        'chain_id'      => 'integer',
        'batch_id'      => 'integer',
        'source_block_number' => 'integer',
        'lock_until_block'    => 'integer',
        'locked_until'  => 'datetime',
        'duration_days' => 'integer',
    ];
}
