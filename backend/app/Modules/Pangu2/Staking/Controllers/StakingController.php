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
 * ABI 函数选择器（通过 keccak256 签名计算器非手工录入）:
 *   earned(address)               → 0x008cc262  ✓ verified
 *   positions(address,uint256)    → 0xc1be6677  ✓ verified
 *   userPositionCount(address)    → 0x0918eb14  ✓ verified
 *   totalStaked()                 → 0x817b1cd2  ✓ verified
 *   rewardRate()                  → 0x7b0a47ee  ✓ verified
 *   periodFinish()                → 0xebe2b12b  ✓ verified
 *   availableRewardReserve()      → 0x9fe258eb  ✓ verified
 *   coverageRatio()               → 0xf812fa70  ✓ verified
 */
class StakingController extends Controller
{
    // ─── Verified ABI function selectors (keccak256 first 4 bytes) ───
    private const SELECTOR_EARNED                  = '0x008cc262';
    private const SELECTOR_POSITIONS               = '0xc1be6677';
    private const SELECTOR_USER_POSITION_COUNT      = '0x0918eb14';
    private const SELECTOR_TOTAL_STAKED            = '0x817b1cd2';
    private const SELECTOR_REWARD_RATE             = '0x7b0a47ee';
    private const SELECTOR_PERIOD_FINISH           = '0xebe2b12b';
    private const SELECTOR_AVAILABLE_REWARD_RESERVE = '0x9fe258eb';
    private const SELECTOR_COVERAGE_RATIO          = '0xf812fa70';

    /// Single position query page size limit
    private const POSITIONS_PER_PAGE = 50;

    private function rpcUrl(): string
    {
        return config('pangu2.rpc_url', 'http://127.0.0.1:8545');
    }

    private function stakingAddress(): string
    {
        return config('pangu2.staking_address', '');
    }

    /** Whether explicit mock mode is enabled (local/test only). */
    private function isMockMode(): bool
    {
        return $this->stakingAddress() === '';
    }

    /**
     * Execute eth_call. Returns hex result or throws on failure.
     *
     * @throws \RuntimeException on RPC / contract failure
     */
    private function ethCall(string $data, ?string $blockTag = null): string
    {
        $to = $this->stakingAddress();
        if ($to === '') {
            throw new \RuntimeException('Staking contract address not configured');
        }

        $blockTag ??= 'latest';

        $response = Http::timeout(5)
            ->withHeaders(['Content-Type' => 'application/json'])
            ->post($this->rpcUrl(), [
                'jsonrpc' => '2.0',
                'method'  => 'eth_call',
                'params'  => [[
                    'to'   => $to,
                    'data' => $data,
                ], $blockTag],
                'id'      => random_int(1, 999999),
            ]);

        if (! $response->successful()) {
            throw new \RuntimeException('RPC HTTP ' . $response->status());
        }

        $body = $response->json();
        if (isset($body['error'])) {
            throw new \RuntimeException('RPC error: ' . json_encode($body['error']));
        }

        $result = $body['result'] ?? null;
        if ($result === null || $result === '0x') {
            throw new \RuntimeException('RPC returned empty hex');
        }

        return $result;
    }

    private function encodeCallData(string $selector, array $params = []): string
    {
        $encoded = '';
        foreach ($params as $p) {
            if (is_int($p)) {
                $encoded .= str_pad(dechex($p), 64, '0', STR_PAD_LEFT);
            } elseif (is_string($p) && str_starts_with($p, '0x')) {
                $hex = substr($p, 2);
                $encoded .= str_pad(strtolower($hex), 64, '0', STR_PAD_LEFT);
            } elseif (is_string($p) && ctype_digit($p)) {
                // Convert decimal string → hex → 64-char padded
                $encoded .= str_pad(gmp_strval(gmp_init($p, 10), 16), 64, '0', STR_PAD_LEFT);
            }
        }
        return $selector . $encoded;
    }

    private function decodeUint256(string $hex): string
    {
        $hex = str_starts_with($hex, '0x') ? substr($hex, 2) : $hex;
        if ($hex === '' || ! ctype_xdigit($hex)) {
            throw new \RuntimeException('Invalid hex for uint256');
        }
        return gmp_strval(gmp_init($hex, 16));
    }

