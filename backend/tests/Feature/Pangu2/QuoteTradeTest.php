<?php

declare(strict_types=1);

namespace Tests\Feature\Pangu2;

use Tests\TestCase;

class QuoteTradeTest extends TestCase
{
    private const BUY_URI   = '/api/v1/projects/pangu2/quotes/buy';
    private const SELL_URI  = '/api/v1/projects/pangu2/quotes/sell';
    private const TX_URI    = '/api/v1/projects/pangu2/wallets/0x7c4e00000000000000000000000000000a91f/transactions';

    // ===================================================================
    // 1. Buy quote — valid
    // ===================================================================

    public function test_buy_quote_returns_mock_quote_with_correct_fields(): void
    {
        $res = $this->postJson(self::BUY_URI, [
            'amount_bnb_wei' => '100000000000000000',
        ]);

        $res->assertOk();
        $res->assertJsonPath('data.source', 'mock');
        $res->assertJsonPath('data.tax_rate', '4.00%');
        $res->assertJsonPath('meta.data_status', 'UNAVAILABLE');
        $res->assertJsonPath('error', null);

        // All amounts are string
        $this->assertIsString($res->json('data.amount_in_wei'));
        $this->assertIsString($res->json('data.gross_tokens_raw'));
        $this->assertIsString($res->json('data.tax_tokens_raw'));
        $this->assertIsString($res->json('data.net_tokens_raw'));
        $this->assertIsString($res->json('data.min_receive_raw'));
        $this->assertIsString($res->json('data.quote_block'));
        $this->assertIsString($res->json('data.expires_at'));

        // net < gross (tax deducted)
        $net   = $res->json('data.net_tokens_raw');
        $gross = $res->json('data.gross_tokens_raw');
        $this->assertLessThan($gross, $net);

        // min_receive <= net
        $min = $res->json('data.min_receive_raw');
        $this->assertLessThanOrEqual($net, $min);

        // quote_block present in meta
        $this->assertNotNull($res->json('meta.block_number'));
    }

    public function test_buy_quote_scales_with_amount(): void
    {
        $small = $this->postJson(self::BUY_URI, [
            'amount_bnb_wei' => '100000000000000000',   // 0.1 BNB
        ]);
        $large = $this->postJson(self::BUY_URI, [
            'amount_bnb_wei' => '1000000000000000000',  // 1.0 BNB
        ]);

        $smallGross = (int) $small->json('data.gross_tokens_raw');
        $largeGross = (int) $large->json('data.gross_tokens_raw');

        $this->assertGreaterThan($smallGross, $largeGross);
    }

    // ===================================================================
    // 2. Buy quote — invalid
    // ===================================================================

    public function test_buy_quote_rejects_missing_amount(): void
    {
        $res = $this->postJson(self::BUY_URI, []);

        $res->assertStatus(422);
    }

    public function test_buy_quote_rejects_zero_amount(): void
    {
        $res = $this->postJson(self::BUY_URI, [
            'amount_bnb_wei' => '0',
        ]);

        $res->assertStatus(422);
    }

    public function test_buy_quote_rejects_negative_amount(): void
    {
        $res = $this->postJson(self::BUY_URI, [
            'amount_bnb_wei' => '-100',
        ]);

        $res->assertStatus(422);
    }

    public function test_buy_quote_rejects_non_numeric_amount(): void
    {
        $res = $this->postJson(self::BUY_URI, [
            'amount_bnb_wei' => 'not-a-number',
        ]);

        $res->assertStatus(422);
    }

    // ===================================================================
    // 3. Sell quote — valid
    // ===================================================================

    public function test_sell_quote_returns_mock_quote_with_correct_fields(): void
    {
        $res = $this->postJson(self::SELL_URI, [
            'amount_token_raw' => '10000000000000000000000',
            'wallet_address'   => '0x7c4E00000000000000000000000000000A91F',
        ]);

        $res->assertOk();
        $res->assertJsonPath('data.source', 'mock');
        $res->assertJsonPath('data.tax_rate', '4%');
        $res->assertJsonPath('data.tax_destination', '4%→SupportPool');
        $res->assertJsonPath('meta.data_status', 'UNAVAILABLE');
        $res->assertJsonPath('error', null);

        $this->assertIsString($res->json('data.amount_in_raw'));
        $this->assertIsString($res->json('data.gross_bnb_wei'));
        $this->assertIsString($res->json('data.net_bnb_wei'));
        $this->assertIsString($res->json('data.min_receive_wei'));
    }

    public function test_sell_quote_normalizes_wallet_address(): void
    {
        $res = $this->postJson(self::SELL_URI, [
            'amount_token_raw' => '10000000000000000000000',
            'wallet_address'   => '0x7C4E00000000000000000000000000000A91F', // uppercase
        ]);

        $res->assertOk();
    }

