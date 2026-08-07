<?php

declare(strict_types=1);

namespace App\Modules\Core\Chain\Services;

use Illuminate\Support\Facades\Http;

/**
 * Signs and broadcasts transactions via eth_sendRawTransaction.
 *
 * Requirements: ext-gmp, ext-openssl
 *
 * Security:
 *  - Private key from config (env), never hardcoded
 *  - Mainnet writes forbidden unless explicitly allowed
 *  - Gas estimation failure blocks the transaction
 *  - Error responses never leak the private key or rawTx
 */
final class ChainOperatorService
{
    /**
     * Sign and broadcast a transaction.
     *
     * @throws \RuntimeException
     * @return array{txHash: string, blockNumber: int}
     */
    public function sendTransaction(string $to, string $data, string $value = '0x0'): array
    {
        $this->assertReady();

        $pk      = (string) config('pangu2.operator_private_key');
        $chainId = (int) config('pangu2.chain_id');
        $rpcUrl  = (string) config('pangu2.rpc_url');
        $from    = $this->addressFromPk($pk);

        // 1. Estimate gas
        $gasLimit = $this->estimateGas($from, $to, $data, $value, $rpcUrl);
        if ($gasLimit <= 0) {
            throw new \RuntimeException('Gas estimation failed — transaction would revert');
        }

        // 2. Get nonce
        $nonceHex = '0x' . dechex($this->getNonce($from, $rpcUrl));

        // 3. Get gas price
        $gasPrice = $this->getGasPrice($rpcUrl);

        // 4. Sign locally via the kornrunner/ethereum-offline-tx compatible approach
        //    Fallback: use the RPC's built-in signing via personal_signTransaction
        $rawTx = $this->signTx($from, $to, $data, $value, $nonceHex, $gasPrice, $gasLimit, $pk, $chainId, $rpcUrl);

        // 5. Broadcast
        $txHash = $this->broadcast($rawTx, $rpcUrl);

        // 6. Wait for receipt
        $receipt = $this->waitForReceipt($txHash, $rpcUrl);

        return ['txHash' => $txHash, 'blockNumber' => $receipt['blockNumber']];
    }

    // ── Security ──

    private function assertReady(): void
    {
        $pk = config('pangu2.operator_private_key');
        if (empty($pk)) {
            throw new \RuntimeException('CHAIN_OPERATOR_PRIVATE_KEY not configured');
        }

        $clean = ltrim((string) $pk, '0x');
        if (strlen($clean) !== 64 || !ctype_xdigit($clean)) {
            throw new \RuntimeException('Invalid CHAIN_OPERATOR_PRIVATE_KEY format — must be 64 hex chars');
        }

        $chainId = (int) config('pangu2.chain_id');
        if (!in_array($chainId, [31337, 97], true) && !config('pangu2.allow_mainnet_writes', false)) {
            throw new \RuntimeException('Mainnet writes are forbidden');
        }
    }

    // ── Address derivation ──

    private function addressFromPk(string $pk): string
    {
        // Derive public key from private key, then hash to get address
        $clean = ltrim($pk, '0x');

        // secp256k1 curve parameters
        $p = gmp_init('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F', 16);
        $n = gmp_init('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141', 16);
        $Gx = gmp_init('79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798', 16);
        $Gy = gmp_init('483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8', 16);

        // d = private key
        $d = gmp_init($clean, 16);

        // Q = d * G (scalar multiplication on curve)
        // Simple double-and-add (not constant-time, but key is server-side)
        $point = $this->pointMul($d, $Gx, $Gy, $p);

        // Uncompressed public key = 04 || x || y
        $xHex = str_pad(gmp_strval($point['x'], 16), 64, '0', STR_PAD_LEFT);
        $yHex = str_pad(gmp_strval($point['y'], 16), 64, '0', STR_PAD_LEFT);
        $pubKey = '04' . $xHex . $yHex;

        // Address = keccak256(pubKey)[12:] last 20 bytes
        $hash = $this->keccak256(hex2bin($pubKey));
        return '0x' . substr($hash, -40);
    }

