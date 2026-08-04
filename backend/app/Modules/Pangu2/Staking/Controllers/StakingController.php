<?php

declare(strict_types=1);

namespace App\Modules\Pangu2\Staking\Controllers;

use App\Http\ApiEnvelope;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * PANGU2 Staking API Controller.
 *
 * 合约函数映射 (ABI → Solidity):
 *   earned(address)          → view: 返回已累积但未领取的收益
 *   positions(user, id)      → view: 返回单个质押仓位
 *   userPositionCount(user)   → view: 返回用户质押仓位数量
 *   totalStaked()            → view: 总质押量
 *   rewardRate()             → view: 当前奖励速率 (tokens/sec)
 *   periodFinish()           → view: 当前奖励周期结束时间 (unix)
 *   availableRewardReserve() → view: 可用奖励储备
 *   coverageRatio()          → view: 偿付比率 (principal, reward, total)
 *   fundRewards(amount)      → REWARD_MANAGER_ROLE: 注入奖励资金
 *   setRewardRate(rate)      → REWARD_MANAGER_ROLE: 设置奖励速率
 *
 * ABI 函数选择器 (硬编码):
 *   earned(address)               → 0x008cc262
 *   positions(address,uint256)    → 0x02d3da9a
 *   userPositionCount(address)    → 0x8f32d59b
 *   totalStaked()                 → 0x817b1cd2
 *   rewardRate()                  → 0x7b0a47ee
 *   periodFinish()                → 0xebe2b12b
 *   availableRewardReserve()      → 0xa2cfb28a
 *   coverageRatio()               → 0xb91e9e9c
 */
class StakingController extends Controller
{
    private function rpcUrl(): string
    {
        return config('pangu2.rpc_url', 'http://127.0.0.1:8545');
    }

    private function stakingAddress(): string
    {
        return config('pangu2.staking_address', '');
    }

    /**
     * 执行 eth_call 读取合约数据。
     *
     * @return mixed|null 成功返回 decoded 结果，失败返回 null
     */
    private function ethCall(string $data, string $to = null): mixed
    {
        $to = $to ?? $this->stakingAddress();
        if ($to === '') return null;

        try {
            $response = Http::timeout(5)
                ->withHeaders(['Content-Type' => 'application/json'])
                ->post($this->rpcUrl(), [
                    'jsonrpc' => '2.0',
                    'method'  => 'eth_call',
                    'params'  => [[
                        'to'   => $to,
                        'data' => $data,
                    ], 'latest'],
                    'id'      => random_int(1, 999999),
                ]);

            if (! $response->successful()) return null;
            $body = $response->json();
            $result = $body['result'] ?? null;
            if ($result === null || $result === '0x' || $result === '0x0') return null;

            return $result;
        } catch (\Throwable $e) {
            Log::warning('StakingController: eth_call failed', [
                'error' => $e->getMessage(),
            ]);
            return null;
        }
    }

    // ─── Static ABI function selectors (keccak256 前 4 字节) ───
    private const SELECTOR_EARNED                = '0x008cc262'; // earned(address)
    private const SELECTOR_POSITIONS             = '0x02d3da9a'; // positions(address,uint256)
    private const SELECTOR_USER_POSITION_COUNT    = '0x8f32d59b'; // userPositionCount(address)
    private const SELECTOR_TOTAL_STAKED          = '0x817b1cd2'; // totalStaked()
    private const SELECTOR_REWARD_RATE           = '0x7b0a47ee'; // rewardRate()
    private const SELECTOR_PERIOD_FINISH         = '0xebe2b12b'; // periodFinish()
    private const SELECTOR_AVAILABLE_REWARD_RESERVE = '0xa2cfb28a'; // availableRewardReserve()
    private const SELECTOR_COVERAGE_RATIO        = '0xb91e9e9c'; // coverageRatio()

    /**
     * 编码 ABI 函数调用（eth_call 用）。
     *
     * @param string $selector  0x 前缀的 4 字节选择器
     * @param array  $params    参数列表（每个元素: hex string 或 int）
     */
    private function encodeCallData(string $selector, array $params = []): string
    {
        $encoded = '';
        foreach ($params as $p) {
            if (is_int($p)) {
                $encoded .= str_pad(dechex($p), 64, '0', STR_PAD_LEFT);
            } elseif (is_string($p) && str_starts_with($p, '0x')) {
                // ABI 地址编码：左填充到 32 字节
                $hex = substr($p, 2);
                $encoded .= str_pad(strtolower($hex), 64, '0', STR_PAD_LEFT);
            } elseif (is_string($p) && ctype_digit($p)) {
                $encoded .= str_pad($p, 64, '0', STR_PAD_LEFT);
            }
        }

        return $selector . $encoded;
    }

    /**
     * 解码 uint256 返回值。
     */
    private function decodeUint256(string $hex): string
    {
        $hex = str_starts_with((string) $hex, '0x') ? substr((string) $hex, 2) : $hex;
        return gmp_strval(gmp_init($hex, 16));
    }

