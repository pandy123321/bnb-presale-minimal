<?php

declare(strict_types=1);

namespace App\Modules\Core\Chain\Services;

use Illuminate\Support\Facades\DB;

/**
 * Assesses system health: block sync across ALL worker streams,
 * queue status, open anomalies.
 *
 * Key rules:
 *  - All known streams must have cursors for LIVE status.
 *  - The most-behind cursor determines overall block lag.
 *  - Cursor status REORG_RECOVERY/ERROR → DEGRADED at best.
 *  - Empty chain raw events table + no confirmed events → NOT LIVE.
 */
final class SystemStatusService
{
    /** Worker streams that must be present for LIVE status */
    private const REQUIRED_STREAMS = ['TRADE_EVENTS', 'DIVIDEND_EVENTS'];

    /**
     * Assemble the full system status payload.
     */
    public function getStatus(): array
    {
        $syncCursors = $this->getAllSyncCursors();
        $blockLag    = $this->computeBlockLag($syncCursors);
        $rpcStatus   = app(ChainConfigService::class)->getRpcStatus();

        return [
            'latest_chain_block'   => $syncCursors['latest_chain_block'] ?? '0',
            'last_scanned_block'   => $syncCursors['last_scanned_block'] ?? '0',
            'block_lag'            => $blockLag,
            'rpc_status'           => $rpcStatus,
            'queue_status'         => $this->getQueueStatus(),
            'open_anomalies'       => $this->countOpenAnomalies(),
            'streams'              => $this->streamStatuses($syncCursors),
        ];
    }

    /**
     * Compute the overall data_status for the envelope meta.
     *
     * Priority (highest-first):
     *   1. Missing required stream → SYNCING
     *   2. Any stream in REORG_RECOVERY/ERROR → DEGRADED
     *   3. block_lag ≤ stale threshold → LIVE
     *   4. block_lag ≤ degraded threshold → STALE
     *   5. Otherwise → DEGRADED
     *
     * Additional checks:
     *   - No CONFIRMED events in chain_raw_events → not LIVE (empty table guard)
     *   - All cursors with last_scanned_block=0 → SYNCING
     */
    public function getDataStatus(): string
    {
        $syncCursors = $this->getAllSyncCursors();
        $blockLag    = $this->computeBlockLag($syncCursors);

        $staleThreshold    = (int) config('pangu2.freshness_stale_blocks', 20);
        $degradedThreshold = (int) config('pangu2.freshness_degraded_blocks', 200);
        $chainId           = (int) config('pangu2.chain_id', 31337);

        // Check: all required streams have cursors
        foreach (self::REQUIRED_STREAMS as $stream) {
            if (!isset($syncCursors[$stream])) {
                return 'SYNCING';
            }
        }

        // Check: cursor statuses — any error/reorg → DEGRADED
        foreach ($syncCursors as $stream => $cursor) {
            if (in_array($cursor['status'] ?? '', ['REORG_RECOVERY', 'ERROR'], true)) {
                return 'DEGRADED';
            }
        }

        // All last_scanned = 0 → SYNCING
        $allZero = true;
        foreach ($syncCursors as $cursor) {
            if (((int) ($cursor['last_scanned_block'] ?? 0)) > 0) {
                $allZero = false;
                break;
            }
        }
        if ($allZero && !empty($syncCursors)) {
            return 'SYNCING';
        }

        // Empty table guard: no CONFIRMED events → not LIVE
        try {
            $confirmedCount = DB::table('chain_raw_events')
                ->where('chain_id', $chainId)
                ->where('status', 'CONFIRMED')
                ->count();
            if ($confirmedCount === 0) {
                return 'SYNCING';
            }
        } catch (\Throwable) {
            // table may not exist yet
        }

        if ($blockLag <= $staleThreshold) {
            return 'LIVE';
        }
        if ($blockLag <= $degradedThreshold) {
            return 'STALE';
        }
        return 'DEGRADED';
    }

