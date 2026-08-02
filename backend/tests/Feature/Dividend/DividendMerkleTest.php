<?php

declare(strict_types=1);

namespace Tests\Feature\Dividend;

use App\Modules\Pangu2\Dividend\Models\DividendAllocation;
use App\Modules\Pangu2\Dividend\Models\DividendEpoch;
use App\Modules\Pangu2\Dividend\Services\MerkleProofGenerator;
use Tests\TestCase;

class DividendMerkleTest extends TestCase
{
    private MerkleProofGenerator $merkle;

    protected function setUp(): void
    {
        parent::setUp();
        $this->merkle = app(MerkleProofGenerator::class);
    }

    // ── Deterministic Ranking ────────────────────

    public function test_ranking_is_descending_by_balance(): void
    {
        $alloc = [
            ['wallet_address' => '0x' . str_repeat('aa', 20), 'balance_raw' => '100000000000000000000000'],
            ['wallet_address' => '0x' . str_repeat('bb', 20), 'balance_raw' => '500000000000000000000000'],
            ['wallet_address' => '0x' . str_repeat('cc', 20), 'balance_raw' => '300000000000000000000000'],
        ];

        $tree = $this->merkle->buildTree($alloc);

        $this->assertEquals(3, $tree['total_leaves']);
        $this->assertEquals('0x' . str_repeat('bb', 20), $tree['leaves'][0]['wallet_address']); // largest
        $this->assertEquals(1, $tree['leaves'][0]['rank']);
        $this->assertEquals('0x' . str_repeat('cc', 20), $tree['leaves'][1]['wallet_address']);
        $this->assertEquals(2, $tree['leaves'][1]['rank']);
        $this->assertEquals('0x' . str_repeat('aa', 20), $tree['leaves'][2]['wallet_address']);
        $this->assertEquals(3, $tree['leaves'][2]['rank']);
    }

    public function test_tie_break_uses_address_ascending(): void
    {
        $alloc = [
            ['wallet_address' => '0x' . str_repeat('dd', 19) . 'cc', 'balance_raw' => '100000000000000000000000'],
            ['wallet_address' => '0x' . str_repeat('dd', 19) . '11', 'balance_raw' => '100000000000000000000000'],
            ['wallet_address' => '0x' . str_repeat('dd', 19) . 'aa', 'balance_raw' => '100000000000000000000000'],
        ];

        $tree = $this->merkle->buildTree($alloc);

        // Same balance → sorted by address ascending
        $this->assertEquals('0x' . str_repeat('dd', 19) . '11', $tree['leaves'][0]['wallet_address']);
        $this->assertEquals(1, $tree['leaves'][0]['rank']);
        $this->assertEquals('0x' . str_repeat('dd', 19) . 'aa', $tree['leaves'][1]['wallet_address']);
        $this->assertEquals(2, $tree['leaves'][1]['rank']);
        $this->assertEquals('0x' . str_repeat('dd', 19) . 'cc', $tree['leaves'][2]['wallet_address']);
        $this->assertEquals(3, $tree['leaves'][2]['rank']);
    }

    // ── Tier Assignment ─────────────────────────

    public function test_tier_assignment_matches_spec(): void
    {
        $alloc = [];
        // Create 100 addresses with varying balances
        for ($i = 1; $i <= 100; $i++) {
            $alloc[] = [
                'wallet_address' => '0x' . str_pad(dechex($i * 1000), 40, '0', STR_PAD_LEFT),
                'balance_raw'    => bcmul((string) (101 - $i), '1000000000000000000', 0),
            ];
        }

        $tree = $this->merkle->buildTree($alloc);

        $this->assertEquals(100, $tree['total_leaves']);
        $this->assertEquals('Tier 1', $tree['leaves'][0]['tier_name']);  // rank 1
        $this->assertEquals('Tier 1', $tree['leaves'][9]['tier_name']);  // rank 10
        $this->assertEquals('Tier 2', $tree['leaves'][10]['tier_name']); // rank 11
        $this->assertEquals('Tier 4', $tree['leaves'][99]['tier_name']); // rank 100
    }

    public function test_share_percent_matches_tier(): void
    {
        $alloc = [
            ['wallet_address' => '0x' . str_repeat('a1', 20), 'balance_raw' => '500000000000000000000000'],
            ['wallet_address' => '0x' . str_repeat('a2', 20), 'balance_raw' => '400000000000000000000000'],
            ['wallet_address' => '0x' . str_repeat('a3', 20), 'balance_raw' => '300000000000000000000000'],
        ];

        $tree = $this->merkle->buildTree($alloc);

        $this->assertEquals(35, $tree['leaves'][0]['share_percent']); // Tier 1
        $this->assertEquals(35, $tree['leaves'][1]['share_percent']); // Tier 1
        $this->assertEquals(35, $tree['leaves'][2]['share_percent']); // Tier 1
    }

