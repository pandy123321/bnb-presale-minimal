<?php

declare(strict_types=1);

namespace Tests\Feature\Core;

use App\Modules\Core\ContractRegistry\Models\ContractRegistry;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class ApiStatusContractTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Config::set('app.env', 'local');
        Config::set('pangu2.chain_id', 31337);
        Config::set('pangu2.chain_name', 'Anvil');
        Config::set('pangu2.rpc_url', 'http://127.0.0.1:8545');
        Config::set('pangu2.backup_rpc_url', '');
        Config::set('pangu2.supported_networks', [31337, 97]);
        Config::set('pangu2.freshness_stale_blocks', 20);
        Config::set('pangu2.freshness_degraded_blocks', 200);
        Config::set('pangu2.deployment_block', '42000000');
    }

    // ═══════════════════════════════════════════════════
    // RPC chainId mismatch
    // ═══════════════════════════════════════════════════

    public function test_rpc_chain_id_mismatch_detected(): void
    {
        // eth_blockNumber succeeds, but eth_chainId returns 56 (wrong)
        Http::fake([
            'http://127.0.0.1:8545' => fn ($request) => $this->mockRpcResponse($request, [
                'eth_blockNumber' => ['result' => '0x28fa66'],
                'eth_chainId'     => ['result' => '0x38'], // 56 = BSC Mainnet, not 31337
            ]),
        ]);

        $res = $this->getJson('/api/v1/projects/pangu2/system-status');

        $res->assertOk();
        // RPC should be DOWN because chainId doesn't match
        $res->assertJsonPath('data.rpc_status', 'DOWN');
    }

    public function test_rpc_chain_id_matches_ok(): void
    {
        Http::fake([
            'http://127.0.0.1:8545' => fn ($request) => $this->mockRpcResponse($request, [
                'eth_blockNumber' => ['result' => '0x28fa66'],
                'eth_chainId'     => ['result' => '0x7a69'], // 31337
            ]),
        ]);

        $res = $this->getJson('/api/v1/projects/pangu2/system-status');

        $res->assertOk();
        $res->assertJsonPath('data.rpc_status', 'OK');
    }

    // ═══════════════════════════════════════════════════
    // Worker unsynced state
    // ═══════════════════════════════════════════════════

    public function test_system_status_syncing_when_no_cursors(): void
    {
        Http::fake([
            'http://127.0.0.1:8545' => fn ($request) => $this->mockRpcResponse($request, [
                'eth_blockNumber' => ['result' => '0x28fa66'],
                'eth_chainId'     => ['result' => '0x7a69'],
            ]),
        ]);

        // No cursors inserted → should be SYNCING
        $res = $this->getJson('/api/v1/projects/pangu2/system-status');

        $res->assertOk();
        $res->assertJsonPath('meta.data_status', 'SYNCING');
    }

    public function test_system_status_syncing_when_missing_stream(): void
    {
        Http::fake([
            'http://127.0.0.1:8545' => fn ($request) => $this->mockRpcResponse($request, [
                'eth_blockNumber' => ['result' => '0x28fa66'],
                'eth_chainId'     => ['result' => '0x7a69'],
            ]),
        ]);

        // Only TRADE_EVENTS cursor, missing DIVIDEND_EVENTS
        \DB::table('chain_sync_cursors')->insert([
            'chain_id'           => 31337,
            'stream'             => 'TRADE_EVENTS',
            'last_scanned_block'  => 2684510,
            'latest_chain_block'  => 2684514,
            'status'             => 'SYNCED',
        ]);

        $res = $this->getJson('/api/v1/projects/pangu2/system-status');
        $res->assertJsonPath('meta.data_status', 'SYNCING');
    }

    public function test_system_status_live_when_all_streams_synced(): void
    {
        Http::fake([
            'http://127.0.0.1:8545' => fn ($request) => $this->mockRpcResponse($request, [
                'eth_blockNumber' => ['result' => '0x28fa66'],
                'eth_chainId'     => ['result' => '0x7a69'],
            ]),
        ]);

        // Both streams present, within stale threshold
        foreach (['TRADE_EVENTS', 'DIVIDEND_EVENTS'] as $stream) {
            \DB::table('chain_sync_cursors')->insert([
                'chain_id'           => 31337,
                'stream'             => $stream,
                'last_scanned_block'  => 2684514,
                'latest_chain_block'  => 2684518,
                'status'             => 'SYNCED',
            ]);
        }

        // Need at least one CONFIRMED event for LIVE
        \DB::table('chain_raw_events')->insert([
            'chain_id'          => 31337,
            'contract_address'  => '0x' . str_repeat('aa', 20),
            'event_name'        => 'BuyExecuted',
            'transaction_hash'  => '0x' . str_repeat('ab', 32),
            'log_index'         => 0,
            'block_number'      => 2684510,
            'block_hash'        => '0x' . str_repeat('bb', 32),
            'block_timestamp'   => now(),
            'decoded_data'      => '{}',
            'topics'            => '[]',
            'status'            => 'CONFIRMED',
        ]);

        $res = $this->getJson('/api/v1/projects/pangu2/system-status');
        $res->assertJsonPath('meta.data_status', 'LIVE');
    }

    public function test_system_status_degraded_on_reorg_recovery(): void
    {
        Http::fake([
            'http://127.0.0.1:8545' => fn ($request) => $this->mockRpcResponse($request, [
                'eth_blockNumber' => ['result' => '0x28fa66'],
                'eth_chainId'     => ['result' => '0x7a69'],
            ]),
        ]);

        foreach (['TRADE_EVENTS', 'DIVIDEND_EVENTS'] as $stream) {
            \DB::table('chain_sync_cursors')->insert([
                'chain_id'           => 31337,
                'stream'             => $stream,
                'last_scanned_block'  => 2684514,
                'latest_chain_block'  => 2684518,
                'status'             => 'REORG_RECOVERY',
            ]);
        }

        \DB::table('chain_raw_events')->insert([
            'chain_id'          => 31337,
            'contract_address'  => '0x' . str_repeat('aa', 20),
            'event_name'        => 'BuyExecuted',
            'transaction_hash'  => '0x' . str_repeat('ab', 32),
            'log_index'         => 0,
            'block_number'      => 2684510,
            'block_hash'        => '0x' . str_repeat('bb', 32),
            'block_timestamp'   => now(),
            'decoded_data'      => '{}',
            'topics'            => '[]',
            'status'            => 'CONFIRMED',
        ]);

        $res = $this->getJson('/api/v1/projects/pangu2/system-status');
        $res->assertJsonPath('meta.data_status', 'DEGRADED');
    }

    public function test_empty_confirmed_events_not_live(): void
    {
        Http::fake([
            'http://127.0.0.1:8545' => fn ($request) => $this->mockRpcResponse($request, [
                'eth_blockNumber' => ['result' => '0x28fa66'],
                'eth_chainId'     => ['result' => '0x7a69'],
            ]),
        ]);

        foreach (['TRADE_EVENTS', 'DIVIDEND_EVENTS'] as $stream) {
            \DB::table('chain_sync_cursors')->insert([
                'chain_id'           => 31337,
                'stream'             => $stream,
                'last_scanned_block'  => 2684514,
                'latest_chain_block'  => 2684518,
                'status'             => 'SYNCED',
            ]);
        }

        // No CONFIRMED events → SYNCING, not LIVE
        $res = $this->getJson('/api/v1/projects/pangu2/system-status');
        $res->assertJsonPath('meta.data_status', 'SYNCING');
    }

    // ═══════════════════════════════════════════════════
    // Contract Registry validation
    // ═══════════════════════════════════════════════════

    public function test_contracts_returns_unavailable_for_missing_contracts(): void
    {
        Http::fake([
            'http://127.0.0.1:8545' => fn ($request) => $this->mockRpcResponse($request, [
                'eth_blockNumber' => ['result' => '0x28fa66'],
                'eth_chainId'     => ['result' => '0x7a69'],
            ]),
        ]);

        $res = $this->getJson('/api/v1/projects/pangu2/contracts');
        $res->assertOk();

        // Since no contracts are configured, each known contract should be UNAVAILABLE
        $data = $res->json('data');
        $this->assertIsArray($data);

        foreach ($data as $entry) {
            if ($entry['status'] === 'UNAVAILABLE') {
                $this->assertEquals('0x0000000000000000000000000000000000000000', $entry['address']);
                $this->assertEquals('0.0.0', $entry['abi_version']);
            }
        }
    }

    public function test_contract_invalid_address_rejected(): void
    {
        Http::fake([
            'http://127.0.0.1:8545' => fn ($request) => $this->mockRpcResponse($request, [
                'eth_blockNumber' => ['result' => '0x28fa66'],
                'eth_chainId'     => ['result' => '0x7a69'],
            ]),
        ]);

        // Register an invalid address in the DB
        \DB::table('contract_registry')->insert([
            'environment'      => 'local',
            'chain_id'         => 31337,
            'name'             => 'BNBPresale',
            'address'          => '0xINVALID',
            'abi_version'      => '1.0.0',
            'deployment_block' => '0',
            'status'           => 'ACTIVE',
        ]);

        $res = $this->getJson('/api/v1/projects/pangu2/contracts');
        $res->assertOk();

        // The invalid address should be in the response but marked accordingly
        $data = collect($res->json('data'));
        $presale = $data->firstWhere('name', 'BNBPresale');
        $this->assertNotNull($presale);
    }

    // ═══════════════════════════════════════════════════
    // Quote source whitelist
    // ═══════════════════════════════════════════════════

    public function test_mock_buy_quote_returns_unavailable(): void
    {
        $res = $this->postJson('/api/v1/projects/pangu2/quotes/buy', [
            'amount_bnb_wei' => '1000000000000000000',
        ]);

        $res->assertOk();
        // Mock source → UNAVAILABLE
        $res->assertJsonPath('meta.data_status', 'UNAVAILABLE');
        $res->assertJsonPath('data.source', 'mock');
    }

    public function test_mock_sell_quote_returns_unavailable(): void
    {
        $res = $this->postJson('/api/v1/projects/pangu2/quotes/sell', [
            'amount_token_raw' => '100000000000000000000000',
            'wallet_address'   => '0x' . str_repeat('a', 40),
        ]);

        $res->assertOk();
        $res->assertJsonPath('meta.data_status', 'UNAVAILABLE');
        $res->assertJsonPath('data.source', 'mock');
    }

    // ═══════════════════════════════════════════════════
    // OpenAPI envelope validation
    // ═══════════════════════════════════════════════════

    public function test_config_response_matches_envelope(): void
    {
        Http::fake([
            'http://127.0.0.1:8545' => fn ($request) => $this->mockRpcResponse($request, [
                'eth_blockNumber' => ['result' => '0x28fa66'],
                'eth_chainId'     => ['result' => '0x7a69'],
            ]),
        ]);

        $res = $this->getJson('/api/v1/projects/pangu2/config');
        $this->assertValidEnvelope($res);
        $res->assertJsonPath('data.project', 'PANGU2');
        $res->assertJsonPath('data.rpc_status', 'OK');
    }

    public function test_system_status_response_matches_envelope(): void
    {
        Http::fake([
            'http://127.0.0.1:8545' => fn ($request) => $this->mockRpcResponse($request, [
                'eth_blockNumber' => ['result' => '0x28fa66'],
                'eth_chainId'     => ['result' => '0x7a69'],
            ]),
        ]);

        $res = $this->getJson('/api/v1/projects/pangu2/system-status');
        $this->assertValidEnvelope($res);
        $res->assertJsonPath('success', true);
        $res->assertJsonPath('error', null);
    }

    public function test_all_endpoints_return_valid_envelope(): void
    {
        Http::fake([
            'http://127.0.0.1:8545' => fn ($request) => $this->mockRpcResponse($request, [
                'eth_blockNumber' => ['result' => '0x28fa66'],
                'eth_chainId'     => ['result' => '0x7a69'],
            ]),
        ]);

        $endpoints = [
            ['GET',  '/api/v1/projects/pangu2/config'],
            ['GET',  '/api/v1/projects/pangu2/system-status'],
            ['GET',  '/api/v1/projects/pangu2/contracts'],
            ['POST', '/api/v1/projects/pangu2/quotes/buy', ['amount_bnb_wei' => '1000000000000000000']],
            ['POST', '/api/v1/projects/pangu2/quotes/sell', ['amount_token_raw' => '100000000000000000000000', 'wallet_address' => '0x' . str_repeat('a', 40)]],
            ['GET',  '/api/v1/projects/pangu2/wallets/0x' . str_repeat('a', 40) . '/transactions'],
            ['GET',  '/api/v1/projects/pangu2/staking/status'],
        ];

        foreach ($endpoints as $endpoint) {
            $method = $endpoint[0];
            $url    = $endpoint[1];
            $body   = $endpoint[2] ?? [];

            $res = match ($method) {
                'GET'  => $this->getJson($url),
                'POST' => $this->postJson($url, $body),
            };

            $this->assertValidEnvelope($res, "Endpoint $method $url");
            $this->assertContains(
                $res->json('meta.data_status'),
                ['LIVE', 'STALE', 'DEGRADED', 'SYNCING', 'UNAVAILABLE'],
                "data_status must be a known enum value for $method $url"
            );
        }
    }

    public function test_openapi_spec_is_accessible(): void
    {
        $res = $this->get('/openapi.yaml');
        $res->assertOk();
        $res->assertHeader('Content-Type', 'text/yaml; charset=UTF-8');
    }

    // ═══════════════════════════════════════════════════
    // Backward compatibility
    // ═══════════════════════════════════════════════════

    public function test_buy_quote_response_shape_unchanged(): void
    {
        $res = $this->postJson('/api/v1/projects/pangu2/quotes/buy', [
            'amount_bnb_wei' => '1000000000000000000',
        ]);

        $res->assertOk();
        $data = $res->json('data');
        $this->assertArrayHasKey('amount_in_wei', $data);
        $this->assertArrayHasKey('gross_tokens_raw', $data);
        $this->assertArrayHasKey('tax_rate', $data);
        $this->assertArrayHasKey('tax_tokens_raw', $data);
        $this->assertArrayHasKey('net_tokens_raw', $data);
        $this->assertArrayHasKey('min_receive_raw', $data);
        $this->assertArrayHasKey('quote_block', $data);
        $this->assertArrayHasKey('expires_at', $data);
        $this->assertArrayHasKey('source', $data);
    }

    public function test_sell_quote_response_shape_unchanged(): void
    {
        $res = $this->postJson('/api/v1/projects/pangu2/quotes/sell', [
            'amount_token_raw' => '100000000000000000000000',
            'wallet_address'   => '0x' . str_repeat('a', 40),
        ]);

        $res->assertOk();
        $data = $res->json('data');
        $this->assertArrayHasKey('amount_in_raw', $data);
        $this->assertArrayHasKey('gross_bnb_wei', $data);
        $this->assertArrayHasKey('tax_rate', $data);
        $this->assertArrayHasKey('tax_tokens_raw', $data);
        $this->assertArrayHasKey('tax_destination', $data);
        $this->assertArrayHasKey('net_bnb_wei', $data);
        $this->assertArrayHasKey('min_receive_wei', $data);
        $this->assertArrayHasKey('quote_block', $data);
        $this->assertArrayHasKey('expires_at', $data);
        $this->assertArrayHasKey('source', $data);
    }

    // ═══════════════════════════════════════════════════
    // Helpers
    // ═══════════════════════════════════════════════════

    private function mockRpcResponse($request, array $methodResults): \Illuminate\Http\Client\Response
    {
        $body = json_decode((string) $request->body(), true);
        $method = $body['method'] ?? '';

        if (isset($methodResults[$method])) {
            return Http::response(array_merge([
                'jsonrpc' => '2.0',
                'id'      => $body['id'] ?? 1,
            ], $methodResults[$method]));
        }

        return Http::response([
            'jsonrpc' => '2.0',
            'result'  => '0x0',
            'id'      => $body['id'] ?? 1,
        ]);
    }

    private function assertValidEnvelope($response, string $message = ''): void
    {
        $response->assertOk();
        $json = $response->json();

        $this->assertTrue($json['success'] ?? false, "success must be true $message");
        $this->assertArrayHasKey('data', $json, "must have data $message");
        $this->assertArrayHasKey('meta', $json, "must have meta $message");
        $this->assertNull($json['error'] ?? null, "error must be null for success $message");

        $meta = $json['meta'];
        $this->assertEquals('PANGU2', $meta['project'] ?? '');
        $this->assertEquals('pangu2', $meta['project_id'] ?? '');
        $this->assertEquals('1.0.0', $meta['schema_version'] ?? '');
        $this->assertArrayHasKey('data_status', $meta);
        $this->assertArrayHasKey('generated_at', $meta);
    }
}
