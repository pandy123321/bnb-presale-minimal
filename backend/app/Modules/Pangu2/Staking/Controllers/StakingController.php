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
 * ABI Selectors (keccak256-verified):
 *   earned(address)               -> 0x008cc262
 *   positions(address,uint256)    -> 0xc1be6677
 *   userPositionCount(address)    -> 0x0918eb14
 *   totalStaked()                 -> 0x817b1cd2
 *   rewardRate()                  -> 0x7b0a47ee
 *   periodFinish()                -> 0xebe2b12b
 *   availableRewardReserve()      -> 0x9fe258eb
 *   coverageRatio()               -> 0xf812fa70
 */
class StakingController extends Controller
{
    // ─── Verified ABI selectors ───
    private const SELECTOR_EARNED                  = '0x008cc262';
    private const SELECTOR_POSITIONS               = '0xc1be6677';
    private const SELECTOR_USER_POSITION_COUNT      = '0x0918eb14';
    private const SELECTOR_TOTAL_STAKED            = '0x817b1cd2';
    private const SELECTOR_REWARD_RATE             = '0x7b0a47ee';
    private const SELECTOR_PERIOD_FINISH           = '0xebe2b12b';
    private const SELECTOR_AVAILABLE_REWARD_RESERVE = '0x9fe258eb';
    private const SELECTOR_COVERAGE_RATIO          = '0xf812fa70';

    /// Maximum positions per page + per-request time budget
    private const POSITIONS_PER_PAGE = 20;
    private const POSITIONS_RPC_BUDGET_SEC = 25;

    private function rpcUrl(): string
    {
        return config('pangu2.rpc_url', 'http://127.0.0.1:8545');
    }

    private function stakingAddress(): string
    {
        return config('pangu2.staking_address', '');
    }

    /**
     * Mock mode is ONLY allowed in local/testing with an explicit config flag.
     * Production returns a hard 503.
     */
    private function isMockMode(): bool
    {
        $addr = $this->stakingAddress();
        if ($addr !== '') return false; // address configured → always live

        $env = app()->environment();
        if (! in_array($env, ['local', 'testing'], true)) return false;

        return (bool) config('pangu2.staking_mock_enabled', false);
    }

    /**
     * Return structured JSON error when staking is not configured.
     * Never throws — always returns a JsonResponse.
     */
    private function requireLiveOrError(): ?JsonResponse
    {
        if ($this->isMockMode()) return null;
        if ($this->stakingAddress() !== '') return null;

        return $this->configError('Staking contract address not configured');
    }

    // ═══════════════════════════════════════════
    // Unified RPC handler
    // ═══════════════════════════════════════════

    /**
     * Generic JSON-RPC call. Returns result or throws.
     */
    private function rpc(string $method, array $params = [], ?string $blockTag = null): mixed
    {
        $payload = [
            'jsonrpc' => '2.0',
            'method'  => $method,
            'params'  => $params,
            'id'      => random_int(1, 999999),
        ];

        $response = Http::timeout(5)
            ->withHeaders(['Content-Type' => 'application/json'])
            ->post($this->rpcUrl(), $payload);

        if (! $response->successful()) {
            throw new \RuntimeException("RPC HTTP {$response->status()}");
        }

        $body = $response->json();
        if (! is_array($body)) {
            throw new \RuntimeException('RPC returned non-JSON response');
        }
        if (isset($body['error'])) {
            throw new \RuntimeException('RPC error: ' . json_encode($body['error']));
        }

        return $body['result'] ?? null;
    }

    /**
     * eth_call wrapper.
     */
    private function ethCall(string $data, ?string $blockTag = null): string
    {
        $to = $this->stakingAddress();
        if ($to === '') {
            throw new \RuntimeException('Staking contract address not configured');
        }

        $params = [[
            'to'   => $to,
            'data' => $data,
        ], $blockTag ?? 'latest'];

        $result = $this->rpc('eth_call', $params);
        if ($result === null || $result === '0x') {
            throw new \RuntimeException('RPC returned empty hex result');
        }

        return $result;
    }

    /**
     * eth_blockNumber — returns hex string or throws. No fallback to "latest".
     */
    private function getBlockNumber(): string
    {
        $result = $this->rpc('eth_blockNumber');
        if (! is_string($result) || ! preg_match('/^0x[0-9a-f]+$/i', $result)) {
            throw new \RuntimeException('RPC did not return a valid block number');
        }
        return $result;
    }

    // ═══════════════════════════════════════════
    // ABI encoding / decoding
    // ═══════════════════════════════════════════