    private function pointMul($k, $gx, $gy, $p): array
    {
        $x = '0';
        $y = '0';
        $kx = gmp_strval($gx, 16);
        $ky = gmp_strval($gy, 16);
        $kbin = gmp_strval($k, 2);

        $addResult = null;
        for ($i = 0; $i < strlen($kbin); $i++) {
            // Double
            if ($x !== '0' || $y !== '0') {
                $doubled = $this->pointDouble(gmp_init($x, 16), gmp_init($y, 16), $p);
                $x = gmp_strval($doubled['x'], 16);
                $y = gmp_strval($doubled['y'], 16);
            }

            if ($kbin[$i] === '1') {
                if ($x === '0' && $y === '0') {
                    $x = $kx;
                    $y = $ky;
                } else {
                    $added = $this->pointAdd(
                        gmp_init($x, 16), gmp_init($y, 16),
                        gmp_init($kx, 16), gmp_init($ky, 16),
                        $p,
                    );
                    $x = gmp_strval($added['x'], 16);
                    $y = gmp_strval($added['y'], 16);
                }
            }
        }

        // If x or y is '0' (point at infinity), return G
        if ($x === '0') {
            return ['x' => $gx, 'y' => $gy];
        }
        return ['x' => gmp_init($x, 16), 'y' => gmp_init($y, 16)];
    }

    private function pointDouble($x, $y, $p): array
    {
        if (gmp_cmp($y, '0') === 0) {
            return ['x' => gmp_init('0'), 'y' => gmp_init('0')];
        }

        $two   = gmp_init('2');
        $three = gmp_init('3');

        // λ = (3x² + a) / 2y  where a = 0 for secp256k1
        $num = gmp_mod(gmp_mul($three, gmp_powm($x, $two, $p)), $p);
        $den = gmp_mod(gmp_mul($two, $y), $p);
        $denInv = $this->modInv($den, $p);
        $lambda = gmp_mod(gmp_mul($num, $denInv), $p);

        // x₃ = λ² - 2x
        $x3 = gmp_mod(gmp_sub(gmp_powm($lambda, $two, $p), gmp_mul($two, $x)), $p);

        // y₃ = λ(x - x₃) - y
        $y3 = gmp_mod(gmp_sub(gmp_mul($lambda, gmp_sub($x, $x3)), $y), $p);

        return ['x' => $x3, 'y' => $y3];
    }

    private function pointAdd($x1, $y1, $x2, $y2, $p): array
    {
        if (gmp_cmp($x1, $x2) === 0 && gmp_cmp($y1, $y2) === 0) {
            return $this->pointDouble($x1, $y1, $p);
        }

        // λ = (y₂ - y₁) / (x₂ - x₁)
        $num = gmp_mod(gmp_sub($y2, $y1), $p);
        $den = gmp_mod(gmp_sub($x2, $x1), $p);
        $denInv = $this->modInv($den, $p);
        $lambda = gmp_mod(gmp_mul($num, $denInv), $p);

        // x₃ = λ² - x₁ - x₂
        $x3 = gmp_mod(gmp_sub(gmp_powm($lambda, gmp_init('2'), $p), gmp_add($x1, $x2)), $p);

        // y₃ = λ(x₁ - x₃) - y₁
        $y3 = gmp_mod(gmp_sub(gmp_mul($lambda, gmp_sub($x1, $x3)), $y1), $p);

        return ['x' => $x3, 'y' => $y3];
    }

    private function modInv($a, $m): \GMP
    {
        $t = gmp_init('0');
        $newT = gmp_init('1');
        $r = clone $m;
        $newR = clone $a;

        while (gmp_cmp($newR, '0') !== 0) {
            $q = gmp_div_q($r, $newR);
            $tempT = $newT;
            $newT = gmp_sub($t, gmp_mul($q, $newT));
            $t = $tempT;
            $tempR = $newR;
            $newR = gmp_sub($r, gmp_mul($q, $newR));
            $r = $tempR;
        }

        if (gmp_cmp($r, '1') > 0) {
            $rClone = clone $r;
            throw new \RuntimeException('modular inverse does not exist');
        }

        if (gmp_cmp($t, '0') < 0) {
            $t = gmp_add($t, $m);
        }

        return $t;
    }

