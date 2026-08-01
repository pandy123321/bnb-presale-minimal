<?php

declare(strict_types=1);

namespace App\Modules\Core\Auth\Services;

use App\Modules\Core\Auth\Models\Nonce;
use Elliptic\EC;
use kornrunner\Keccak;
use RuntimeException;

class AuthenticationException extends RuntimeException {}
class NonceAlreadyUsedException extends AuthenticationException {}
class NonceExpiredException extends AuthenticationException {}
class NonceNotFoundException extends AuthenticationException {}
class InvalidSignatureException extends AuthenticationException {}

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
            throw new NonceNotFoundException('Nonce not found or does not belong to wallet.');
        }
        if ($record->isExpired()) {
            throw new NonceExpiredException('Nonce has expired. Request a new one.');
        }
        if ($record->isUsed()) {
            throw new NonceAlreadyUsedException('Nonce has already been used.');
        }
        if ($record->domain !== $expectedDomain) {
            throw new AuthenticationException('Domain mismatch.');
        }
        if ($record->chain_id !== $expectedChainId) {
            throw new AuthenticationException('Chain ID mismatch.');
        }

        return $record;
    }

    public function consumeNonceAtomic(int $nonceId): string // returns 'consumed' | 'expired' | 'already_used'
    {
        $consumed = Nonce::whereKey($nonceId)
            ->whereNull('used_at')
            ->where('expires_at', '>', now())
            ->update(['used_at' => now()]);

        if ($consumed === 1) {
            return 'consumed';
        }

        $record = Nonce::find($nonceId);
        if ($record && $record->isExpired()) {
            return 'expired';
        }

        return 'already_used';
    }

    public function validateSignatureFormat(string $signature): void
    {
        $hex = str_starts_with($signature, '0x') ? substr($signature, 2) : $signature;
        $hex = strtolower($hex);

        if ($hex === '') {
            throw new InvalidSignatureException('Empty signature.');
        }
        if (!ctype_xdigit($hex)) {
            throw new InvalidSignatureException('Signature contains non-hexadecimal characters.');
        }

        $len = strlen($hex);

        if ($len === 128) {
            throw new InvalidSignatureException('EIP-2098 compact signatures are not supported.');
        }
        if ($len !== 130) {
            throw new InvalidSignatureException("Invalid signature length: expected 130 hex chars (65 bytes).");
        }
    }

    /**
     * Recover signer. All exceptions are wrapped as AuthenticationException.
     */
    public function recoverSigner(string $message, string $signature): string
    {
        try {
            $msgHash = $this->eip191Hash($message);
            $sig     = $this->parseSignature($signature);

            $ec = new EC('secp256k1');
            $v  = $sig['v'];
            if ($v >= 27) {
                $v -= 27;
            }
            if ($v !== 0 && $v !== 1) {
                throw new InvalidSignatureException('Invalid v: must be 0, 1, 27, or 28.');
            }

            $pubKey = $ec->recoverPubKey($msgHash, ['r' => $sig['r'], 's' => $sig['s']], $v);

            return $this->pubKeyToAddress($pubKey->encode('hex'));
        } catch (AuthenticationException) {
            throw;
        } catch (\Throwable $e) {
            throw new InvalidSignatureException('Signature verification failed.', 0, $e);
        }
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
            throw new InvalidSignatureException('Expected 130 hex chars (65 bytes: r+s+v).');
        }

        $r = substr($hex, 0, 64);
        $s = substr($hex, 64, 64);
        $v = hexdec(substr($hex, 128, 2));

        if (trim($r, '0') === '' || trim($s, '0') === '') {
            throw new InvalidSignatureException('Invalid signature: r or s is zero.');
        }

        return ['r' => $r, 's' => $s, 'v' => $v];
    }
}
