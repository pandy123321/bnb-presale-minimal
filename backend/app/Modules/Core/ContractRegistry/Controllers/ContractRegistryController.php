<?php

declare(strict_types=1);

namespace App\Modules\Core\ContractRegistry\Controllers;

use App\Http\ApiEnvelope;
use App\Modules\Core\ContractRegistry\Models\ContractRegistry;
use App\Modules\Core\ContractRegistry\Services\ContractRegistryService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class ContractRegistryController extends Controller
{
    private const ALLOWED_NAMES = [
        'Pangu2Token',
        'Pangu2TradeRouter',
        'DividendDistributor',
        'SupportPool',
        'BuybackLocker',
        'FeeVault',
        'CostBasisManager',
        'Pangu2Staking',
        'PancakeV2Adapter',
        'PancakeV2TwapOracle',
        'V2Pair',
    ];

    public function index(ContractRegistryService $service): JsonResponse
    {
        $items = $service->getAll();
        return ApiEnvelope::success($items, count($items) > 0 ? 'LIVE' : 'UNAVAILABLE');
    }

    public function store(Request $request, ContractRegistryService $service): JsonResponse
    {
        $data = $request->validate([
            'name'             => ['required', 'string', 'max:100'],
            'address'          => ['required', 'string', 'regex:/^0x[a-fA-F0-9]{40}$/'],
            'abi_version'      => ['sometimes', 'string', 'max:32'],
            'deployment_block' => ['sometimes', 'string', 'max:32'],
        ]);

        $name = $data['name'];

        if (!in_array($name, self::ALLOWED_NAMES, true)) {
            return ApiEnvelope::error(
                'INVALID_CONTRACT_NAME',
                "Contract name '{$name}' is not in the allowed whitelist.",
                false,
                ['allowed_names' => self::ALLOWED_NAMES],
                422,
            );
        }

        if (!$service->isValidAddress($data['address'])) {
            return ApiEnvelope::error(
                'INVALID_ADDRESS',
                'Address must be 0x + 40 hex characters.',
                false,
                [],
                422,
            );
        }

        $before = ContractRegistry::where('name', $name)->first();

        $entry = ContractRegistry::updateOrCreate(
            [
                'environment' => (string) config('app.env', 'local'),
                'chain_id'    => (int) config('pangu2.chain_id', 31337),
                'name'        => $name,
            ],
            [
                'address'          => strtolower($data['address']),
                'abi_version'      => $data['abi_version'] ?? '0.0.0',
                'deployment_block' => $data['deployment_block'] ?? '0',
                'status'           => 'ACTIVE',
                'version'          => '1.0.0',
            ]
        );

        $service->audit(
            $before ? 'CONTRACT_UPDATED' : 'CONTRACT_CREATED',
            $entry->id,
            $before?->toArray() ?? null,
            $entry->toArray(),
        );

        return ApiEnvelope::success([
            'id'               => $entry->id,
            'name'             => $entry->name,
            'address'          => $entry->address,
            'abi_version'      => $entry->abi_version,
            'deployment_block' => $entry->deployment_block,
            'status'           => $entry->status,
        ], 'LIVE');
    }

    public function destroy(int $id, ContractRegistryService $service): JsonResponse
    {
        $entry = ContractRegistry::find($id);

        if ($entry === null) {
            return ApiEnvelope::error(
                'NOT_FOUND',
                "Contract registry entry #{$id} not found.",
                false,
                [],
                404,
            );
        }

        $before = $entry->toArray();
        $entry->status = 'UNAVAILABLE';
        $entry->save();

        $service->audit(
            'CONTRACT_DELETED',
            $entry->id,
            $before,
            $entry->toArray(),
        );

        return ApiEnvelope::success([
            'id'     => $entry->id,
            'name'   => $entry->name,
            'status' => $entry->status,
        ], 'LIVE');
    }

    public function resync(ContractRegistryService $service): JsonResponse
    {
        $environment = (string) config('app.env', 'local');
        $chainId     = (int) config('pangu2.chain_id', 31337);

        $contracts = [
            ['name' => 'Pangu2Token',         'env' => 'pangu2.token_address'],
            ['name' => 'Pangu2TradeRouter',   'env' => 'pangu2.trade_router_address'],
            ['name' => 'DividendDistributor', 'env' => 'pangu2.dividend_distributor_address'],
            ['name' => 'SupportPool',         'env' => 'pangu2.support_pool_address'],
            ['name' => 'BuybackLocker',       'env' => 'pangu2.buyback_locker_address'],
            ['name' => 'FeeVault',            'env' => 'pangu2.fee_vault_address'],
            ['name' => 'CostBasisManager',    'env' => 'pangu2.cost_basis_manager_address'],
            ['name' => 'Pangu2Staking',       'env' => 'pangu2.staking_address'],
        ];

        $synced = [];
        foreach ($contracts as $c) {
            $address = config($c['env'], '');
            if ($address === '') continue;
            if (!$service->isValidAddress($address)) continue;

            $entry = ContractRegistry::updateOrCreate(
                [
                    'environment' => $environment,
                    'chain_id'    => $chainId,
                    'name'        => $c['name'],
                ],
                [
                    'address'          => strtolower($address),
                    'abi_version'      => '1.0.0',
                    'deployment_block' => config('pangu2.deployment_block', '0'),
                    'status'           => 'ACTIVE',
                    'version'          => '1.0.0',
                ]
            );

            $synced[] = [
                'id'      => $entry->id,
                'name'    => $entry->name,
                'address' => $entry->address,
                'status'  => $entry->status,
            ];
        }

        $service->audit(
            'CONTRACT_REGISTRY_RESYNC',
            null,
            null,
            ['synced_count' => count($synced)],
        );

        return ApiEnvelope::success([
            'synced' => count($synced),
            'items'  => $synced,
        ], count($synced) > 0 ? 'LIVE' : 'UNAVAILABLE');
    }
}
