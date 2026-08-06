<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Http\ApiEnvelope;
use App\Modules\Pangu2\Trade\Services\QuoteService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

final class TradeController extends Controller
{
    public function __construct(
        private readonly QuoteService $quote,
    ) {}

    /**
     * POST /api/v1/projects/pangu2/quotes/buy
     */
    public function buyQuote(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'amount_bnb_wei' => ['required', 'string', 'regex:/^[1-9][0-9]*$/'],
        ]);

        try {
            $data   = $this->quote->getBuyQuote($validated['amount_bnb_wei']);
            $source = $data['source'] ?? 'unknown';
            $status = $this->quote->sourceStatus($source);
            return ApiEnvelope::success($data, $status, $data['quote_block'] ?? null);
        } catch (\InvalidArgumentException $e) {
            return ApiEnvelope::error('INVALID_AMOUNT', $e->getMessage());
        } catch (\Throwable $e) {
            return ApiEnvelope::error('QUOTE_FAILED', 'Unable to generate buy quote', true);
        }
    }

    /**
     * POST /api/v1/projects/pangu2/quotes/sell
     */
    public function sellQuote(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'amount_token_raw' => ['required', 'string', 'regex:/^[1-9][0-9]*$/'],
            'wallet_address'   => ['required', 'string', 'max:42'],
        ]);

        try {
            $data   = $this->quote->getSellQuote($validated['amount_token_raw'], $validated['wallet_address']);
            $source = $data['source'] ?? 'unknown';
            $status = $this->quote->sourceStatus($source);
            return ApiEnvelope::success($data, $status, $data['quote_block'] ?? null);
        } catch (\InvalidArgumentException $e) {
            return ApiEnvelope::error('INVALID_AMOUNT', $e->getMessage());
        } catch (\Throwable $e) {
            return ApiEnvelope::error('QUOTE_FAILED', 'Unable to generate sell quote', true);
        }
    }

    /**
     * GET /api/v1/projects/pangu2/wallets/{address}/transactions
     *
     * Returns transaction data from chain_raw_events or UNAVAILABLE if unsynced.
     */
    public function transactions(string $address, Request $request): JsonResponse
    {
        $chainId = (int) config('pangu2.chain_id', 31337);

        // Validate address format
        if (!preg_match('/^0x[a-fA-F0-9]{40}$/', $address)) {
            return ApiEnvelope::error('INVALID_ADDRESS', 'Address must be a valid EVM address');
        }

        try {
            // Only return if we have CONFIRMED events — empty table = unsynced
            $confirmedCount = \DB::table('chain_raw_events')
                ->where('chain_id', $chainId)
                ->where('status', 'CONFIRMED')
                ->count();

            if ($confirmedCount === 0) {
                return ApiEnvelope::success([
                    'message' => 'Transaction data unavailable — chain worker not yet synced',
                ], 'UNAVAILABLE');
            }

            $events = \DB::table('chain_raw_events')
                ->where('chain_id', $chainId)
                ->where('status', 'CONFIRMED')
                ->where(function ($q) use ($address) {
                    $q->whereRaw("decoded_data->>'buyer' = ?", [$address])
                      ->orWhereRaw("decoded_data->>'seller' = ?", [$address]);
                })
                ->orderBy('block_number', 'desc')
                ->limit(50)
                ->get();

            if ($events->isEmpty()) {
                return ApiEnvelope::success([
                    'message' => 'No transactions found for this address',
                ], 'LIVE');
            }

            $items = [];
            foreach ($events as $ev) {
                $decoded = json_decode($ev->decoded_data, true) ?? [];
                $items[] = [
                    'tx_hash'      => $ev->transaction_hash,
                    'block_number' => (string) $ev->block_number,
                    'event_name'   => $ev->event_name,
                    'decoded_data' => $decoded,
                    'timestamp'    => $ev->block_timestamp,
                    'status'       => $ev->status,
                ];
            }

            return ApiEnvelope::success(['items' => $items], 'LIVE');
        } catch (\Throwable) {
            return ApiEnvelope::success([
                'message' => 'Transaction data unavailable — chain worker not yet synced',
            ], 'UNAVAILABLE');
        }
    }
}