    private function encodeCallData(string $selector, array $params = []): string
    {
        $encoded = '';
        foreach ($params as $p) {
            if (is_int($p)) {
                $encoded .= str_pad(dechex($p), 64, '0', STR_PAD_LEFT);
            } elseif (is_string($p) && str_starts_with($p, '0x')) {
                $encoded .= str_pad(strtolower(substr($p, 2)), 64, '0', STR_PAD_LEFT);
            } elseif (is_string($p) && ctype_digit($p)) {
                $encoded .= str_pad(gmp_strval(gmp_init($p, 10), 16), 64, '0', STR_PAD_LEFT);
            }
        }
        return $selector . $encoded;
    }

    private function decodeUint256(string $hex): string
    {
        $hex = str_starts_with($hex, '0x') ? substr($hex, 2) : $hex;
        if (strlen($hex) > 64 || ! ctype_xdigit($hex)) {
            throw new \RuntimeException('Invalid uint256 hex');
        }
        return gmp_strval(gmp_init($hex, 16));
    }

    /** Decode StakePosition: (uint256 amount, uint64 lockedAt, uint64 unlockAt, bool claimed) = 4 x 32 bytes */
    private function decodePosition(string $hex, int $positionId): ?array
    {
        $hex = str_starts_with($hex, '0x') ? substr($hex, 2) : $hex;
        if (strlen($hex) !== 256 || ! ctype_xdigit($hex)) return null;

        $ch = fn (int $i) => substr($hex, $i * 64, 64);
        $claimedVal = gmp_init($ch(3), 16);
        if (gmp_cmp($claimedVal, '1') > 0) return null; // bool must be 0 or 1

        return [
            'positionId' => $positionId,
            'amount'     => gmp_strval(gmp_init($ch(0), 16)),
            'lockedAt'   => gmp_strval(gmp_init($ch(1), 16)),
            'unlockAt'   => gmp_strval(gmp_init($ch(2), 16)),
            'claimed'    => gmp_cmp($claimedVal, '0') > 0,
        ];
    }

    /** Decode coverageRatio: (uint256 principal, uint256 reward, uint256 total) = 3 x 32 bytes */
    private function decodeCoverageRatio(string $hex): array
    {
        $hex = str_starts_with($hex, '0x') ? substr($hex, 2) : $hex;
        if (strlen($hex) !== 192 || ! ctype_xdigit($hex)) {
            throw new \RuntimeException('Invalid coverageRatio hex length');
        }
        $ch = fn (int $i) => substr($hex, $i * 64, 64);
        return [gmp_strval(gmp_init($ch(0), 16)), gmp_strval(gmp_init($ch(1), 16)), gmp_strval(gmp_init($ch(2), 16))];
    }

    // ═══════════════════════════════════════════
    // Error helpers
    // ═══════════════════════════════════════════

    private function configError(string $message): JsonResponse
    {
        return ApiEnvelope::error('STAKING_CONFIG_ERROR', $message, false, [], 503);
    }

    private function rpcError(string $message): JsonResponse
    {
        return ApiEnvelope::error('STAKING_RPC_UNAVAILABLE', $message, true, [], 503);
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

        if ($r = $this->requireLiveOrError()) return $r;
        if ($this->isMockMode()) return $this->mockEarned($address);

        try {
            $result = $this->ethCall($this->encodeCallData(self::SELECTOR_EARNED, [$address]));
            return ApiEnvelope::success([
                'address' => strtolower($address),
                'earned'  => $this->decodeUint256($result),
            ], 'LIVE');
        } catch (\Throwable $e) {
            Log::warning('StakingController: earned failed', ['error' => $e->getMessage()]);
            return $this->rpcError('Unable to read earned() from staking contract');
        }
    }

