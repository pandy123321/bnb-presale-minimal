<?php

declare(strict_types=1);

namespace App\Modules\Pangu2\Admin\Controllers;

use App\Http\ApiEnvelope;
use Illuminate\Http\JsonResponse;
use Illuminate\Routing\Controller;
use Illuminate\Support\Facades\Http;

/**
 * Admin governance read-only monitoring via eth_call.
 *
 * All routes require auth:web + rbac:governance.read (SUPER_ADMIN + OPERATOR).
 */
class GovernanceController extends Controller
{
    private const ORACLE_LABELS = [
        0 => 'UNINITIALIZED',
        1 => 'ACCUMULATING',
        2 => 'READY',
        3 => 'LIQUIDITY_LOW',
    ];

    private const BUYBACK_REASON_LABELS = [
        0 => 'No blocking reason',
        1 => 'Contract paused',
        2 => 'Locker not configured',
        3 => 'Insufficient pool balance',
        4 => 'Cooldown period',
        5 => 'Oracle unavailable',
        6 => 'Invalid oracle quote',
    ];

    // ── RPC helper ──

    private function ethCall(string $to, string $data): string
    {
        $rpcUrl = config('pangu2.rpc_url');
        if (empty($rpcUrl)) {
            throw new \RuntimeException('RPC URL not configured');
        }

        $payload = [
            'jsonrpc' => '2.0',
            'method'  => 'eth_call',
            'params'  => [['to' => $to, 'data' => $data], 'latest'],
            'id'      => 1,
        ];

        $resp = Http::timeout(5)->withHeaders([
            'Content-Type' => 'application/json',
        ])->post($rpcUrl, $payload);

        if (!$resp->ok()) {
            throw new \RuntimeException('RPC call failed: HTTP ' . $resp->status());
        }

        $body = $resp->json();
        if (isset($body['error'])) {
            throw new \RuntimeException('RPC error: ' . ($body['error']['message'] ?? json_encode($body['error'])));
        }

        $result = $body['result'] ?? null;
        if ($result === null || $result === '0x') {
            throw new \RuntimeException('RPC returned empty result');
        }

        return $result;
    }

    // ── 1. Trading Status ──

    public function tradingStatus(): JsonResponse
    {
        try {
            $pairAddress = config('pangu2.pair_address', '');
            if (empty($pairAddress)) {
                return ApiEnvelope::success(['tradingEnabled' => false], 'UNAVAILABLE');
            }

            $tokenAddress = config('pangu2.token_address', '');
            // selector: isPair(address) → 0xe5e31b13
            $data = '0xe5e31b13' . str_pad(substr($pairAddress, 2), 64, '0', STR_PAD_LEFT);
            $raw = $this->ethCall($tokenAddress, $data);

            $enabled = hexdec($raw) === 1;

            return ApiEnvelope::success(['tradingEnabled' => $enabled], 'LIVE');
        } catch (\Throwable $e) {
            return ApiEnvelope::error('RPC_ERROR', $e->getMessage(), true, [], 502);
        }
    }

    // ── 2. Buyback Check ──

    public function buybackCheck(): JsonResponse
    {
        try {
            $supportPool = config('pangu2.support_pool_address', '');
            if (empty($supportPool)) {
                return ApiEnvelope::success([
                    'canBuyback'    => false,
                    'reason'        => 1,
                    'reasonLabel'   => 'Contract address not configured',
                    'poolBalance'   => '0',
                    'nextAllowedAt' => '0',
                ], 'UNAVAILABLE');
            }

            // selector: canExecuteBuyback() → 0x7dc15e0d
            $raw = $this->ethCall($supportPool, '0x7dc15e0d');

            // ABI decode: (bool, uint8, uint256, uint256) — 4 x 32 bytes after selector
            $hex = substr($raw, 2);
            $canBuyback    = hexdec(substr($hex, 0, 64)) === 1;
            $reason        = (int) hexdec(substr($hex, 64, 64));
            $poolBalance   = (string) hexdec(substr($hex, 128, 64));
            $nextAllowedAt = (string) hexdec(substr($hex, 192, 64));

            return ApiEnvelope::success([
                'canBuyback'    => $canBuyback,
                'reason'        => $reason,
                'reasonLabel'   => self::BUYBACK_REASON_LABELS[$reason] ?? "Unknown ({$reason})",
                'poolBalance'   => $poolBalance,
                'nextAllowedAt' => $nextAllowedAt,
            ], 'LIVE');
        } catch (\Throwable $e) {
            return ApiEnvelope::error('RPC_ERROR', $e->getMessage(), true, [], 502);
        }
    }

    // ── 3. Oracle Status ──

    public function oracleStatus(): JsonResponse
    {
        try {
            $oracleAddress = config('pangu2.oracle_address', '');
            if (empty($oracleAddress)) {
                return ApiEnvelope::success([
                    'status'      => -1,
                    'statusLabel' => 'NOT_CONFIGURED',
                ], 'UNAVAILABLE');
            }

            // selector: status() → 0x200d2ed2
            $raw = $this->ethCall($oracleAddress, '0x200d2ed2');
            $status = (int) hexdec($raw);

            return ApiEnvelope::success([
                'status'      => $status,
                'statusLabel' => self::ORACLE_LABELS[$status] ?? "UNKNOWN ({$status})",
            ], 'LIVE');
        } catch (\Throwable $e) {
            return ApiEnvelope::error('RPC_ERROR', $e->getMessage(), true, [], 502);
        }
    }