    /**
     * Determine latest block number hint from the most-behind cursor.
     */
    public function getLatestBlockHint(): ?string
    {
        $syncCursors = $this->getAllSyncCursors();
        $blockLag    = $this->computeBlockLag($syncCursors);
        $latest      = $syncCursors['latest_chain_block'] ?? null;
        return $latest !== null ? (string) $latest : null;
    }

    // -------------------------------------------------------------------
    // Internal helpers
    // -------------------------------------------------------------------

    /**
     * Get ALL sync cursors for the configured chain across all streams.
     *
     * @return array<string, array{latest_chain_block: string, last_scanned_block: string, status: string}>
     */
    private function getAllSyncCursors(): array
    {
        $chainId = (int) config('pangu2.chain_id', 31337);

        $rows = DB::table('chain_sync_cursors')
            ->where('chain_id', $chainId)
            ->get();

        $cursors = [];
        $latestChainBlock = '0';

        foreach ($rows as $row) {
            $stream = $row->stream;
            $lastScanned = (string) ($row->last_scanned_block ?? '0');
            $cursorLatest = (string) ($row->latest_chain_block ?? $row->last_scanned_block ?? '0');
            $status = $row->status ?? 'UNKNOWN';

            $cursors[$stream] = [
                'latest_chain_block' => $cursorLatest,
                'last_scanned_block' => $lastScanned,
                'status'             => $status,
            ];

            // Track the highest latest_chain_block across all streams
            if (bccomp($cursorLatest, $latestChainBlock) > 0) {
                $latestChainBlock = $cursorLatest;
            }
        }

        // Store aggregate values under a synthetic key
        $cursors['latest_chain_block'] = $latestChainBlock;
        $cursors['last_scanned_block'] = $this->mostBehindBlock($cursors);

        return $cursors;
    }

    /**
     * Find the smallest (most-behind) last_scanned_block across all streams.
     */
    private function mostBehindBlock(array $cursors): string
    {
        $min = null;
        foreach ($cursors as $stream => $cursor) {
            if (in_array($stream, ['latest_chain_block', 'last_scanned_block'], true)) continue;
            $block = (int) ($cursor['last_scanned_block'] ?? 0);
            if ($min === null || $block < $min) {
                $min = $block;
            }
        }
        return $min !== null ? (string) $min : '0';
    }

    /**
     * Stream-by-stream status breakdown.
     */
    private function streamStatuses(array $syncCursors): array
    {
        $result = [];
        foreach ($syncCursors as $stream => $cursor) {
            if (in_array($stream, ['latest_chain_block', 'last_scanned_block'], true)) continue;
            $result[$stream] = [
                'last_scanned_block' => (int) ($cursor['last_scanned_block'] ?? 0),
                'status'             => $cursor['status'] ?? 'UNKNOWN',
            ];
        }
        return $result;
    }

    private function computeBlockLag(array $syncCursors): int
    {
        $latestChain = (int) ($syncCursors['latest_chain_block'] ?? 0);
        $lastScanned = (int) ($syncCursors['last_scanned_block'] ?? 0);

        if ($latestChain <= 0 || $lastScanned <= 0) {
            return 0;
        }

        return max(0, $latestChain - $lastScanned);
    }

    private function getQueueStatus(): string
    {
        try {
            $failedCount = DB::table('failed_jobs')->count();
            if ($failedCount > 0) {
                return 'DEGRADED';
            }

            $stuckBatch = DB::table('job_batches')
                ->where('pending_jobs', '>', 0)
                ->where('created_at', '<', now()->subMinutes(30))
                ->exists();

            if ($stuckBatch) {
                return 'DEGRADED';
            }

            return 'HEALTHY';
        } catch (\Throwable) {
            return 'UNKNOWN';
        }
    }

    /**
     * Count only CONFIRMED anomalies — PENDING_CONFIRMATION is not an anomaly.
     */
    private function countOpenAnomalies(): int
    {
        try {
            return DB::table('system_anomalies')
                ->where('status', 'OPEN')
                ->count();
        } catch (\Throwable) {
            return 0;
        }
    }
}
