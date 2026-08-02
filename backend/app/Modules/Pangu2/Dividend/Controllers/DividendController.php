<?php

declare(strict_types=1);

namespace App\Modules\Pangu2\Dividend\Controllers;

use App\Http\ApiEnvelope;
use App\Modules\Pangu2\Dividend\Models\DividendAllocation;
use App\Modules\Pangu2\Dividend\Models\DividendEpoch;
use App\Modules\Pangu2\Dividend\Services\MerkleProofGenerator;
use Illuminate\Http\JsonResponse;
use Illuminate\Routing\Controller;

class DividendController extends Controller
{
    public function __construct(
        private readonly MerkleProofGenerator $merkle,
    ) {}

    /**
     * GET /api/v1/projects/pangu2/dividend/epochs/current
     *
     * Return the current epoch with tiers and allocations.
     * Falls back to MOCK_DATA if no epoch exists in the database.
     */
    public function current(): JsonResponse
    {
        $epoch = DividendEpoch::where('chain_id', $this->chainId())
            ->orderBy('epoch_id', 'desc')
            ->first();

        if (!$epoch) {
            return $this->mockCurrentEpoch();
        }

        $tiers = $this->buildTiers($epoch->epoch_id);

        return ApiEnvelope::success([
            'epoch_id'           => $epoch->epoch_id,
            'snapshot_block'     => (string) $epoch->snapshot_block,
            'total_dividend_raw' => $epoch->total_dividend_raw,
            'merkle_root'        => $epoch->merkle_root,
            'tiers'              => $tiers,
            'status'             => $epoch->status,
        ], 'MOCK_DATA', (string) $epoch->snapshot_block);
    }

    /**
     * GET /api/v1/projects/pangu2/dividend/epochs/{epochId}
     */
    public function show(int $epochId): JsonResponse
    {
        $epoch = DividendEpoch::where('chain_id', $this->chainId())
            ->where('epoch_id', $epochId)
            ->first();

        if (!$epoch) {
            return ApiEnvelope::error('NOT_FOUND', 'Epoch not found.', false, [], 404);
        }

        $tiers = $this->buildTiers($epochId);

        return ApiEnvelope::success([
            'epoch_id'           => $epoch->epoch_id,
            'snapshot_block'     => (string) $epoch->snapshot_block,
            'total_dividend_raw' => $epoch->total_dividend_raw,
            'merkle_root'        => $epoch->merkle_root,
            'tiers'              => $tiers,
            'status'             => $epoch->status,
        ], 'MOCK_DATA', (string) $epoch->snapshot_block);
    }

    /**
     * GET /api/v1/projects/pangu2/dividend/epochs/{epochId}/proof/{address}
     *
     * Return a Merkle proof for a specific wallet in an epoch.
     */
    public function proof(int $epochId, string $address): JsonResponse
    {
        $addr = strtolower(trim($address));

        $allocation = DividendAllocation::where('chain_id', $this->chainId())
            ->where('epoch_id', $epochId)
            ->where('wallet_address', $addr)
            ->first();

        if (!$allocation) {
            return ApiEnvelope::error('NOT_FOUND', 'No allocation found for this address in epoch.', false, [], 404);
        }

        $epoch = DividendEpoch::where('chain_id', $this->chainId())
            ->where('epoch_id', $epochId)
            ->first();

        if (!$epoch) {
            return ApiEnvelope::error('NOT_FOUND', 'Epoch not found.', false, [], 404);
        }

        // Rebuild the tree deterministically to generate proof
        $allAllocations = DividendAllocation::where('chain_id', $this->chainId())
            ->where('epoch_id', $epochId)
            ->orderBy('rank')
            ->get()
            ->map(fn ($a) => [
                'wallet_address' => $a->wallet_address,
                'balance_raw'    => $a->balance_raw,
            ])
            ->toArray();

        $tree = $this->merkle->buildTree($allAllocations);

        // Find the leaf index for this address
        $leafIndex = null;
        foreach ($tree['leaves'] as $i => $leaf) {
            if ($leaf['wallet_address'] === $addr) {
                $leafIndex = $i;
                break;
            }
        }

        if ($leafIndex === null) {
            return ApiEnvelope::error('INTERNAL_ERROR', 'Leaf not found in rebuilt tree.', false, [], 500);
        }

        $proof = $this->merkle->generateProof($tree['tree'], $leafIndex);

        return ApiEnvelope::success([
            'epoch_id'   => $epochId,
            'address'    => $addr,
            'amount_raw' => $allocation->allocated_raw,
            'proof'      => $proof,
            'claimed'    => $allocation->claimed,
        ], 'MOCK_DATA');
    }

    // ── Helpers ──────────────────────────────

    private function chainId(): int
    {
        return (int) config('pangu2.chain_id', 31337);
    }

    private function buildTiers(int $epochId): array
    {
        $allocations = DividendAllocation::where('chain_id', $this->chainId())
            ->where('epoch_id', $epochId)
            ->get();

        $tiers = [];
        foreach ([
            ['name' => 'Tier 1', 'rank_range' => '1-10',  'share_percent' => 35],
            ['name' => 'Tier 2', 'rank_range' => '11-30', 'share_percent' => 25],
            ['name' => 'Tier 3', 'rank_range' => '31-60', 'share_percent' => 25],
            ['name' => 'Tier 4', 'rank_range' => '61-100','share_percent' => 15],
        ] as $t) {
            $tiers[] = $t;
        }

        return $tiers;
    }

    private function mockCurrentEpoch(): JsonResponse
    {
        return ApiEnvelope::success([
            'epoch_id'           => 28,
            'snapshot_block'     => '42814660',
            'total_dividend_raw' => '6420000000000000000000000',
            'merkle_root'        => '0x76b100000000000000000000000000000000000000000000000000000000c4a8',
            'tiers'              => [
                ['name' => 'Tier 1', 'rank_range' => '1-10',  'share_percent' => 35],
                ['name' => 'Tier 2', 'rank_range' => '11-30', 'share_percent' => 25],
                ['name' => 'Tier 3', 'rank_range' => '31-60', 'share_percent' => 25],
                ['name' => 'Tier 4', 'rank_range' => '61-100','share_percent' => 15],
            ],
            'status'             => 'claim_open',
        ], 'MOCK_DATA');
    }
}
