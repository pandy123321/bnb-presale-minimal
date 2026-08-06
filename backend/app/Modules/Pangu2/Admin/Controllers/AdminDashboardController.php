<?php

declare(strict_types=1);

namespace App\Modules\Pangu2\Admin\Controllers;

use App\Http\ApiEnvelope;
use App\Modules\Core\ContractRegistry\Services\ContractRegistryService;
use App\Modules\Core\RBAC\RbacMatrix;
use App\Modules\Core\Transaction\Models\TransactionProjection;
use App\Modules\Pangu2\Buyback\Models\BuybackEvent;
use App\Modules\Pangu2\Dividend\Models\DividendAllocation;
use App\Modules\Pangu2\Dividend\Models\DividendEpoch;
use App\Modules\Pangu2\Locker\Models\LockerBatch;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class AdminDashboardController extends Controller
{
    public function dashboard(): JsonResponse
    {
        $chainId = $this->chainId();

        $totalTransactions = TransactionProjection::where('chain_id', $chainId)->where('status', 'confirmed')->count();
        $totalBuy   = TransactionProjection::where('chain_id', $chainId)->where('type', 'buy')->where('status', 'confirmed')->count();
        $totalSell  = TransactionProjection::where('chain_id', $chainId)->where('type', 'sell')->where('status', 'confirmed')->count();

        $currentEpoch = DividendEpoch::where('chain_id', $chainId)->orderBy('epoch_id', 'desc')->first();
        $totalClaimed = DividendAllocation::where('chain_id', $chainId)->where('claimed', true)->count();
        $totalBuybacks = BuybackEvent::where('chain_id', $chainId)->count();
        $activeBatches = LockerBatch::where('chain_id', $chainId)->where('status', 'locked')->count();

        $hasData = $totalTransactions > 0 || ($currentEpoch !== null);

        return ApiEnvelope::success([
            'total_transactions'      => $totalTransactions,
            'total_buy'               => $totalBuy,
            'total_sell'              => $totalSell,
            'current_epoch_id'        => $currentEpoch?->epoch_id ?? 0,
            'current_epoch_status'    => $currentEpoch?->status ?? 'pending',
            'total_claimed'           => $totalClaimed,
            'total_buybacks'          => $totalBuybacks,
            'active_locker_batches'   => $activeBatches,
            'your_permissions'        => RbacMatrix::permissionsFor($this->currentRole()),
        ], $hasData ? 'LIVE' : 'UNAVAILABLE');
    }

    /**
     * GET /admin-api/v1/projects/pangu2/contracts
     * Returns real contract addresses from pangu2 config — no fake addresses.
     */
    public function contracts(): JsonResponse
    {
        $items = app(ContractRegistryService::class)->getAll();
        $hasAny = count($items) > 0;

        return ApiEnvelope::success($items, $hasAny ? 'LIVE' : 'UNAVAILABLE');
    }

    private function chainId(): int
    {
        return (int) config('pangu2.chain_id', 31337);
    }

    private function currentRole(): string
    {
        return request()->user()?->role ?? 'VIEWER';
    }
}