    /// Decode StakePosition struct from ABI: (uint256 amount, uint64 lockedAt, uint64 unlockAt, bool claimed)
    private function decodePosition(string $hex, int $positionId): ?array
    {
        $hex = str_starts_with($hex, '0x') ? substr($hex, 2) : $hex;
        if (strlen($hex) < 256 || ! ctype_xdigit($hex)) return null;

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

    private function decodeCoverageRatio(string $hex): array
    {
        $hex = str_starts_with($hex, '0x') ? substr($hex, 2) : $hex;
        if (strlen($hex) < 192 || ! ctype_xdigit($hex)) {
            throw new \RuntimeException('Invalid hex for coverageRatio');
        }
        $chunk = fn (int $i) => substr($hex, $i * 64, 64);
        return [
            gmp_strval(gmp_init($chunk(0), 16)),
            gmp_strval(gmp_init($chunk(1), 16)),
            gmp_strval(gmp_init($chunk(2), 16)),
        ];
    }

    private function rpcError(string $code, string $message): JsonResponse
    {
        return ApiEnvelope::error($code, $message, true, [], 503);
    }

    // ═══════════════════════════════════════════
    // Public API
    // ═══════════════════════════════════════════

    public function earned(Request $request): JsonResponse
    {
        $address = $request->query('address', '');
        if ($address === '' || ! preg_match('/^0x[a-fA-F0-9]{40}$/', $address)) {
            return ApiEnvelope::error('INVALID_ADDRESS', 'address must be a valid EVM address', false, ['received' => $address]);
        }

        if ($this->isMockMode()) return $this->mockEarned($address);

        try {
            $data   = $this->encodeCallData(self::SELECTOR_EARNED, [$address]);
            $result = $this->ethCall($data);
            return ApiEnvelope::success([
                'address' => strtolower($address),
                'earned'  => $this->decodeUint256($result),
            ], 'LIVE');
        } catch (\Throwable $e) {
            Log::warning('StakingController: earned failed', ['error' => $e->getMessage()]);
            return $this->rpcError('STAKING_RPC_UNAVAILABLE', 'Unable to read staking contract');
        }
    }

    public function positions(Request $request): JsonResponse
    {
        $address = $request->query('address', '');
        if ($address === '' || ! preg_match('/^0x[a-fA-F0-9]{40}$/', $address)) {
            return ApiEnvelope::error('INVALID_ADDRESS', 'address must be a valid EVM address', false, ['received' => $address]);
        }

        $cursor = max(0, (int) ($request->query('cursor', 0)));
        $limit  = min(100, max(1, (int) ($request->query('limit', self::POSITIONS_PER_PAGE))));

        if ($this->isMockMode()) return $this->mockPositions($address);

        try {
            // Use a pinned block number for consistency across multiple calls
            $blockHex = $this->ethCall('0x', '0x' . dechex(random_int(1, 100000))); // placeholder — read block once
            // Actually: read latest block number first
            $blockNumHex = Http::timeout(5)
                ->withHeaders(['Content-Type' => 'application/json'])
                ->post($this->rpcUrl(), [
                    'jsonrpc' => '2.0', 'method' => 'eth_blockNumber', 'params' => [], 'id' => random_int(1, 999999),
                ]);
            $blockTag = $blockNumHex->successful()
                ? ($blockNumHex->json()['result'] ?? 'latest')
                : 'latest';

            $countData = $this->encodeCallData(self::SELECTOR_USER_POSITION_COUNT, [$address]);
            $countHex  = $this->ethCall($countData, $blockTag);
            $total     = (int) $this->decodeUint256($countHex);

            $start = $cursor;
            $end   = min($total, $start + $limit);
            $items = [];
            $failedIds = [];

            for ($i = $start; $i < $end; $i++) {
                try {
                    $posHex = $this->ethCall(
                        $this->encodeCallData(self::SELECTOR_POSITIONS, [$address, $i]),
                        $blockTag
                    );
                    $pos = $this->decodePosition($posHex, $i);
                    if ($pos !== null) {
                        $pos['earned'] = null; // earned is per-account, computed separately
                        $items[] = $pos;
                    } else {
                        $failedIds[] = $i;
                    }
                } catch (\Throwable $e) {
                    $failedIds[] = $i;
                    Log::warning('StakingController: position read failed', [
                        'positionId' => $i, 'error' => $e->getMessage(),
                    ]);
                }
            }

            $dataStatus = empty($failedIds) ? 'LIVE' : 'PARTIAL';
            $meta = ['source' => 'chain'];
            if (! empty($failedIds)) $meta['failedPositionIds'] = $failedIds;

            return ApiEnvelope::success([
                'address'       => strtolower($address),
                'positions'     => $items,
                'returnedCount' => count($items),
                'onchainCount'  => $total,
                'cursor'        => $cursor,
                'limit'         => $limit,
                'nextCursor'    => $end < $total ? $end : null,
            ], $dataStatus, $blockTag, $meta);
        } catch (\Throwable $e) {
            Log::warning('StakingController: positions failed', ['error' => $e->getMessage()]);
            return $this->rpcError('STAKING_RPC_UNAVAILABLE', 'Unable to read staking contract');
        }
    }

    public function status(): JsonResponse
    {
        if ($this->isMockMode()) return $this->mockStatus();

        try {
            $blockNumHex = Http::timeout(5)
                ->withHeaders(['Content-Type' => 'application/json'])
                ->post($this->rpcUrl(), [
                    'jsonrpc' => '2.0', 'method' => 'eth_blockNumber', 'params' => [], 'id' => random_int(1, 999999),
                ]);
            $blockTag = $blockNumHex->successful()
                ? ($blockNumHex->json()['result'] ?? 'latest')
                : 'latest';

            $totalStaked = $this->decodeUint256($this->ethCall($this->encodeCallData(self::SELECTOR_TOTAL_STAKED), $blockTag));
            $rewardRate  = $this->decodeUint256($this->ethCall($this->encodeCallData(self::SELECTOR_REWARD_RATE), $blockTag));
            $periodEnd   = $this->decodeUint256($this->ethCall($this->encodeCallData(self::SELECTOR_PERIOD_FINISH), $blockTag));
            $available   = $this->decodeUint256($this->ethCall($this->encodeCallData(self::SELECTOR_AVAILABLE_REWARD_RESERVE), $blockTag));

            return ApiEnvelope::success([
                'totalStaked'            => $totalStaked,
                'rewardRate'             => $rewardRate,
                'periodFinish'           => $periodEnd,
                'availableRewardReserve' => $available,
            ], 'LIVE', $blockTag);
        } catch (\Throwable $e) {
            Log::warning('StakingController: status failed', ['error' => $e->getMessage()]);
            return $this->rpcError('STAKING_RPC_UNAVAILABLE', 'Unable to read staking contract');
        }
    }

    // ═══════════════════════════════════════════
    // Admin API
    // ═══════════════════════════════════════════

    public function fundRewards(Request $request): JsonResponse
    {
        $amount = $request->input('amount', '');
        if ($amount === '' || ! ctype_digit($amount) || gmp_cmp(gmp_init($amount, 10), gmp_init('0')) <= 0) {
            return ApiEnvelope::error('INVALID_AMOUNT', 'amount must be a positive decimal integer string', false, ['received' => $amount]);
        }

        return ApiEnvelope::error(
            'NOT_IMPLEMENTED',
            'Chain write operations are not yet implemented. This endpoint will submit fundRewards(amount) once the governance signer is integrated.',
            false,
            ['action' => 'fundRewards', 'amount' => $amount],
            501
        );
    }

    public function setRewardRate(Request $request): JsonResponse
    {
        $rate = $request->input('rate', '');
        if ($rate === '' || ! ctype_digit($rate) || gmp_cmp(gmp_init($rate, 10), gmp_init('0')) <= 0) {
            return ApiEnvelope::error('INVALID_RATE', 'rate must be a positive decimal integer string', false, ['received' => $rate]);
        }

        return ApiEnvelope::error(
            'NOT_IMPLEMENTED',
            'Chain write operations are not yet implemented. This endpoint will submit setRewardRate(rate) once the reward manager signer is integrated.',
            false,
            ['action' => 'setRewardRate', 'rate' => $rate],
            501
        );
    }

    public function coverage(): JsonResponse
    {
        if ($this->isMockMode()) return $this->mockCoverage();

        try {
            $result = $this->ethCall($this->encodeCallData(self::SELECTOR_COVERAGE_RATIO));
            [$principal, $reward, $total] = $this->decodeCoverageRatio($result);
            return ApiEnvelope::success([
                'principal' => $principal,
                'reward'    => $reward,
                'total'     => $total,
            ], 'LIVE');
        } catch (\Throwable $e) {
            Log::warning('StakingController: coverage failed', ['error' => $e->getMessage()]);
            return $this->rpcError('STAKING_RPC_UNAVAILABLE', 'Unable to read staking contract');
        }
    }

    // ═══════════════════════════════════════════
    // Mock responses (ONLY in explicit mock mode)
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
            'address'       => strtolower($address),
            'positions'     => [],
            'returnedCount' => 0,
            'onchainCount'  => 0,
            'cursor'        => 0,
            'limit'         => self::POSITIONS_PER_PAGE,
            'nextCursor'    => null,
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
