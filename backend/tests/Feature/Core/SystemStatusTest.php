<?php

declare(strict_types=1);

namespace Tests\Feature\Core;

use App\Modules\Core\ContractRegistry\Models\ContractRegistry;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class SystemStatusTest extends TestCase
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

        // Default: RPC is responsive so tests that don't care about RPC
        // don't accidentally make real HTTP calls.
        Http::fake([
            'http://127.0.0.1:8545' => Http::response([
                'jsonrpc' => '2.0',
                'result'  => '0x28fa66',
                'id'      => 1,
            ]),
        ]);
    }

    // ===================================================================
    // 1. Public read — all three endpoints accessible without auth
    // ===================================================================

    public function test_config_endpoint_returns_200(): void
    {
        Http::fake([
            'http://127.0.0.1:8545' => Http::response([
                'jsonrpc' => '2.0',
                'result'  => '0x28fa66',
                'id'      => 1,
            ]),
        ]);

        $res = $this->getJson('/api/v1/projects/pangu2/config');

        $res->assertOk();
        $res->assertJsonPath('data.project', 'PANGU2');
        $res->assertJsonPath('data.environment', 'local');
        $res->assertJsonPath('data.chain_id', 31337);
        $res->assertJsonPath('data.chain_name', 'Anvil');
        $res->assertJsonPath('data.rpc_status', 'OK');
        $res->assertJsonPath('data.supported_networks', [31337, 97]);
        $res->assertJsonPath('meta.data_status', 'LIVE');
        $res->assertJsonPath('error', null);
    }

    public function test_system_status_endpoint_returns_200(): void
    {
        $this->seedSyncCursor(31337, 5000, 4998);

        $res = $this->getJson('/api/v1/projects/pangu2/system-status');

        $res->assertOk();
        $res->assertJsonPath('data.latest_chain_block', '5000');
        $res->assertJsonPath('data.last_scanned_block', '4998');
        $res->assertJsonPath('data.block_lag', 2);
        $res->assertJsonPath('data.open_anomalies', 0);
        $res->assertJsonPath('error', null);
    }

    public function test_contracts_endpoint_returns_200(): void
    {
        ContractRegistry::create([
            'environment'      => 'local',
            'chain_id'         => 31337,
            'name'             => 'BNBPresale',
            'address'          => '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'abi_version'      => '1.0.0',
            'deployment_block' => '42000000',
            'status'           => 'ACTIVE',
            'version'          => '1.0.0',
        ]);

        $res = $this->getJson('/api/v1/projects/pangu2/contracts');

        $res->assertOk();
        $res->assertJsonPath('data.0.name', 'BNBPresale');
        $res->assertJsonPath('data.0.status', 'ACTIVE');
        $res->assertJsonPath('error', null);
    }

    // ===================================================================
    // 2. Contract status values
    // ===================================================================

    public function test_active_contract_returns_active_status(): void
    {
        ContractRegistry::create([
            'environment'      => 'local',
            'chain_id'         => 31337,
            'name'             => 'BNBPresale',
            'address'          => '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'abi_version'      => '1.2.0',
            'deployment_block' => '42000000',
            'status'           => 'ACTIVE',
            'version'          => '1.0.0',
        ]);

        $res = $this->getJson('/api/v1/projects/pangu2/contracts');

        $res->assertOk();
        $res->assertJsonPath('data.0.status', 'ACTIVE');
        $res->assertJsonPath('data.0.abi_version', '1.2.0');
        $res->assertJsonPath('data.0.deployment_block', '42000000');
    }

    public function test_paused_contract_returns_paused_status(): void
    {
        ContractRegistry::create([
            'environment'      => 'local',
            'chain_id'         => 31337,
            'name'             => 'BNBPresale',
            'address'          => '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            'abi_version'      => '1.0.0',
            'deployment_block' => '42000000',
            'status'           => 'PAUSED',
            'version'          => '1.0.0',
        ]);

        $res = $this->getJson('/api/v1/projects/pangu2/contracts');

        $res->assertOk();
        $res->assertJsonPath('data.0.status', 'PAUSED');
    }

    // ===================================================================
    // 3. Wrong chain — contracts filtered by current chain_id only
    // ===================================================================

    public function test_contracts_filtered_by_current_chain_id(): void
    {
        // Register contract on chain 31337
        ContractRegistry::create([
            'environment'      => 'local',
            'chain_id'         => 31337,
            'name'             => 'BNBPresale',
            'address'          => '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'abi_version'      => '1.0.0',
            'deployment_block' => '42000000',
            'status'           => 'ACTIVE',
            'version'          => '1.0.0',
        ]);

        // Register a DIFFERENT contract on chain 97 (testnet)
        ContractRegistry::create([
            'environment'      => 'local',
            'chain_id'         => 97,
            'name'             => 'BNBPresale',
            'address'          => '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            'abi_version'      => '1.1.0',
            'deployment_block' => '43000000',
            'status'           => 'ACTIVE',
            'version'          => '1.0.0',
        ]);

        // Current chain is 31337 → should only see that entry
        $res = $this->getJson('/api/v1/projects/pangu2/contracts');

        $res->assertOk();
        $res->assertJsonPath('data.0.chain_id', null); // chain_id is NOT in the output schema
        $res->assertJsonPath('data.0.address', '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
        $res->assertJsonPath('data.0.deployment_block', '42000000');

        // Should NOT see the chain-97 address
        $data = $res->json('data');
        $addresses = array_column($data, 'address');
        $this->assertNotContains('0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb', $addresses);
    }

    public function test_switching_chain_shows_different_contracts(): void
    {
        ContractRegistry::create([
            'environment'      => 'local',
            'chain_id'         => 31337,
            'name'             => 'BNBPresale',
            'address'          => '0xaaaa000000000000000000000000000000000000',
            'abi_version'      => '1.0.0',
            'deployment_block' => '42000000',
            'status'           => 'ACTIVE',
            'version'          => '1.0.0',
        ]);

        ContractRegistry::create([
            'environment'      => 'local',
            'chain_id'         => 97,
            'name'             => 'BNBPresale',
            'address'          => '0xbbbb000000000000000000000000000000000000',
            'abi_version'      => '1.1.0',
            'deployment_block' => '43000000',
            'status'           => 'ACTIVE',
            'version'          => '1.0.0',
        ]);

        // Point config to chain 97
        Config::set('pangu2.chain_id', 97);

        $res = $this->getJson('/api/v1/projects/pangu2/contracts');

        $res->assertOk();
        $res->assertJsonPath('data.0.address', '0xbbbb000000000000000000000000000000000000');
        $res->assertJsonPath('data.0.deployment_block', '43000000');
    }

    // ===================================================================
    // 4. Missing contract → UNAVAILABLE
    // ===================================================================

    public function test_missing_contract_returns_unavailable(): void
    {
        // No contract_registry rows at all — known names fall through to UNAVAILABLE
        $res = $this->getJson('/api/v1/projects/pangu2/contracts');

        $res->assertOk();

        // At least one known contract should be UNAVAILABLE
        $data   = $res->json('data');
        $names  = array_column($data, 'name');
        $this->assertContains('BNBPresale', $names);

        // Find the BNBPresale entry
        $presale = null;
        foreach ($data as $entry) {
            if ($entry['name'] === 'BNBPresale') {
                $presale = $entry;
                break;
            }
        }

        $this->assertNotNull($presale, 'BNBPresale should be in contract list');
        $this->assertEquals('UNAVAILABLE', $presale['status']);
        $this->assertEquals('0.0.0', $presale['abi_version']);
        $this->assertEquals('0', $presale['deployment_block']);

        // Envelope meta should reflect UNAVAILABLE if ANY contract is unavailable
        $this->assertEquals('UNAVAILABLE', $res->json('meta.data_status'));
    }

    public function test_partially_configured_contracts_mixed_status(): void
    {
        // Only BNBPresale is configured
        ContractRegistry::create([
            'environment'      => 'local',
            'chain_id'         => 31337,
            'name'             => 'BNBPresale',
            'address'          => '0xcccccccccccccccccccccccccccccccccccccccc',
            'abi_version'      => '1.0.0',
            'deployment_block' => '42000000',
            'status'           => 'ACTIVE',
            'version'          => '1.0.0',
        ]);

        $res = $this->getJson('/api/v1/projects/pangu2/contracts');

        $res->assertOk();

        $data      = $res->json('data');
        $presale   = null;
        $wbnb      = null;

        foreach ($data as $entry) {
            if ($entry['name'] === 'BNBPresale') {
                $presale = $entry;
            }
            if ($entry['name'] === 'WBNB') {
                $wbnb = $entry;
            }
        }

        $this->assertNotNull($presale);
        $this->assertEquals('ACTIVE', $presale['status']);

        // WBNB should be UNAVAILABLE since it's a known contract not configured
        $this->assertNotNull($wbnb, 'WBNB should appear as a known contract name');
        $this->assertEquals('UNAVAILABLE', $wbnb['status']);

        // Overall data_status should be UNAVAILABLE due to WBNB
        $this->assertEquals('UNAVAILABLE', $res->json('meta.data_status'));
    }

    // ===================================================================
    // 5. Freshness — data_staleness based on block lag
    // ===================================================================

    public function test_fresh_data_when_block_lag_within_threshold(): void
    {
        $this->seedSyncCursor(31337, 5000, 4990); // lag = 10

        $res = $this->getJson('/api/v1/projects/pangu2/system-status');

        $res->assertOk();
        $res->assertJsonPath('data.block_lag', 10);
        $res->assertJsonPath('meta.data_status', 'LIVE');
    }

    public function test_stale_data_when_block_lag_exceeds_stale_threshold(): void
    {
        Config::set('pangu2.freshness_stale_blocks', 20);
        Config::set('pangu2.freshness_degraded_blocks', 200);

        $this->seedSyncCursor(31337, 5000, 4970); // lag = 30

        $res = $this->getJson('/api/v1/projects/pangu2/system-status');

        $res->assertOk();
        $res->assertJsonPath('data.block_lag', 30);
        $res->assertJsonPath('meta.data_status', 'STALE');
    }

    public function test_degraded_data_when_block_lag_exceeds_degraded_threshold(): void
    {
        Config::set('pangu2.freshness_stale_blocks', 20);
        Config::set('pangu2.freshness_degraded_blocks', 200);

        $this->seedSyncCursor(31337, 5000, 4700); // lag = 300

        $res = $this->getJson('/api/v1/projects/pangu2/system-status');

        $res->assertOk();
        $res->assertJsonPath('data.block_lag', 300);
        $res->assertJsonPath('meta.data_status', 'DEGRADED');
    }

    public function test_syncing_status_when_no_sync_cursor_exists(): void
    {
        // No sync cursor seeded

        $res = $this->getJson('/api/v1/projects/pangu2/system-status');

        $res->assertOk();
        $res->assertJsonPath('meta.data_status', 'SYNCING');
        $res->assertJsonPath('data.latest_chain_block', '0');
        $res->assertJsonPath('data.last_scanned_block', '0');
        $res->assertJsonPath('data.block_lag', 0);
    }

    // ===================================================================
    // 6. Envelope structure validation
    // ===================================================================

    public function test_config_response_has_correct_envelope_structure(): void
    {
        $res = $this->getJson('/api/v1/projects/pangu2/config');

        $res->assertOk();
        $json = $res->json();

        // Envelope fields
        $this->assertArrayHasKey('data', $json);
        $this->assertArrayHasKey('meta', $json);
        $this->assertArrayHasKey('error', $json);
        $this->assertNull($json['error']);

        // Meta fields
        $this->assertArrayHasKey('project', $json['meta']);
        $this->assertArrayHasKey('environment', $json['meta']);
        $this->assertArrayHasKey('chain_id', $json['meta']);
        $this->assertArrayHasKey('data_status', $json['meta']);
        $this->assertArrayHasKey('generated_at', $json['meta']);
        $this->assertArrayHasKey('schema_version', $json['meta']);
    }

    public function test_system_status_response_has_correct_envelope_structure(): void
    {
        $res = $this->getJson('/api/v1/projects/pangu2/system-status');

        $res->assertOk();
        $json = $res->json();

        $this->assertArrayHasKey('data', $json);
        $this->assertArrayHasKey('meta', $json);
        $this->assertArrayHasKey('error', $json);
        $this->assertNull($json['error']);
    }

    public function test_contracts_response_has_correct_envelope_structure(): void
    {
        $res = $this->getJson('/api/v1/projects/pangu2/contracts');

        $res->assertOk();
        $json = $res->json();

        $this->assertArrayHasKey('data', $json);
        $this->assertArrayHasKey('meta', $json);
        $this->assertArrayHasKey('error', $json);
        $this->assertNull($json['error']);
        $this->assertIsArray($json['data']);
    }

    // ===================================================================
    // 7. RPC status scenarios
    // ===================================================================

    public function test_rpc_ok_when_primary_responds(): void
    {
        Http::fake([
            'http://127.0.0.1:8545' => Http::response([
                'jsonrpc' => '2.0',
                'result'  => '0x1',
                'id'      => 1,
            ]),
        ]);

        $res = $this->getJson('/api/v1/projects/pangu2/config');

        $res->assertOk();
        $res->assertJsonPath('data.rpc_status', 'OK');
    }

    public function test_rpc_degraded_when_primary_fails_but_backup_works(): void
    {
        Config::set('pangu2.backup_rpc_url', 'http://backup:8545');

        Http::fake([
            'http://127.0.0.1:8545' => Http::response('', 500),
            'http://backup:8545'    => Http::response([
                'jsonrpc' => '2.0',
                'result'  => '0x1',
                'id'      => 1,
            ]),
        ]);

        $res = $this->getJson('/api/v1/projects/pangu2/config');

        $res->assertOk();
        $res->assertJsonPath('data.rpc_status', 'DEGRADED');
    }

    public function test_rpc_down_when_both_primary_and_backup_fail(): void
    {
        Config::set('pangu2.backup_rpc_url', 'http://backup:8545');

        Http::fake([
            'http://127.0.0.1:8545' => Http::response('', 500),
            'http://backup:8545'    => Http::response('', 500),
        ]);

        $res = $this->getJson('/api/v1/projects/pangu2/config');

        $res->assertOk();
        $res->assertJsonPath('data.rpc_status', 'DOWN');
    }

    public function test_rpc_down_when_no_rpc_url_configured(): void
    {
        Config::set('pangu2.rpc_url', '');
        Config::set('pangu2.backup_rpc_url', '');

        $res = $this->getJson('/api/v1/projects/pangu2/config');

        $res->assertOk();
        $res->assertJsonPath('data.rpc_status', 'DOWN');
    }

    // ===================================================================
    // 8. RPC status reflected in system-status endpoint
    // ===================================================================

    public function test_system_status_includes_rpc_status(): void
    {
        Http::fake([
            'http://127.0.0.1:8545' => Http::response([
                'jsonrpc' => '2.0',
                'result'  => '0x28fa66',
                'id'      => 1,
            ]),
        ]);

        $this->seedSyncCursor(31337, 100, 100);

        $res = $this->getJson('/api/v1/projects/pangu2/system-status');

        $res->assertOk();
        $res->assertJsonPath('data.rpc_status', 'OK');
    }

    // ===================================================================
    // Helpers
    // ===================================================================

    private function seedSyncCursor(int $chainId, int $latestChainBlock, int $lastScannedBlock): void
    {
        \Illuminate\Support\Facades\DB::table('chain_sync_cursors')->insert([
            'chain_id'             => $chainId,
            'stream'               => 'default',
            'last_scanned_block'   => $lastScannedBlock,
            'latest_chain_block'   => $latestChainBlock,
            'status'               => 'ACTIVE',
            'created_at'           => now(),
            'updated_at'           => now(),
        ]);
    }
}
