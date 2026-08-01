<?php

declare(strict_types=1);

namespace Tests\Feature\Auth;

use App\Modules\Core\Auth\Models\Nonce;
use Elliptic\EC;
use kornrunner\Keccak;
use Tests\TestCase;

class WalletAuthTest extends TestCase
{
    private const TEST_PRIVATE_KEY = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

    private const TEST_DOMAIN = 'app.example.com';
    private const TEST_CHAIN_ID = 1;

    private string $testAddress;

    private static EC $ec;

    protected function setUp(): void
    {
        parent::setUp();

        self::$ec = new EC('secp256k1');

        $this->testAddress = $this->deriveAddress(self::TEST_PRIVATE_KEY);
    }

    // -----------------------------------------------------------------
    // Valid authentication flow
    // -----------------------------------------------------------------

    public function test_full_auth_flow_succeeds(): void
    {
        // 1. Request nonce
        $nonceRes = $this->postJson('/api/v1/projects/pangu2/auth/nonce', [
            'wallet_address' => $this->testAddress,
            'domain'         => self::TEST_DOMAIN,
            'chain_id'       => self::TEST_CHAIN_ID,
        ]);

        $nonceRes->assertOk();
        $this->assertEquals('NONCE_ISSUED', $nonceRes->json('meta.data_status'));

        $nonce   = $nonceRes->json('data.nonce');
        $message = $nonceRes->json('data.message');

        $this->assertNotEmpty($nonce);
        $this->assertStringContainsString(self::TEST_DOMAIN, $message);

        // 2. Sign the message
        $signature = $this->signMessage($message, self::TEST_PRIVATE_KEY);

        // 3. Verify
        $verifyRes = $this->postJson('/api/v1/projects/pangu2/auth/verify', [
            'wallet_address' => $this->testAddress,
            'nonce'          => $nonce,
            'signature'      => $signature,
            'domain'         => self::TEST_DOMAIN,
            'chain_id'       => self::TEST_CHAIN_ID,
        ]);

        $verifyRes->assertOk();
        $this->assertEquals('AUTHENTICATED', $verifyRes->json('meta.data_status'));
        $this->assertEquals($this->testAddress, $verifyRes->json('data.wallet_address'));

        // 4. Access authenticated session endpoint
        $sessionRes = $this->getJson('/api/v1/projects/pangu2/auth/session');
        $sessionRes->assertOk();
        $this->assertEquals($this->testAddress, $sessionRes->json('data.wallet_address'));

        // 5. Logout
        $logoutRes = $this->postJson('/api/v1/projects/pangu2/auth/logout');
        $logoutRes->assertOk();

        // 6. Session should be dead after logout
        $afterLogout = $this->getJson('/api/v1/projects/pangu2/auth/session');
        $afterLogout->assertStatus(401);
    }

    // -----------------------------------------------------------------
    // Signature verification failures
    // -----------------------------------------------------------------

    public function test_invalid_signature_rejected(): void
    {
        $nonce = $this->requestNonce($this->testAddress);

        $fakeSig = '0x' . str_repeat('ab', 65);

        $res = $this->postJson('/api/v1/projects/pangu2/auth/verify', [
            'wallet_address' => $this->testAddress,
            'nonce'          => $nonce,
            'signature'      => $fakeSig,
            'domain'         => self::TEST_DOMAIN,
            'chain_id'       => self::TEST_CHAIN_ID,
        ]);

        $res->assertStatus(401);
        $this->assertEquals('VERIFICATION_FAILED', $res->json('error.code'));
    }

    public function test_wrong_signer_rejected(): void
    {
        $nonce   = $this->requestNonce($this->testAddress);
        $message = $this->buildMessage($nonce);

        // Sign with the correct key
        $signature = $this->signMessage($message, self::TEST_PRIVATE_KEY);

        // But claim a different address
        $otherKey    = 'ff' . substr(self::TEST_PRIVATE_KEY, 2);
        $otherAddr   = $this->deriveAddress($otherKey);

        $res = $this->postJson('/api/v1/projects/pangu2/auth/verify', [
            'wallet_address' => $otherAddr,
            'nonce'          => $nonce,
            'signature'      => $signature,
            'domain'         => self::TEST_DOMAIN,
            'chain_id'       => self::TEST_CHAIN_ID,
        ]);

        $res->assertStatus(401);
    }

    // -----------------------------------------------------------------
    // Nonce lifecycle: replay, expiry
    // -----------------------------------------------------------------

