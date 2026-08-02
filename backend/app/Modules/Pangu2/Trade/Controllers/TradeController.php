<?php

declare(strict_types=1);

namespace App\Modules\Pangu2\Trade\Controllers;

use App\Http\ApiEnvelope;
use App\Modules\Pangu2\Trade\Services\QuoteService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

final class TradeController
{
    public function __construct(
        private readonly QuoteService $quoteService,
    ) {}

    public function buyQuote(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'amount_bnb_wei' => ['required', 'string', 'regex:/^[0-9]+$/'],
        ]);

        try {
            $quote = $this->quoteService->getBuyQuote($validated['amount_bnb_wei']);
        } catch (\InvalidArgumentException $e) {
            return ApiEnvelope::error('INVALID_AMOUNT', $e->getMessage(), false, [], 422);
        }

        return ApiEnvelope::success($quote, 'MOCK_DATA', $quote['quote_block']);
    }

    public function sellQuote(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'amount_token_raw' => ['required', 'string', 'regex:/^[0-9]+$/'],
            'wallet_address'   => ['required', 'string', 'regex:/^0x[0-9a-fA-F]{40}$/'],
        ]);

        try {
            $quote = $this->quoteService->getSellQuote(
                $validated['amount_token_raw'],
                strtolower($validated['wallet_address']),
            );
        } catch (\InvalidArgumentException $e) {
            return ApiEnvelope::error('INVALID_AMOUNT', $e->getMessage(), false, [], 422);
        }

        return ApiEnvelope::success($quote, 'MOCK_DATA', $quote['quote_block']);
    }

    public function transactions(Request $request, string $address): JsonResponse
    {
        $page    = (int) $request->query('page', 1);
        $perPage = (int) $request->query('per_page', 20);
        $result  = $this->quoteService->getTransactions(strtolower($address), $page, $perPage);

        return ApiEnvelope::paginated(
            $result['items'],
            $result['current_page'],
            $result['per_page'],
            $result['total'],
            'MOCK_DATA',
        );
    }
}