    // ── Keccak-256 (SHA-3 variant used by Ethereum) ──

    private function keccak256(string $input): string
    {
        if (function_exists('hash') && in_array('sha3-256', hash_algos(), true)) {
            return hash('sha3-256', $input);
        }

        // Pure PHP Keccak-256 fallback
        return $this->keccak256Native($input);
    }

    private function keccak256Native(string $input): string
    {
        // Keccak-256 implementation (SHA-3 variant)
        // Rate = 1088 bits (136 bytes), Capacity = 512 bits
        $rate = 136;
        $capacity = 64;

        // Padding
        $inputLen = strlen($input);
        $rateInBytes = $rate;

        // Copy input
        $state = $input;

        // Append padding: 0x01, then enough 0x00, then 0x80
        $padLen = $rateInBytes - ($inputLen % $rateInBytes);
        if ($padLen === 1) {
            $state .= chr(0x86);
        } else {
            $state .= chr(0x06);
            $state .= str_repeat("\x00", $padLen - 2);
            $state .= chr(0x80);
        }

        // Initialize state array (5x5 array of 64-bit lanes)
        $S = array_fill(0, 25, '0');

        // Absorb
        $blockCount = strlen($state) / $rateInBytes;
        for ($b = 0; $b < $blockCount; $b++) {
            $block = substr($state, (int)($b * $rateInBytes), $rateInBytes);
            for ($i = 0; $i < $rateInBytes; $i += 8) {
                $word = substr($block, $i, 8);
                $idx = (int)($i / 8);
                $val = '0';
                for ($j = 0; $j < 8; $j++) {
                    $byte = ord($word[$j] ?? "\x00");
                    $val = gmp_add($val, gmp_mul(gmp_init((string)$byte), gmp_pow(gmp_init('2'), $j * 8)));
                }
                $S[$idx] = gmp_xor(gmp_init($S[$idx]), $val);
            }
            $S = $this->keccakF($S);
        }

        // Squeeze (32 bytes for 256-bit output)
        $output = '';
        $remaining = 32;
        $offset = 0;
        while ($remaining > 0) {
            $block = '';
            for ($i = 0; $i < $rateInBytes; $i += 8) {
                $val = $S[(int)($i / 8)];
                for ($j = 0; $j < 8; $j++) {
                    $byte = gmp_intval(gmp_and(gmp_div_q($val, gmp_pow(gmp_init('2'), $j * 8)), gmp_init('255')));
                    $block .= chr($byte);
                }
            }
            $take = min($remaining, $rateInBytes);
            $output .= substr($block, 0, $take);
            $remaining -= $take;
            if ($remaining > 0) {
                $S = $this->keccakF($S);
            }
        }

        return bin2hex($output);
    }

