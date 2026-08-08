$ErrorActionPreference = "Stop"

# ======== 0. RPC from approved env (P0-RT02-01) ========
$primary = $env:BGP_BSC_TESTNET_RPC_PRIMARY
$backup  = $env:BGP_BSC_TESTNET_RPC_BACKUP
if ([string]::IsNullOrWhiteSpace($primary)) { throw "BGP_BSC_TESTNET_RPC_PRIMARY not set — BLOCKED_APPROVED_RPC_REQUIRED" }
if ([string]::IsNullOrWhiteSpace($backup))  { throw "BGP_BSC_TESTNET_RPC_BACKUP not set — BLOCKED_APPROVED_RPC_REQUIRED" }

# ======== RPC helper (fail-closed with retry) ========
function Rpc($url, $method, $params) {
    $body = @{ jsonrpc = "2.0"; method = $method; params = $params; id = 1 } | ConvertTo-Json -Compress -Depth 10
    $maxRetry = 3
    for ($i = 0; $i -le $maxRetry; $i++) {
        try {
            $r = Invoke-RestMethod -Uri $url -Method Post -ContentType "application/json" -Body $body -TimeoutSec 30
            if ($null -ne $r.error) { throw "JSON_RPC_ERROR: $($r.error.message) (code=$($r.error.code))" }
            if ($null -ne $r.result) { return $r.result }
            # No result — transient, retry
            Start-Sleep -Milliseconds 2000
        } catch {
            if ($i -eq $maxRetry) { throw "RPC_FAILED_AFTER_RETRY: $($_.Exception.Message)" }
            Start-Sleep -Milliseconds 2000
        }
    }
    throw "RPC_NO_RESULT_AFTER_RETRY"
}

function HexToInt($h) {
    if ($h -and $h -match '^0x[0-9a-fA-F]+$') { return [Convert]::ToInt64($h, 16) }
    throw "NOT_HEX: $h"
}

$sha = New-Object System.Security.Cryptography.SHA256Managed
function Sha256Hex($hex) {
    $bytes = for ($i = 0; $i -lt $hex.Length; $i += 2) { [byte]::Parse($hex.Substring($i, 2), [System.Globalization.NumberStyles]::HexNumber) }
    return -join ($sha.ComputeHash($bytes) | % { $_.ToString("x2") })
}

$results = [System.Collections.ArrayList]::new()

# ======== 1. Chain ID ========
Write-Host "=== 1. CHAIN ID ==="
$c1 = HexToInt (Rpc $primary "eth_chainId" @())
$c2 = HexToInt (Rpc $backup "eth_chainId" @())
if ($c1 -ne 97 -or $c2 -ne 97) { throw "CHAIN_ID_FAIL: p=$c1 b=$c2" }
[void]$results.Add("CHAIN_ID|primary=$c1|backup=$c2|verdict=PASS")
Write-Host "  PASS: p=$c1 b=$c2"

# ======== 2. Evidence Block ========
Write-Host "=== 2. BLOCK ==="
$blk1 = Rpc $primary "eth_getBlockByNumber" @("latest", $false)
$bn1 = HexToInt $blk1.number; $bh1 = $blk1.hash
$blockHex = "0x" + $bn1.ToString('x')
$blk2 = Rpc $backup "eth_getBlockByNumber" @($blockHex, $false)
if ($blk2.hash -ne $bh1) { throw "BLOCK_HASH_MISMATCH" }
[void]$results.Add("BLOCK|number=$bn1|hash=$bh1|verdict=PASS")
Write-Host "  PASS: block=$bn1 ($bh1)"

# ======== 3. Bytecode Identity — receipt-bound deploy block (P1-RT02-BLOCK-BINDING) ========
Write-Host "=== 3. BYTECODE ==="

