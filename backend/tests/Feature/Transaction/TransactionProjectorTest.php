<?php

declare(strict_types=1);

namespace Tests\Feature\Transaction;

use App\Modules\Core\Transaction\Models\TransactionProjection;
use App\Modules\Core\Transaction\TransactionProjector;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class TransactionProjectorTest extends TestCase
{
    private TransactionProjector $projector;

    protected function setUp(): void
    {
        parent::setUp();
        $this->projector = app(TransactionProjector::class);
    }

    // ── Event Mapping ────────────────────────

    public function test_buy_event_creates_buy_projection(): void
    {
        DB::table('chain_raw_events')->insert([
            'chain_id'          => 31337,
            'contract_address'  => '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'event_name'        => 'BuyExecuted',
            'transaction_hash'  => '0x' . str_repeat('ab', 32),
            'log_index'         => 0,
            'block_number'      => 100,
            'block_hash'        => '0x' . str_repeat('cc', 32),
            'block_timestamp'   => now()->subHour(),
            'decoded_data'      => json_encode(['buyer' => '0xB0b0000000000000000000000000000000000000']),
            'topics'            => json_encode([]),
            'status'            => 'PENDING_CONFIRMATION',
            'created_at'        => now(),
            'updated_at'        => now(),
        ]);

        $result = $this->projector->processBatch(31337, 0, 200);

        $this->assertEquals(1, $result['created']);

        $tx = TransactionProjection::where('tx_hash', '0x' . str_repeat('ab', 32))->first();
        $this->assertNotNull($tx);
        $this->assertEquals('buy', $tx->type);
        $this->assertEquals('0xb0b0000000000000000000000000000000000000', $tx->from_address);
        $this->assertEquals('pending', $tx->status);
    }

    public function test_sell_event_creates_sell_projection(): void
    {
        DB::table('chain_raw_events')->insert([
            'chain_id'          => 31337,
            'contract_address'  => '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'event_name'        => 'SellExecuted',
            'transaction_hash'  => '0x' . str_repeat('cd', 32),
            'log_index'         => 1,
            'block_number'      => 101,
            'block_hash'        => '0x' . str_repeat('dd', 32),
            'block_timestamp'   => now()->subHour(),
            'decoded_data'      => json_encode(['seller' => '0xcafe000000000000000000000000000000000000']),
            'topics'            => json_encode([]),
            'status'            => 'PENDING_CONFIRMATION',
            'created_at'        => now(),
            'updated_at'        => now(),
        ]);

        $result = $this->projector->processBatch(31337, 0, 200);

        $tx = TransactionProjection::where('tx_hash', '0x' . str_repeat('cd', 32))->first();
        $this->assertNotNull($tx);
        $this->assertEquals('sell', $tx->type);
        $this->assertEquals('0xcafe000000000000000000000000000000000000', $tx->from_address);
    }

    // ── Status Transitions ───────────────────

    public function test_confirmed_raw_event_updates_projection_status(): void
    {
        // Create a pending projection
        $tx = TransactionProjection::create([
            'chain_id'          => 31337,
            'tx_hash'           => '0x' . str_repeat('ef', 32),
            'block_hash'        => '0x' . str_repeat('ff', 32),
            'block_number'      => 200,
            'from_address'      => '0xdead000000000000000000000000000000000000',
            'contract_address'  => '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'type'              => 'buy',
            'status'            => 'pending',
            'event_timestamp'   => now()->subHours(2),
        ]);

        // Insert a confirmed raw event for the same tx
        DB::table('chain_raw_events')->insert([
            'chain_id'          => 31337,
            'contract_address'  => '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'event_name'        => 'BuyExecuted',
            'transaction_hash'  => '0x' . str_repeat('ef', 32),
            'log_index'         => 0,
            'block_number'      => 200,
            'block_hash'        => '0x' . str_repeat('ff', 32),
            'block_timestamp'   => now()->subHours(2),
            'decoded_data'      => json_encode(['buyer' => '0xdead000000000000000000000000000000000000']),
            'topics'            => json_encode([]),
            'status'            => 'CONFIRMED',
            'created_at'        => now(),
            'updated_at'        => now(),
        ]);

        $this->projector->processBatch(31337, 0, 300);

        $tx->refresh();
        $this->assertEquals('confirmed', $tx->status);
        $this->assertNotNull($tx->confirmed_at);
    }

    public function test_reorged_raw_event_marks_projection_reorged(): void
    {
        $tx = TransactionProjection::create([
            'chain_id'          => 31337,
            'tx_hash'           => '0x' . str_repeat('99', 32),
            'block_hash'        => '0x' . str_repeat('88', 32),
            'block_number'      => 300,
            'from_address'      => '0xbad0000000000000000000000000000000000000',
            'contract_address'  => '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'type'              => 'sell',
            'status'            => 'confirmed',
            'confirmed_at'      => now()->subHour(),
            'event_timestamp'   => now()->subHours(3),
        ]);

        DB::table('chain_raw_events')->insert([
            'chain_id'          => 31337,
            'contract_address'  => '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'event_name'        => 'SellExecuted',
            'transaction_hash'  => '0x' . str_repeat('99', 32),
            'log_index'         => 0,
            'block_number'      => 300,
            'block_hash'        => '0x' . str_repeat('88', 32),
            'block_timestamp'   => now()->subHours(3),
            'decoded_data'      => json_encode(['seller' => '0xbad0000000000000000000000000000000000000']),
            'topics'            => json_encode([]),
            'status'            => 'REORGED',
            'created_at'        => now(),
            'updated_at'        => now(),
        ]);

        $this->projector->processBatch(31337, 0, 400);

        $tx->refresh();
        $this->assertEquals('reorged', $tx->status);
        $this->assertNotNull($tx->reorged_at);
    }

    // ── Idempotency ──────────────────────────

    public function test_process_batch_is_idempotent(): void
    {
        DB::table('chain_raw_events')->insert([
            'chain_id'          => 31337,
            'contract_address'  => '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'event_name'        => 'BuyExecuted',
            'transaction_hash'  => '0x' . str_repeat('aa', 32),
            'log_index'         => 0,
            'block_number'      => 400,
            'block_hash'        => '0x' . str_repeat('bb', 32),
            'block_timestamp'   => now()->subHour(),
            'decoded_data'      => json_encode(['buyer' => '0xace00000000000000000000000000000000000000']),
            'topics'            => json_encode([]),
            'status'            => 'PENDING_CONFIRMATION',
            'created_at'        => now(),
            'updated_at'        => now(),
        ]);

        $r1 = $this->projector->processBatch(31337, 0, 500);
        $r2 = $this->projector->processBatch(31337, 0, 500);

        $this->assertEquals($r1['created'], $r2['created']);
        $this->assertEquals(0, $r2['created']); // second pass created nothing new
    }

    // ── Handle Reorg ─────────────────────────

    public function test_handle_reorg_marks_all_projections_in_block(): void
    {
        TransactionProjection::create([
            'chain_id'          => 31337,
            'tx_hash'           => '0x' . str_repeat('11', 32),
            'block_hash'        => '0x' . str_repeat('22', 32),
            'block_number'      => 500,
            'from_address'      => '0xf00d000000000000000000000000000000000000',
            'contract_address'  => '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'type'              => 'buy',
            'status'            => 'confirmed',
            'confirmed_at'      => now()->subHour(),
            'event_timestamp'   => now()->subHours(2),
        ]);

        TransactionProjection::create([
            'chain_id'          => 31337,
            'tx_hash'           => '0x' . str_repeat('33', 32),
            'block_hash'        => '0x' . str_repeat('22', 32),
            'block_number'      => 500,
            'from_address'      => '0xbeef000000000000000000000000000000000000',
            'contract_address'  => '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'type'              => 'sell',
            'status'            => 'confirmed',
            'confirmed_at'      => now()->subHour(),
            'event_timestamp'   => now()->subHours(2),
        ]);

        $count = $this->projector->handleReorg(31337, 500);
        $this->assertEquals(2, $count);

        $txs = TransactionProjection::where('block_number', 500)->get();
        foreach ($txs as $tx) {
            $this->assertEquals('reorged', $tx->status);
        }
    }

    // ── History Query ────────────────────────

    public function test_get_history_returns_filtered_transactions(): void
    {
        TransactionProjection::create([
            'chain_id'          => 31337,
            'tx_hash'           => '0x' . str_repeat('h1', 32),
            'block_hash'        => '0x' . str_repeat('bb', 32),
            'block_number'      => 600,
            'from_address'      => '0xwallet000000000000000000000000000000000000',
            'contract_address'  => '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'type'              => 'buy',
            'status'            => 'confirmed',
            'confirmed_at'      => now(),
            'event_timestamp'   => now(),
        ]);

        TransactionProjection::create([
            'chain_id'          => 31337,
            'tx_hash'           => '0x' . str_repeat('h2', 32),
            'block_hash'        => '0x' . str_repeat('cc', 32),
            'block_number'      => 601,
            'from_address'      => '0xwallet000000000000000000000000000000000000',
            'contract_address'  => '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'type'              => 'sell',
            'status'            => 'confirmed',
            'confirmed_at'      => now(),
            'event_timestamp'   => now(),
        ]);

        $history = $this->projector->getHistory(31337, '0xwallet000000000000000000000000000000000000');

        $this->assertEquals(2, $history['total']);
        $this->assertCount(2, $history['data']);
        $this->assertEquals('sell', $history['data'][0]['type']); // most recent first
    }

    public function test_get_history_filters_by_type(): void
    {
        $history = $this->projector->getHistory(
            31337,
            '0xwallet000000000000000000000000000000000000',
            'buy',
        );

        $this->assertEquals(1, $history['total']);
        $this->assertEquals('buy', $history['data'][0]['type']);
    }
}
