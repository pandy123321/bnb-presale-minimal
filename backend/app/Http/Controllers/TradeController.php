<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Http\ApiEnvelope;
use App\Modules\Pangu2\Trade\QuoteService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

/**
 * TradeController — Quote & Transaction API (MOCK stage).
 *
 * ABI unavailable. All quotes return source="mock" and MOCK_DATA.
 * When ABI becomes available, swap QuoteService for an adapter
 * that calls previewBuy / previewSell on the on-chain contract.
 */
final class TradeController extends Controller
{
    public function __construct(
        private readonly QuoteService $quote,
    ) {}

    /**
     * POST /api/v1/projects/pangu2/quotes/buy
     *
     * Request: { amount_bnb_wei: "100000000000000000" }
     */
    public function buyQuote(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'amount_bnb_wei' => ['required', 'string', 'regex:/^[1-9][0-9]*$/'],
        ]);

        $data = $this->quote->buildBuyQuote($validated['amount_bnb_wei']);

        return ApiEnvelope::success($data, 'MOCK_DATA', $data['quote_block']);
    }

    /**
     * POST /api/v1/projects/pangu2/quotes/sell
     *
     * Request: { amount_token_raw: "46235000000000000000000", wallet_address: "0x..." }
     */
    public function sellQuote(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'amount_token_raw' => ['required', 'string', 'regex:/^[1-9][0-9]*$/'],
            'wallet_address'   => ['required', 'string', 'max:42'],
        ]);

        $data = $this->quote->buildSellQuote($validated['amount_token_raw']);

        return ApiEnvelope::success($data, 'MOCK_DATA', $data['quote_block']);
    }

    /**
     * GET /api/v1/projects/pangu2/wallets/{address}/transactions
     *
     * Returns a fixed set of mock transactions for any address.
     */
    public function transactions(string $address, Request $request): JsonResponse
    {
        $mockBlock = '42816000';

        return ApiEnvelope::success([
            [
                'tx_hash'       => '0xe1b4f2a3c5d67890123456789abcdef01234567890abcdef0123456789abcdef',
                'block_number'  => '42815900',
                'type'          => 'buy',
                'amount_in'     => '0.500000000000000000',
                'amount_out'    => '231175000000000000000000',
                'status'        => 'confirmed',
                'timestamp'     => now()->subHours(2)->toIso8601String(),
            ],
            [
                'tx_hash'       => '0xfe9876543210abcdef1234567890abcdef1234567890abcdef1234567890abcd',
                'block_number'  => '42780000',
                'type'          => 'buy',
                'amount_in'     => '1.000000000000000000',
                'amount_out'    => '462350000000000000000000',
                'status'        => 'confirmed',
                'timestamp'     => now()->subHours(5)->toIso8601String(),
            ],
            [
                'tx_hash'       => '0xdcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210fe',
                'block_number'  => '42650000',
                'type'          => 'claim',
                'amount_in'     => '0',
                'amount_out'    => '42000000000000000000',
                'status'        => 'confirmed',
                'timestamp'     => now()->subDays(2)->toIso8601String(),
            ],
        ], 'MOCK_DATA', $mockBlock);
    }
}
