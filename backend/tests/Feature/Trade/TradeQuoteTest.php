<?php

declare(strict_types=1);

namespace Tests\Feature\Trade;

use Tests\TestCase;

class TradeQuoteTest extends TestCase
{
    // ── Buy Quote ────────────────────────────────────────────

    public function test_buy_quote_returns_4_percent_tax_and_mock_source(): void
    {
        $res = $this->postJson('/api/v1/projects/pangu2/quotes/buy', [
            'amount_bnb_wei' => '100000000000000000', // 0.1 BNB
        ]);

        $res->assertOk();
        $this->assertEquals('MOCK_DATA', $res->json('meta.data_status'));
        $this->assertEquals('mock', $res->json('data.source'));
        $this->assertEquals('4.00', $res->json('data.tax_rate'));

        // All quote fields present
        $this->assertNotNull($res->json('data.amount_in_wei'));
        $this->assertNotNull($res->json('data.gross_tokens_raw'));
        $this->assertNotNull($res->json('data.tax_tokens_raw'));
        $this->assertNotNull($res->json('data.net_tokens_raw'));
        $this->assertNotNull($res->json('data.min_receive_raw'));
        $this->assertNotNull($res->json('data.quote_block'));
        $this->assertNotNull($res->json('data.expires_at'));
        $this->assertNotNull($res->json('data.estimated_gas_wei'));
    }

    public function test_buy_quote_net_less_than_gross(): void
    {
        $res = $this->postJson('/api/v1/projects/pangu2/quotes/buy', [
            'amount_bnb_wei' => '1000000000000000000', // 1 BNB
        ]);

        $gross = $res->json('data.gross_tokens_raw');
        $net   = $res->json('data.net_tokens_raw');

        $this->assertGreaterThan(0, bccomp($gross, $net));
    }

    public function test_buy_quote_min_receive_less_than_net(): void
    {
        $res = $this->postJson('/api/v1/projects/pangu2/quotes/buy', [
            'amount_bnb_wei' => '100000000000000000',
        ]);

        $net        = $res->json('data.net_tokens_raw');
        $minReceive = $res->json('data.min_receive_raw');

        $this->assertGreaterThan(0, bccomp($net, $minReceive));
    }

    public function test_buy_quote_expires_in_future(): void
    {
        $res = $this->postJson('/api/v1/projects/pangu2/quotes/buy', [
            'amount_bnb_wei' => '500000000000000000',
        ]);

        $expiresAt = $res->json('data.expires_at');
        $this->assertNotNull($expiresAt);
        $this->assertGreaterThan(time(), strtotime($expiresAt));
    }

    // ── Buy Quote Validation ────────────────────────────────

    public function test_buy_quote_rejects_zero_amount(): void
    {
        $res = $this->postJson('/api/v1/projects/pangu2/quotes/buy', [
            'amount_bnb_wei' => '0',
        ]);
        $res->assertStatus(422);
    }

    public function test_buy_quote_rejects_missing_field(): void
    {
        $res = $this->postJson('/api/v1/projects/pangu2/quotes/buy', []);
        $res->assertStatus(422);
    }

    public function test_buy_quote_rejects_non_numeric(): void
    {
        $res = $this->postJson('/api/v1/projects/pangu2/quotes/buy', [
            'amount_bnb_wei' => 'hello',
        ]);
        $res->assertStatus(422);
    }

    // ── Sell Quote ───────────────────────────────────────────

    public function test_sell_quote_small_amount_returns_4_percent(): void
    {
        $res = $this->postJson('/api/v1/projects/pangu2/quotes/sell', [
            'amount_token_raw' => '10000000000000000000000', // 10,000 tokens
            'wallet_address'   => '0x14791697260e4c9a71f18484c9f997b308e59325',
        ]);

        $res->assertOk();
        $this->assertEquals('4.00', $res->json('data.tax_rate'));
        $this->assertEquals('dividend_pool', $res->json('data.tax_destination'));
        $this->assertEquals('mock', $res->json('data.source'));
        $this->assertEquals('MOCK_DATA', $res->json('meta.data_status'));
    }

    public function test_sell_quote_large_amount_returns_10_percent(): void
    {
        // 100,000 tokens (raw units)
        $res = $this->postJson('/api/v1/projects/pangu2/quotes/sell', [
            'amount_token_raw' => '100000000000000000000000',
            'wallet_address'   => '0x14791697260e4c9a71f18484c9f997b308e59325',
        ]);

        $res->assertOk();
        $this->assertEquals('10.00', $res->json('data.tax_rate'));
        $this->assertEquals('buyback_pool', $res->json('data.tax_destination'));
    }

    public function test_sell_quote_boundary_50k_tokens_returns_10_percent(): void
    {
        // Exactly 50,000 tokens = should be 10% tier
        $res = $this->postJson('/api/v1/projects/pangu2/quotes/sell', [
            'amount_token_raw' => '50000000000000000000000',
            'wallet_address'   => '0x14791697260e4c9a71f18484c9f997b308e59325',
        ]);

        $res->assertOk();
        $this->assertEquals('10.00', $res->json('data.tax_rate'));
    }

    public function test_sell_quote_requires_wallet_address(): void
    {
        $res = $this->postJson('/api/v1/projects/pangu2/quotes/sell', [
            'amount_token_raw' => '10000000000000000000000',
        ]);
        $res->assertStatus(422);
    }

    // ── Transactions ─────────────────────────────────────────

    public function test_transactions_returns_list_of_three(): void
    {
        $res = $this->getJson(
            '/api/v1/projects/pangu2/wallets/0x14791697260e4c9a71f18484c9f997b308e59325/transactions'
        );

        $res->assertOk();
        $this->assertIsArray($res->json('data'));
        $this->assertCount(3, $res->json('data'));
        $this->assertEquals('MOCK_DATA', $res->json('meta.data_status'));
    }

    public function test_transactions_all_confirmed(): void
    {
        $res = $this->getJson(
            '/api/v1/projects/pangu2/wallets/0x0000000000000000000000000000000000000000/transactions'
        );

        $res->assertOk();
        foreach ($res->json('data') as $tx) {
            $this->assertEquals('confirmed', $tx['status']);
        }
    }

    public function test_transactions_have_all_required_fields(): void
    {
        $res = $this->getJson(
            '/api/v1/projects/pangu2/wallets/0x0000000000000000000000000000000000000000/transactions'
        );

        $res->assertOk();
        $tx = $res->json('data')[0] ?? null;
        $this->assertNotNull($tx);
        $this->assertNotEmpty($tx['tx_hash']);
        $this->assertNotEmpty($tx['block_number']);
        $this->assertContains($tx['type'], ['buy', 'sell', 'claim']);
        $this->assertNotEmpty($tx['timestamp']);
    }

    // ── Envelope contract ────────────────────────────────────

    public function test_success_response_has_envelope_structure(): void
    {
        $res = $this->postJson('/api/v1/projects/pangu2/quotes/buy', [
            'amount_bnb_wei' => '100000000000000000',
        ]);

        $this->assertTrue($res->json('success'));
        $this->assertNotNull($res->json('data'));
        $this->assertEquals('PANGU2', $res->json('meta.project'));
        $this->assertNotNull($res->json('meta.generated_at'));
        $this->assertEquals('1.0.0', $res->json('meta.schema_version'));
        $this->assertNull($res->json('error'));
    }
}
