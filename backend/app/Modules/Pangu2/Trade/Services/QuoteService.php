<?php

declare(strict_types=1);

namespace App\Modules\Pangu2\Trade\Services;

use App\Modules\Core\Chain\ChainAmount;

/**
 * Quote generation service (Mock phase).
 *
 * ABI for contract previewBuy / previewSell is NOT available yet.
 * This service returns mock quotes with source: "mock" and MOCK_DATA envelope.
 * When ABI becomes available, this will be replaced with real contract calls.
 *
 * Hard rules:
 *  - Never calculate tax rates client-side (frontend must NOT pass rate)
 *  - All amounts are integer strings (WeiAmount)
 *  - source is always "mock" until ABI is live
 *  - Buy is ALWAYS 4% tax
 *  - Sell tax rate (4% or 10%) is contract-determined; mock returns arbitrary tier
 */
final class QuoteService
{
    private const MOCK_BLOCK = '42815128';

    private const QUOTE_EXPIRY_SECONDS = 30;

    private const BUY_TAX_PERCENT = 4;

    /**
     * Return a mock buy quote for given BNB amount (in wei).
     */
    public function getBuyQuote(string $amountBnbWei): array
    {
        if (!ChainAmount::isValidWei($amountBnbWei)) {
            throw new \InvalidArgumentException('amount_bnb_wei must be a positive integer string.');
        }

        $rate           = '462350';
        $gross          = bcdiv(bcmul($amountBnbWei, $rate), '1000000000000000000', 0);
        $tax            = ChainAmount::applyTax($gross, self::BUY_TAX_PERCENT);
        $net            = bcsub($gross, $tax, 0);
        $minReceive     = bcdiv(bcmul($net, '99'), '100', 0);
        $quoteBlock     = self::MOCK_BLOCK;
        $expiresAt      = now()->addSeconds(self::QUOTE_EXPIRY_SECONDS)->toIso8601String();

        return [
            'amount_in_wei'    => $amountBnbWei,
            'gross_tokens_raw' => $gross,
            'tax_rate'         => '4.00%',
            'tax_tokens_raw'   => $tax,
            'net_tokens_raw'   => $net,
            'min_receive_raw'  => $minReceive,
            'quote_block'      => $quoteBlock,
            'expires_at'       => $expiresAt,
            'source'           => 'mock',
        ];
    }

    /**
     * Return a mock sell quote for given token amount (raw units).
     *
     * Sell tax rate is 4% or 10% — contract determines which tier applies.
     * This mock uses 4% as default. Real implementation calls previewSell.
     */
    public function getSellQuote(string $amountTokenRaw, string $walletAddress): array
    {
        if (!ChainAmount::isValidWei($amountTokenRaw)) {
            throw new \InvalidArgumentException('amount_token_raw must be a positive integer string.');
        }

        $rate           = '21630000000';
        $grossBnb       = bcdiv(bcmul($amountTokenRaw, $rate), '10000000000000000000000', 0);
        $taxRate         = '4%';
        $taxTokens       = ChainAmount::applyTax($amountTokenRaw, 4);
        $taxDest         = '4%→SupportPool';
        $netBnb          = $grossBnb; // simplified mock
        $minReceive      = bcdiv(bcmul($netBnb, '99'), '100', 0);
        $quoteBlock      = self::MOCK_BLOCK;
        $expiresAt       = now()->addSeconds(self::QUOTE_EXPIRY_SECONDS)->toIso8601String();

        return [
            'amount_in_raw'    => $amountTokenRaw,
            'gross_bnb_wei'    => $grossBnb,
            'tax_rate'         => $taxRate,
            'tax_tokens_raw'   => $taxTokens,
            'tax_destination'  => $taxDest,
            'net_bnb_wei'      => $netBnb,
            'min_receive_wei'  => $minReceive,
            'quote_block'      => $quoteBlock,
            'expires_at'       => $expiresAt,
            'source'           => 'mock',
        ];
    }

    /**
     * Return mock transaction history for a wallet.
     */
    public function getTransactions(string $address, int $page = 1, int $perPage = 20): array
    {
        $page = max(1, $page);
        $perPage = min(max(1, $perPage), 100);

        $allTxs = $this->mockTransactions($address);
        $total = count($allTxs);
        $offset = ($page - 1) * $perPage;
        $items = array_slice($allTxs, $offset, $perPage);

        return [
            'items'          => $items,
            'current_page'   => $page,
            'per_page'       => $perPage,
            'total'          => $total,
            'last_page'      => (int) ceil($total / max($perPage, 1)),
        ];
    }

    /**
     * Generate mock transaction records.
     */
    private function mockTransactions(string $address): array
    {
        return [
            [
                'tx_hash'      => '0x' . str_repeat('a', 64),
                'block_number' => '42815125',
                'type'         => 'buy',
                'amount_in'    => '100000000000000000',
                'amount_out'   => '44385600000000000000000',
                'status'       => 'confirmed',
                'timestamp'    => now()->subMinutes(5)->toIso8601String(),
            ],
            [
                'tx_hash'      => '0x' . str_repeat('b', 64),
                'block_number' => '42815110',
                'type'         => 'sell',
                'amount_in'    => '10000000000000000000000',
                'amount_out'   => '21400000000000000',
                'status'       => 'confirmed',
                'timestamp'    => now()->subHours(2)->toIso8601String(),
            ],
            [
                'tx_hash'      => '0x' . str_repeat('c', 64),
                'block_number' => '42810000',
                'type'         => 'buy',
                'amount_in'    => '1500000000000000000',
                'amount_out'   => '665784000000000000000000',
                'status'       => 'confirmed',
                'timestamp'    => now()->subHours(6)->toIso8601String(),
            ],
        ];
    }
}