    // ── Determinism ─────────────────────────────

    public function test_same_inputs_produce_same_root(): void
    {
        $alloc = [
            ['wallet_address' => '0x' . str_repeat('ab', 20), 'balance_raw' => '100000'],
            ['wallet_address' => '0x' . str_repeat('cd', 20), 'balance_raw' => '200000'],
            ['wallet_address' => '0x' . str_repeat('ef', 20), 'balance_raw' => '300000'],
        ];

        $tree1 = $this->merkle->buildTree($alloc);
        $tree2 = $this->merkle->buildTree($alloc);

        $this->assertEquals($tree1['root'], $tree2['root']);
        $this->assertEquals($tree1['leaves'], $tree2['leaves']);

        // Run 5 times — always the same
        for ($i = 0; $i < 5; $i++) {
            $t = $this->merkle->buildTree($alloc);
            $this->assertEquals($tree1['root'], $t['root']);
        }
    }

    // ── Single Leaf ─────────────────────────────

    public function test_single_leaf_tree(): void
    {
        $alloc = [
            ['wallet_address' => '0x' . str_repeat('ff', 20), 'balance_raw' => '1000'],
        ];

        $tree = $this->merkle->buildTree($alloc);
        $this->assertEquals(1, $tree['total_leaves']);
        $this->assertNotEmpty($tree['root']);
    }

    // ── Merkle Proof Generation ─────────────────

    public function test_proof_generation_and_verification(): void
    {
        $alloc = [];
        for ($i = 1; $i <= 16; $i++) {
            $alloc[] = [
                'wallet_address' => '0x' . str_pad(dechex($i * 1111), 40, '0', STR_PAD_LEFT),
                'balance_raw'    => (string) ($i * 1000),
            ];
        }

        $tree = $this->merkle->buildTree($alloc);

        // For each leaf, generate proof and verify it
        foreach ($tree['leaves'] as $i => $leaf) {
            $proof = $this->merkle->generateProof($tree['tree'], $i);
            $valid = $this->merkle->verifyProof($leaf['leaf_hash'], $proof, $tree['root']);

            $this->assertTrue($valid, "Proof verification failed for leaf {$i}");
        }
    }

    public function test_proof_verification_fails_with_wrong_root(): void
    {
        $alloc = [
            ['wallet_address' => '0x' . str_repeat('a1', 20), 'balance_raw' => '1000'],
            ['wallet_address' => '0x' . str_repeat('b2', 20), 'balance_raw' => '2000'],
        ];

        $tree = $this->merkle->buildTree($alloc);
        $proof = $this->merkle->generateProof($tree['tree'], 0);

        $this->assertFalse(
            $this->merkle->verifyProof(
                $tree['leaves'][0]['leaf_hash'],
                $proof,
                '0x' . str_repeat('ff', 32), // wrong root
            ),
        );
    }

    public function test_proof_verification_fails_with_tampered_leaf(): void
    {
        $alloc = [
            ['wallet_address' => '0x' . str_repeat('a1', 20), 'balance_raw' => '1000'],
            ['wallet_address' => '0x' . str_repeat('b2', 20), 'balance_raw' => '2000'],
        ];

        $tree = $this->merkle->buildTree($alloc);
        $proof = $this->merkle->generateProof($tree['tree'], 0);

        // Tamper with the leaf hash
        $tamperedLeaf = $this->merkle->hashLeaf(
            '0x' . str_repeat('a1', 20),
            '9999', // changed balance
            '1',
        );

        $this->assertFalse(
            $this->merkle->verifyProof($tamperedLeaf, $proof, $tree['root']),
        );
    }

    // ── API: Current Epoch ──────────────────────

    public function test_current_epoch_returns_mock_data_when_empty(): void
    {
        $res = $this->getJson('/api/v1/projects/pangu2/dividend/epochs/current');
        $res->assertOk();
        $this->assertEquals(28, $res->json('data.epoch_id'));
        $this->assertCount(4, $res->json('data.tiers'));
        $this->assertEquals('MOCK_DATA', $res->json('meta.data_status'));
    }