# Deploy tx from BSC_TESTNET_DEPLOYMENT_BASELINE.md
# NO hardcoded deploy blocks — they MUST come from eth_getTransactionReceipt
$deployTx = @{
    "Pangu2Token"           = "0x8f6ddf160a6d010d78748095a0bfa0a576e8ca7cd93dbdcc671806b43805398f"
    "CostBasisManager"      = "0x00dff4728b02e46d4aab34de4864ca8f260d9c3691070f8b589e039b107c489e"
    "PancakeV2TwapOracle"   = "0xbd85ea70b006874a7a995ed047d1c8c83401335f61ede206de890da43e724382"
    "SupportPool"           = "0x5e5c58303fa25fd937fc5d099478886c0d85a677d9d8603308b57f1feaf12b63"
    "FeeVault"              = "0x418e592e4f56eabff5773b93f9053ac3a13372319c71ee64dbf13130f9659312"
    "BuybackLocker"         = "0x7f299e80f5017b94d1db8c6c0783c1c397afbe03ebafd7235d6e368ce8271d1a"
    "DividendDistributor"   = "0xb749c44f0e31ec21df27b386061da518bc321dbaa9d048a33e30dc57865d5591"
    "Pangu2TradeRouter"     = "0x36d1b0662777c539732e726e47a0a5bc48471431f31ea0916a992a95510966bb"
    "Pangu2Staking"         = "0xd503e6c381fa6fe8326ab3d6299e6263e038db3d94faf6155a4a79d85f80c1bf"
    "PancakeV2Adapter"      = "0xcc6de4cd4a191d9e16c64a73999ef7bdff3eac2748b25c511749b3214b7ebe16"
}

$contracts = @(
    @{k="Pangu2Token"; a="0x49a4a6ecaacc5d9ae60df7717f62e0605f591bc3"},
    @{k="CostBasisManager"; a="0x695660310afb747589d415d24f20a3eef05693d0"},
    @{k="PancakeV2TwapOracle"; a="0x11c39db60a95b232c6c303c1869aa81886694d9c"},
    @{k="SupportPool"; a="0xe6d37841b13d78e9ae759b77ecfaebeddb90589b"},
    @{k="FeeVault"; a="0xf82313eb70d24250d541c26796fe1615beb15d29"},
    @{k="BuybackLocker"; a="0x0a2283cd52523889fcb333596c3f0a14741b1cce"},
    @{k="DividendDistributor"; a="0x917705d794ec31144f7b2c4d62bfaab4fe327385"},
    @{k="Pangu2TradeRouter"; a="0xb0b5b52cb99ee7ea055669ba49afd02cf69c71b5"},
    @{k="Pangu2Staking"; a="0xf1d27ef1037c38b6752bae449fd3a460b49775a8"},
    @{k="PancakeV2Adapter"; a="0xc3bb2129cb362b82cc15ec63a8355e80d4198e3a"},
    @{k="PancakeV2Pair"; a="0x07d481b52c27941f6daaeb53aaa879c588408f32"},
    @{k="PancakeFactory"; a="0x6725F303b657a9451d8BA641348b6761A6CC7a17"}
)

$bcVerified = 0; $bcFingerprints = 0; $bcBlocked = 0

