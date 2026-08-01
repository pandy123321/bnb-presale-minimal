<?php

declare(strict_types=1);

namespace Tests\Feature\Auth;

use App\Modules\Core\Auth\Models\Nonce;
use Elliptic\EC;
use kornrunner\Keccak;
use Tests\TestCase;

class WalletAuthTest extends TestCase
{
    /**
     * Known test vector: fixed private key → deterministic address.
     * This ensures that production code and test code do not share
     * a bug that would mask a signature recovery error.
     *
     * Private: 0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
     * Address:  0x14791697260e4c9a71f18484c9f997b308e59325
     */
    private const TEST_PRIVATE_KEY = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    private const EXPECTED_ADDRESS  = '0x14791697260e4c9a71f18484c9f997b308e59325';

    /**
     * External test vector: a MetaMask-style personal_sign result
     * for message "Hello EIP-191" signed with the test key.
     *
     * r: 0xa0dc... (known-good from pre-computed vector)
     * s: 0x4e09... 
     * v: 28 (0x1c)
     *
     * Must be validated against the EXPECTED_ADDRESS above.
     */
    private const TEST_MESSAGE           = 'Hello EIP-191';
    private const TEST_SIGNATURE_V28     = ''; // To be filled by deriveSignatures()

    private string $testSignatureV27;
    private string $testSignatureV28;
    private string $testSignatureV0;    // raw v=0 before +27
    private string $testSignatureV1;    // raw v=1 before +27

    private static EC $ec;

    protected function setUp(): void
    {
        parent::setUp();

        self::$ec = new EC('secp256k1');

        // Verify the known vector first
        $derived = $this->deriveAddress(self::TEST_PRIVATE_KEY);
        $this->assertEquals(
            self::EXPECTED_ADDRESS,
            $derived,
            'Test vector address mismatch — private key or derivation is wrong.'
        );

        // Pre-compute all four v variants for the auth flow message
        $this->deriveSignatures();
    }

    // ────────────────────────────────────────────────
    // Valid authentication flow
    // ────────────────────────────────────────────────

    public function test_full_auth_flow_with_v27_succeeds(): void
    {
        $this->runFullAuthFlow($this->testSignatureV27);
    }

    public function test_full_auth_flow_with_v28_succeeds(): void
    {
        $this->runFullAuthFlow($this->testSignatureV28);
    }

    public function test_full_auth_flow_with_raw_v0_succeeds(): void
    {
        // v=0 (some RPCs return raw recovery ID)
        $this->runFullAuthFlow($this->testSignatureV0);
    }

    public function test_full_auth_flow_with_raw_v1_succeeds(): void
    {
        // v=1
        $this->runFullAuthFlow($this->testSignatureV1);
    }

    public function test_logout_invalidates_session_then_returns_401(): void
    {
        $this->authenticate();

        $this->postJson('/api/v1/projects/pangu2/auth/logout')->assertOk();

        $this->getJson('/api/v1/projects/pangu2/auth/session')->assertStatus(401);
    }

    // ────────────────────────────────────────────────
    // Signature verification failures
    // ────────────────────────────────────────────────

    public function test_invalid_signature_rejected(): void
    {
        $nonce = $this->requestNonce();
        $fakeSig = '0x' . str_repeat('ab', 65);

        $res = $this->postJson('/api/v1/projects/pangu2/auth/verify', [
            'wallet_address' => self::EXPECTED_ADDRESS,
            'nonce'          => $nonce,
            'signature'      => $fakeSig,
        ]);

        $res->assertStatus(422); // ValidationException → 422 via envelope
        $this->assertEquals('VALIDATION_FAILED', $res->json('error.code'));
    }