    public function positions(Request $request): JsonResponse
    {
        $address = $request->query('address', '');
        if ($address === '' || ! preg_match('/^0x[a-fA-F0-9]{40}$/', $address)) {
            return ApiEnvelope::error('INVALID_ADDRESS', 'address must be a valid EVM address', false, ['received' => $address]);
        }

        $validated = $request->validate([
            'cursor' => ['integer', 'min:0'],
            'limit'  => ['integer', 'min:1', 'max:' . self::POSITIONS_PER_PAGE],
        ]);
        $cursor = (int) ($validated['cursor'] ?? 0);
        $limit  = (int) ($validated['limit'] ?? self::POSITIONS_PER_PAGE);

        if ($r = $this->requireLiveOrError()) return $r;

        if ($this->isMockMode()) return $this->mockPositions($address);

        try {
            $blockTag = $this->getBlockNumber();

            $countHex = $this->ethCall(
                $this->encodeCallData(self::SELECTOR_USER_POSITION_COUNT, [$address]),
                $blockTag
            );
            $total = (int) $this->decodeUint256($countHex);

            $start = $cursor;
            $end   = min($total, $start + $limit);
            $items     = [];
            $failedIds = [];

            $deadline = microtime(true) + self::POSITIONS_RPC_BUDGET_SEC;

            for ($i = $start; $i < $end; $i++) {
                if (microtime(true) > $deadline) {
                    for ($j = $i; $j < $end; $j++) $failedIds[] = $j;
                    Log::warning('StakingController: positions time budget exceeded', [
                        'cursor' => $cursor, 'limit' => $limit, 'stoppedAt' => $i,
                    ]);
                    break;
                }
                try {
                    $posHex = $this->ethCall(
                        $this->encodeCallData(self::SELECTOR_POSITIONS, [$address, $i]),
                        $blockTag
                    );
                    $pos = $this->decodePosition($posHex, $i);
                    if ($pos !== null) {
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

            $isComplete = empty($failedIds);
            $dataStatus = $isComplete ? 'LIVE' : 'DEGRADED';

            return ApiEnvelope::success([
                'address'        => strtolower($address),
                'positions'      => $items,
                'returnedCount'  => count($items),
                'onchainCount'   => $total,
                'cursor'         => $cursor,
                'limit'          => $limit,
                'nextCursor'     => $end < $total ? $end : null,
                'isComplete'     => $isComplete,
                'failedPositionIds' => $failedIds,
            ], $dataStatus, $blockTag);
        } catch (\Throwable $e) {
            Log::warning('StakingController: positions failed', ['error' => $e->getMessage()]);
            return $this->rpcError('Unable to read positions from staking contract');
        }
    }

    public function status(): JsonResponse
    {
        if ($r = $this->requireLiveOrError()) return $r;

        if ($this->isMockMode()) return $this->mockStatus();

        try {
            $blockTag = $this->getBlockNumber();

            $total = $this->decodeUint256($this->ethCall($this->encodeCallData(self::SELECTOR_TOTAL_STAKED), $blockTag));
            $rate  = $this->decodeUint256($this->ethCall($this->encodeCallData(self::SELECTOR_REWARD_RATE), $blockTag));
            $end   = $this->decodeUint256($this->ethCall($this->encodeCallData(self::SELECTOR_PERIOD_FINISH), $blockTag));
            $avail = $this->decodeUint256($this->ethCall($this->encodeCallData(self::SELECTOR_AVAILABLE_REWARD_RESERVE), $blockTag));

            return ApiEnvelope::success([
                'totalStaked'            => $total,
                'rewardRate'             => $rate,
                'periodFinish'           => $end,
                'availableRewardReserve' => $avail,
            ], 'LIVE', $blockTag);
        } catch (\Throwable $e) {
            Log::warning('StakingController: status failed', ['error' => $e->getMessage()]);
            return $this->rpcError('Unable to read staking contract status');
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
            'Chain write operations not yet implemented.',
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
            'Chain write operations not yet implemented.',
            false,
            ['action' => 'setRewardRate', 'rate' => $rate],
            501
        );
    }

    public function coverage(): JsonResponse
    {
        if ($r = $this->requireLiveOrError()) return $r;

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
            return $this->rpcError('Unable to read coverage from staking contract');
        }
    }

    // ═══════════════════════════════════════════
    // Mock
    // ═══════════════════════════════════════════

    private function mockEarned(string $address): JsonResponse
    {
        return ApiEnvelope::success(['address' => strtolower($address), 'earned' => '0'], 'LIVE');
    }

    private function mockPositions(string $address): JsonResponse
    {
        return ApiEnvelope::success([
            'address'           => strtolower($address),
            'positions'         => [],
            'returnedCount'     => 0,
            'onchainCount'      => 0,
            'cursor'            => 0,
            'limit'             => self::POSITIONS_PER_PAGE,
            'nextCursor'        => null,
            'isComplete'        => true,
            'failedPositionIds' => [],
        ], 'LIVE');
    }

    private function mockStatus(): JsonResponse
    {
        return ApiEnvelope::success([
            'totalStaked' => '0', 'rewardRate' => '0',
            'periodFinish' => '0', 'availableRewardReserve' => '0',
        ], 'LIVE');
    }

    private function mockCoverage(): JsonResponse
    {
        return ApiEnvelope::success(['principal' => '0', 'reward' => '0', 'total' => '0'], 'LIVE');
    }
}