    // ===================================================================
    // 4. Sell quote — invalid
    // ===================================================================

    public function test_sell_quote_rejects_missing_wallet_address(): void
    {
        $res = $this->postJson(self::SELL_URI, [
            'amount_token_raw' => '10000000000000000000000',
        ]);

        $res->assertStatus(422);
    }

    public function test_sell_quote_rejects_invalid_wallet_address(): void
    {
        $res = $this->postJson(self::SELL_URI, [
            'amount_token_raw' => '10000000000000000000000',
            'wallet_address'   => 'not-an-address',
        ]);

        $res->assertStatus(422);
    }

    public function test_sell_quote_rejects_short_wallet_address(): void
    {
        $res = $this->postJson(self::SELL_URI, [
            'amount_token_raw' => '10000000000000000000000',
            'wallet_address'   => '0x123',
        ]);

        $res->assertStatus(422);
    }

    // ===================================================================
    // 5. Transactions — valid
    // ===================================================================

    public function test_transactions_returns_mock_list(): void
    {
        $res = $this->getJson(self::TX_URI);

        $res->assertOk();
        $res->assertJsonPath('meta.data_status', 'UNAVAILABLE');
        $res->assertJsonPath('error', null);
        $this->assertIsArray($res->json('data'));
        $this->assertGreaterThan(0, count($res->json('data')));

        // Each transaction has required fields
        $tx = $res->json('data')[0];
        $this->assertArrayHasKey('tx_hash', $tx);
        $this->assertArrayHasKey('block_number', $tx);
        $this->assertArrayHasKey('type', $tx);
        $this->assertArrayHasKey('amount_in', $tx);
        $this->assertArrayHasKey('amount_out', $tx);
        $this->assertArrayHasKey('status', $tx);
        $this->assertArrayHasKey('timestamp', $tx);
    }

    public function test_transactions_supports_pagination(): void
    {
        $res = $this->getJson(self::TX_URI . '?page=1&per_page=2');

        $res->assertOk();

        // Pagination meta
        $this->assertArrayHasKey('current_page', $res->json('meta'));
        $this->assertArrayHasKey('per_page', $res->json('meta'));
        $this->assertArrayHasKey('total', $res->json('meta'));
        $this->assertArrayHasKey('last_page', $res->json('meta'));
        $this->assertEquals(1, $res->json('meta.current_page'));
        $this->assertEquals(2, $res->json('meta.per_page'));

        // Should return at most per_page items
        $items = $res->json('data');
        $this->assertLessThanOrEqual(2, count($items));
    }

    // ===================================================================
    // 6. Envelope structure
    // ===================================================================

    public function test_all_endpoints_return_uniform_envelope(): void
    {
        $endpoints = [
            ['method' => 'postJson', 'uri' => self::BUY_URI,  'body' => ['amount_bnb_wei'   => '100000000000000000']],
            ['method' => 'postJson', 'uri' => self::SELL_URI, 'body' => ['amount_token_raw' => '10000', 'wallet_address' => '0x7c4E00000000000000000000000000000A91F']],
            ['method' => 'getJson',  'uri' => self::TX_URI,   'body' => []],
        ];

        foreach ($endpoints as $ep) {
            if ($ep['body']) {
                $res = $this->{$ep['method']}($ep['uri'], $ep['body']);
            } else {
                $res = $this->{$ep['method']}($ep['uri']);
            }

            $json = $res->json();
            $this->assertArrayHasKey('data', $json, "{$ep['uri']} missing data");
            $this->assertArrayHasKey('meta', $json, "{$ep['uri']} missing meta");
            $this->assertArrayHasKey('error', $json, "{$ep['uri']} missing error");
            $this->assertArrayHasKey('project', $json['meta']);
            $this->assertArrayHasKey('environment', $json['meta']);
            $this->assertArrayHasKey('data_status', $json['meta']);
            $this->assertEquals('UNAVAILABLE', $json['meta']['data_status']);
        }
    }

    // ===================================================================
    // 7. No client rate parameter accepted
    // ===================================================================

    public function test_sell_quote_ignores_client_rate_parameter(): void
    {
        // Even if client sends a rate, it should not affect the quote
        $res = $this->postJson(self::SELL_URI, [
            'amount_token_raw' => '10000000000000000000000',
            'wallet_address'   => '0x7c4E00000000000000000000000000000A91F',
            'rate'             => '10%',  // client trying to select 10% tier
        ]);

        $res->assertOk();
        // Rate is determined by mock service (4%), not by client input
        $this->assertEquals('4%', $res->json('data.tax_rate'));
    }
}