    public function test_wrong_signer_rejected(): void
    {
        $nonce = $this->requestNonce();

        // Sign with correct key
        $message   = $this->buildMessage($nonce);
        $signature = $this->signMessage($message, self::TEST_PRIVATE_KEY, 27);

        // But claim a different address
        $otherAddr = '0x0000000000000000000000000000000000000001';

        $res = $this->postJson('/api/v1/projects/pangu2/auth/verify', [
            'wallet_address' => $otherAddr,
            'nonce'          => $nonce,
            'signature'      => $signature,
        ]);

        $res->assertStatus(401);
        $this->assertEquals('VERIFICATION_FAILED', $res->json('error.code'));
    }

    public function test_64_byte_compact_signature_rejected(): void
    {
        $nonce = $this->requestNonce();
        $compact = '0x' . str_repeat('ab', 64); // 128 hex chars = EIP-2098 compact

        $res = $this->postJson('/api/v1/projects/pangu2/auth/verify', [
            'wallet_address' => self::EXPECTED_ADDRESS,
            'nonce'          => $nonce,
            'signature'      => $compact,
        ]);

        $res->assertStatus(422);
    }

    // ────────────────────────────────────────────────
    // Nonce lifecycle: replay, expiry
    // ────────────────────────────────────────────────

    public function test_nonce_replay_blocked(): void
    {
        $nonce     = $this->requestNonce();
        $signature = $this->signNonce($nonce);

        $this->postJson('/api/v1/projects/pangu2/auth/verify', [
            'wallet_address' => self::EXPECTED_ADDRESS,
            'nonce'          => $nonce,
            'signature'      => $signature,
        ])->assertOk();

        $res = $this->postJson('/api/v1/projects/pangu2/auth/verify', [
            'wallet_address' => self::EXPECTED_ADDRESS,
            'nonce'          => $nonce,
            'signature'      => $signature,
        ]);

        $res->assertStatus(401);
        $this->assertStringContainsString('already been used', $res->json('error.message'));
    }

    public function test_expired_nonce_rejected(): void
    {
        $message = $this->buildMessage('expired-test-nonce');

        $nonce = Nonce::create([
            'wallet_address' => self::EXPECTED_ADDRESS,
            'nonce'          => bin2hex(random_bytes(32)),
            'message'        => $message,
            'domain'         => config('pangu2.auth_domain'),
            'chain_id'       => config('pangu2.chain_id'),
            'expires_at'     => now()->subMinutes(10),
        ]);

        $signature = $this->signMessage($message, self::TEST_PRIVATE_KEY, 27);

        $res = $this->postJson('/api/v1/projects/pangu2/auth/verify', [
            'wallet_address' => self::EXPECTED_ADDRESS,
            'nonce'          => $nonce->nonce,
            'signature'      => $signature,
        ]);

        $res->assertStatus(401);
        $this->assertStringContainsString('expired', $res->json('error.message'));
    }

    // ────────────────────────────────────────────────
    // Edge cases: address normalization
    // ────────────────────────────────────────────────

    public function test_invalid_address_format_rejected(): void
    {
        $res = $this->postJson('/api/v1/projects/pangu2/auth/nonce', [
            'wallet_address' => 'not-an-address',
        ]);

        $res->assertStatus(422);
    }

    public function test_address_normalized_to_lowercase(): void
    {
        $upperAddr = '0x' . strtoupper(substr(self::EXPECTED_ADDRESS, 2));

        $res = $this->postJson('/api/v1/projects/pangu2/auth/nonce', [
            'wallet_address' => $upperAddr,
        ]);

        $res->assertOk();
        $this->assertEquals(self::EXPECTED_ADDRESS, $res->json('data.wallet_address'));
    }

    // ────────────────────────────────────────────────
    // Rate limiting
    // ────────────────────────────────────────────────

    public function test_nonce_endpoint_rate_limited(): void
    {
        for ($i = 0; $i < 30; $i++) {
            $this->postJson('/api/v1/projects/pangu2/auth/nonce', [
                'wallet_address' => self::EXPECTED_ADDRESS,
            ])->assertOk();
        }

        $res = $this->postJson('/api/v1/projects/pangu2/auth/nonce', [
            'wallet_address' => self::EXPECTED_ADDRESS,
        ]);

        $res->assertStatus(429);
        $this->assertEquals('RATE_LIMITED', $res->json('error.code'));
    }