foreach ($c in $contracts) {
    # Evidence-block runtime code
    $codeNow = Rpc $primary "eth_getCode" @($c.a, $blockHex)
    if (-not $codeNow -or $codeNow -eq "0x") { throw "EMPTY_CODE: $($c.k) at evidence block" }
    $hexNow = $codeNow.Substring(2)
    $size = $hexNow.Length / 2
    $hashNow = Sha256Hex $hexNow

    $tx = $deployTx[$c.k]
    if ($tx) {
        # ── Receipt-bound deploy block (NO hardcoded blocks, NO offset fallback) ──
        try {
            $receipt = Rpc $primary "eth_getTransactionReceipt" @($tx)
        } catch {
            Write-Host "  $($c.k): RECEIPT_FETCH_FAILED — UNABLE_TO_VERIFY"
            [void]$results.Add("BYTECODE|contract=$($c.k)|address=$($c.a)|deploy_tx=$tx|evidence_sha256=$hashNow|verdict=UNABLE_TO_VERIFY_RECEIPT_FAILED|evidence_block=$bn1")
            $bcBlocked++
            continue
        }

        # Validate receipt
        if ($null -eq $receipt) {
            Write-Host "  $($c.k): RECEIPT_NOT_FOUND — BLOCKED"
            [void]$results.Add("BYTECODE|contract=$($c.k)|address=$($c.a)|deploy_tx=$tx|evidence_sha256=$hashNow|verdict=BLOCKED_RECEIPT_NOT_FOUND|evidence_block=$bn1")
            $bcBlocked++
            continue
        }
        if ($receipt.status -ne "0x1") {
            Write-Host "  $($c.k): RECEIPT_STATUS_FAIL (status=$($receipt.status)) — BLOCKED"
            [void]$results.Add("BYTECODE|contract=$($c.k)|address=$($c.a)|deploy_tx=$tx|receipt_status=$($receipt.status)|evidence_sha256=$hashNow|verdict=BLOCKED_RECEIPT_STATUS|evidence_block=$bn1")
            $bcBlocked++
            continue
        }
        if (-not $receipt.blockNumber) {
            Write-Host "  $($c.k): RECEIPT_MISSING_BLOCK — BLOCKED"
            [void]$results.Add("BYTECODE|contract=$($c.k)|address=$($c.a)|deploy_tx=$tx|evidence_sha256=$hashNow|verdict=BLOCKED_RECEIPT_NO_BLOCK|evidence_block=$bn1")
            $bcBlocked++
            continue
        }
        if (-not $receipt.blockHash) {
            Write-Host "  $($c.k): RECEIPT_MISSING_BLOCKHASH — BLOCKED"
            [void]$results.Add("BYTECODE|contract=$($c.k)|address=$($c.a)|deploy_tx=$tx|evidence_sha256=$hashNow|verdict=BLOCKED_RECEIPT_NO_BLOCKHASH|evidence_block=$bn1")
            $bcBlocked++
            continue
        }

        $deployBlockHex = $receipt.blockNumber
        $deployBlock = HexToInt $deployBlockHex

        # Verify receipt block hash against eth_getBlockByNumber
        $receiptBlock = Rpc $primary "eth_getBlockByNumber" @($deployBlockHex, $false)
        if ($receiptBlock.hash -ne $receipt.blockHash) {
            Write-Host "  $($c.k): RECEIPT_BLOCK_HASH_MISMATCH (receipt=$($receipt.blockHash) block=$($receiptBlock.hash)) — BLOCKED"
            [void]$results.Add("BYTECODE|contract=$($c.k)|address=$($c.a)|deploy_tx=$tx|receipt_block=$deployBlock|receipt_block_hash=$($receipt.blockHash)|actual_block_hash=$($receiptBlock.hash)|evidence_sha256=$hashNow|verdict=BLOCKED_BLOCK_HASH_MISMATCH|evidence_block=$bn1")
            $bcBlocked++
            continue
        }

        # Get deploy-block runtime code
        try {
            $codeDeploy = Rpc $primary "eth_getCode" @($c.a, $deployBlockHex)
        } catch {
            Write-Host "  $($c.k): eth_getCode at deploy block $deployBlock FAILED — UNABLE_TO_VERIFY"
            [void]$results.Add("BYTECODE|contract=$($c.k)|address=$($c.a)|deploy_tx=$tx|receipt_block=$deployBlock|receipt_status=0x1|evidence_sha256=$hashNow|verdict=UNABLE_TO_VERIFY_PRUNED|evidence_block=$bn1")
            $bcBlocked++
            continue
        }

        if (-not $codeDeploy -or $codeDeploy -eq "0x") {
            Write-Host "  $($c.k): CODE_EMPTY at deploy block $deployBlock (pruned) — UNABLE_TO_VERIFY"
            [void]$results.Add("BYTECODE|contract=$($c.k)|address=$($c.a)|deploy_tx=$tx|receipt_block=$deployBlock|receipt_status=0x1|evidence_sha256=$hashNow|verdict=UNABLE_TO_VERIFY_PRUNED|evidence_block=$bn1")
            $bcBlocked++
            continue
        }

        $hashDeploy = Sha256Hex $codeDeploy.Substring(2)
        $match = ($hashNow -eq $hashDeploy)
        $verdict = if ($match) { "IDENTITY_VERIFIED" } else { "IDENTITY_MISMATCH" }
        if ($match) { $bcVerified++ }

        Write-Host "  $($c.k): deploy@${deployBlock}=$hashDeploy evidence@${bn1}=$hashNow match=$match -> $verdict"
        [void]$results.Add("BYTECODE|contract=$($c.k)|address=$($c.a)|deploy_tx=$tx|receipt_block_number=$deployBlock|receipt_block_hash=$($receipt.blockHash)|receipt_status=0x1|evidence_block_number=$bn1|evidence_block_hash=$bh1|deploy_code_sha256=$hashDeploy|evidence_code_sha256=$hashNow|identity_match=$match|verdict=$verdict")
    } else {
        # No deploy tx — pre-existing or factory infrastructure
        $verdict = "FINGERPRINT_CAPTURED"
        $bcFingerprints++
        Write-Host "  $($c.k): ${size}b sha256=$hashNow (no deploy tx in baseline) -> $verdict"
        [void]$results.Add("BYTECODE|contract=$($c.k)|address=$($c.a)|size=$size|evidence_sha256=$hashNow|verdict=$verdict|evidence_block=$bn1")
    }
}

