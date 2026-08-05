<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Http\ApiEnvelope;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

final class SystemController extends Controller
{
    /**
     * GET /api/v1/projects/pangu2/config
     */
    public function config()
    {
        $chainId = (int) config('pangu2.chain_id', 31337);

        // Probe RPC to determine real status
        $rpcOk = $this->checkRpc();

        return ApiEnvelope::success([
            'project'             => 'PANGU2',
            'environment'         => config('app.env', 'LOCAL'),
            'chain_id'            => $chainId,
            'chain_name'          => match ($chainId) {
                56 => 'BSC Mainnet', 97 => 'BSC Testnet', default => 'Anvil',
            },
            'rpc_status'          => $rpcOk ? 'OK' : 'UNAVAILABLE',
            'supported_networks'  => [31337, 97],
        ], $rpcOk ? 'LIVE' : 'DEGRADED');
    }

    /**
     * GET /api/v1/projects/pangu2/system-status
     */
    public function systemStatus()
    {
        $rpcBlock    = $this->getLatestBlock();
        $scannedBlock = $this->getScannedBlock();

        return ApiEnvelope::success([
            'latest_chain_block'   => $rpcBlock ?? '—',
            'last_scanned_block'   => $scannedBlock ?? '—',
            'block_lag'            => $rpcBlock !== null && $scannedBlock !== null
                ? max(0, (int) $rpcBlock - (int) $scannedBlock) : null,
            'rpc_status'           => $rpcBlock !== null ? 'OK' : 'UNAVAILABLE',
            'queue_status'         => $this->getQueueStatus(),
            'open_anomalies'       => $this->getOpenAnomalies(),
        ], $rpcBlock !== null ? 'LIVE' : 'UNAVAILABLE');
    }

    /**
     * GET /api/v1/projects/pangu2/contracts
     * Returns real contract addresses from pangu2 config.
     */
    public function contracts()
    {
        $chainId = (int) config('pangu2.chain_id', 31337);

        $contracts = [
            ['name' => 'Pangu2Token',           'env' => 'token_address'],
            ['name' => 'Pangu2TradeRouter',     'env' => 'trade_router_address'],
            ['name' => 'DividendDistributor',   'env' => 'dividend_distributor_address'],
            ['name' => 'SupportPool',           'env' => 'support_pool_address'],
            ['name' => 'BuybackLocker',         'env' => 'buyback_locker_address'],
            ['name' => 'FeeVault',              'env' => 'fee_vault_address'],
            ['name' => 'CostBasisManager',      'env' => 'cost_basis_manager_address'],
            ['name' => 'Pangu2Staking',         'env' => 'staking_address'],
        ];

        $hasAny = false;
        $items = [];
        foreach ($contracts as $c) {
            $addr = config("pangu2.{$c['env']}", '');
            if ($addr === '') continue;
            $hasAny = true;
            $items[] = [
                'name'             => $c['name'],
                'address'          => $addr,
                'chain_id'         => $chainId,
                'status'           => 'ACTIVE',
            ];
        }

        $status = $hasAny ? 'LIVE' : 'UNAVAILABLE';
        return ApiEnvelope::success($items ?: [], $status);
    }

    // ── Helpers ──────────────────────────────

    private function checkRpc(): bool
    {
        try {
            $response = Http::timeout(5)
                ->withHeaders(['Content-Type' => 'application/json'])
                ->post(config('pangu2.rpc_url', 'http://127.0.0.1:8545'), [
                    'jsonrpc' => '2.0', 'method' => 'eth_blockNumber', 'params' => [], 'id' => 1,
                ]);
            return $response->successful() && isset($response->json()['result']);
        } catch (\Throwable) {
            return false;
        }
    }

    private function getLatestBlock(): ?string
    {
        try {
            $response = Http::timeout(5)
                ->withHeaders(['Content-Type' => 'application/json'])
                ->post(config('pangu2.rpc_url', 'http://127.0.0.1:8545'), [
                    'jsonrpc' => '2.0', 'method' => 'eth_blockNumber', 'params' => [], 'id' => 1,
                ]);
            $result = $response->json()['result'] ?? null;
            if ($result && str_starts_with((string)$result, '0x')) {
                return gmp_strval(gmp_init(substr($result, 2), 16));
            }
            return null;
        } catch (\Throwable) {
            return null;
        }
    }

    private function getScannedBlock(): ?string
    {
        try {
            $chainId = (int) config('pangu2.chain_id', 31337);
            $row = DB::table('chain_cursors')
                ->where('chain_id', $chainId)
                ->orderBy('last_scanned_block', 'desc')
                ->first();
            return $row ? (string) $row->last_scanned_block : null;
        } catch (\Throwable) {
            return null;
        }
    }

    private function getQueueStatus(): string
    {
        try {
            $pending = DB::table('jobs')->where('reserved_at', null)->count() ?? 0;
            $failed  = DB::table('failed_jobs')->count() ?? 0;
            if ($failed > 0) return 'DEGRADED';
            if ($pending > 50) return 'BUSY';
            return 'HEALTHY';
        } catch (\Throwable) {
            return 'UNKNOWN';
        }
    }

    private function getOpenAnomalies(): int
    {
        try {
            return DB::table('chain_raw_events')
                ->where('status', 'PENDING_CONFIRMATION')
                ->count() ?? 0;
        } catch (\Throwable) {
            return -1;
        }
    }
}
