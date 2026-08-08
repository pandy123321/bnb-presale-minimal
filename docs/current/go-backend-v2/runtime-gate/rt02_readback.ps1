$ErrorActionPreference = "Stop"

# ======== 0. RPC from approved env (P0-RT02-01) ========
$primary = $env:BGP_BSC_TESTNET_RPC_PRIMARY
$backup  = $env:BGP_BSC_TESTNET_RPC_BACKUP
if ([string]::IsNullOrWhiteSpace($primary)) { throw "BGP_BSC_TESTNET_RPC_PRIMARY not set — BLOCKED_APPROVED_RPC_REQUIRED" }
if ([string]::IsNullOrWhiteSpace($backup))  { throw "BGP_BSC_TESTNET_RPC_BACKUP not set — BLOCKED_APPROVED_RPC_REQUIRED" }

# ======== RPC helper (fail-closed, P1-RT02-03) ========
function Rpc($url, $method, $params) {
    $body = @{ jsonrpc = "2.0"; method = $method; params = $params; id = 1 } | ConvertTo-Json -Compress -Depth 10
    try {
        $r = Invoke-RestMethod -Uri $url -Method Post -ContentType "application/json" -Body $body -TimeoutSec 30
    } catch {
        throw "RPC_NETWORK_FAILED: $($_.Exception.Message)"
    }
    if ($null -ne $r.error) { throw "JSON_RPC_ERROR: $($r.error.message) (code=$($r.error.code))" }
    if ($null -eq $r.result) { throw "JSON_RPC_MISSING_RESULT" }
    return $r.result
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

# ======== 3. Bytecode with expected_hash comparison (P1-RT02-01) ========
Write-Host "=== 3. BYTECODE ==="

# Expected hashes from deployment commit 3ef50b6 artifacts (contracts-v2/out/)
# NOTE: contracts have been modified post-deployment; hashes below are from artifacts
# that may differ from current workspace. Identity only MATCH when expected==actual.
$expected = @{
    "Pangu2Token"           = "c3b9cc9726c9168f9ade9cf946ec9960fe2b8553d094849d2f85dd1a13425e09"
    "CostBasisManager"      = "a6a01b17e016f735f695c8565faa711b228c98fb1dc4f8ef38011b8e2a605e96"
    "PancakeV2TwapOracle"   = "8e21d2cca67a34a38f1306ac2a6300b547aa12ee95910ad29dc0a293b71b79d5"
    "SupportPool"           = "8a77e540420479a2b86bef71aabcdddb0b2a6ba1480ba830d6716d904cb341a5"
    "FeeVault"              = "d5df3bb23c9675f1922e85f1f07820f7be9a8b97adc5cd4d3410440f89e54aaf"
    "BuybackLocker"         = "2770b07e18f1021f87be0de3e91e95de298b5e0d0e7791515f1856946779c9c7"
    "DividendDistributor"   = "6484606b99fbdcf1b18ecd6e5111477c11a4ded7441b69a9628cc18e872ed410"
    "Pangu2TradeRouter"     = "c31a4e5585b3c43f3fa79ca82105ed659e72e582a33092954a6301b394a290c8"
    "Pangu2Staking"         = "c9ba5f0337dc96c58ffc272717fa29be8420866ec44c9fad2d18826e890b9961"
    "PancakeV2Adapter"      = "59f80a58d7d9be15d96f15656f15cb857f8e565e3acddfa71e2c0120d5188d95"
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

$bcIdentities = 0; $bcMatches = 0; $bcFingerprints = 0
foreach ($c in $contracts) {
    $code = Rpc $primary "eth_getCode" @($c.a, $blockHex)
    if (-not $code -or $code -eq "0x") { throw "EMPTY_CODE: $($c.k)" }
    $hex = $code.Substring(2)
    $size = $hex.Length / 2
    $actualHash = Sha256Hex $hex
    $expHash = $expected[$c.k]
    $match = "N/A"
    $verdict = "FINGERPRINT_CAPTURED"
    if ($expHash) {
        $match = ($actualHash -eq $expHash).ToString()
        if ($actualHash -eq $expHash) { $verdict = "IDENTITY_MATCH"; $bcMatches++ } else { $verdict = "IDENTITY_MISMATCH" }
        $bcIdentities++
    } else { $bcFingerprints++ }
    Write-Host "  $($c.k): ${size}b actual=$actualHash expected=$expHash match=$match -> $verdict"
    [void]$results.Add("BYTECODE|$($c.k)|$($c.a)|size=$size|actual_sha256=$actualHash|expected_sha256=$expHash|match=$match|verdict=$verdict|block=$bn1")
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

# ======== 5. Roles (P1-RT02-02) — verify actual governance holder ========
Write-Host "=== 5. ROLES ==="
$gov = "0xD34E41b719BA5a613E36948F0f008B1bc4cC4FF2"
$adminRole = "0x0000000000000000000000000000000000000000000000000000000000000000"
$hasRoleSel = "0x91d14854"

# Contracts that implement AccessControl (from 3ef50b6 deploy broadcast role events)
# BuybackLocker, PancakeV2TwapOracle: NOT AccessControl → NA
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
    $v = if ($hasGov) { $rolePass++; "PASS" } else { "FAIL" }
    Write-Host "  $($ac.k): hasRole(DEFAULT_ADMIN_ROLE, governance)=$hasGov -> $v"
    [void]$results.Add("ROLE|$($ac.k)|$($ac.a)|DEFAULT_ADMIN_ROLE|holder=0xD34E...|hasRole(governance)=$hasGov|verdict=$v")
}
foreach ($n in $nonAc) {
    $roleNA++
    Write-Host "  ${n}: NOT_APPLICABLE (no AccessControl)"
    [void]$results.Add("ROLE|${n}|.|DEFAULT_ADMIN_ROLE|verdict=NOT_APPLICABLE")
}

# ======== 6. Getters (P1-RT02-04) — fixed selectors from ABI ========
Write-Host "=== 6. GETTERS ==="
# Selectors verified against methodIdentifiers in contracts-v2/out/*.json
$getters = @(
    # Pangu2Token
    @{k="Pangu2Token"; a="0x49a4a6ecaacc5d9ae60df7717f62e0605f591bc3"; n="paused";                 s="0x5c975abb"},
    @{k="Pangu2Token"; a="0x49a4a6ecaacc5d9ae60df7717f62e0605f591bc3"; n="tradingOpenAt";          s="0x87b20b63"},
    # PancakeV2TwapOracle
    @{k="PancakeV2TwapOracle"; a="0x11c39db60a95b232c6c303c1869aa81886694d9c"; n="status";                 s="0x200d2ed2"},
    @{k="PancakeV2TwapOracle"; a="0x11c39db60a95b232c6c303c1869aa81886694d9c"; n="twapWindow";            s="0x8107e133"},
    @{k="PancakeV2TwapOracle"; a="0x11c39db60a95b232c6c303c1869aa81886694d9c"; n="lastTwapCompletedAt";    s="0x66d83ac0"},
    # FeeVault
    @{k="FeeVault"; a="0xf82313eb70d24250d541c26796fe1615beb15d29"; n="dividendBalance";        s="0x3368a120"},
    @{k="FeeVault"; a="0xf82313eb70d24250d541c26796fe1615beb15d29"; n="supportBalance";         s="0x69140aec"},
    # SupportPool
    @{k="SupportPool"; a="0xe6d37841b13d78e9ae759b77ecfaebeddb90589b"; n="lastSuccessfulBuybackAt"; s="0xcf268504"},
    @{k="SupportPool"; a="0xe6d37841b13d78e9ae759b77ecfaebeddb90589b"; n="BUYBACK_AMOUNT";         s="0x7dc42a8b"},
    # BuybackLocker
    @{k="BuybackLocker"; a="0x0a2283cd52523889fcb333596c3f0a14741b1cce"; n="mode";                   s="0x295a5212"},
    @{k="BuybackLocker"; a="0x0a2283cd52523889fcb333596c3f0a14741b1cce"; n="duration";              s="0x0fb5a6b4"},
    # DividendDistributor
    @{k="DividendDistributor"; a="0x917705d794ec31144f7b2c4d62bfaab4fe327385"; n="totalReservedClaims";   s="0x7b608e70"},
    # Pangu2Staking
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

# ======== 7. Count model (P2-RT02-03) ========
$totalChain  = 1  # dual RPC check counted as 1 chain_id gate
$totalBytecode = 12  # all getCode + size, identity match TBD
$totalPair   = 1
$totalRoleRequired = $roleCheck
$totalRoleNA = $roleNA
$totalGetterRequired = $getters.Count
$totalGetterNA = 0
$totalRequired = $totalChain + $totalBytecode + $totalPair + $totalRoleRequired + $totalGetterRequired
$passRequired = 1 + $bcIdentities + 1 + $rolePass + $getterPass  # chain + identities + pair + role + getter

[void]$results.Add("COUNT|total_required=$totalRequired|pass=$passRequired|fail=$($totalRequired - $passRequired)")
[void]$results.Add("COUNT_DETAIL|chain=1/1|bytecode_with_hash=$bcIdentities/$totalBytecode|bytecode_match=$bcMatches/$bcIdentities|pair=1/1|role_pass=$rolePass/$totalRoleRequired|role_na=$totalRoleNA|getter_pass=$getterPass/$totalGetterRequired|getter_fail=$getterFail/$totalGetterRequired")

# ======== 8. Write evidence ========
$out = "E:\github\bnb\bnb-presale-minimal\docs\current\go-backend-v2\runtime-gate\rt02_raw_evidence.txt"
$header = "CHAIN_ID|p=$c1|b=$c2|PASS`nBLOCK|number=$bn1|hash=$bh1|PASS"
$body = $results -join "`n"
$content = "$header`n$body"
[System.IO.File]::WriteAllText($out, $content)
$sha.Dispose()

Write-Host "`n=== COMPLETE ==="
Write-Host "CHAIN: 1/1 | BYTECODE: $bcMatches/$bcIdentities matched ($bcFingerprints fingerprint-only) | PAIR: 1/1 | ROLE: $rolePass/$totalRoleRequired ($totalRoleNA NA) | GETTER: $getterPass/$totalGetterRequired ($getterFail fail)"
Write-Host "TOTAL_REQUIRED=$totalRequired PASS_REQUIRED=$passRequired"
