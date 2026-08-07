<?php

declare(strict_types=1);

namespace App\Modules\Core\ContractRegistry\Services;

use App\Modules\Core\ContractRegistry\Models\ContractRegistry;
use App\Modules\Core\Chain\Services\ChainConfigService;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Manages the contract registry: reads from DB, falls back to config when
 * a contract is not yet registered, and never returns hardcoded production
 * addresses.
 *
 * Validation rules:
 *  - Address must match 0x + 40 hex chars
 *  - chain_id must match the configured chain
 *  - Bytecode at the address must exist (contract deployed)
 */
final class ContractRegistryService
{
    /**
     * Get all contract entries for the current environment and chain.
     *
     * @return array<int, array<string, mixed>>
     */
    public function getAll(): array
    {
        $environment = (string) config('app.env', 'local');
        $chainId     = (int) config('pangu2.chain_id', 31337);

        $dbContracts = ContractRegistry::query()
            ->where('environment', $environment)
            ->where('chain_id', $chainId)
            ->get()
            ->keyBy('name');

        return array_values(
            $this->mergeFallbacks($dbContracts->toArray(), $environment, $chainId)
        );
    }

    /**
     * Find a single contract by name.
     *
     * @return array{name: string, address: string, abi_version: string, deployment_block: string, status: string}|null
     */
    public function findByName(string $name): ?array
    {
        $environment = (string) config('app.env', 'local');
        $chainId     = (int) config('pangu2.chain_id', 31337);

        $entry = ContractRegistry::query()
            ->where('environment', $environment)
            ->where('chain_id', $chainId)
            ->where('name', $name)
            ->first();

        if ($entry !== null) {
            return $this->entryToArray($entry);
        }

        return $this->findFallback($name, $environment, $chainId);
    }

    /**
     * Validate a contract address has bytecode deployed.
     * Uses the configured RPC to check eth_getCode.
     */
    public function hasBytecode(string $address): bool
    {
        try {
            $rpcUrl = config('pangu2.rpc_url');
            if (empty($rpcUrl)) return false;

            $response = \Illuminate\Support\Facades\Http::timeout(5)
                ->withHeaders(['Content-Type' => 'application/json'])
                ->post($rpcUrl, [
                    'jsonrpc' => '2.0',
                    'method'  => 'eth_getCode',
                    'params'  => [$address, 'latest'],
                    'id'      => 1,
                ]);

            if (!$response->successful()) return false;

            $body = $response->json();
            $code = $body['result'] ?? '0x';

            // No code or empty code → not deployed
            return is_string($code) && $code !== '0x' && !empty(str_replace('0', '', substr($code, 2)));
        } catch (\Throwable) {
            return false;
        }
    }

    /**
     * Validate an EVM address format.
     */
    public function isValidAddress(string $address): bool
    {
        return preg_match('/^0x[a-fA-F0-9]{40}$/', $address) === 1;
    }

    /**
     * Record an audit entry for contract registry mutations.
     */
    public function audit(string $action, ?int $contractId, ?array $before, ?array $after): void
    {
        try {
            DB::table('admin_audit_logs')->insert([
                'action'      => $action,
                'target_type' => 'ContractRegistry',
                'target_id'   => $contractId,
                'before_data' => $before !== null ? json_encode($before) : null,
                'after_data'  => $after !== null ? json_encode($after) : null,
                'ip_address'  => request()?->ip(),
                'result'      => 'SUCCESS',
                'created_at'  => now(),
            ]);
        } catch (\Throwable $e) {
            Log::warning('ContractRegistryService: audit write failed', [
                'action' => $action, 'error'  => $e->getMessage(),
            ]);
        }
    }

    // -------------------------------------------------------------------
    // Private
    // -------------------------------------------------------------------