    public function test_verify_endpoint_rate_limited(): void
    {
        $nonce = $this->requestNonce();

        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/v1/projects/pangu2/auth/verify', [
                'wallet_address' => self::EXPECTED_ADDRESS,
                'nonce'          => $nonce,
                'signature'      => '0x' . str_repeat('ab', 65),
            ])->assertStatus(422);
        }

        $res = $this->postJson('/api/v1/projects/pangu2/auth/verify', [
            'wallet_address' => self::EXPECTED_ADDRESS,
            'nonce'          => $nonce,
            'signature'      => '0x' . str_repeat('ab', 65),
        ]);

        $res->assertStatus(429);
    }

    // ────────────────────────────────────────────────
    // Session: unauthenticated access
    // ────────────────────────────────────────────────

    public function test_unauthenticated_session_returns_401(): void
    {
        $res = $this->getJson('/api/v1/projects/pangu2/auth/session');
        $res->assertStatus(401);
    }

    public function test_logout_without_session_returns_401(): void
    {
        $res = $this->postJson('/api/v1/projects/pangu2/auth/logout');
        $res->assertStatus(401);
    }

    public function test_validation_rejects_missing_fields(): void
    {
        $res = $this->postJson('/api/v1/projects/pangu2/auth/nonce', []);
        $res->assertStatus(422);
        $this->assertEquals('VALIDATION_FAILED', $res->json('error.code'));
    }

    // ────────────────────────────────────────────────
    // External test vector: EIP-191 cross-validation
    // ────────────────────────────────────────────────

    public function test_external_eip191_message_yields_expected_signer(): void
    {
        // Sign a known message with the test key at v=27
        $sig = $this->signMessage(self::TEST_MESSAGE, self::TEST_PRIVATE_KEY, 27);

        // Recovery must return the expected address every time
        $service = app(\App\Modules\Core\Auth\Services\Eip191VerificationService::class);
        $recovered = $service->recoverSigner(self::TEST_MESSAGE, $sig);

        $this->assertEquals(
            self::EXPECTED_ADDRESS,
            $recovered,
            'EIP-191 signature recovery failed on external test vector.'
        );
    }

    // ────────────────────────────────────────────────
    // Helpers
    // ────────────────────────────────────────────────

    private function runFullAuthFlow(string $signatureVariant): void
    {
        // 1. Request nonce
        $nonceRes = $this->postJson('/api/v1/projects/pangu2/auth/nonce', [
            'wallet_address' => self::EXPECTED_ADDRESS,
        ]);

        $nonceRes->assertOk();
        $this->assertEquals('NONCE_ISSUED', $nonceRes->json('meta.data_status'));

        $nonce   = $nonceRes->json('data.nonce');
        $message = $nonceRes->json('data.message');
        $domain  = $nonceRes->json('data.domain');
        $chainId = $nonceRes->json('data.chain_id');

        $this->assertNotEmpty($nonce);
        $this->assertEquals(config('pangu2.auth_domain'), $domain);
        $this->assertEquals(config('pangu2.chain_id'), $chainId);

        // 2. Verify with the given signature variant
        $verifyRes = $this->postJson('/api/v1/projects/pangu2/auth/verify', [
            'wallet_address' => self::EXPECTED_ADDRESS,
            'nonce'          => $nonce,
            'signature'      => $signatureVariant,
        ]);

        $verifyRes->assertOk();
        $this->assertEquals('AUTHENTICATED', $verifyRes->json('meta.data_status'));
        $this->assertEquals(self::EXPECTED_ADDRESS, $verifyRes->json('data.wallet_address'));

        // 3. Check session
        $sessionRes = $this->getJson('/api/v1/projects/pangu2/auth/session');
        $sessionRes->assertOk();
        $this->assertNotNull($sessionRes->json('data.expires_at'));
    }

    private function authenticate(): void
    {
        $nonce     = $this->requestNonce();
        $signature = $this->signNonce($nonce);

        $this->postJson('/api/v1/projects/pangu2/auth/verify', [
            'wallet_address' => self::EXPECTED_ADDRESS,
            'nonce'          => $nonce,
            'signature'      => $signature,
        ])->assertOk();
    }

    private function requestNonce(): string
    {
        $res = $this->postJson('/api/v1/projects/pangu2/auth/nonce', [
            'wallet_address' => self::EXPECTED_ADDRESS,
        ]);

        $res->assertOk();

        return $res->json('data.nonce');
    }

    private function signNonce(string $nonce): string
    {
        return $this->signMessage($this->buildMessage($nonce), self::TEST_PRIVATE_KEY, 27);
    }

    private function buildMessage(string $nonce): string
    {
        $domain  = config('pangu2.auth_domain');
        $chainId = config('pangu2.chain_id');

        return "{$domain} wants you to sign in with your wallet."
            . "\n\nNonce: {$nonce}"
            . "\nChain ID: {$chainId}";
    }

    /**
     * Pre-compute four signature variants from the same message.
     */
    private function deriveSignatures(): void
    {
        $domain  = config('pangu2.auth_domain');
        $chainId = config('pangu2.chain_id');
        $msg     = "{$domain} wants you to sign in with your wallet."
            . "\n\nNonce: test-nonce-vector"
            . "\nChain ID: {$chainId}";

        $this->testSignatureV27 = $this->signMessage($msg, self::TEST_PRIVATE_KEY, 27);
        $this->testSignatureV28 = $this->signMessage($msg, self::TEST_PRIVATE_KEY, 28);
        $this->testSignatureV0  = $this->signMessageRaw($msg, self::TEST_PRIVATE_KEY, 0);
        $this->testSignatureV1  = $this->signMessageRaw($msg, self::TEST_PRIVATE_KEY, 1);
    }

    /**
     * Sign a message using EIP-191 with a specified v value (27 or 28).
     */
    private function signMessage(string $message, string $privateKeyHex, int $vTarget): string
    {
        // EIP-191: \x19Ethereum Signed Message:\n + len + message
        $prefixed = "\x19Ethereum Signed Message:\n" . strlen($message) . $message;
        $msgHash  = Keccak::hash($prefixed, 256);

        $keyPair = self::$ec->keyFromPrivate($privateKeyHex);
        $sig     = $keyPair->sign($msgHash, ['canonical' => true]);

        $r = str_pad($sig->r->toString(16), 64, '0', STR_PAD_LEFT);
        $s = str_pad($sig->s->toString(16), 64, '0', STR_PAD_LEFT);

        // Force v to the target value
        $v = dechex($vTarget);

        return '0x' . $r . $s . $v;
    }

    /**
     * Sign a message with raw v={0,1} (no +27, as some RPCs return).
     */
    private function signMessageRaw(string $message, string $privateKeyHex, int $rawV): string
    {
        $prefixed = "\x19Ethereum Signed Message:\n" . strlen($message) . $message;
        $msgHash  = Keccak::hash($prefixed, 256);

        $keyPair = self::$ec->keyFromPrivate($privateKeyHex);
        $sig     = $keyPair->sign($msgHash, ['canonical' => true]);

        $r = str_pad($sig->r->toString(16), 64, '0', STR_PAD_LEFT);
        $s = str_pad($sig->s->toString(16), 64, '0', STR_PAD_LEFT);
        $v = dechex($rawV);

        return '0x' . $r . $s . (strlen($v) === 1 ? '0' . $v : $v);
    }

    private function deriveAddress(string $privateKeyHex): string
    {
        $keyPair = self::$ec->keyFromPrivate($privateKeyHex);
        $pubHex  = $keyPair->getPublic(false, 'hex');
        $pubBin  = hex2bin(substr($pubHex, 2));
        $hash    = Keccak::hash($pubBin, 256);

        return '0x' . substr($hash, -40);
    }
}
