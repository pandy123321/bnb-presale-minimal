<?php

declare(strict_types=1);

namespace App\Modules\Pangu2\Admin\Controllers;

use App\Http\ApiEnvelope;
use App\Modules\Core\RBAC\RbacMatrix;
use App\Modules\Core\Transaction\Models\TransactionProjection;
use App\Modules\Pangu2\Buyback\Models\BuybackEvent;
use App\Modules\Pangu2\Dividend\Models\DividendAllocation;
use App\Modules\Pangu2\Dividend\Models\DividendEpoch;
use App\Modules\Pangu2\Locker\Models\LockerBatch;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

/**
 * Admin Controller — Dashboard KPIs consuming data from B05+B06 modules.
 * All endpoints require admin authentication + RBAC.
 */
class AdminDashboardController extends Controller
{
    /**
     * GET /admin-api/v1/projects/pangu2/dashboard
     *
     * Aggregated KPIs from transaction projections, dividend epochs,
     * buyback events, and locker batches.
     */
    public function dashboard(): JsonResponse
    {
        $chainId = $this->chainId();

        // ── Transaction KPIs ──
        $totalTransactions = TransactionProjection::where('chain_id', $chainId)
            ->where('status', 'confirmed')
            ->count();

        $totalBuy = TransactionProjection::where('chain_id', $chainId)
            ->where('type', 'buy')
            ->where('status', 'confirmed')
            ->count();

        $totalSell = TransactionProjection::where('chain_id', $chainId)
            ->where('type', 'sell')
            ->where('status', 'confirmed')
            ->count();

        $uniqueWallets = TransactionProjection::where('chain_id', $chainId)
            ->where('status', 'confirmed')
            ->distinct('from_address')
            ->count('from_address');

        // ── Dividend KPIs ──
        $currentEpoch = DividendEpoch::where('chain_id', $chainId)
            ->orderBy('epoch_id', 'desc')
            ->first();

        $totalClaimed = DividendAllocation::where('chain_id', $chainId)
            ->where('claimed', true)
            ->count();

        $totalAllocatedRaw = DividendAllocation::where('chain_id', $chainId)
            ->sum('allocated_raw');

        // ── Buyback KPIs ──
        $totalBuybacks = BuybackEvent::where('chain_id', $chainId)->count();
        $totalBuybackBnbWei = BuybackEvent::where('chain_id', $chainId)->sum('bnb_amount_wei');

        // ── Locker KPIs ──
        $activeBatches = LockerBatch::where('chain_id', $chainId)
            ->where('status', 'locked')
            ->count();
        $totalLockedRaw = LockerBatch::where('chain_id', $chainId)
            ->where('status', 'locked')
            ->sum('tokens_raw');

        return ApiEnvelope::success([
            // Transaction
            'total_transactions'      => $totalTransactions,
            'total_buy'               => $totalBuy,
            'total_sell'              => $totalSell,
            'unique_wallets'          => $uniqueWallets,
            // Dividend
            'current_epoch_id'        => $currentEpoch?->epoch_id ?? 0,
            'current_epoch_status'    => $currentEpoch?->status ?? 'pending',
            'total_claimed'           => $totalClaimed,
            'total_allocated_raw'     => $totalAllocatedRaw ?? '0',
            // Buyback
            'total_buybacks'          => $totalBuybacks,
            'total_buyback_bnb_wei'   => $totalBuybackBnbWei ?? '0',
            // Locker
            'active_locker_batches'   => $activeBatches,
            'total_locked_tokens_raw' => $totalLockedRaw ?? '0',
            // RBAC context for the current admin
            'your_permissions'        => RbacMatrix::permissionsFor($this->currentRole()),
        ], $currentEpoch ? 'LIVE' : 'MOCK_DATA');
    }

    /**
     * GET /admin-api/v1/projects/pangu2/contracts
     */
    public function contracts(): JsonResponse
    {
        return ApiEnvelope::success([
            [
                'name'              => 'Pangu2TradeRouter',
                'address'           => '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
                'abi_version'       => '1.0.0',
                'deployment_block'  => '42000000',
                'status'            => 'ACTIVE',
            ],
            [
                'name'              => 'DividendDistributor',
                'address'           => '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
                'abi_version'       => '1.0.0',
                'deployment_block'  => '42000001',
                'status'            => 'ACTIVE',
            ],
            [
                'name'              => 'SupportPool',
                'address'           => '0xcccccccccccccccccccccccccccccccccccccccc',
                'abi_version'       => '1.0.0',
                'deployment_block'  => '42000002',
                'status'            => 'ACTIVE',
            ],
            [
                'name'              => 'BuybackLocker',
                'address'           => '0xdddddddddddddddddddddddddddddddddddddddd',
                'abi_version'       => '1.0.0',
                'deployment_block'  => '42000003',
                'status'            => 'ACTIVE',
            ],
        ], 'MOCK_DATA');
    }

    // ── Helpers ──────────────────────────────

    private function chainId(): int
    {
        return (int) config('pangu2.chain_id', 31337);
    }

    private function currentRole(): string
    {
        return request()->user()?->role ?? 'VIEWER';
    }
}
