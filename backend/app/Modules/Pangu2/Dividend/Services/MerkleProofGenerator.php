<?php

declare(strict_types=1);

namespace App\Modules\Pangu2\Dividend\Services;

use App\Modules\Pangu2\Dividend\Models\DividendAllocation;

/**
 * Deterministic Merkle Proof Generator for Dividend Distributor.
 *
 * Hard rules:
 * - Same inputs → same ranking, same allocations, same root, same proofs
 * - Ranking: descending by balance_raw, ascending by address for ties
 * - Format: "keccak256(keccak256(leftNode) + keccak256(rightNode))"
 *   for interior nodes
 * - Leaf: keccak256(pack(address, balance_raw, allocated_raw))
 */
final class MerkleProofGenerator
{
    /**
     * Dividend tiers definition (from pangu2-domain-v1.json).
     */
    private const TIERS = [
        ['name' => 'Tier 1', 'min' => 1,  'max' => 10,  'share' => 35],
        ['name' => 'Tier 2', 'min' => 11, 'max' => 30,  'share' => 25],
        ['name' => 'Tier 3', 'min' => 31, 'max' => 60,  'share' => 25],
        ['name' => 'Tier 4', 'min' => 61, 'max' => 100, 'share' => 15],
    ];

    /**
     * Build a complete deterministic Merkle tree from a set of allocations.
     *
     * Returns: ['root' => hex, 'leaves' => [address => hash], 'tree' => [[layers]]]
     */
    public function buildTree(array $allocations): array
    {
        // Sort: descending balance, ascending address for ties
        usort($allocations, function (array $a, array $b) {
            $cmp = bccomp($b['balance_raw'], $a['balance_raw']);
            if ($cmp !== 0) return $cmp;
            return strcmp($a['wallet_address'], $b['wallet_address']);
        });

        // Assign ranks and tiers
        $leaves = [];
        $rank = 0;
        foreach ($allocations as $alloc) {
            $rank++;
            $tier = $this->determineTier($rank);
            $sharePercent = $tier['share'];

            $leafHash = $this->hashLeaf(
                $alloc['wallet_address'],
                $alloc['balance_raw'],
                (string) $rank,
            );

            $leaves[] = [
                'wallet_address' => $alloc['wallet_address'],
                'balance_raw'    => $alloc['balance_raw'],
                'rank'           => $rank,
                'tier_name'      => $tier['name'],
                'share_percent'  => $sharePercent,
                'leaf_hash'      => $leafHash,
            ];
        }

        // Build Merkle tree from leaf hashes
        $tree = $this->buildMerkleTree(array_column($leaves, 'leaf_hash'));
        $root = $tree[0][0] ?? '0x' . str_repeat('00', 32);

        return [
            'root'          => '0x' . $root,
            'leaves'        => $leaves,
            'tree'          => $tree,
            'total_leaves'  => count($leaves),
        ];
    }

    /**
     * Generate a Merkle proof for a specific leaf.
     *
     * Returns sibling hashes from leaf to root.
     */
    public function generateProof(array $tree, int $leafIndex): array
    {
        $proof = [];
        $index = $leafIndex;

        for ($layer = count($tree) - 1; $layer > 0; $layer--) {
            $siblingIndex = ($index % 2 === 0) ? $index + 1 : $index - 1;

            if (isset($tree[$layer][$siblingIndex])) {
                $proof[] = '0x' . $tree[$layer][$siblingIndex];
            }

            $index = (int) floor($index / 2);
        }

        return $proof;
    }

    /**
     * Verify a Merkle proof against a root.
     */
    public function verifyProof(string $leafHash, array $proof, string $root): bool
    {
        $computed = $leafHash;

        foreach ($proof as $siblingHex) {
            $sibling = substr($siblingHex, 2);
            $sorted = $this->sortPair($computed, $sibling);
            // keccak256(keccak256(left) . keccak256(right))
            $inner = hash('sha3-512', hex2bin($this->keccak($sorted[0]) . $this->keccak($sorted[1])), true);
            $computed = bin2hex(substr($inner, 0, 32));
        }

        return $computed === substr($root, 2);
    }

    /**
     * Build a binary Merkle tree from an array of leaf hex strings.
     * Returns layers from root (index 0) to leaves (last index).
     */
    private function buildMerkleTree(array $leaves): array
    {
        if (empty($leaves)) {
            return [['0x' . str_repeat('00', 32)]];
        }

        // Pad to even number of leaves
        $tree = [$leaves];
        $layer = $leaves;

        while (count($layer) > 1) {
            $nextLayer = [];
            $layerLen = count($layer);

            for ($i = 0; $i < $layerLen; $i += 2) {
                $left  = $layer[$i];
                $right = $layer[$i + 1] ?? $left; // duplicate last if odd

                $pair = $this->sortPair($left, $right);
                $inner = hash('sha3-512', hex2bin($this->keccak($pair[0]) . $this->keccak($pair[1])), true);
                $nextLayer[] = bin2hex(substr($inner, 0, 32));
            }

            array_unshift($tree, $nextLayer);
            $layer = $nextLayer;
        }

        return $tree;
    }

    /**
     * Hash a leaf node: keccak256(address || balance_raw || rank)
     */
    public function hashLeaf(string $address, string $balanceRaw, string $rank): string
    {
        $packed = $this->packAddress($address) . $this->packUint256($balanceRaw) . $this->packUint256($rank);
        return $this->keccak(hex2bin($packed));
    }

    /**
     * Sort two hex hashes lexicographically.
     */
    private function sortPair(string $a, string $b): array
    {
        return strcmp($a, $b) <= 0 ? [$a, $b] : [$b, $a];
    }

    /**
     * keccak256 as raw hex string (no 0x prefix).
     */
    private function keccak(string $data): string
    {
        $hash = hash('sha3-512', $data, true);
        return bin2hex(substr($hash, 0, 32));
    }

    /**
     * Pack an EVM address to 32 bytes.
     */
    private function packAddress(string $address): string
    {
        $clean = substr(strtolower($address), 2);
        return str_pad($clean, 64, '0', STR_PAD_LEFT);
    }

    /**
     * Pack a decimal string to 32 bytes (big-endian).
     */
    private function packUint256(string $value): string
    {
        $hex = '';
        $v = $value;
        while (bccomp($v, '0') > 0) {
            $rem = bcmod($v, '16');
            $hex = dechex((int) $rem) . $hex;
            $v = bcdiv($v, '16', 0);
        }
        return str_pad($hex ?: '0', 64, '0', STR_PAD_LEFT);
    }

    /**
     * Determine tier by rank.
     */
    private function determineTier(int $rank): array
    {
        foreach (self::TIERS as $tier) {
            if ($rank >= $tier['min'] && $rank <= $tier['max']) {
                return $tier;
            }
        }
        return ['name' => 'Unranked', 'share' => 0];
    }
}
