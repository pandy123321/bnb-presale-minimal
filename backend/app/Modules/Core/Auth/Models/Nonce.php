<?php

declare(strict_types=1);

namespace App\Modules\Core\Auth\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * @property int    $id
 * @property string $wallet_address  Lowercase normalized EVM address.
 * @property string $nonce           Unique one-time nonce (hex).
 * @property string $message         The EIP-191 message the user signs.
 * @property string $domain          Request origin domain.
 * @property int    $chain_id        Requested chain ID.
 * @property string $expires_at      Auto-expiry timestamp.
 * @property string|null $used_at    Consumed timestamp.
 */
class Nonce extends Model
{
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
        'chain_id'   => 'integer',
        'expires_at' => 'datetime',
        'used_at'    => 'datetime',
    ];

    public function isExpired(): bool
    {
        return $this->expires_at->isPast();
    }

    public function isUsed(): bool
    {
        return $this->used_at !== null;
    }

    public function markUsed(): void
    {
        $this->used_at = now();
        $this->save();
    }
}
