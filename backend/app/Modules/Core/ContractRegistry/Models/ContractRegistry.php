<?php

declare(strict_types=1);

namespace App\Modules\Core\ContractRegistry\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * @property int $id
 * @property string $environment
 * @property int    $chain_id
 * @property string $name
 * @property string $address       0x-prefixed lowercase
 * @property string $abi_version
 * @property string $deployment_block
 * @property string $status        ACTIVE | PAUSED | FINALIZED | UNKNOWN | UNAVAILABLE
 * @property string $version       Config version for this entry
 * @property array|null $metadata
 * @property \Carbon\Carbon $created_at
 * @property \Carbon\Carbon $updated_at
 */
class ContractRegistry extends Model
{
    protected $table = 'contract_registry';

    protected $fillable = [
        'environment',
        'chain_id',
        'name',
        'address',
        'abi_version',
        'deployment_block',
        'status',
        'version',
        'metadata',
    ];

    protected $casts = [
        'chain_id'   => 'integer',
        'metadata'   => 'array',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    /**
     * Check if this contract entry is available for use.
     */
    public function isAvailable(): bool
    {
        return in_array($this->status, ['ACTIVE', 'PAUSED', 'FINALIZED'], true);
    }
}