    public function test_nonce_replay_blocked(): void
    {
        $nonce     = $this->requestNonce($this->testAddress);
        $signature = $this->signNonce($nonce);

        // First verify succeeds
        $this->postJson('/api/v1/projects/pangu2/auth/verify', [
            'wallet_address' => $this->testAddress,
            'nonce'          => $nonce,
            'signature'      => $signature,
            'domain'         => self::TEST_DOMAIN,
            'chain_id'       => self::TEST_CHAIN_ID,
        ])->assertOk();

        // Second verify with same nonce fails
        $res = $this->postJson('/api/v1/projects/pangu2/auth/verify', [
            'wallet_address' => $this->testAddress,
            'nonce'          => $nonce,
            'signature'      => $signature,
            'domain'         => self::TEST_DOMAIN,
            'chain_id'       => self::TEST_CHAIN_ID,
        ]);

        $res->assertStatus(401);
        $this->assertStringContainsString('already been used', $res->json('error.message'));
    }

    public function test_expired_nonce_rejected(): void
    {
        // Manually create an expired nonce
        $nonce = Nonce::create([
            'wallet_address' => $this->testAddress,
            'nonce'          => bin2hex(random_bytes(32)),
            'message'        => $this->buildMessage('expired-test-nonce'),
            'domain'         => self::TEST_DOMAIN,
            'chain_id'       => self::TEST_CHAIN_ID,
            'expires_at'     => now()->subMinutes(10),
        ]);

        $signature = $this->signMessage($nonce->message, self::TEST_PRIVATE_KEY);

        $res = $this->postJson('/api/v1/projects/pangu2/auth/verify', [
            'wallet_address' => $this->testAddress,
            'nonce'          => $nonce->nonce,
            'signature'      => $signature,
            'domain'         => self::TEST_DOMAIN,
            'chain_id'       => self::TEST_CHAIN_ID,
        ]);

        $res->assertStatus(401);
        $this->assertStringContainsString('expired', $res->json('error.message'));
    }

    // -----------------------------------------------------------------
    // Domain and chain ID binding
    // -----------------------------------------------------------------

    public function test_wrong_domain_rejected(): void
    {
        $nonce     = $this->requestNonce($this->testAddress);
        $signature = $this->signNonce($nonce);

        $res = $this->postJson('/api/v1/projects/pangu2/auth/verify', [
            'wallet_address' => $this->testAddress,
            'nonce'          => $nonce,
            'signature'      => $signature,
            'domain'         => 'evil.example.com',
            'chain_id'       => self::TEST_CHAIN_ID,
        ]);

        $res->assertStatus(401);
        $this->assertStringContainsString('Domain mismatch', $res->json('error.message'));
    }

    public function test_wrong_chain_id_rejected(): void
    {
        $nonce     = $this->requestNonce($this->testAddress);
        $signature = $this->signNonce($nonce);

        $res = $this->postJson('/api/v1/projects/pangu2/auth/verify', [
            'wallet_address' => $this->testAddress,
            'nonce'          => $nonce,
            'signature'      => $signature,
            'domain'         => self::TEST_DOMAIN,
            'chain_id'       => 99999,
        ]);

        $res->assertStatus(401);
        $this->assertStringContainsString('Chain ID mismatch', $res->json('error.message'));
    }

    // -----------------------------------------------------------------
    // Edge cases: invalid address, validation
    // -----------------------------------------------------------------

    public function test_invalid_address_format_rejected(): void
    {
        $res = $this->postJson('/api/v1/projects/pangu2/auth/nonce', [
            'wallet_address' => 'not-an-address',
            'domain'         => self::TEST_DOMAIN,
            'chain_id'       => self::TEST_CHAIN_ID,
        ]);

        $res->assertStatus(422);
        $this->assertEquals('INVALID_ADDRESS', $res->json('error.code'));
    }

    public function test_non_hex_address_rejected(): void
    {
        $res = $this->postJson('/api/v1/projects/pangu2/auth/nonce', [
            'wallet_address' => '0xGGGG000000000000000000000000000000000000',
            'domain'         => self::TEST_DOMAIN,
            'chain_id'       => self::TEST_CHAIN_ID,
        ]);

        $res->assertStatus(422);
    }

    public function test_wallet_address_normalized_to_lowercase(): void
    {
        $upperAddr = '0x' . strtoupper(substr($this->testAddress, 2));

        $res = $this->postJson('/api/v1/projects/pangu2/auth/nonce', [
            'wallet_address' => $upperAddr,
            'domain'         => self::TEST_DOMAIN,
            'chain_id'       => self::TEST_CHAIN_ID,
        ]);

        $res->assertOk();
        $this->assertEquals($this->testAddress, $res->json('data.wallet_address'));
    }

