<?php

declare(strict_types=1);

namespace App\Modules\Core\Transaction\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * @property int    $id
 * @property int    $chain_id
 * @property string $tx_hash
 * @property string $block_hash
 * @property int    $block_number
 * @property string $from_address
 * @property string $contract_address
 * @property string $type          buy|sell|claim|buyback|other
 * @property string $amount_in_raw
 * @property string $amount_out_raw
 * @property string|null $tax_amount_raw
 * @property string|null $tax_rate_bps
 * @property string $status        pending|confirmed|failed|replaced|dropped|reorged
 */
class TransactionProjection extends Model
{
    protected $fillable = [
        'chain_id', 'tx_hash', 'block_hash', 'block_number',
        'from_address', 'contract_address', 'type',
        'amount_in_raw', 'amount_out_raw', 'tax_amount_raw', 'tax_rate_bps',
        'status', 'confirmed_at', 'failed_at', 'replaced_at', 'dropped_at', 'reorged_at',
        'replaced_by_tx_id', 'metadata', 'event_timestamp',
    ];

    protected $casts = [
        'chain_id'           => 'integer',
        'block_number'       => 'integer',
        'confirmed_at'       => 'datetime',
        'failed_at'          => 'datetime',
        'replaced_at'        => 'datetime',
        'dropped_at'         => 'datetime',
        'reorged_at'         => 'datetime',
        'event_timestamp'    => 'datetime',
        'metadata'           => 'array',
    ];

    public function isFinal(): bool
    {
        return in_array($this->status, ['confirmed', 'failed', 'replaced', 'dropped', 'reorged']);
    }
}