    /**
     * @param array<string, ContractRegistry> $dbContracts keyed by name
     * @return array<string, array>
     */
    private function mergeFallbacks(array $dbContracts, string $environment, int $chainId): array
    {
        $result = [];
        $seen   = [];

        foreach ($dbContracts as $name => $entry) {
            $result[$name] = $this->entryToArray($entry);
            $seen[$name]   = true;
        }

        foreach ($this->getEnvContractKeys() as $pair) {
            $name       = $pair['name'];
            $configKey  = $pair['key'];
            $abiVersion = $pair['abi_version'];

            if (isset($seen[$name])) continue;

            $address = config($configKey, '');
            if (empty($address)) continue;

            // Validate address format
            if (!$this->isValidAddress($address)) {
                Log::warning('ContractRegistry: env address invalid format', [
                    'name'    => $name,
                    'address' => $address,
                ]);
                continue;
            }

            $result[$name] = [
                'name'             => $name,
                'address'          => strtolower($address),
                'abi_version'      => $abiVersion,
                'deployment_block'  => config('pangu2.deployment_block', '0'),
                'status'           => 'UNKNOWN',
            ];
        }

        // Any known contract not in DB or env → UNAVAILABLE
        foreach ($this->knownContractNames() as $name) {
            if (!isset($result[$name])) {
                $result[$name] = [
                    'name'             => $name,
                    'address'          => '0x0000000000000000000000000000000000000000',
                    'abi_version'      => '0.0.0',
                    'deployment_block'  => '0',
                    'status'           => 'UNAVAILABLE',
                ];
            }
        }

        return $result;
    }

    private function findFallback(string $name, string $environment, int $chainId): ?array
    {
        foreach ($this->getEnvContractKeys() as $pair) {
            if ($pair['name'] !== $name) continue;

            $address = config($pair['key'], '');
            if (empty($address)) return null;

            if (!$this->isValidAddress($address)) return null;

            return [
                'name'             => $name,
                'address'          => strtolower($address),
                'abi_version'      => $pair['abi_version'],
                'deployment_block'  => config('pangu2.deployment_block', '0'),
                'status'           => 'UNKNOWN',
            ];
        }

        return [
            'name'             => $name,
            'address'          => '0x0000000000000000000000000000000000000000',
            'abi_version'      => '0.0.0',
            'deployment_block'  => '0',
            'status'           => 'UNAVAILABLE',
        ];
    }

    private function knownContractNames(): array
    {
        return [
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
    }

    private function getEnvContractKeys(): array
    {
        return [
            ['name' => 'Pangu2Token',         'key' => 'pangu2.token_address',                   'abi_version' => '1.0.0'],
            ['name' => 'Pangu2TradeRouter',   'key' => 'pangu2.trade_router_address',            'abi_version' => '1.0.0'],
            ['name' => 'DividendDistributor', 'key' => 'pangu2.dividend_distributor_address',    'abi_version' => '1.0.0'],
            ['name' => 'SupportPool',         'key' => 'pangu2.support_pool_address',            'abi_version' => '1.0.0'],
            ['name' => 'BuybackLocker',       'key' => 'pangu2.buyback_locker_address',          'abi_version' => '1.0.0'],
            ['name' => 'FeeVault',            'key' => 'pangu2.fee_vault_address',               'abi_version' => '1.0.0'],
            ['name' => 'CostBasisManager',    'key' => 'pangu2.cost_basis_manager_address',      'abi_version' => '1.0.0'],
            ['name' => 'Pangu2Staking',       'key' => 'pangu2.staking_address',                 'abi_version' => '1.0.0'],
        ];
    }

    /**
     * @return array{name: string, address: string, abi_version: string, deployment_block: string, status: string}
     */
    private function entryToArray(ContractRegistry $entry): array
    {
        return [
            'name'             => $entry->name,
            'address'          => $entry->address,
            'abi_version'      => $entry->abi_version,
            'deployment_block'  => $entry->deployment_block,
            'status'           => $entry->status,
        ];
    }
}
