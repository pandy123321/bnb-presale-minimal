<?php

declare(strict_types=1);

namespace App\Modules\Core\Chain\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Provides environment and chain configuration data for the /config endpoint.
 *
 * RPC probing now validates BOTH eth_blockNumber AND eth_chainId to prevent
 * cross-chain misconfiguration (e.g. pointing at Mainnet when expecting Testnet).
 */
final class ChainConfigService
{
    /**
     * Probe RPC status: OK, DEGRADED, or DOWN.
     */
    public function getRpcStatus(): string
    {
        $primaryUrl = config('pangu2.rpc_url');
        $backupUrl  = config('pangu2.backup_rpc_url');

        if (empty($primaryUrl)) {
            return 'DOWN';
        }

        $primaryOk = $this->probeRpc($primaryUrl);
        if ($primaryOk) {
            return 'OK';
        }

        if (!empty($backupUrl) && $this->probeRpc($backupUrl)) {
            return 'DEGRADED';
        }

        return 'DOWN';
    }

    /**
     * Assemble the full environment config payload.
     */
    public function getConfig(): array
    {
        return [
            'project'            => 'PANGU2',
            'environment'         => config('app.env', 'LOCAL'),
            'chain_id'            => (int) config('pangu2.chain_id', 31337),
            'chain_name'          => config('pangu2.chain_name', 'Anvil'),
            'rpc_status'          => $this->getRpcStatus(),
            'supported_networks'  => config('pangu2.supported_networks', [31337, 97, 56]),
        ];
    }

    /**
     * Lightweight RPC health check: validates both eth_blockNumber and eth_chainId.
     *
     * A server that responds to eth_blockNumber but returns wrong chainId is
     * considered INVALID and treated as DOWN.
     */
    public function probeRpc(string $url): bool
    {
        try {
            // Check 1: eth_blockNumber
            $blockOk = $this->rpcCall($url, 'eth_blockNumber');
            if (!$blockOk) return false;

            // Check 2: eth_chainId must match configured chain_id
            $chainOk = $this->rpcCall($url, 'eth_chainId');
            if (!$chainOk) return false;

            // Check 3: Verify chainId matches expected
            $expectedChainId = (int) config('pangu2.chain_id', 31337);
            $actualChainId = $this->rpcChainId($url);
            if ($actualChainId === null || $actualChainId !== $expectedChainId) {
                Log::warning('ChainConfigService: RPC chainId mismatch', [
                    'url'               => $url,
                    'expected_chain_id' => $expectedChainId,
                    'actual_chain_id'   => $actualChainId,
                ]);
                return false;
            }

            return true;
        } catch (\Throwable $e) {
            Log::warning('ChainConfigService: RPC probe failed', [
                'url'   => $url,
                'error' => $e->getMessage(),
            ]);
            return false;
        }
    }

    /**
     * Make a single JSON-RPC call and validate the response.
     */
    private function rpcCall(string $url, string $method): bool
    {
        $response = Http::timeout(5)
            ->withHeaders(['Content-Type' => 'application/json'])
            ->post($url, [
                'jsonrpc' => '2.0',
                'method'  => $method,
                'params'  => [],
                'id'      => 1,
            ]);

        if (!$response->successful()) {
            return false;
        }

        $body = $response->json();
        if (!is_array($body) || isset($body['error'])) {
            return false;
        }

        $result = $body['result'] ?? null;
        return is_string($result) && str_starts_with($result, '0x');
    }

    /**
     * Get the chain ID from the RPC endpoint.
     */
    public function rpcChainId(string $url): ?int
    {
        try {
            $response = Http::timeout(5)
                ->withHeaders(['Content-Type' => 'application/json'])
                ->post($url, [
                    'jsonrpc' => '2.0',
                    'method'  => 'eth_chainId',
                    'params'  => [],
                    'id'      => 1,
                ]);

            if (!$response->successful()) return null;

            $body = $response->json();
            $result = $body['result'] ?? null;

            if (!is_string($result) || !str_starts_with($result, '0x')) {
                return null;
            }

            return (int) hexdec($result);
        } catch (\Throwable) {
            return null;
        }
    }

    /**
     * Get the latest block number from the RPC endpoint.
     */
    public function getBlockNumber(): ?string
    {
        try {
            $response = Http::timeout(5)
                ->withHeaders(['Content-Type' => 'application/json'])
                ->post(config('pangu2.rpc_url'), [
                    'jsonrpc' => '2.0',
                    'method'  => 'eth_blockNumber',
                    'params'  => [],
                    'id'      => 1,
                ]);

            if (!$response->successful()) return null;

            $body = $response->json();
            $result = $body['result'] ?? null;

            if (!is_string($result) || !str_starts_with($result, '0x')) {
                return null;
            }

            return gmp_strval(gmp_init(substr($result, 2), 16));
        } catch (\Throwable) {
            return null;
        }
    }
}
