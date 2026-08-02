<?php

declare(strict_types=1);

namespace App\Modules\Pangu2\Dividend\Services;

final class MerkleProofGenerator
{
    private const TIERS = [
        ['name' => 'Tier 1', 'min' => 1,  'max' => 10,  'share' => 35],
        ['name' => 'Tier 2', 'min' => 11, 'max' => 30,  'share' => 25],
        ['name' => 'Tier 3', 'min' => 31, 'max' => 60,  'share' => 25],
        ['name' => 'Tier 4', 'min' => 61, 'max' => 100, 'share' => 15],
    ];

    public function buildTree(array $allocations, int $chainId, string $distributor, int $epochId, string $rewardToken): array
    {
        usort($allocations, function (array $a, array $b) {
            $cmp = bccomp($b['balance_raw'], $a['balance_raw']);
            return $cmp !== 0 ? $cmp : strcmp($a['wallet_address'], $b['wallet_address']);
        });

        $leaves = [];
        $rank = 0;
        foreach ($allocations as $alloc) {
            $rank++;
            $tier = $this->determineTier($rank);
            $leafHash = $this->hashLeaf($chainId, $distributor, $epochId, $rewardToken, $alloc['wallet_address'], $alloc['balance_raw']);
            $leaves[] = [
                'wallet_address' => $alloc['wallet_address'], 'balance_raw' => $alloc['balance_raw'],
                'rank' => $rank, 'tier_name' => $tier['name'], 'share_percent' => $tier['share'], 'leaf_hash' => $leafHash,
            ];
        }

        $tree = $this->buildMerkleTree(array_column($leaves, 'leaf_hash'));
        $root = $tree[0][0] ?? '0x' . str_repeat('00', 32);
        return ['root' => '0x' . $root, 'leaves' => $leaves, 'tree' => $tree, 'total_leaves' => count($leaves)];
    }

    public function generateProof(array $tree, int $leafIndex): array
    {
        $proof = [];
        $index = $leafIndex;
        for ($layer = count($tree) - 1; $layer > 0; $layer--) {
            $si = ($index % 2 === 0) ? $index + 1 : $index - 1;
            if (isset($tree[$layer][$si])) $proof[] = '0x' . $tree[$layer][$si];
            $index = (int) floor($index / 2);
        }
        return $proof;
    }

    public function verifyProof(string $leafHash, array $proof, string $root): bool
    {
        $c = $leafHash;
        foreach ($proof as $s) {
            $pair = $this->sortPair($c, substr($s, 2));
            $c = $this->keccak(hex2bin($pair[0] . $pair[1]));
        }
        return '0x' . $c === $root;
    }

    public function hashLeaf(int $chainId, string $distributor, int $epochId, string $rewardToken, string $account, string $amount): string
    {
        $enc = $this->encU256((string)$chainId) . $this->encAddr($distributor)
             . $this->encU256((string)$epochId) . $this->encAddr($rewardToken)
             . $this->encAddr($account) . $this->encU256($amount);
        return $this->keccak(hex2bin($this->keccak(hex2bin($enc))));
    }

    private function keccak(string $d): string
    {
        if (class_exists(\kornrunner\Keccak::class)) return \kornrunner\Keccak::hash($d, 256);
        $h = hash('sha3-256', $d, false);
        $exp = '36f028580bb02cc8272a9a020f4200e346e276ae664e45ee80745574e2f5ab80';
        if (hash('sha3-256', 'test', false) === $exp) return $h;
        throw new \RuntimeException('No EVM keccak-256 available.');
    }

    private function encU256(string $v): string
    {
        $hex = ''; $x = $v;
        while (bccomp($x, '0') > 0) { $rem = bcmod($x, '16'); $hex = dechex((int)$rem) . $hex; $x = bcdiv($x, '16', 0); }
        return str_pad($hex ?: '0', 64, '0', STR_PAD_LEFT);
    }

    private function encAddr(string $a): string
    {
        return str_pad(substr(strtolower(trim($a)), 2), 64, '0', STR_PAD_LEFT);
    }

    private function buildMerkleTree(array $leaves): array
    {
        if (empty($leaves)) return [['0x' . str_repeat('00', 32)]];
        $tree = [$leaves]; $layer = $leaves;
        while (count($layer) > 1) {
            $next = [];
            for ($i = 0; $i < count($layer); $i += 2) {
                $l = $layer[$i]; $r = $layer[$i+1] ?? $l;
                $p = $this->sortPair($l, $r);
                $next[] = $this->keccak(hex2bin($p[0] . $p[1]));
            }
            array_unshift($tree, $next); $layer = $next;
        }
        return $tree;
    }

    private function sortPair(string $a, string $b): array { return strcmp($a, $b) <= 0 ? [$a, $b] : [$b, $a]; }

    private function determineTier(int $rank): array
    {
        foreach (self::TIERS as $t) { if ($rank >= $t['min'] && $rank <= $t['max']) return $t; }
        return ['name' => 'Unranked', 'share' => 0];
    }
}
