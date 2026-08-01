<?php

declare(strict_types=1);

namespace App\Modules\Core\Chain;

/**
 * Chain amount utilities.
 *
 * All blockchain asset arithmetic MUST use BCMath through this class.
 * Using PHP float for BNB or token amounts is FORBIDDEN.
 */
final class ChainAmount
{
    private function __construct() {}

    /**
     * Convert BNB in ether to wei integer string.
     * e.g. "0.01" → "10000000000000000"
     */
    public static function bnbToWei(string $bnb): string
    {
        return bcmul($bnb, '1000000000000000000', 0);
    }

    /**
     * Convert wei integer string to BNB formatted string.
     * e.g. "10000000000000000" → "0.010000000000000000"
     */
    public static function weiToBnb(string $wei, int $decimals = 18): string
    {
        if ($wei === '0') {
            return '0';
        }
        $padded = str_pad($wei, $decimals + 1, '0', STR_PAD_LEFT);
        $intPart = substr($padded, 0, -$decimals);
        $fracPart = substr($padded, -$decimals);
        $intPart = $intPart === '' ? '0' : ltrim($intPart, '0') ?: '0';
        return $intPart . '.' . $fracPart;
    }

    /**
     * Convert raw token units to formatted string.
     * e.g. "126840000000000000000000" with decimals 18 → "126840.000000000000000000"
     */
    public static function rawToFormatted(string $raw, int $decimals = 18): string
    {
        return self::weiToBnb($raw, $decimals);
    }

    /**
     * Validate that a string is a positive integer (no decimals, no negatives).
     */
    public static function isValidWei(string $value): bool
    {
        return ctype_digit($value) && $value !== '' && bccomp($value, '0') > 0;
    }

    /**
     * Apply a percentage tax and return truncated integer.
     * taxPercent: 4 → 4%
     */
    public static function applyTax(string $amount, int $taxPercent): string
    {
        $tax = bcdiv(bcmul($amount, (string) $taxPercent), '100', 0);
        return $tax;
    }

    /**
     * Return amount minus tax.
     */
    public static function afterTax(string $amount, int $taxPercent): string
    {
        return bcsub($amount, self::applyTax($amount, $taxPercent), 0);
    }
}