# ======== 4. Pair ========
Write-Host "=== 4. PAIR ==="
$p2 = "0x49a4a6ecaacc5d9ae60df7717f62e0605f591bc3"
$wb = "0xae13d989dac2f0debff460ac112a837c89baa7cd"
$ep = "0x07d481b52c27941f6daaeb53aaa879c588408f32".ToLower()
$fc = "0x6725F303b657a9451d8BA641348b6761A6CC7a17"
$getPairSel = "0xe6a43905"
$pd = $getPairSel + $p2.Substring(2).PadLeft(64,'0') + $wb.Substring(2).PadLeft(64,'0')
$pr = Rpc $primary "eth_call" @(@{to=$fc; data=$pd}, $blockHex)
$ap = "0x" + $pr.Substring($pr.Length - 40).ToLower()
if ($ap -ne $ep) { throw "PAIR_MISMATCH: expected=$ep actual=$ap" }
[void]$results.Add("PAIR|expected=$ep|actual=$ap|verdict=PASS")
Write-Host "  PASS: $ap"

# ======== 5. Roles — Owner Decision: EXPECTED = false ========
# DEFAULT_ADMIN_ROLE is self-administered (normal AccessControl).
# Owner has confirmed: governance does NOT hold DEFAULT_ADMIN_ROLE by design.
# DEPLOYMENT_MANIFEST "NO" is correct. This is the final frozen security model.
Write-Host "=== 5. ROLES ==="
$gov = "0xD34E41b719BA5a613E36948F0f008B1bc4cC4FF2"
$adminRole = "0x0000000000000000000000000000000000000000000000000000000000000000"
$hasRoleSel = "0x91d14854"

