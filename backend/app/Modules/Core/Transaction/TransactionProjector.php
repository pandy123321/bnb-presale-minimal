<?php

declare(strict_types=1);

namespace App\Modules\Core\Transaction;

use App\Modules\Core\Transaction\Models\TransactionProjection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * TransactionProjector — consumes raw events and creates user-facing TransactionProjection records.
 *
 * This is the outbox consumer. Chain Worker writes raw events.
 * Laravel reads raw events → projects into transaction_projections.
 *
 * Hard rules:
 * - Laravel only reads the raw_events outbox, never calls RPC directly for events
 * - Transaction projections are append-only; status transitions only
 * - Reorg handling: mark existing projections REORGED, create new projections from canonical chain
 */
final class TransactionProjector
{
    /**
     * Process a batch of raw events and create/update transaction projections.
     */
    public function processBatch(int $chainId, int $fromBlock, int $toBlock): array
    {
        $created = 0;
        $updated = 0;

        $rawEvents = DB::table('chain_raw_events')
            ->where('chain_id', $chainId)
            ->whereBetween('block_number', [$fromBlock, $toBlock])
            ->whereIn('event_name', [
                'BuyExecuted',
                'SellExecuted',
                'DividendClaimed',
                'BuybackExecuted',
            ])
            ->orderBy('block_number')
            ->orderBy('log_index')
            ->get();

        foreach ($rawEvents as $raw) {
            $decoded = json_decode($raw->decoded_data, true) ?? [];
            $fromAddress = $this->extractFromAddress($raw->event_name, $decoded);
            $type = $this->mapEventToType($raw->event_name);

            if (!$fromAddress || !$type) {
                continue;
            }

            $projection = TransactionProjection::firstOrNew(
                ['chain_id' => $chainId, 'tx_hash' => $raw->transaction_hash],
                [
                    'block_hash'       => $raw->block_hash,
                    'block_number'     => $raw->block_number,
                    'from_address'     => $fromAddress,
                    'contract_address' => $raw->contract_address,
                    'type'             => $type,
                    'event_timestamp'  => $raw->block_timestamp,
                    'status'           => 'pending',
                ],
            );

            if (!$projection->exists) {
                $projection->save();
                $created++;
            }

            // Update status based on raw event status
            if ($raw->status === 'CONFIRMED' && $projection->status !== 'confirmed') {
                $projection->update([
                    'status'       => 'confirmed',
                    'confirmed_at' => now(),
                ]);
                $updated++;
            } elseif ($raw->status === 'REORGED' && $projection->status !== 'reorged') {
                $projection->update([
                    'status'     => 'reorged',
                    'reorged_at' => now(),
                ]);
                $updated++;
            }
        }

        Log::info("TransactionProjector: processed {$rawEvents->count()} raw events → {$created} created, {$updated} updated");

        return ['created' => $created, 'updated' => $updated];
    }

    /**
     * Handle a reorg: mark projections in the reorged block as REORGED.
     */
    public function handleReorg(int $chainId, int $blockNumber): int
    {
        return TransactionProjection::where('chain_id', $chainId)
            ->where('block_number', $blockNumber)
            ->where('status', '!=', 'reorged')
            ->update([
                'status'     => 'reorged',
                'reorged_at' => now(),
                'updated_at' => now(),
            ]);
    }

    /**
     * Get transaction history for a wallet address.
     */
    public function getHistory(
        int $chainId,
        string $address,
        ?string $type = null,
        int $page = 1,
        int $perPage = 20,
    ): array {
        $query = TransactionProjection::where('chain_id', $chainId)
            ->where('from_address', strtolower($address))
            ->orderBy('event_timestamp', 'desc');

        if ($type) {
            $query->where('type', $type);
        }

        return $query->paginate($perPage, ['*'], 'page', $page)->toArray();
    }

    // ── Helpers ──────────────────────────────

    private function mapEventToType(?string $eventName): ?string
    {
        return match ($eventName) {
            'BuyExecuted'       => 'buy',
            'SellExecuted'      => 'sell',
            'DividendClaimed'   => 'claim',
            'BuybackExecuted'   => 'buyback',
            default             => 'other',
        };
    }

    private function extractFromAddress(?string $eventName, array $decoded): ?string
    {
        return match ($eventName) {
            'BuyExecuted'       => isset($decoded['buyer']) ? strtolower($decoded['buyer']) : null,
            'SellExecuted'      => isset($decoded['seller']) ? strtolower($decoded['seller']) : null,
            'DividendClaimed'   => isset($decoded['account']) ? strtolower($decoded['account']) : null,
            'BuybackExecuted'   => isset($decoded['trigger']) ? strtolower($decoded['trigger']) : null,
            default             => null,
        };
    }
}
