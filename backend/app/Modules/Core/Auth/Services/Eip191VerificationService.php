<?php

declare(strict_types=1);

namespace App\Modules\Core\Auth\Services;

use App\Modules\Core\Auth\Models\Nonce;
use Elliptic\EC;
use kornrunner\Keccak;
use RuntimeException;

/**
 * EIP-191 signature verification and nonce management.
 *
 * This service NEVER holds or exposes private keys.
 * It only recovers a public key from a signature to verify
 * that the signer controls the claimed EVM address.
 */
final class Eip191VerificationService
{
    /**
     * EIP-191 prefix for Ethereum Signed Message.
     */
    private const EIP191_PREFIX = "\x19Ethereum Signed Message:\n";

    /**
     * Nonce expiry in minutes.
     */
    private const NONCE_TTL_MINUTES = 5;

    /**
     * Generate a fresh nonce and persist it.
     */
    public function generateNonce(
        string $walletAddress,
        string $domain,
        int $chainId,
    ): Nonce {
        $nonce = bin2hex(random_bytes(32));

        $message = $this->buildMessage($nonce, $domain, $chainId);

        return Nonce::create([
            'wallet_address' => $walletAddress,
            'nonce'          => $nonce,
            'message'        => $message,
            'domain'         => $domain,
            'chain_id'       => $chainId,
            'expires_at'     => now()->addMinutes(self::NONCE_TTL_MINUTES),
        ]);
    }

    /**
     * Verify an EIP-191 signature and consume the nonce.
     *
     * @throws RuntimeException When nonce is invalid, expired, already used, or signature mismatch.
     */
    public function verify(
        string $walletAddress,
        string $nonce,
        string $signature,
        string $domain,
        int $chainId,
    ): Nonce {
        $walletLower = $this->normalizeAddress($walletAddress);

        $record = Nonce::where('nonce', $nonce)
            ->where('wallet_address', $walletLower)
            ->first();

        if (!$record) {
            throw new RuntimeException('Nonce not found or does not belong to wallet.');
        }

        if ($record->isExpired()) {
            throw new RuntimeException('Nonce has expired. Request a new one.');
        }

        if ($record->isUsed()) {
            throw new RuntimeException('Nonce has already been used.');
        }

        // Re-prompt signature on domain mismatch
        if ($record->domain !== $domain) {
            throw new RuntimeException('Domain mismatch. Request a new nonce for this origin.');
        }

        // Re-prompt signature on chain ID mismatch
        if ($record->chain_id !== $chainId) {
            throw new RuntimeException('Chain ID mismatch. Request a new nonce for this chain.');
        }

        $recoveredAddress = $this->recoverSigner($record->message, $signature);

        if ($recoveredAddress !== $walletLower) {
            throw new RuntimeException('Signature verification failed.');
        }

        $record->markUsed();

        return $record;
    }

    /**
     * Build the EIP-191 message that the wallet will sign.
     *
     * Format: "{domain} wants you to sign in with your wallet.\n\nNonce: {nonce}\nChain ID: {chainId}"
     */
    public function buildMessage(string $nonce, string $domain, int $chainId): string
    {
        return "{$domain} wants you to sign in with your wallet."
            . "\n\nNonce: {$nonce}"
            . "\nChain ID: {$chainId}";
    }

    /**
     * Compute the EIP-191 hash (what the wallet actually signs).
     *
     * EIP-191: keccak256("\x19Ethereum Signed Message:\n" + len(message) + message)
     */
    public function eip191Hash(string $message): string
    {
        $prefixed = self::EIP191_PREFIX . strlen($message) . $message;

        return Keccak::hash($prefixed, 256);
    }

    /**
     * Recover the EVM address (lowercase) from an EIP-191 signature.
     *
     * @param string $message   The raw message that was displayed to the user.
     * @param string $signature Hex-encoded 65-byte signature (0x... or raw hex).
     */
    public function recoverSigner(string $message, string $signature): string
    {
        $msgHash = $this->eip191Hash($message);

        $sig = $this->normalizeSignature($signature);

        $ec = new EC('secp256k1');

        $recoveryParam = $sig['v'] - 27;
        if ($recoveryParam < 0 || $recoveryParam > 3) {
            // Some wallets use v = 27/28, which maps to recoveryParam 0/1 after -27.
            // v >= 27 indicates the old Ethereum signature scheme.
            throw new RuntimeException('Invalid signature recovery parameter.');
        }

        $pubKey = $ec->recoverPubKey(
            $msgHash,
            ['r' => $sig['r'], 's' => $sig['s']],
            $recoveryParam,
        );

        return $this->pubKeyToAddress($pubKey->encode('hex'));
    }

    /**
     * Convert an uncompressed public key hex (04xxxx...yyyy) to an EVM address.
     */
    public function pubKeyToAddress(string $pubKeyHex): string
    {
        // Remove "04" prefix, keep raw 64-byte x,y
        $pubKeyBin = hex2bin(substr($pubKeyHex, 2));
        if ($pubKeyBin === false || strlen($pubKeyBin) !== 64) {
            throw new RuntimeException('Invalid public key encoding.');
        }

        // keccak256(pubKey) → last 20 bytes = address
        $hash = Keccak::hash($pubKeyBin, 256);

        return '0x' . substr($hash, -40);
    }

    /**
     * Normalize an EVM address to lowercase 0x-prefixed 40-hex-char format.
     */
    public function normalizeAddress(string $address): string
    {
        $lower = strtolower(trim($address));

        if (!str_starts_with($lower, '0x')) {
            $lower = '0x' . $lower;
        }

        if (!preg_match('/^0x[0-9a-f]{40}$/', $lower)) {
            throw new RuntimeException('Invalid EVM address format.');
        }

        return $lower;
    }

    /**
     * Parse a hex signature into r, s, v components.
     *
     * Accepts: 0x-prefixed or raw hex, 130 or 132 hex chars (plus optional 0x).
     * Returns: ['r' => hex, 's' => hex, 'v' => int]
     */
    private function normalizeSignature(string $signature): array
    {
        $hex = str_starts_with($signature, '0x') ? substr($signature, 2) : $signature;
        $hex = strtolower($hex);

        $len = strlen($hex);

        if ($len === 130) {
            // v is implicit 0x1b (27)
            return [
                'r' => substr($hex, 0, 64),
                's' => substr($hex, 64, 64),
                'v' => 27,
            ];
        }

        if ($len === 132) {
            return [
                'r' => substr($hex, 0, 64),
                's' => substr($hex, 64, 64),
                'v' => hexdec(substr($hex, 128, 2)),
            ];
        }

        throw new RuntimeException('Invalid signature length: expected 130 or 132 hex chars.');
    }
}