    public function test_current_epoch_returns_persisted_epoch(): void
    {
        DividendEpoch::create([
            'chain_id'           => 31337,
            'epoch_id'           => 42,
            'snapshot_block'     => 500000,
            'total_dividend_raw' => '999000000000000000000000',
            'merkle_root'        => '0x' . str_repeat('ab', 32),
            'status'             => 'claim_open',
        ]);

        $res = $this->getJson('/api/v1/projects/pangu2/dividend/epochs/current');
        $res->assertOk();
        $this->assertEquals(42, $res->json('data.epoch_id'));
        $this->assertEquals('500000', $res->json('data.snapshot_block'));
        $this->assertEquals('claim_open', $res->json('data.status'));
    }

    // ── API: Proof ──────────────────────────────

    public function test_proof_endpoint_returns_proof_for_valid_allocation(): void
    {
        $addr = '0x' . str_repeat('ab', 20);

        DividendEpoch::create([
            'chain_id'           => 31337,
            'epoch_id'           => 1,
            'snapshot_block'     => 100,
            'total_dividend_raw' => '100000000000000000000000',
            'merkle_root'        => '0x' . str_repeat('00', 32),
            'status'             => 'claim_open',
        ]);

        DividendAllocation::create([
            'chain_id'         => 31337,
            'epoch_id'         => 1,
            'wallet_address'   => $addr,
            'balance_raw'      => '50000000000000000000000',
            'rank'             => 1,
            'tier'             => 'Tier 1',
            'share_percent'    => 35,
            'allocated_raw'    => '35000000000000000000000',
            'proof_hash'       => '0x' . str_repeat('aa', 32),
        ]);

        $res = $this->getJson("/api/v1/projects/pangu2/dividend/epochs/1/proof/{$addr}");
        $res->assertOk();
        $this->assertEquals(1, $res->json('data.epoch_id'));
        $this->assertEquals($addr, $res->json('data.address'));
        $this->assertIsArray($res->json('data.proof'));
        $this->assertFalse($res->json('data.claimed'));
    }

    public function test_proof_endpoint_returns_404_for_unknown_address(): void
    {
        DividendEpoch::create([
            'chain_id'           => 31337,
            'epoch_id'           => 2,
            'snapshot_block'     => 200,
            'total_dividend_raw' => '0',
            'merkle_root'        => '0x' . str_repeat('00', 32),
            'status'             => 'pending',
        ]);

        $res = $this->getJson('/api/v1/projects/pangu2/dividend/epochs/2/proof/0x' . str_repeat('ff', 20));
        $res->assertStatus(404);
    }

    // ── API: Buybacks ───────────────────────────

    public function test_buybacks_returns_mock_data_when_empty(): void
    {
        $res = $this->getJson('/api/v1/projects/pangu2/buybacks');
        $res->assertOk();
        $this->assertIsArray($res->json('data'));
        $this->assertGreaterThanOrEqual(2, count($res->json('data')));
        $this->assertEquals('MOCK_DATA', $res->json('meta.data_status'));
    }

    // ── API: Locker Batches ─────────────────────

    public function test_locker_batches_returns_mock_data_when_empty(): void
    {
        $res = $this->getJson('/api/v1/projects/pangu2/locker/batches');
        $res->assertOk();
        $this->assertIsArray($res->json('data'));
        $this->assertGreaterThanOrEqual(2, count($res->json('data')));
        $this->assertEquals('MOCK_DATA', $res->json('meta.data_status'));
    }

    // ── Merkle with 100 Leaves ──────────────────

    public function test_100_leaf_tree_builds_and_verifies_all(): void
    {
        $alloc = [];
        for ($i = 1; $i <= 100; $i++) {
            $alloc[] = [
                'wallet_address' => '0x' . str_pad(dechex($i * 12345), 40, '0', STR_PAD_LEFT),
                'balance_raw'    => bcmul((string) (101 - $i), '1000000000000000000', 0),
            ];
        }

        $tree = $this->merkle->buildTree($alloc);
        $this->assertEquals(100, $tree['total_leaves']);
        $this->assertNotEmpty($tree['root']);

        $failures = 0;
        foreach ($tree['leaves'] as $i => $leaf) {
            $proof = $this->merkle->generateProof($tree['tree'], $i);
            $valid = $this->merkle->verifyProof($leaf['leaf_hash'], $proof, $tree['root']);
            if (!$valid) $failures++;
        }
        $this->assertEquals(0, $failures, "{$failures} proof verifications failed out of 100");
    }
}