    /**
     * 解码 address 返回值。
     */
    private function decodeAddress(string $hex): string
    {
        return '0x' . substr((string) $hex, -40);
    }

    /**
     * 判断是否应该返回 mock 数据。
     */
    private function shouldMock(): bool
    {
        return $this->stakingAddress() === '';
    }

    // ═══════════════════════════════════════════
    // Public API (用户端)
    // ═══════════════════════════════════════════

    /**
     * GET /api/v1/projects/pangu2/staking/earned?address=0x...
     *
     * 查询用户已累积但未领取的质押收益。
     */
    public function earned(Request $request): JsonResponse
    {
        $address = $request->query('address', '');
        if ($address === '' || ! preg_match('/^0x[a-fA-F0-9]{40}$/', $address)) {
            return ApiEnvelope::error('INVALID_ADDRESS', 'address 必须为合法的 EVM 地址', false, [
                'received' => $address,
            ]);
        }

        if ($this->shouldMock()) {
            return $this->mockEarned($address);
        }

        $data = $this->encodeCallData(self::SELECTOR_EARNED, [$address]);
        $result = $this->ethCall($data);

        if ($result === null) {
            return $this->mockEarned($address);
        }

        return ApiEnvelope::success([
            'address' => strtolower($address),
            'earned'  => $this->decodeUint256($result),
        ], 'LIVE');
    }

    /**
     * GET /api/v1/projects/pangu2/staking/positions?address=0x...
     *
     * 返回用户所有质押仓位列表。
     */
    public function positions(Request $request): JsonResponse
    {
        $address = $request->query('address', '');
        if ($address === '' || ! preg_match('/^0x[a-fA-F0-9]{40}$/', $address)) {
            return ApiEnvelope::error('INVALID_ADDRESS', 'address 必须为合法的 EVM 地址', false, [
                'received' => $address,
            ]);
        }

        if ($this->shouldMock()) {
            return $this->mockPositions($address);
        }

        // 1. 查询仓位数量
        $countData = $this->encodeCallData(self::SELECTOR_USER_POSITION_COUNT, [$address]);
        $countHex = $this->ethCall($countData);
        if ($countHex === null) return $this->mockPositions($address);
        $count = (int) $this->decodeUint256($countHex);

        // 2. 遍历每个仓位
        $items = [];
        for ($i = 0; $i < $count; $i++) {
            $posData = $this->encodeCallData(self::SELECTOR_POSITIONS, [$address, $i]);
            $posHex = $this->ethCall($posData);
            if ($posHex === null) continue;

            $pos = $this->decodePosition($posHex);
            if ($pos === null) continue;

            $items[] = $pos;
        }

        return ApiEnvelope::success([
            'address'   => strtolower($address),
            'positions' => $items,
            'count'     => count($items),
        ], 'LIVE');
    }

    /**
     * GET /api/v1/projects/pangu2/staking/status
     *
     * 返回质押合约全局状态。
     */
    public function status(): JsonResponse
    {
        if ($this->shouldMock()) {
            return $this->mockStatus();
        }

        $totalStaked = $this->ethCall($this->encodeCallData(self::SELECTOR_TOTAL_STAKED));
        $rewardRate  = $this->ethCall($this->encodeCallData(self::SELECTOR_REWARD_RATE));
        $periodEnd   = $this->ethCall($this->encodeCallData(self::SELECTOR_PERIOD_FINISH));
        $available   = $this->ethCall($this->encodeCallData(self::SELECTOR_AVAILABLE_REWARD_RESERVE));

        if ($totalStaked === null || $rewardRate === null) {
            return $this->mockStatus();
        }

        return ApiEnvelope::success([
            'totalStaked'            => $this->decodeUint256($totalStaked),
            'rewardRate'             => $this->decodeUint256($rewardRate),
            'periodFinish'           => $periodEnd ? $this->decodeUint256($periodEnd) : '0',
            'availableRewardReserve' => $available ? $this->decodeUint256($available) : '0',
        ], 'LIVE');
    }

    // ═══════════════════════════════════════════
    // Admin API (管理员端)
    // ═══════════════════════════════════════════

    /**
     * POST /admin-api/v1/projects/pangu2/staking/fund-rewards
     *
     * 注入奖励资金。需要 GOVERNANCE_ROLE 签名。
     * 当前返回 mock（写操作需要链上签名）。
     */
    public function fundRewards(Request $request): JsonResponse
    {
        $amount = $request->input('amount', '');
        if ($amount === '' || ! ctype_digit($amount)) {
            return ApiEnvelope::error('INVALID_AMOUNT', 'amount 必须为十进制整数字符串', false, [
                'received' => $amount,
            ]);
        }

        // 写操作需要私钥签名，当前阶段返回 mock 确认
        return ApiEnvelope::success([
            'action'  => 'fundRewards',
            'amount'  => $amount,
            'status'  => 'MOCK_RECEIVED',
            'message' => 'Reward funding accepted. Real tx submission requires governance signer (not yet implemented).',
        ], 'MOCK_DATA');
    }

