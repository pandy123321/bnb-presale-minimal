<?php

declare(strict_types=1);

namespace App\Modules\Core\Chain\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Provides environment and chain configuration data for the /config endpoint.
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
            'project'           => 'PANGU2',
            'environment'        => config('app.env', 'LOCAL'),
            'chain_id'           => (int) config('pangu2.chain_id', 31337),
            'chain_name'         => config('pangu2.chain_name', 'Anvil'),
            'rpc_status'         => $this->getRpcStatus(),
            'supported_networks' => config('pangu2.supported_networks', [31337, 97, 56]),
        ];
    }

    /**
     * Lightweight RPC health check via eth_blockNumber.
     */
    private function probeRpc(string $url): bool
    {
        try {
            $response = Http::timeout(5)
                ->withHeaders(['Content-Type' => 'application/json'])
                ->post($url, [
                    'jsonrpc' => '2.0',
                    'method'  => 'eth_blockNumber',
                    'params'  => [],
                    'id'      => 1,
                ]);

            if (!$response->successful()) {
                return false;
            }

            $body = $response->json();
            return isset($body['result']) && str_starts_with((string) $body['result'], '0x');
        } catch (\Throwable $e) {
            Log::warning('ChainConfigService: RPC probe failed', [
                'url'   => $url,
                'error' => $e->getMessage(),
            ]);
            return false;
        }
    }
}
