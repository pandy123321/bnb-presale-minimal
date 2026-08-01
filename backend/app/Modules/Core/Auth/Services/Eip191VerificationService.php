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
    private const EIP191_PREFIX = "\x19Ethereum Signed Message:\n";
    /**
     * Generate a fresh nonce and persist it.
     * TTL is read from pangu2.nonce_ttl_minutes config (default 5).
     */
    public function generateNonce(
        string $walletAddress,
        string $domain,
        int $chainId,
    ): Nonce {
        $nonce  = bin2hex(random_bytes(32));
        $ttlMin = (int) config('pangu2.nonce_ttl_minutes', 5);

        $message = $this->buildMessage($nonce, $domain, $chainId);

        return Nonce::create([
            'wallet_address' => $walletAddress,
            'nonce'          => $nonce,
            'message'        => $message,
            'domain'         => $domain,
            'chain_id'       => $chainId,
            'expires_at'     => now()->addMinutes($ttlMin),
        ]);
    }

    /**
     * Verify an EIP-191 signature and atomically consume the nonce.
     *
     * The nonce is consumed via a conditional UPDATE that checks used_at IS NULL
     * in a database transaction, preventing concurrent replay.
     *
     * @return Nonce|null  null if nonce was already consumed by a concurrent request.
     * @throws RuntimeException When nonce is expired, domain/chain mismatch, or signature invalid.
     */
    public function verify(
        string $walletAddress,
        string $nonceHex,
        string $signature,
        string $expectedDomain,
        int $expectedChainId,
    ): ?Nonce {
        $walletLower = $this->normalizeAddress($walletAddress);

        $record = Nonce::where('nonce', $nonceHex)
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

        if ($record->domain !== $expectedDomain) {
            throw new RuntimeException('Domain mismatch. Request a new nonce for this origin.');
        }

        if ($record->chain_id !== $expectedChainId) {
            throw new RuntimeException('Chain ID mismatch. Request a new nonce for this chain.');
        }

        $this->validateSignatureFormat($signature);

        $recoveredAddress = $this->recoverSigner($record->message, $signature);

        if ($recoveredAddress !== $walletLower) {
            throw new RuntimeException('Signature verification failed.');
        }

        // Atomic consumption: conditional UPDATE
        $consumed = Nonce::whereKey($record->id)
            ->whereNull('used_at')
            ->where('expires_at', '>', now())
            ->update(['used_at' => now()]);

        if ($consumed !== 1) {
            return null; // Concurrent request already consumed it
        }

        $record->refresh();

        return $record;
    }

    /**
     * Build the EIP-191 message that the wallet will sign.
     */
    public function buildMessage(string $nonce, string $domain, int $chainId): string
    {
        return "{$domain} wants you to sign in with your wallet."
            . "\n\nNonce: {$nonce}"
            . "\nChain ID: {$chainId}";
    }

    /**
     * Compute the EIP-191 keccak256 hash.
     */
    public function eip191Hash(string $message): string
    {
        $prefixed = self::EIP191_PREFIX . strlen($message) . $message;

        return Keccak::hash($prefixed, 256);
    }

    /**
     * Recover the EVM address from an EIP-191 signed message.
     */
    public function recoverSigner(string $message, string $signature): string
    {
        $msgHash = $this->eip191Hash($message);

        $sig = $this->normalizeSignature($signature);

        $ec = new EC('secp256k1');

        // v ∈ {0,1,27,28} → recoveryParam ∈ {0,1}
        $v = $sig['v'];
        if ($v >= 27) {
            $v -= 27;
        }
        if ($v !== 0 && $v !== 1) {
            throw new RuntimeException('Invalid signature recovery parameter: v must be 0, 1, 27, or 28.');
        }

        $pubKey = $ec->recoverPubKey(
            $msgHash,
            ['r' => $sig['r'], 's' => $sig['s']],
            $v,
        );

        return $this->pubKeyToAddress($pubKey->encode('hex'));
    }

    /**
     * Convert an uncompressed public key hex to an EVM address.
     */
    public function pubKeyToAddress(string $pubKeyHex): string
    {
        $pubKeyBin = hex2bin(substr($pubKeyHex, 2));
        if ($pubKeyBin === false || strlen($pubKeyBin) !== 64) {
            throw new RuntimeException('Invalid public key encoding.');
        }

        $hash = Keccak::hash($pubKeyBin, 256);

        return '0x' . substr($hash, -40);
    }

    /**
     * Normalize an EVM address to lowercase 0x-prefixed format.
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
     * Validate signature format before parsing, rejecting obviously invalid input.
     */
    public function validateSignatureFormat(string $signature): void
    {
        $hex = str_starts_with($signature, '0x') ? substr($signature, 2) : $signature;
        $hex = strtolower($hex);

        if ($hex === '') {
            throw new RuntimeException('Empty signature.');
        }

        if (!ctype_xdigit($hex)) {
            throw new RuntimeException('Signature contains non-hexadecimal characters.');
        }

        if (strlen($hex) > 132) {
            throw new RuntimeException('Signature too long.');
        }

        if (strlen($hex) < 130) {
            throw new RuntimeException('Signature too short: expected 130 hex chars (65 bytes).');
        }

        // 64-byte compact signature (EIP-2098) is explicitly not supported
        if (strlen($hex) === 128) {
            throw new RuntimeException('EIP-2098 compact signatures are not supported. Use standard 65-byte format.');
        }
    }

    /**
     * Parse a standard 65-byte ECDSA signature into r, s, v.
     *
     * Accepts 130 hex chars (65 bytes: r=32, s=32, v=1).
     * Also handles v in {0,1,27,28} format.
     */
    private function normalizeSignature(string $signature): array
    {
        $hex = str_starts_with($signature, '0x') ? substr($signature, 2) : $signature;
        $hex = strtolower($hex);

        $len = strlen($hex);

        if ($len !== 130) {
            throw new RuntimeException(
                "Invalid signature length: expected 130 hex chars (65 bytes), got {$len}."
            );
        }

        $rHex = substr($hex, 0, 64);
        $sHex = substr($hex, 64, 64);
        $v    = hexdec(substr($hex, 128, 2));

        // Validate r and s are not all zeros (invalid signature)
        if (hexdec($rHex) === 0 || hexdec($sHex) === 0) {
            throw new RuntimeException('Invalid signature: r or s is zero.');
        }

        return [
            'r' => $rHex,
            's' => $sHex,
            'v' => $v,
        ];
    }
}
