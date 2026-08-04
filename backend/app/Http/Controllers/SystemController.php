<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Http\ApiEnvelope;
use Illuminate\Http\Request;

final class SystemController extends Controller
{
    /**
     * GET /api/v1/projects/pangu2/config
     */
    public function config()
    {
        return ApiEnvelope::success([
            'project' => 'PANGU2',
            'environment' => config('app.env', 'LOCAL'),
            'chain_id' => (int) config('pangu2.chain_id', 31337),
            'chain_name' => match ((int) config('pangu2.chain_id')) {
                56 => 'BSC Mainnet',
                97 => 'BSC Testnet',
                default => 'Anvil',
            },
            'rpc_status' => 'OK',
            'supported_networks' => [31337, 97],
        ], 'LIVE');
    }

    /**
     * GET /api/v1/projects/pangu2/system-status
     */
    public function systemStatus()
    {
        $mockLatest = '42815128';
        $mockScanned = '42815125';

        return ApiEnvelope::success([
            'latest_chain_block' => $mockLatest,
            'last_scanned_block' => $mockScanned,
            'block_lag' => (int) bcsub($mockLatest, $mockScanned),
            'rpc_status' => 'OK',
            'queue_status' => 'HEALTHY',
            'open_anomalies' => 0,
        ], 'LIVE');
    }

    /**
     * GET /api/v1/projects/pangu2/contracts
     */
    public function contracts()
    {
        return ApiEnvelope::success([
            [
                'name' => 'BNBPresale',
                'address' => '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
                'abi_version' => '1.0.0',
                'deployment_block' => '42000000',
                'status' => 'ACTIVE',
            ],
            [
                'name' => 'Distributor',
                'address' => '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
                'abi_version' => '1.0.0',
                'deployment_block' => '42000001',
                'status' => 'ACTIVE',
            ],
            [
                'name' => 'BuybackLocker',
                'address' => '0xcccccccccccccccccccccccccccccccccccccccc',
                'abi_version' => '1.0.0',
                'deployment_block' => '42000002',
                'status' => 'ACTIVE',
            ],
            [
                'name' => 'Timelock',
                'address' => '0xdddddddddddddddddddddddddddddddddddddddd',
                'abi_version' => '1.0.0',
                'deployment_block' => '42000003',
                'status' => 'ACTIVE',
            ],
        ], 'LIVE');
    }
}
