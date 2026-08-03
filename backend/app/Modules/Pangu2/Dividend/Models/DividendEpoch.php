<?php

declare(strict_types=1);

namespace App\Modules\Pangu2\Dividend\Models;

use Illuminate\Database\Eloquent\Model;

class DividendEpoch extends Model
{
    protected $fillable = [
        'chain_id', 'epoch_id', 'snapshot_block',
        'total_dividend_raw', 'merkle_root', 'artifact_checksum',
        'status', 'published_at', 'snapshot_at',
    ];

    /**
     * Set reward_token_address — only allowed before publish. Enforces lowercase.
     */
    public function setRewardTokenAddressAttribute(?string $value): void
    {
        if ($this->published_at !== null) {
            throw new \RuntimeException('reward_token_address is immutable after epoch publish.');
        }
        $this->attributes['reward_token_address'] = $value ? strtolower(trim($value)) : null;
    }

    /**
     * Set distributor_address — only allowed before publish. Enforces lowercase.
     */
    public function setDistributorAddressAttribute(?string $value): void
    {
        if ($this->published_at !== null) {
            throw new \RuntimeException('distributor_address is immutable after epoch publish.');
        }
        $this->attributes['distributor_address'] = $value ? strtolower(trim($value)) : null;
    }

    protected $casts = [
        'chain_id'       => 'integer',
        'epoch_id'       => 'integer',
        'snapshot_block' => 'integer',
        'published_at'   => 'datetime',
        'snapshot_at'    => 'datetime',
    ];
}