$acContracts = @(
    @{k="Pangu2Token"; a="0x49a4a6ecaacc5d9ae60df7717f62e0605f591bc3"},
    @{k="Pangu2TradeRouter"; a="0xb0b5b52cb99ee7ea055669ba49afd02cf69c71b5"},
    @{k="CostBasisManager"; a="0x695660310afb747589d415d24f20a3eef05693d0"},
    @{k="FeeVault"; a="0xf82313eb70d24250d541c26796fe1615beb15d29"},
    @{k="SupportPool"; a="0xe6d37841b13d78e9ae759b77ecfaebeddb90589b"},
    @{k="DividendDistributor"; a="0x917705d794ec31144f7b2c4d62bfaab4fe327385"},
    @{k="Pangu2Staking"; a="0xf1d27ef1037c38b6752bae449fd3a460b49775a8"},
    @{k="PancakeV2Adapter"; a="0xc3bb2129cb362b82cc15ec63a8355e80d4198e3a"}
)
$nonAc = @("BuybackLocker", "PancakeV2TwapOracle", "PancakeV2Pair", "PancakeFactory")

$rolePass = 0; $roleNA = 0; $roleCheck = 0
foreach ($ac in $acContracts) {
    $roleCheck++
    $govAddr = $gov.Substring(2).ToLower().PadLeft(64,'0')
    $data = $hasRoleSel + $adminRole.Substring(2) + $govAddr
    $rr = Rpc $primary "eth_call" @(@{to=$ac.a; data=$data}, $blockHex)
    $hasGov = ($rr -ne "0x" + "0"*64)
    # EXPECTED = False (Owner Decision)
    $v = if (-not $hasGov) { $rolePass++; "PASS" } else { "FAIL" }
    Write-Host "  $($ac.k): hasRole(DEFAULT_ADMIN_ROLE, $gov)=$hasGov EXPECTED=False -> $v"
    [void]$results.Add("ROLE|contract=$($ac.k)|address=$($ac.a)|role=DEFAULT_ADMIN_ROLE|holder=$gov|raw=$rr|expected=False|actual=$hasGov|verdict=$v")
}
foreach ($n in $nonAc) {
    $roleNA++
    Write-Host "  ${n}: NOT_APPLICABLE (no AccessControl)"
    [void]$results.Add("ROLE|${n}|.|DEFAULT_ADMIN_ROLE|verdict=NOT_APPLICABLE")
}

# ======== 6. Getters — fixed selectors from ABI ========
Write-Host "=== 6. GETTERS ==="
$getters = @(
    @{k="Pangu2Token"; a="0x49a4a6ecaacc5d9ae60df7717f62e0605f591bc3"; n="paused";                 s="0x5c975abb"},
    @{k="Pangu2Token"; a="0x49a4a6ecaacc5d9ae60df7717f62e0605f591bc3"; n="tradingOpenAt";          s="0x87b20b63"},
    @{k="PancakeV2TwapOracle"; a="0x11c39db60a95b232c6c303c1869aa81886694d9c"; n="status";                 s="0x200d2ed2"},
    @{k="PancakeV2TwapOracle"; a="0x11c39db60a95b232c6c303c1869aa81886694d9c"; n="twapWindow";            s="0x8107e133"},
    @{k="PancakeV2TwapOracle"; a="0x11c39db60a95b232c6c303c1869aa81886694d9c"; n="lastTwapCompletedAt";    s="0x66d83ac0"},
    @{k="FeeVault"; a="0xf82313eb70d24250d541c26796fe1615beb15d29"; n="dividendBalance";        s="0x3368a120"},
    @{k="FeeVault"; a="0xf82313eb70d24250d541c26796fe1615beb15d29"; n="supportBalance";         s="0x69140aec"},
    @{k="SupportPool"; a="0xe6d37841b13d78e9ae759b77ecfaebeddb90589b"; n="lastSuccessfulBuybackAt"; s="0xcf268504"},
    @{k="SupportPool"; a="0xe6d37841b13d78e9ae759b77ecfaebeddb90589b"; n="BUYBACK_AMOUNT";         s="0x7dc42a8b"},
    @{k="BuybackLocker"; a="0x0a2283cd52523889fcb333596c3f0a14741b1cce"; n="mode";                   s="0x295a5212"},
    @{k="BuybackLocker"; a="0x0a2283cd52523889fcb333596c3f0a14741b1cce"; n="duration";              s="0x0fb5a6b4"},
    @{k="DividendDistributor"; a="0x917705d794ec31144f7b2c4d62bfaab4fe327385"; n="totalReservedClaims";   s="0x7b608e70"},
    @{k="Pangu2Staking"; a="0xf1d27ef1037c38b6752bae449fd3a460b49775a8"; n="totalStaked";            s="0x817b1cd2"},
    @{k="Pangu2Staking"; a="0xf1d27ef1037c38b6752bae449fd3a460b49775a8"; n="rewardRate";            s="0x7b0a47ee"}
)

