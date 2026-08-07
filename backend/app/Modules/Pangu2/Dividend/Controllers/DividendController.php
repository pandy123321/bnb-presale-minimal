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
     * Returns UNAVAILABLE if no epoch exists in the database.
     */
    public function current(): JsonResponse
    {
        $epoch = DividendEpoch::where('chain_id', $this->chainId())
            ->orderBy('epoch_id', 'desc')
            ->first();

        if (!$epoch) {
            return ApiEnvelope::error(
                'NO_EPOCH',
                'No dividend epoch has been published yet. Data will become available after the first epoch is created.',
                false, [], 503,
            );
        }

        $tiers = $this->buildTiers($epoch->epoch_id);

        return ApiEnvelope::success([
            'epoch_id'           => $epoch->epoch_id,
            'snapshot_block'     => (string) $epoch->snapshot_block,
            'total_dividend_raw' => $epoch->total_dividend_raw,
            'merkle_root'        => $epoch->merkle_root,
            'tiers'              => $tiers,
            'status'             => $epoch->status,
        ], 'LIVE', (string) $epoch->snapshot_block);
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
        ], 'LIVE', (string) $epoch->snapshot_block);
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

        // Rebuild with epoch-immutable params (NOT current config).
        // These were frozen when the Epoch Root was published on-chain.
        $chainId   = (int) $epoch->chain_id;
        $tokenAddr = (string) ($epoch->reward_token_address ?: '0x0000000000000000000000000000000000000000');
        $distAddr  = (string) ($epoch->distributor_address ?: '0x0000000000000000000000000000000000000000');

        if ($tokenAddr === '0x0000000000000000000000000000000000000000' ||
            $distAddr === '0x0000000000000000000000000000000000000000') {
            return ApiEnvelope::error(
                'EPOCH_NOT_CONFIGURED',
                'Epoch is missing immutable distributor or reward token address. Proofs are unavailable.',
                false,
                [],
                503,
            );
        }
        $allAllocations = DividendAllocation::where('chain_id', $chainId)
            ->where('epoch_id', $epochId)
            ->orderBy('rank')
            ->get()
            ->map(fn ($a) => ['wallet_address' => $a->wallet_address, 'balance_raw' => $a->allocated_raw])
            ->toArray();

        $tree = $this->merkle->buildTree($allAllocations, $chainId, $distAddr, $epochId, $tokenAddr);

        // Verify rebuilt root matches stored root
        if ($tree['root'] !== $epoch->merkle_root) {
            return ApiEnvelope::error(
                'ROOT_MISMATCH',
                'Rebuilt Merkle root does not match the stored epoch root. Proof is unavailable.',
                false,
                [],
                503,
            );
        }

        // Find the leaf index for this address
        $leafIndex = null;
        $leafHash = null;
        foreach ($tree['leaves'] as $i => $leaf) {
            if ($leaf['wallet_address'] === $addr) {
                $leafIndex = $i;
                $leafHash = $leaf['leaf_hash'];
                break;
            }
        }

        if ($leafIndex === null || $leafHash === null) {
            return ApiEnvelope::error('INTERNAL_ERROR', 'Leaf not found in rebuilt tree.', false, [], 500);
        }

        $proof = $this->merkle->generateProof($tree['tree'], $leafIndex);

        // Verify the proof against the stored root before returning
        if (!$this->merkle->verifyProof($leafHash, $proof, $epoch->merkle_root)) {
            return ApiEnvelope::error(
                'PROOF_VERIFICATION_FAILED',
                'Generated proof does not verify against the stored root.',
                false,
                [],
                503,
            );
        }

        return ApiEnvelope::success([
            'epoch_id'   => $epochId,
            'address'    => $addr,
            'amount_raw' => $allocation->allocated_raw,
            'proof'      => $proof,
            'claimed'    => $allocation->claimed,
        ], $epoch->status === 'claim_open' ? 'LIVE' : 'LIVE');
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

        if ($allocations->isNotEmpty()) {
            $totalAllocated = (int) $allocations->sum('amount_raw');
            if ($totalAllocated > 0) {
                $tiers = [];
                foreach ($allocations->groupBy('tier') as $tier => $group) {
                    $tierAmount = (int) $group->sum('amount_raw');
                    $sharePercent = (int) round(($tierAmount / $totalAllocated) * 100);
                    $tiers[] = [
                        'name' => "Tier {$tier}",
                        'rank_range' => "—",
                        'share_percent' => max($sharePercent, 0),
                    ];
                }
                return $tiers;
            }
        }

        return [
            ['name' => 'Tier 1', 'rank_range' => '1-10',  'share_percent' => 35],
            ['name' => 'Tier 2', 'rank_range' => '11-30', 'share_percent' => 25],
            ['name' => 'Tier 3', 'rank_range' => '31-60', 'share_percent' => 25],
            ['name' => 'Tier 4', 'rank_range' => '61-100','share_percent' => 15],
        ];
    }
}