    // -----------------------------------------------------------------
    // Rate limiting
    // -----------------------------------------------------------------

    public function test_nonce_endpoint_rate_limited(): void
    {
        // Make 30 requests (the limit per minute)
        for ($i = 0; $i < 30; $i++) {
            $this->postJson('/api/v1/projects/pangu2/auth/nonce', [
                'wallet_address' => $this->testAddress,
                'domain'         => self::TEST_DOMAIN,
                'chain_id'       => self::TEST_CHAIN_ID,
            ])->assertOk();
        }

        // 31st should be rate limited
        $res = $this->postJson('/api/v1/projects/pangu2/auth/nonce', [
            'wallet_address' => $this->testAddress,
            'domain'         => self::TEST_DOMAIN,
            'chain_id'       => self::TEST_CHAIN_ID,
        ]);

        $res->assertStatus(429);
    }

    public function test_verify_endpoint_rate_limited_by_wallet(): void
    {
        $nonce = $this->requestNonce($this->testAddress);

        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/v1/projects/pangu2/auth/verify', [
                'wallet_address' => $this->testAddress,
                'nonce'          => $nonce,
                'signature'      => '0x' . str_repeat('ab', 65),
                'domain'         => self::TEST_DOMAIN,
                'chain_id'       => self::TEST_CHAIN_ID,
            ])->assertStatus(401); // fails because of invalid sig
        }

        $res = $this->postJson('/api/v1/projects/pangu2/auth/verify', [
            'wallet_address' => $this->testAddress,
            'nonce'          => $nonce,
            'signature'      => '0x' . str_repeat('ab', 65),
            'domain'         => self::TEST_DOMAIN,
            'chain_id'       => self::TEST_CHAIN_ID,
        ]);

        $res->assertStatus(429);
    }

    // -----------------------------------------------------------------
    // Session: unauthenticated access
    // -----------------------------------------------------------------

    public function test_unauthenticated_session_returns_401(): void
    {
        $res = $this->getJson('/api/v1/projects/pangu2/auth/session');
        $res->assertStatus(401);
    }

    public function test_logout_without_session_returns_401(): void
    {
        $res = $this->postJson('/api/v1/projects/pangu2/auth/logout');
        // Without a session with wallet_address, the middleware rejects
        $res->assertStatus(401);
    }

    public function test_missing_required_fields_on_nonce(): void
    {
        $res = $this->postJson('/api/v1/projects/pangu2/auth/nonce', [
            'wallet_address' => $this->testAddress,
        ]);

        $res->assertStatus(422);
    }

    // -----------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------

    private function requestNonce(string $address): string
    {
        $res = $this->postJson('/api/v1/projects/pangu2/auth/nonce', [
            'wallet_address' => $address,
            'domain'         => self::TEST_DOMAIN,
            'chain_id'       => self::TEST_CHAIN_ID,
        ]);

        $res->assertOk();

        return $res->json('data.nonce');
    }

    private function signNonce(string $nonce): string
    {
        return $this->signMessage($this->buildMessage($nonce), self::TEST_PRIVATE_KEY);
    }

    private function buildMessage(string $nonce): string
    {
        return self::TEST_DOMAIN . ' wants you to sign in with your wallet.'
            . "\n\nNonce: {$nonce}"
            . "\nChain ID: " . self::TEST_CHAIN_ID;
    }

    /**
     * Sign a message using EIP-191 (personal_sign) and return the hex signature.
     */
    private function signMessage(string $message, string $privateKeyHex): string
    {
        // EIP-191 prefix
        $prefixed = "\x19Ethereum Signed Message:\n" . strlen($message) . $message;

        $msgHash = Keccak::hash($prefixed, 256);

        $keyPair = self::$ec->keyFromPrivate($privateKeyHex);

        $sig = $keyPair->sign($msgHash, ['canonical' => true]);

        $r = str_pad($sig->r->toString(16), 64, '0', STR_PAD_LEFT);
        $s = str_pad($sig->s->toString(16), 64, '0', STR_PAD_LEFT);
        $v = dechex($sig->recoveryParam + 27);

        return '0x' . $r . $s . $v;
    }

    /**
     * Derive the lowercase 0x-prefixed EVM address from a private key.
     */
    private function deriveAddress(string $privateKeyHex): string
    {
        $keyPair = self::$ec->keyFromPrivate($privateKeyHex);

        $pubHex  = $keyPair->getPublic(false, 'hex');
        $pubBin  = hex2bin(substr($pubHex, 2));
        $hash    = Keccak::hash($pubBin, 256);

        return '0x' . substr($hash, -40);
    }
}
