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
        $validated = $request->validate([
            'page'     => ['integer', 'min:1'],
            'per_page' => ['integer', 'min:1', 'max:100'],
        ]);
        $page    = (int) ($validated['page'] ?? 1);
        $perPage = (int) ($validated['per_page'] ?? 20);
        $chainId = $this->chainId();

        $query = BuybackEvent::where('chain_id', $chainId)
            ->orderBy('event_timestamp', 'desc');

        $total = $query->count();
        $events = $query->skip(($page - 1) * $perPage)
            ->take($perPage)
            ->get();

        if ($events->isEmpty()) {
            return ApiEnvelope::paginated([], 1, 20, 0, 'LIVE');
        }

        $data = $events->map(fn ($e) => [
            'batch_id'        => $e->buyback_id,
            'amount_bnb_wei'  => $e->bnb_amount_wei,
            'tokens_raw'      => $e->token_amount_raw,
            'trigger'         => $e->trigger_address,
            'locker'          => $e->locker_address,
            'timestamp'       => $e->event_timestamp->toIso8601String(),
        ])->toArray();

        return ApiEnvelope::paginated($data, $page, $perPage, $total, 'LIVE');
    }

    /**
     * GET /api/v1/projects/pangu2/locker/batches
     *
     * List locker batches.
     */
    public function lockerBatches(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'page'     => ['integer', 'min:1'],
            'per_page' => ['integer', 'min:1', 'max:100'],
        ]);
        $page    = (int) ($validated['page'] ?? 1);
        $perPage = (int) ($validated['per_page'] ?? 20);
        $chainId = $this->chainId();

        $query = LockerBatch::where('chain_id', $chainId)
            ->orderBy('batch_id', 'desc');

        $total = $query->count();
        $batches = $query->skip(($page - 1) * $perPage)
            ->take($perPage)
            ->get();

        if ($batches->isEmpty()) {
            return ApiEnvelope::paginated([], 1, 20, 0, 'LIVE');
        }

        $data = $batches->map(fn ($b) => [
            'batch_id'        => $b->batch_id,
            'tokens_raw'      => $b->tokens_raw,
            'locked_until'    => $b->locked_until?->toIso8601String(),
            'duration_days'   => $b->duration_days,
            'status'          => $b->status,
        ])->toArray();

        return ApiEnvelope::paginated($data, $page, $perPage, $total, 'LIVE');
    }

    // ── Helpers ──────────────────────────────

    private function chainId(): int
    {
        return (int) config('pangu2.chain_id', 31337);
    }
}