$getterPass = 0; $getterFail = 0
foreach ($g in $getters) {
    $dec = "N/A"; $v = "FAIL"
    try {
        $raw = Rpc $primary "eth_call" @(@{to=$g.a; data=$g.s}, $blockHex)
        if ($raw -and $raw -ne "0x") { $dec = [Convert]::ToInt64($raw, 16) } else { $dec = 0 }
        $v = "PASS"; $getterPass++
        Write-Host "  $($g.k).$($g.n): $dec PASS"
    } catch {
        $dec = "REVERT"; $getterFail++
        Write-Host "  $($g.k).$($g.n): REVERT (sel=$($g.s)) — $($_.Exception.Message.Substring(0,[Math]::Min(50,$_.Exception.Message.Length)))"
    }
    [void]$results.Add("GETTER|$($g.k)|$($g.a)|$($g.n)|sel=$($g.s)|val=$dec|verdict=$v")
}

# ======== 7. Count model ========
$totalChain  = 1
$totalBytecode = 12
$totalPair   = 1
$totalRoleRequired = $roleCheck
$totalRoleNA = $roleNA
$totalGetterRequired = $getters.Count
$totalRequired = $totalChain + 10 + $totalPair + $totalRoleRequired + $totalGetterRequired
$passRequired = 1 + $bcVerified + 1 + $rolePass + $getterPass

[void]$results.Add("COUNT|total_required=$totalRequired|pass=$passRequired|fail=$($totalRequired - $passRequired)|blocked=$bcBlocked")
[void]$results.Add("COUNT_DETAIL|chain=1/1|bytecode_verified=$bcVerified/10|bytecode_fingerprint=$bcFingerprints|bytecode_blocked=$bcBlocked|pair=1/1|role_pass=$rolePass/$totalRoleRequired|role_na=$totalRoleNA|getter_pass=$getterPass/$totalGetterRequired|getter_fail=$getterFail")

# ======== 8. Write evidence — UTF-8 NO BOM ========
$out = "E:\github\bnb\bnb-presale-minimal\docs\current\go-backend-v2\runtime-gate\rt02_raw_evidence.txt"
$header = "CHAIN_ID|p=$c1|b=$c2|PASS`nBLOCK|number=$bn1|hash=$bh1|PASS"
$body = $results -join "`n"
$content = "$header`n$body"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($out, $content, $utf8NoBom)
$sha.Dispose()

Write-Host "`n=== COMPLETE ==="
Write-Host "CHAIN: 1/1 | BYTECODE: $bcVerified/10 verified ($bcFingerprints fingerprint, $bcBlocked blocked) | PAIR: 1/1 | ROLE: $rolePass/$totalRoleRequired ($totalRoleNA NA) | GETTER: $getterPass/$totalGetterRequired ($getterFail fail)"
Write-Host "TOTAL_REQUIRED=$totalRequired PASS=$passRequired FAIL=$(($totalRequired - $passRequired)) BLOCKED=$bcBlocked"

$totalFail = ($totalRequired - $passRequired) + $bcBlocked
if ($totalFail -gt 0) {
    Write-Host "NON_ZERO_EXIT: $totalFail FAIL/BLOCKED detected — exit 1"
    exit 1
}
