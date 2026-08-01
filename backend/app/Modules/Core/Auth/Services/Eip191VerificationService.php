<?php

declare(strict_types=1);

namespace App\Modules\Core\Auth\Services;

use App\Modules\Core\Auth\Models\Nonce;
use Elliptic\EC;
use kornrunner\Keccak;
use RuntimeException;

final class Eip191VerificationService
{
    private const EIP191_PREFIX = "\x19Ethereum Signed Message:\n";

    public function generateNonce(string $walletAddress, string $domain, int $chainId): Nonce
    {
        $nonce  = bin2hex(random_bytes(32));
        $ttlMin = (int) config('pangu2.nonce_ttl_minutes', 5);
        $msg    = $this->buildMessage($nonce, $domain, $chainId);

        return Nonce::create([
            'wallet_address' => $walletAddress,
            'nonce'          => $nonce,
            'message'        => $msg,
            'domain'         => $domain,
            'chain_id'       => $chainId,
            'expires_at'     => now()->addMinutes($ttlMin),
        ]);
    }

    /**
     * Look up and validate the nonce record. Does NOT consume it, does NOT do crypto.
     * Call this OUTSIDE a DB transaction.
     */
    public function validateNonceRecord(
        string $walletLower,
        string $nonceHex,
        string $expectedDomain,
        int $expectedChainId,
    ): Nonce {
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
            throw new RuntimeException('Domain mismatch.');
        }
        if ($record->chain_id !== $expectedChainId) {
            throw new RuntimeException('Chain ID mismatch.');
        }

        return $record;
    }

    /**
     * Atomically consume a nonce. Returns true if THIS call consumed it.
     * Must be called INSIDE the same DB transaction as the audit insert.
     */
    public function consumeNonceAtomic(int $nonceId): bool
    {
        $consumed = Nonce::whereKey($nonceId)
            ->whereNull('used_at')
            ->where('expires_at', '>', now())
            ->update(['used_at' => now()]);

        return $consumed === 1;
    }

    // ── Crypto ──────────────────────────────────────────

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

        $len = strlen($hex);

        if ($len === 128) {
            throw new RuntimeException('EIP-2098 compact signatures are not supported. Use standard 65-byte format.');
        }
        if ($len !== 130) {
            throw new RuntimeException("Invalid signature length: expected 130 hex chars (65 bytes), got {$len}.");
        }
    }

    public function recoverSigner(string $message, string $signature): string
    {
        $msgHash = $this->eip191Hash($message);
        $sig     = $this->parseSignature($signature);

        $ec = new EC('secp256k1');
        $v  = $sig['v'];
        if ($v >= 27) {
            $v -= 27;
        }
        if ($v !== 0 && $v !== 1) {
            throw new RuntimeException('Invalid v: must be 0, 1, 27, or 28.');
        }

        $pubKey = $ec->recoverPubKey($msgHash, ['r' => $sig['r'], 's' => $sig['s']], $v);

        return $this->pubKeyToAddress($pubKey->encode('hex'));
    }

    public function eip191Hash(string $message): string
    {
        return Keccak::hash(self::EIP191_PREFIX . strlen($message) . $message, 256);
    }

    public function pubKeyToAddress(string $pubKeyHex): string
    {
        $bin = hex2bin(substr($pubKeyHex, 2));
        if ($bin === false || strlen($bin) !== 64) {
            throw new RuntimeException('Invalid public key encoding.');
        }
        return '0x' . substr(Keccak::hash($bin, 256), -40);
    }

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

    public function buildMessage(string $nonce, string $domain, int $chainId): string
    {
        return "{$domain} wants you to sign in with your wallet."
            . "\n\nNonce: {$nonce}"
            . "\nChain ID: {$chainId}";
    }

    private function parseSignature(string $signature): array
    {
        $hex = str_starts_with($signature, '0x') ? substr($signature, 2) : $signature;
        $hex = strtolower($hex);

        if (strlen($hex) !== 130) {
            throw new RuntimeException('Expected 130 hex chars (65 bytes: r+s+v).');
        }

        $r = substr($hex, 0, 64);
        $s = substr($hex, 64, 64);
        $v = hexdec(substr($hex, 128, 2));

        if (hexdec($r) === 0 || hexdec($s) === 0) {
            throw new RuntimeException('Invalid signature: r or s is zero.');
        }

        return ['r' => $r, 's' => $s, 'v' => $v];
    }
}