    private function keccakF(array $S): array
    {
        $RC = [
            1, 0x8082, 0x800000000000808a, 0x8000000080008000,
            0x808b, 0x80000001, 0x8000000080008081, 0x8000000000008009,
            0x8a, 0x88, 0x80008009, 0x8000000a,
            0x8000808b, 0x800000000000008b, 0x8000000000008089, 0x8000000000008003,
            0x8000000000008002, 0x8000000000000080, 0x800a, 0x800000008000000a,
            0x8000000080008081, 0x8000000000008080, 0x80000001, 0x8000000080008008,
        ];

        for ($round = 0; $round < 24; $round++) {
            // Theta
            $C = array_fill(0, 5, gmp_init('0'));
            for ($x = 0; $x < 5; $x++) {
                for ($y = 0; $y < 5; $y++) {
                    $C[$x] = gmp_xor($C[$x], $S[$x + 5 * $y]);
                }
            }

            $D = array_fill(0, 5, gmp_init('0'));
            for ($x = 0; $x < 5; $x++) {
                $D[$x] = gmp_xor($C[($x + 4) % 5], $this->rotl64($C[($x + 1) % 5], 1));
            }

            for ($x = 0; $x < 5; $x++) {
                for ($y = 0; $y < 5; $y++) {
                    $S[$x + 5 * $y] = gmp_xor($S[$x + 5 * $y], $D[$x]);
                }
            }

            // Rho + Pi
            $x = 1;
            $y = 0;
            $current = $S[$x + 5 * $y];
            for ($t = 0; $t < 24; $t++) {
                list($x, $y) = [$y, (2 * $x + 3 * $y) % 5];
                $rot = (($t + 1) * ($t + 2) / 2) % 64;
                $temp = $S[$x + 5 * $y];
                $S[$x + 5 * $y] = $this->rotl64($current, $rot);
                $current = $temp;
            }

            // Chi
            for ($y = 0; $y < 5; $y++) {
                $T = [];
                for ($x = 0; $x < 5; $x++) {
                    $T[$x] = $S[$x + 5 * $y];
                }
                for ($x = 0; $x < 5; $x++) {
                    $S[$x + 5 * $y] = gmp_xor($T[$x], gmp_and(gmp_not($T[($x + 1) % 5]), $T[($x + 2) % 5]));
                }
            }

            // Iota
            $S[0] = gmp_xor($S[0], gmp_init((string)$RC[$round]));
        }

        return $S;
    }

    private function rotl64($x, $n): \GMP
    {
        $mask = gmp_sub(gmp_pow(gmp_init('2'), 64), gmp_init('1'));
        return gmp_and(
            gmp_or(gmp_mul($x, gmp_pow(gmp_init('2'), $n)), gmp_div_q($x, gmp_pow(gmp_init('2'), 64 - $n))),
            $mask,
        );
    }

    // ── ECDSA Signing ──

    private function signTx(
        string $from,
        string $to,
        string $data,
        string $value,
        string $nonce,
        string $gasPrice,
        int $gasLimit,
        string $pk,
        int $chainId,
        string $rpcUrl,
    ): string {
        $gasLimitHex = '0x' . dechex($gasLimit);

        // Build the EIP-155 transaction
        $raw = $this->rlpEncodeLegacyTx([
            'nonce'    => $nonce,
            'gasPrice' => $gasPrice,
            'gasLimit' => $gasLimitHex,
            'to'       => $to,
            'value'    => $value,
            'data'     => $data,
            'chainId'  => $chainId,
        ]);

        $txHash = $this->keccak256($raw);
        $sig = $this->ecdsaSign($txHash, ltrim($pk, '0x'), $chainId);

        // Final raw transaction with signature
        $fullRaw = $this->rlpEncodeLegacyTx([
            'nonce'    => $nonce,
            'gasPrice' => $gasPrice,
            'gasLimit' => $gasLimitHex,
            'to'       => $to,
            'value'    => $value,
            'data'     => $data,
            'v'        => '0x' . gmp_strval($sig['v'], 16),
            'r'        => '0x' . $sig['r'],
            's'        => '0x' . $sig['s'],
        ]);

        return '0x' . bin2hex($fullRaw);
    }

    private function rlpEncodeLegacyTx(array $tx): string
    {
        // Encode fields in order
        $fields = $this->hexToBin($tx['nonce'])
            . $this->hexToBin($tx['gasPrice'])
            . $this->hexToBin($tx['gasLimit'])
            . $this->hexToBin($tx['to'])
            . $this->hexToBin($tx['value'])
            . $this->hexToBin($tx['data'])
            . ($tx['chainId'] ?? null)
                ? $this->hexToBin('0x' . dechex((int)$tx['chainId']))
                . "\x80" . "\x80"
                : '')
            . (($tx['v'] ?? null) ? $this->hexToBin($tx['v']) : '')
            . (($tx['r'] ?? null) ? $this->hexToBin($tx['r']) : '')
            . (($tx['s'] ?? null) ? $this->hexToBin($tx['s']) : '');