    /**
     * POST /admin-api/v1/projects/pangu2/staking/set-reward-rate
     *
     * 设置奖励速率。需要 REWARD_MANAGER_ROLE 签名。
     * 当前返回 mock（写操作需要链上签名）。
     */
    public function setRewardRate(Request $request): JsonResponse
    {
        $rate = $request->input('rate', '');
        if ($rate === '' || ! ctype_digit($rate)) {
            return ApiEnvelope::error('INVALID_RATE', 'rate 必须为十进制整数字符串', false, [
                'received' => $rate,
            ]);
        }

        // 写操作需要私钥签名，当前阶段返回 mock 确认
        return ApiEnvelope::success([
            'action'  => 'setRewardRate',
            'rate'    => $rate,
            'status'  => 'MOCK_RECEIVED',
            'message' => 'Rate change accepted. Real tx submission requires reward manager signer (not yet implemented).',
        ], 'MOCK_DATA');
    }

    /**
     * GET /admin-api/v1/projects/pangu2/staking/coverage
     *
     * 返回合约偿付比率。
     */
    public function coverage(): JsonResponse
    {
        if ($this->shouldMock()) {
            return $this->mockCoverage();
        }

        $data = $this->encodeCallData(self::SELECTOR_COVERAGE_RATIO);
        $result = $this->ethCall($data);

        if ($result === null) return $this->mockCoverage();

        [$principal, $reward, $total] = $this->decodeCoverageRatio($result);

        return ApiEnvelope::success([
            'principal' => $principal,
            'reward'    => $reward,
            'total'     => $total,
        ], 'LIVE');
    }

    // ═══════════════════════════════════════════
    // ABI 解码辅助
    // ═══════════════════════════════════════════

    /**
     * 解码 positions(address,uint256) 返回的 StakePosition 结构体。
     *
     * ABI 编码 (4 x uint256 等价):
     *   [0]  amount   (uint256)
     *   [1]  lockedAt (uint64)  → 同槽的 claimed (bool)
     *   [2]  unlockAt (uint64)
     *   [3]  claimed  (bool)   → 实际上 claimed 与 lockedAt 共享槽位
     *
     * 简化：按 Solidity 返回的 (uint256, uint64, uint64, bool) 解析
     * 实际 ABI 编码中 bool 占 32 字节
     *
     * @return array{positionId: int, amount: string, lockedAt: string, unlockAt: string, claimed: bool}|null
     */
    private function decodePosition(string $hex, int $positionId = null): ?array
    {
        $hex = str_starts_with((string) $hex, '0x') ? substr((string) $hex, 2) : $hex;
        $len = strlen($hex);
        if ($len < 256) return null; // 至少 4 × 32 字节 = 128 hex chars → adjust: 4 × 64 = 256

        // 每个 ABI 编码字段占 32 字节 (64 hex chars)
        $chunk = fn (int $i) => substr($hex, $i * 64, 64);

        $amount   = gmp_strval(gmp_init($chunk(0), 16));
        $lockedAt = gmp_strval(gmp_init($chunk(1), 16));
        $unlockAt = gmp_strval(gmp_init($chunk(2), 16));
        $claimed  = gmp_init($chunk(3), 16) > 0;

        return [
            'positionId' => $positionId,
            'amount'     => $amount,
            'lockedAt'   => $lockedAt,
            'unlockAt'   => $unlockAt,
            'claimed'    => $claimed,
        ];
    }

    /**
     * 解码 coverageRatio() 返回值 (principal, reward, total)。
     */
    private function decodeCoverageRatio(string $hex): array
    {
        $hex = str_starts_with((string) $hex, '0x') ? substr((string) $hex, 2) : $hex;
        $chunk = fn (int $i) => substr($hex, $i * 64, 64);
        return [
            'principal' => gmp_strval(gmp_init($chunk(0), 16)),
            'reward'    => gmp_strval(gmp_init($chunk(1), 16)),
            'total'     => gmp_strval(gmp_init($chunk(2), 16)),
        ];
    }

    // ═══════════════════════════════════════════
    // Mock 数据
    // ═══════════════════════════════════════════

    private function mockEarned(string $address): JsonResponse
    {
        return ApiEnvelope::success([
            'address' => strtolower($address),
            'earned'  => '0',
        ], 'MOCK_DATA', null, ['source' => 'mock']);
    }

    private function mockPositions(string $address): JsonResponse
    {
        return ApiEnvelope::success([
            'address'   => strtolower($address),
            'positions' => [],
            'count'     => 0,
        ], 'MOCK_DATA', null, ['source' => 'mock']);
    }

    private function mockStatus(): JsonResponse
    {
        return ApiEnvelope::success([
            'totalStaked'            => '0',
            'rewardRate'             => '0',
            'periodFinish'           => '0',
            'availableRewardReserve' => '0',
        ], 'MOCK_DATA', null, ['source' => 'mock']);
    }

    private function mockCoverage(): JsonResponse
    {
        return ApiEnvelope::success([
            'principal' => '0',
            'reward'    => '0',
            'total'     => '0',
        ], 'MOCK_DATA', null, ['source' => 'mock']);
    }
}
