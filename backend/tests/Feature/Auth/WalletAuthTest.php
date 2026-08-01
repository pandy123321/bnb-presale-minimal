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
    private const EXPECTED_ADDRESS  = '0x14791697260e4c9a71f18484c9f997b308e59325';
    private const TEST_MESSAGE      = 'Hello EIP-191';

    private string $testSignatureV27;
    private string $testSignatureV28;
    private string $testSignatureV0;
    private string $testSignatureV1;

    private static EC $ec;

    protected function setUp(): void
    {
        parent::setUp();
        self::$ec = new EC('secp256k1');

        $derived = $this->deriveAddress(self::TEST_PRIVATE_KEY);
        $this->assertEquals(self::EXPECTED_ADDRESS, $derived, 'Test vector mismatch.');

        $this->deriveSignatures();
    }

    // ── Valid auth flow ─────────────────────────────────

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
        $this->runFullAuthFlow($this->testSignatureV0);
    }

    public function test_full_auth_flow_with_raw_v1_succeeds(): void
    {
        $this->runFullAuthFlow($this->testSignatureV1);
    }

    public function test_logout_invalidates_session_then_returns_401(): void
    {
        $this->authenticate();
        $this->postJson('/api/v1/projects/pangu2/auth/logout')->assertOk();
        $this->getJson('/api/v1/projects/pangu2/auth/session')->assertStatus(401);
    }

    // ── Signature failures ──────────────────────────────

    public function test_invalid_signature_rejected(): void
    {
        $nonce   = $this->requestNonce();
        $fakeSig = '0x' . str_repeat('ab', 65);

        $res = $this->postJson('/api/v1/projects/pangu2/auth/verify', [
            'wallet_address' => self::EXPECTED_ADDRESS,
            'nonce'          => $nonce,
            'signature'      => $fakeSig,
        ]);

        $res->assertStatus(401);
        $this->assertEquals('VERIFICATION_FAILED', $res->json('error.code'));
    }

    public function test_wrong_signer_rejected(): void
    {
        $nonce     = $this->requestNonce();
        $message   = $this->buildMessage($nonce);
        $signature = $this->signMessage($message, self::TEST_PRIVATE_KEY, 27);
        $otherAddr = '0x0000000000000000000000000000000000000001';

        $res = $this->postJson('/api/v1/projects/pangu2/auth/verify', [
            'wallet_address' => $otherAddr,
            'nonce'          => $nonce,
            'signature'      => $signature,
        ]);

        $res->assertStatus(401);
        $this->assertEquals('VERIFICATION_FAILED', $res->json('error.code'));
    }

    public function test_compact_signature_rejected(): void
    {
        $nonce   = $this->requestNonce();
        $compact = '0x' . str_repeat('ab', 64);

        $res = $this->postJson('/api/v1/projects/pangu2/auth/verify', [
            'wallet_address' => self::EXPECTED_ADDRESS,
            'nonce'          => $nonce,
            'signature'      => $compact,
        ]);

        $res->assertStatus(401);
        $this->assertStringContainsString('EIP-2098', $res->json('error.message'));
    }

    // ── Nonce replay / expiry ───────────────────────────

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
        $this->assertStringContainsString('already used', $res->json('error.message'));
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

    // ── Address normalization ────────────────────────────

    public function test_invalid_address_rejected(): void
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

    // ── Rate limiting ────────────────────────────────────

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
            ])->assertStatus(401);
        }

        $res = $this->postJson('/api/v1/projects/pangu2/auth/verify', [
            'wallet_address' => self::EXPECTED_ADDRESS,
            'nonce'          => $nonce,
            'signature'      => '0x' . str_repeat('ab', 65),
        ]);

        $res->assertStatus(429);
    }

    // ── Session access control ───────────────────────────

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

    public function test_missing_fields_on_nonce_returns_422(): void
    {
        $res = $this->postJson('/api/v1/projects/pangu2/auth/nonce', []);
        $res->assertStatus(422);
        $this->assertEquals('VALIDATION_FAILED', $res->json('error.code'));
    }

    // ── External test vector ─────────────────────────────

    public function test_external_eip191_yields_expected_signer(): void
    {
        $sig = $this->signMessage(self::TEST_MESSAGE, self::TEST_PRIVATE_KEY, 27);
        $service = app(\App\Modules\Core\Auth\Services\Eip191VerificationService::class);
        $recovered = $service->recoverSigner(self::TEST_MESSAGE, $sig);

        $this->assertEquals(self::EXPECTED_ADDRESS, $recovered);
    }

    // ── Helpers ──────────────────────────────────────────

    private function runFullAuthFlow(string $signatureVariant): void
    {
        $nonceRes = $this->postJson('/api/v1/projects/pangu2/auth/nonce', [
            'wallet_address' => self::EXPECTED_ADDRESS,
        ]);
        $nonceRes->assertOk();

        $nonce   = $nonceRes->json('data.nonce');
        $domain  = $nonceRes->json('data.domain');
        $chainId = $nonceRes->json('data.chain_id');

        $this->assertNotEmpty($nonce);
        $this->assertEquals(config('pangu2.auth_domain'), $domain);
        $this->assertEquals(config('pangu2.chain_id'), $chainId);

        $verifyRes = $this->postJson('/api/v1/projects/pangu2/auth/verify', [
            'wallet_address' => self::EXPECTED_ADDRESS,
            'nonce'          => $nonce,
            'signature'      => $signatureVariant,
        ]);
        $verifyRes->assertOk();
        $this->assertEquals('AUTHENTICATED', $verifyRes->json('data.auth_status'));
        $this->assertEquals(self::EXPECTED_ADDRESS, $verifyRes->json('data.wallet_address'));

        $sessionRes = $this->getJson('/api/v1/projects/pangu2/auth/session');
        $sessionRes->assertOk();
        $this->assertNotNull($sessionRes->json('data.expires_at'));
        $this->assertNotNull($sessionRes->json('data.authenticated_at'));
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
        $d = config('pangu2.auth_domain');
        $c = config('pangu2.chain_id');
        return "{$d} wants you to sign in with your wallet.\n\nNonce: {$nonce}\nChain ID: {$c}";
    }

    private function deriveSignatures(): void
    {
        $d   = config('pangu2.auth_domain');
        $c   = config('pangu2.chain_id');
        $msg = "{$d} wants you to sign in with your wallet.\n\nNonce: test-nonce-vector\nChain ID: {$c}";

        $this->testSignatureV27 = $this->signMessage($msg, self::TEST_PRIVATE_KEY, 27);
        $this->testSignatureV28 = $this->signMessage($msg, self::TEST_PRIVATE_KEY, 28);
        $this->testSignatureV0  = $this->signMessageRaw($msg, self::TEST_PRIVATE_KEY, 0);
        $this->testSignatureV1  = $this->signMessageRaw($msg, self::TEST_PRIVATE_KEY, 1);
    }

    private function signMessage(string $message, string $pk, int $vTarget): string
    {
        $prefixed = "\x19Ethereum Signed Message:\n" . strlen($message) . $message;
        $msgHash  = Keccak::hash($prefixed, 256);
        $kp       = self::$ec->keyFromPrivate($pk);
        $sig      = $kp->sign($msgHash, ['canonical' => true]);
        $r        = str_pad($sig->r->toString(16), 64, '0', STR_PAD_LEFT);
        $s        = str_pad($sig->s->toString(16), 64, '0', STR_PAD_LEFT);
        $v        = str_pad(dechex($vTarget), 2, '0', STR_PAD_LEFT);
        return '0x' . $r . $s . $v;
    }

    private function signMessageRaw(string $message, string $pk, int $rawV): string
    {
        return $this->signMessage($message, $pk, $rawV);
    }

    private function deriveAddress(string $pkHex): string
    {
        $kp     = self::$ec->keyFromPrivate($pkHex);
        $pubHex = $kp->getPublic(false, 'hex');
        $pubBin = hex2bin(substr($pubHex, 2));
        $hash   = Keccak::hash($pubBin, 256);
        return '0x' . substr($hash, -40);
    }
}