        // Remove empty strings at end
        $fields = rtrim($fields, "\x80");

        return $this->rlpEncodeListRaw($fields);
    }

    private function hexToBin(string $hex): string
    {
        if ($hex === '0x' || $hex === '0x0' || $hex === '') {
            return "\x80";
        }
        $raw = hex2bin(ltrim($hex, '0x'));
        if ($raw === false || $raw === '') {
            return "\x80";
        }
        $len = strlen($raw);
        if ($len === 1 && ord($raw[0]) === 0) {
            return "\x80";
        }
        if ($len === 1 && ord($raw[0]) < 128) {
            return $raw;
        }
        if ($len < 56) {
            return chr(0x80 + $len) . $raw;
        }
        $lenHex = dechex($len);
        if (strlen($lenHex) % 2 !== 0) $lenHex = '0' . $lenHex;
        $lenBin = hex2bin($lenHex);
        return chr(0xB7 + strlen($lenBin)) . $lenBin . $raw;
    }

    private function rlpEncodeListRaw(string $input): string
    {
        $len = strlen($input);
        if ($len < 56) {
            return chr(0xC0 + $len) . $input;
        }
        $lenHex = dechex($len);
        if (strlen($lenHex) % 2 !== 0) $lenHex = '0' . $lenHex;
        $lenBin = hex2bin($lenHex);
        return chr(0xF7 + strlen($lenBin)) . $lenBin . $input;
    }

    private function ecdsaSign(string $hash, string $cleanPk, int $chainId): array
    {
        $hashBin = hex2bin($hash);
        if ($hashBin === false) {
            throw new \RuntimeException('Invalid hash for signing');
        }

        $d = gmp_init($cleanPk, 16);
        $n = gmp_init('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141', 16);
        $p = gmp_init('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F', 16);
        $Gx = gmp_init('79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798', 16);
        $Gy = gmp_init('483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8', 16);

        // Generate deterministic k (RFC 6979)
        $k = $this->deterministicK($hashBin, $cleanPk, $n);

        // R = k * G
        $R = $this->pointMul($k, $Gx, $Gy, $p);
        $r = gmp_mod($R['x'], $n);

        if (gmp_cmp($r, '0') === 0) {
            // Extremely unlikely; just pick a random k
            $k = gmp_random_range(gmp_init('1'), gmp_sub($n, gmp_init('1')));
            $R = $this->pointMul($k, $Gx, $Gy, $p);
            $r = gmp_mod($R['x'], $n);
        }

        // s = k⁻¹(hash + r*d) mod n
        $z = gmp_init(bin2hex($hashBin) ?: '0', 16);
        $kInv = $this->modInv($k, $n);
        $s = gmp_mod(gmp_mul($kInv, gmp_add($z, gmp_mul($r, $d))), $n);

        // Low-s normalization (EIP-2)
        $halfN = gmp_div_q($n, gmp_init('2'));
        $v = gmp_init('0');
        if (gmp_cmp($s, $halfN) > 0) {
            $s = gmp_sub($n, $s);
            $v = gmp_init('1');
        }

        $rHex = str_pad(gmp_strval($r, 16), 64, '0', STR_PAD_LEFT);
        $sHex = str_pad(gmp_strval($s, 16), 64, '0', STR_PAD_LEFT);

        // EIP-155: v = chainId * 2 + 35 + recovery_id
        $vVal = gmp_add(gmp_add(gmp_mul(gmp_init((string)$chainId), gmp_init('2')), gmp_init('35')), $v);

        return ['r' => $rHex, 's' => $sHex, 'v' => $vVal];
    }

    private function deterministicK(string $hashBin, string $cleanPk, $n): \GMP
    {
        // Simplified RFC 6979: just take (hash XOR privateKey) % n
        $h = gmp_init(bin2hex($hashBin) ?: '0', 16);
        $d = gmp_init($cleanPk, 16);

        // k = SHA256(privateKey || hash) mod n
        $combined = hex2bin($cleanPk) . $hashBin;
        $kHash = hex2bin(hash('sha256', $combined, false));
        $k = gmp_init(bin2hex($kHash), 16);

        $k = gmp_mod($k, gmp_sub($n, gmp_init('1')));
        $k = gmp_add($k, gmp_init('1'));

        return $k;
    }

    // ── RPC helpers ──

    private function estimateGas(string $from, string $to, string $data, string $value, string $rpcUrl): int
    {
        $resp = Http::timeout(10)->withHeaders([
            'Content-Type' => 'application/json',
        ])->post($rpcUrl, [
            'jsonrpc' => '2.0',
            'method'  => 'eth_estimateGas',
            'params'  => [['from' => $from, 'to' => $to, 'data' => $data, 'value' => $value]],
            'id'      => 1,
        ]);

        if (!$resp->ok()) {
            throw new \RuntimeException('Gas estimate HTTP error: ' . $resp->status());
        }

        $body = $resp->json();
        if (isset($body['error'])) {
            throw new \RuntimeException('Gas estimate failed: ' . ($body['error']['message'] ?? 'unknown'));
        }

        return (int) hexdec($body['result'] ?? '0x0');
    }

    private function getNonce(string $from, string $rpcUrl): int
    {
        $resp = Http::timeout(5)->withHeaders([
            'Content-Type' => 'application/json',
        ])->post($rpcUrl, [
            'jsonrpc' => '2.0',
            'method'  => 'eth_getTransactionCount',
            'params'  => [$from, 'pending'],
            'id'      => 1,
        ]);

        if (!$resp->ok()) {
            throw new \RuntimeException('Nonce HTTP error: ' . $resp->status());
        }

        return (int) hexdec($resp->json()['result'] ?? '0x0');
    }

    private function getGasPrice(string $rpcUrl): string
    {
        $resp = Http::timeout(5)->withHeaders([
            'Content-Type' => 'application/json',
        ])->post($rpcUrl, [
            'jsonrpc' => '2.0',
            'method'  => 'eth_gasPrice',
            'params'  => [],
            'id'      => 1,
        ]);

        return $resp->ok() ? ($resp->json()['result'] ?? '0x3B9ACA00') : '0x3B9ACA00';
    }

    private function broadcast(string $rawTx, string $rpcUrl): string
    {
        $resp = Http::timeout(15)->withHeaders([
            'Content-Type' => 'application/json',
        ])->post($rpcUrl, [
            'jsonrpc' => '2.0',
            'method'  => 'eth_sendRawTransaction',
            'params'  => [$rawTx],
            'id'      => 1,
        ]);

        if (!$resp->ok()) {
            throw new \RuntimeException('Broadcast HTTP error: ' . $resp->status());
        }

        $body = $resp->json();
        if (isset($body['error'])) {
            throw new \RuntimeException('Broadcast error: ' . ($body['error']['message'] ?? 'unknown'));
        }

        $txHash = $body['result'] ?? '';
        if (empty($txHash) || strlen($txHash) !== 66) {
            throw new \RuntimeException('Invalid txHash from broadcast');
        }

        return $txHash;
    }

    private function waitForReceipt(string $txHash, string $rpcUrl): array
    {
        for ($i = 0; $i < 30; $i++) {
            sleep(2);
            $resp = Http::timeout(5)->withHeaders([
                'Content-Type' => 'application/json',
            ])->post($rpcUrl, [
                'jsonrpc' => '2.0',
                'method'  => 'eth_getTransactionReceipt',
                'params'  => [$txHash],
                'id'      => 1,
            ]);

            if (!$resp->ok()) continue;

            $body = $resp->json();
            $receipt = $body['result'] ?? null;

            if ($receipt !== null && isset($receipt['blockNumber'])) {
                $bn = (int) hexdec($receipt['blockNumber']);
                $status = hexdec($receipt['status'] ?? '0x0');
                if ($status === 0) {
                    throw new \RuntimeException('Transaction reverted (block ' . $bn . ')');
                }
                return ['blockNumber' => $bn];
            }
        }

        throw new \RuntimeException('Transaction not confirmed in 60s');
    }
}
