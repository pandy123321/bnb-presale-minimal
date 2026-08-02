<?php

declare(strict_types=1);

namespace App\Modules\Core\Auth;

use App\Models\WalletNonce;
use Carbon\Carbon;
use Illuminate\Support\Str;
use kornrunner\Keccak;

/**
 * Wallet authentication using EIP-191 signed messages.
 *
 * - Issues one-time nonces bound to domain + chain_id.
 * - Verifies EVM EIP-191 (personal_sign) signatures.
 * - No private key is ever handled or stored.
 */
final class WalletAuthService
{
    private int $nonceTtlSeconds = 300;
    private int $sessionTtlHours = 24;

    public function __construct(
        private readonly string $appDomain,
        private readonly int $chainId,
    ) {}

    /**
     * Generate a one-time nonce for a wallet address.
     */
    public function issueNonce(string $walletAddress): array
    {
        $walletAddress = $this->normalizeAddress($walletAddress);
        $nonce = 'p2-' . Str::random(48);
        $message = $this->buildMessage($walletAddress, $nonce);

        WalletNonce::create([
            'wallet_address' => $walletAddress,
            'nonce' => $nonce,
            'message' => $message,
            'domain' => $this->appDomain,
            'chain_id' => $this->chainId,
            'expires_at' => Carbon::now()->addSeconds($this->nonceTtlSeconds),
        ]);

        return [
            'nonce' => $nonce,
            'message' => $message,
            'expires_at' => Carbon::now()->addSeconds($this->nonceTtlSeconds)->toIso8601String(),
        ];
    }

    /**
     * Verify a signed nonce and create a session.
     */
    public function verifySignature(string $walletAddress, string $signature): ?array
    {
        $walletAddress = $this->normalizeAddress($walletAddress);

        $nonceRecord = WalletNonce::where('wallet_address', $walletAddress)
            ->whereNull('used_at')
            ->where('expires_at', '>', Carbon::now())
            ->orderByDesc('created_at')
            ->first();

        if (! $nonceRecord) {
            return null;
        }

        // Verify EIP-191 signature
        $recoveredAddress = $this->eip191Recover($nonceRecord->message, $signature);

        if (mb_strtolower($recoveredAddress) !== $walletAddress) {
            return null;
        }

        // Mark nonce as used (replay protection)
        $nonceRecord->update(['used_at' => Carbon::now()]);

        // Kill other nonces for this wallet (optional cleanup)
        WalletNonce::where('wallet_address', $walletAddress)
            ->whereNull('used_at')
            ->update(['used_at' => Carbon::now()]);

        return $this->createSession($walletAddress);
    }

    /**
     * Destroy a session by token.
     */
    public function revokeSession(string $token): void
    {
        WalletSession::where('token', $token)->delete();
    }

    /**
     * Normalize EVM address to lowercase.
     */
    public function normalizeAddress(string $address): string
    {
        return mb_strtolower(trim($address));
    }

    private function buildMessage(string $walletAddress, string $nonce): string
    {
        return implode("\n", [
            'PANGU2 Wallet Authentication',
            '',
            "Wallet: {$walletAddress}",
            "Nonce: {$nonce}",
            "Domain: {$this->appDomain}",
            "Chain ID: {$this->chainId}",
            "Expires: {$this->nonceTtlSeconds} seconds",
        ]);
    }

    private function createSession(string $walletAddress): array
    {
        $token = 'p2s-' . Str::random(64);

        WalletSession::create([
            'wallet_address' => $walletAddress,
            'token' => $token,
            'expires_at' => Carbon::now()->addHours($this->sessionTtlHours),
            'last_activity_at' => Carbon::now(),
        ]);

        return [
            'token' => $token,
            'wallet_address' => $walletAddress,
            'expires_at' => Carbon::now()->addHours($this->sessionTtlHours)->toIso8601String(),
        ];
    }

    /**
     * Recover address from EIP-191 personal_sign signature.
     *
     * Uses pure PHP secp256k1 operations (via kornrunner/keccak).
     * This avoids a hard dependency on a full web3 library.
     */
    private function eip191Recover(string $message, string $signature): string
    {
        $sig = $this->decodeSignature($signature);
        $v = $sig['v'];
        $r = $sig['r'];
        $s = $sig['s'];

        $messageHash = $this->eip191Hash($message);

        $publicKey = $this->recoverPublicKey($messageHash, $r, $s, $v);
        if ($publicKey === null) {
            return '';
        }

        return $this->publicKeyToAddress($publicKey);
    }

    private function eip191Hash(string $message): string
    {
        $prefix = "\x19Ethereum Signed Message:\n" . strlen($message);
        $prefixed = $prefix . $message;
        return Keccak::hash($prefixed, 256);
    }

    private function decodeSignature(string $signature): array
    {
        $sig = $signature;
        if (str_starts_with($sig, '0x')) {
            $sig = substr($sig, 2);
        }

        $r = substr($sig, 0, 64);
        $s = substr($sig, 64, 64);
        $v = hexdec(substr($sig, 128, 2));

        // EIP-155 replay protection adjustment
        if ($v >= 35) {
            $v = $v % 2 === 0 ? 28 : 27;
        }

        return ['r' => $r, 's' => $s, 'v' => $v];
    }

    private function recoverPublicKey(string $hashHex, string $rHex, string $sHex, int $v): ?string
    {
        $hash = hex2bin($hashHex);
        $r = hex2bin(str_pad($rHex, 64, '0', STR_PAD_LEFT));
        $s = hex2bin(str_pad($sHex, 64, '0', STR_PAD_LEFT));
        $recoveryId = $v - 27;

        if (! function_exists('secp256k1_ecdsa_recover')) {
            // Fallback: return a deterministic test address for environments
            // without the secp256k1 PHP extension installed.
            // Real verification requires the extension or a compatible library.
            // For initial skeleton, this allows running the nonce flow
            // while documenting the deployment dependency.

            // Simulate recovery identity: a real deployment MUST install
            // ext-secp256k1 and remove this block.
            return null;
        }

        $context = secp256k1_context_create(SECP256K1_CONTEXT_VERIFY);
        /** @var resource $signature */
        $secp256k1Sig = null;
        secp256k1_ecdsa_recoverable_signature_parse_compact($context, $secp256k1Sig, $r . $s, $recoveryId);

        /** @var resource $publicKey */
        $publicKey = null;
        secp256k1_ecdsa_recover($context, $publicKey, $secp256k1Sig, $hash);

        $publicKeyBin = '';
        secp256k1_ec_pubkey_serialize($context, $publicKeyBin, $publicKey, SECP256K1_EC_UNCOMPRESSED);

        return bin2hex($publicKeyBin);
    }

    private function publicKeyToAddress(string $publicKeyHex): string
    {
        // Remove 04 prefix (uncompressed point indicator)
        $pubKey = hex2bin(substr($publicKeyHex, 2));
        $hash = Keccak::hash($pubKey, 256);
        return '0x' . substr($hash, -40);
    }
}
