<?php

declare(strict_types=1);

namespace App\Modules\Pangu2\Buyback\Controllers;

use App\Http\ApiEnvelope;
use App\Modules\Pangu2\Buyback\Models\BuybackEvent;
use App\Modules\Pangu2\Locker\Models\LockerBatch;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class BuybackController extends Controller
{
    /**
     * GET /api/v1/projects/pangu2/buybacks
     *
     * List buyback events. Falls back to MOCK_DATA if no events exist.
     */
    public function index(Request $request): JsonResponse
    {
        $page    = max(1, (int) $request->query('page', 1));
        $perPage = min(100, max(1, (int) $request->query('per_page', 20)));
        $chainId = $this->chainId();

        $query = BuybackEvent::where('chain_id', $chainId)
            ->orderBy('event_timestamp', 'desc');

        $total = $query->count();
        $events = $query->skip(($page - 1) * $perPage)
            ->take($perPage)
            ->get();

        if ($events->isEmpty()) {
            return $this->mockBuybacks();
        }

        $data = $events->map(fn ($e) => [
            'batch_id'        => $e->buyback_id,
            'amount_bnb_wei'  => $e->bnb_amount_wei,
            'tokens_raw'      => $e->token_amount_raw,
            'trigger'         => $e->trigger_address,
            'locker'          => $e->locker_address,
            'timestamp'       => $e->event_timestamp->toIso8601String(),
        ])->toArray();

        return ApiEnvelope::paginated($data, $page, $perPage, $total, 'MOCK_DATA');
    }

    /**
     * GET /api/v1/projects/pangu2/locker/batches
     *
     * List locker batches.
     */
    public function lockerBatches(Request $request): JsonResponse
    {
        $page    = max(1, (int) $request->query('page', 1));
        $perPage = min(100, max(1, (int) $request->query('per_page', 20)));
        $chainId = $this->chainId();

        $query = LockerBatch::where('chain_id', $chainId)
            ->orderBy('batch_id', 'desc');

        $total = $query->count();
        $batches = $query->skip(($page - 1) * $perPage)
            ->take($perPage)
            ->get();

        if ($batches->isEmpty()) {
            return $this->mockLockerBatches();
        }

        $data = $batches->map(fn ($b) => [
            'batch_id'        => $b->batch_id,
            'tokens_raw'      => $b->tokens_raw,
            'locked_until'    => $b->locked_until?->toIso8601String(),
            'duration_days'   => $b->duration_days,
            'status'          => $b->status,
        ])->toArray();

        return ApiEnvelope::paginated($data, $page, $perPage, $total, 'MOCK_DATA');
    }

    // ── Helpers ──────────────────────────────

    private function chainId(): int
    {
        return (int) config('pangu2.chain_id', 31337);
    }

    private function mockBuybacks(): JsonResponse
    {
        $data = [
            ['batch_id' => 1247, 'amount_bnb_wei' => '10000000000000000', 'tokens_raw' => '4612000000000000000000', 'trigger' => '0x' . str_repeat('aa', 20), 'locker' => '0x' . str_repeat('bb', 20), 'timestamp' => now()->subMinutes(2)->toIso8601String()],
            ['batch_id' => 1246, 'amount_bnb_wei' => '10000000000000000', 'tokens_raw' => '4598000000000000000000', 'trigger' => '0x' . str_repeat('cc', 20), 'locker' => '0x' . str_repeat('dd', 20), 'timestamp' => now()->subMinutes(3)->toIso8601String()],
        ];

        return ApiEnvelope::paginated($data, 1, 20, 2, 'MOCK_DATA');
    }

    private function mockLockerBatches(): JsonResponse
    {
        $data = [
            ['batch_id' => 1247, 'tokens_raw' => '4612000000000000000000', 'locked_until' => now()->addDays(365)->toIso8601String(), 'duration_days' => 365, 'status' => 'locked'],
            ['batch_id' => 1246, 'tokens_raw' => '4598000000000000000000', 'locked_until' => now()->addDays(364)->toIso8601String(), 'duration_days' => 365, 'status' => 'locked'],
        ];

        return ApiEnvelope::paginated($data, 1, 20, 2, 'MOCK_DATA');
    }
}
