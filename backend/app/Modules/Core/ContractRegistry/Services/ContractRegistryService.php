<?php

declare(strict_types=1);

namespace App\Modules\Core\ContractRegistry\Services;

use App\Modules\Core\ContractRegistry\Models\ContractRegistry;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Manages the contract registry: reads from DB, falls back to config when
 * a contract is not yet registered, and never returns hardcoded production
 * addresses.
 */
final class ContractRegistryService
{
    /**
     * Get all contract entries for the current environment and chain.
     *
     * Merges env-level config keys (CONTRACT_*_ADDRESS) as fallback entries
     * when no DB row exists yet.
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

        // Merge env-fallback contracts that are not yet in the DB
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
                'action' => $action,
                'error'  => $e->getMessage(),
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
            $envKey     = $pair['env_key'];
            $abiVersion = $pair['abi_version'];

            if (isset($seen[$name])) {
                continue;
            }

            $address = env($envKey);
            if (empty($address)) {
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

        // If a named contract has zero entries (not in DB and not in env),
        // return it as UNAVAILABLE so the API consumer can surface it.
        // The hard rule: "未配置的合约返回 UNAVAILABLE".
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
            if ($pair['name'] !== $name) {
                continue;
            }

            $address = env($pair['env_key']);
            if (empty($address)) {
                return null;
            }

            return [
                'name'             => $name,
                'address'          => strtolower($address),
                'abi_version'      => $pair['abi_version'],
                'deployment_block'  => config('pangu2.deployment_block', '0'),
                'status'           => 'UNKNOWN',
            ];
        }

        // Not configured anywhere → UNAVAILABLE
        return [
            'name'             => $name,
            'address'          => '0x0000000000000000000000000000000000000000',
            'abi_version'      => '0.0.0',
            'deployment_block'  => '0',
            'status'           => 'UNAVAILABLE',
        ];
    }

    /**
     * Known contract names in the system.
     */
    private function knownContractNames(): array
    {
        return [
            'BNBPresale',
            'SaleToken',
            'WBNB',
            'DividendDistributor',
            'SupportPool',
        ];
    }

    /**
     * Env key → contract name mapping with expected ABI versions.
     */
    private function getEnvContractKeys(): array
    {
        return [
            ['name' => 'BNBPresale',           'env_key' => 'CONTRACT_PRESALE_ADDRESS',     'abi_version' => '1.0.0'],
            ['name' => 'SaleToken',            'env_key' => 'CONTRACT_SALE_TOKEN_ADDRESS',   'abi_version' => '1.0.0'],
            ['name' => 'WBNB',                 'env_key' => 'CONTRACT_WBNB_ADDRESS',         'abi_version' => '1.0.0'],
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