    // ── 4. Pause Status ──

    public function pauseStatus(): JsonResponse
    {
        try {
            $routerAddress = config('pangu2.trade_router_address', '');
            if (empty($routerAddress)) {
                return ApiEnvelope::success(['paused' => null], 'UNAVAILABLE');
            }

            // selector: paused() → 0x5c975abb
            $raw = $this->ethCall($routerAddress, '0x5c975abb');
            $paused = hexdec($raw) === 1;

            return ApiEnvelope::success(['paused' => $paused], 'LIVE');
        } catch (\Throwable $e) {
            return ApiEnvelope::error('RPC_ERROR', $e->getMessage(), true, [], 502);
        }
    }

    // ── 5. System Addresses ──

    public function systemAddresses(): JsonResponse
    {
        try {
            $tokenAddress = config('pangu2.token_address', '');

            $systems = [
                ['name' => 'TradeRouter',        'address' => config('pangu2.trade_router_address', '')],
                ['name' => 'PancakeV2Adapter',   'address' => config('pangu2.adapter_address', '')],
                ['name' => 'SupportPool',        'address' => config('pangu2.support_pool_address', '')],
                ['name' => 'FeeVault',           'address' => config('pangu2.fee_vault_address', '')],
                ['name' => 'BuybackLocker',      'address' => config('pangu2.buyback_locker_address', '')],
                ['name' => 'DividendDistributor','address' => config('pangu2.dividend_distributor_address', '')],
                ['name' => 'Pangu2Staking',      'address' => config('pangu2.staking_address', '')],
            ];

            $items = [];
            foreach ($systems as $sys) {
                $addr = $sys['address'];
                if (empty($addr)) continue;

                $isSystem = false;
                try {
                    // isSystemAddress(address) → 0x6ba5228f
                    $data = '0x6ba5228f' . str_pad(substr($addr, 2), 64, '0', STR_PAD_LEFT);
                    $raw = $this->ethCall($tokenAddress, $data);
                    $isSystem = hexdec($raw) === 1;
                } catch (\Throwable) {
                    // individual query failure → leave as false
                }

                $isLiquidityManager = false;
                try {
                    // isLiquidityManager(address) → 0x4fe67b1a
                    $data = '0x4fe67b1a' . str_pad(substr($addr, 2), 64, '0', STR_PAD_LEFT);
                    $raw = $this->ethCall($tokenAddress, $data);
                    $isLiquidityManager = hexdec($raw) === 1;
                } catch (\Throwable) {
                    // individual query failure → leave as false
                }

                $items[] = [
                    'name'               => $sys['name'],
                    'address'            => $addr,
                    'isSystemAddress'    => $isSystem,
                    'isLiquidityManager' => $isLiquidityManager,
                ];
            }

            return ApiEnvelope::success($items, count($items) > 0 ? 'LIVE' : 'UNAVAILABLE');
        } catch (\Throwable $e) {
            return ApiEnvelope::error('RPC_ERROR', $e->getMessage(), true, [], 502);
        }
    }

    // ── 6. Deployer Balance ──

    public function deployerBalance(): JsonResponse
    {
        try {
            $operatorAddress = config('pangu2.operator_address', '');
            if (empty($operatorAddress)) {
                return ApiEnvelope::success([
                    'address'    => '',
                    'balanceWei' => '0',
                    'balanceBnb' => '0',
                ], 'UNAVAILABLE');
            }

            $rpcUrl = config('pangu2.rpc_url');
            $resp = Http::timeout(5)->withHeaders([
                'Content-Type' => 'application/json',
            ])->post($rpcUrl, [
                'jsonrpc' => '2.0',
                'method'  => 'eth_getBalance',
                'params'  => [$operatorAddress, 'latest'],
                'id'      => 1,
            ]);

            if (!$resp->ok()) {
                throw new \RuntimeException('RPC call failed: HTTP ' . $resp->status());
            }

            $body = $resp->json();
            $wei = $body['result'] ?? '0x0';

            $weiDec = (string) hexdec($wei);
            $bnbInt = bcdiv($weiDec, '1000000000000000000', 0);
            $bnbFrac = bcmod($weiDec, '1000000000000000000');
            $bnb = $bnbInt . '.' . str_pad($bnbFrac, 18, '0', STR_PAD_LEFT);

            return ApiEnvelope::success([
                'address'    => $operatorAddress,
                'balanceWei' => $weiDec,
                'balanceBnb' => rtrim(rtrim($bnb, '0'), '.'),
            ], 'LIVE');
        } catch (\Throwable $e) {
            return ApiEnvelope::error('RPC_ERROR', $e->getMessage(), true, [], 502);
        }
    }
}
