<?php

declare(strict_types=1);

namespace App\Modules\Core\Chain\Services;

use Illuminate\Support\Facades\DB;

/**
 * Assesses system health: block sync, queue status, open anomalies.
 */
final class SystemStatusService
{
    /**
     * Assemble the full system status payload.
     */
    public function getStatus(): array
    {
        $syncCursor  = $this->getSyncCursor();
        $blockLag    = $this->computeBlockLag($syncCursor);
        $rpcStatus   = app(ChainConfigService::class)->getRpcStatus();

        return [
            'latest_chain_block'  => $syncCursor['latest_chain_block'] ?? '0',
            'last_scanned_block'  => $syncCursor['last_scanned_block'] ?? '0',
            'block_lag'           => $blockLag,
            'rpc_status'          => $rpcStatus,
            'queue_status'        => $this->getQueueStatus(),
            'open_anomalies'      => $this->countOpenAnomalies(),
        ];
    }

    /**
     * Compute the overall data_status for the envelope meta.
     */
    public function getDataStatus(): string
    {
        $syncCursor = $this->getSyncCursor();
        $blockLag   = $this->computeBlockLag($syncCursor);

        if ($syncCursor === null) {
            return 'SYNCING';
        }

        $staleThreshold    = (int) config('pangu2.freshness_stale_blocks', 20);
        $degradedThreshold = (int) config('pangu2.freshness_degraded_blocks', 200);

        if ($blockLag <= $staleThreshold) {
            return 'LIVE';
        }

        if ($blockLag <= $degradedThreshold) {
            return 'STALE';
        }

        return 'DEGRADED';
    }

    /**
     * Determine latest block number hint.
     * Returns the latest chain block as a string, or null if unknown.
     */
    public function getLatestBlockHint(): ?string
    {
        $cursor = $this->getSyncCursor();
        if ($cursor === null) {
            return null;
        }
        $value = $cursor['latest_chain_block'] ?? $cursor['last_scanned_block'] ?? null;
        return $value !== null ? (string) $value : null;
    }

    // -------------------------------------------------------------------
    // Internal helpers
    // -------------------------------------------------------------------

    /**
     * @return array{latest_chain_block: string, last_scanned_block: string}|null
     */
    private function getSyncCursor(): ?array
    {
        $row = DB::table('chain_sync_cursors')
            ->where('chain_id', (int) config('pangu2.chain_id', 31337))
            ->where('stream', 'default')
            ->first();

        if ($row === null) {
            return null;
        }

        $latestChain = $row->latest_chain_block ?? $row->last_scanned_block;
        $lastScanned = $row->last_scanned_block ?? '0';

        return [
            'latest_chain_block' => (string) $latestChain,
            'last_scanned_block' => (string) $lastScanned,
        ];
    }

    private function computeBlockLag(?array $cursor): int
    {
        if ($cursor === null) {
            return 0;
        }

        $latestChain = (int) $cursor['latest_chain_block'];
        $lastScanned = (int) $cursor['last_scanned_block'];

        if ($latestChain <= 0) {
            return 0;
        }

        return max(0, $latestChain - $lastScanned);
    }

    private function getQueueStatus(): string
    {
        try {
            // Check if any failed jobs exist recently
            $failedCount = DB::table('failed_jobs')->count();
            if ($failedCount > 0) {
                return 'DEGRADED';
            }

            // Horizon-style: check job_batches for stuck batches
            $stuckBatch = DB::table('job_batches')
                ->where('pending_jobs', '>', 0)
                ->where('created_at', '<', now()->subMinutes(30))
                ->exists();

            if ($stuckBatch) {
                return 'DEGRADED';
            }

            return 'HEALTHY';
        } catch (\Throwable $e) {
            return 'UNKNOWN';
        }
    }

    private function countOpenAnomalies(): int
    {
        try {
            return DB::table('system_anomalies')
                ->where('status', 'OPEN')
                ->count();
        } catch (\Throwable $e) {
            return 0;
        }
    }
}
