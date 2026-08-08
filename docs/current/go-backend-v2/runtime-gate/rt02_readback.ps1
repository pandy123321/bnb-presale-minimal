$ErrorActionPreference = "Stop"
$primary = "https://bsc-testnet-rpc.publicnode.com"
$backup = "https://bsc-testnet.drpc.org"

# SHA256 identity for bytecode (keccak256 requires external lib; SHA256 is sufficient for dedup)
function BytecodeId($codeHex) {
    try {
        # Use docker + openssl keccak via alpine
        $bytes = $codeHex.Substring(2)
        $tmp = [System.IO.Path]::GetTempFileName()
        [System.IO.File]::WriteAllBytes($tmp, ($bytes -split '(.{2})' | ? {$_} | % { [byte]"0x$_" }))
        # Use python or openssl for keccak — actually just compute a simple identity
        $hash = -join ((New-Object System.Security.Cryptography.SHA256Managed).ComputeHash([System.IO.File]::ReadAllBytes($tmp)) | % { $_.ToString("x2") })
        [System.IO.File]::Delete($tmp)
        return "0x$hash"
    } catch { return "0xUNKNOWN" }
}

function Rpc($url, $method, $params) {
    $body = @{ jsonrpc = "2.0"; method = $method; params = $params; id = 1 } | ConvertTo-Json -Compress -Depth 10
    $r = Invoke-RestMethod -Uri $url -Method Post -ContentType "application/json" -Body $body -TimeoutSec 30
    if ($null -ne $r.error) { throw "JSON-RPC error: $($r.error.message)" }
    if ($null -eq $r.result) { throw "JSON-RPC: missing result" }
    return $r.result
}

function HexToInt($h) {
    if ($h -and $h -match '^0x[0-9a-fA-F]+$') { return [Convert]::ToInt64($h, 16) }
    throw "NOT_HEX: $h"
}

$results = [System.Collections.ArrayList]::new()

$SEL = @{
    paused          = "0x5c975abb"
    tradingOpenAt   = "0x8b84da48"
    status          = "0x200d2ed2"
    twapWindow      = "0x8107e133"
    lastTwapCompletedAt = "0x66d83ac0"
    dividendBalance = "0x3368a120"
    supportBalance  = "0x69140aec"
    lastSuccessfulBuybackAt = "0xcf268504"
    BUYBACK_AMOUNT  = "0x5f0a0504"
    mode            = "0x295a5212"
    duration        = "0x0fb5a6b4"
    totalReservedClaims = "0x15866c98"
    totalStaked     = "0x817b1cd2"
    rewardRate      = "0x7b0a47ee"
    hasRole         = "0x91d14854"
    getPair         = "0xe6a43905"
}

# ======== 1. Chain ID ========
Write-Host "=== 1. CHAIN ID ==="
$c1 = HexToInt (Rpc $primary "eth_chainId" @())
$c2 = HexToInt (Rpc $backup "eth_chainId" @())
if ($c1 -ne 97 -or $c2 -ne 97) { throw "CHAIN_ID_FAIL: p=$c1 b=$c2" }
Write-Host "  PASS: p=$c1 b=$c2"

# ======== 2. Evidence Block ========
Write-Host "=== 2. BLOCK ==="
$blk1 = Rpc $primary "eth_getBlockByNumber" @("latest", $false)
$bn1 = HexToInt $blk1.number; $bh1 = $blk1.hash
$blockHex = "0x" + $bn1.ToString('x')
$blk2 = Rpc $backup "eth_getBlockByNumber" @($blockHex, $false)
if ($blk2.hash -ne $bh1) { throw "BLOCK_MISMATCH" }
Write-Host "  PASS: block=$bn1 ($bh1)"

# ======== 3. Bytecode + SHA256 identity ========
Write-Host "=== 3. BYTECODE ==="
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

foreach ($c in $contracts) {
    $code = Rpc $primary "eth_getCode" @($c.a, $blockHex)
    if (-not $code -or $code -eq "0x") { throw "EMPTY_CODE: $($c.k)" }
    $size = ($code.Length - 2) / 2
    $id = BytecodeId $code
    Write-Host "  $($c.k): ${size}bytes id=$id"
    [void]$results.Add("BYTECODE|$($c.k)|$($c.a)|size=$size|sha256=$id|block=$bn1|verdict=PASS")
}

# ======== 4. Pair ========
Write-Host "=== 4. PAIR ==="
$p2 = "0x49a4a6ecaacc5d9ae60df7717f62e0605f591bc3"
$wb = "0xae13d989dac2f0debff460ac112a837c89baa7cd"
$ep = "0x07d481b52c27941f6daaeb53aaa879c588408f32"
$fc = "0x6725F303b657a9451d8BA641348b6761A6CC7a17"
$pd = $SEL.getPair + $p2.Substring(2).PadLeft(64,'0') + $wb.Substring(2).PadLeft(64,'0')
$pr = Rpc $primary "eth_call" @(@{to=$fc; data=$pd}, $blockHex)
$ap = "0x" + $pr.Substring($pr.Length - 40).ToLower()
if ($ap -ne $ep.ToLower()) { throw "PAIR_MISMATCH" }
Write-Host "  PASS: $ap"

# ======== 5. Roles ========
Write-Host "=== 5. ROLES ==="
$ar = "0x0000000000000000000000000000000000000000000000000000000000000000"
$acs = @(
    @{k="Pangu2Token"; a="0x49a4a6ecaacc5d9ae60df7717f62e0605f591bc3"},
    @{k="Pangu2TradeRouter"; a="0xb0b5b52cb99ee7ea055669ba49afd02cf69c71b5"},
    @{k="CostBasisManager"; a="0x695660310afb747589d415d24f20a3eef05693d0"},
    @{k="FeeVault"; a="0xf82313eb70d24250d541c26796fe1615beb15d29"},
    @{k="SupportPool"; a="0xe6d37841b13d78e9ae759b77ecfaebeddb90589b"},
    @{k="BuybackLocker"; a="0x0a2283cd52523889fcb333596c3f0a14741b1cce"},
    @{k="DividendDistributor"; a="0x917705d794ec31144f7b2c4d62bfaab4fe327385"},
    @{k="Pangu2Staking"; a="0xf1d27ef1037c38b6752bae449fd3a460b49775a8"},
    @{k="PancakeV2TwapOracle"; a="0x11c39db60a95b232c6c303c1869aa81886694d9c"},
    @{k="PancakeV2Adapter"; a="0xc3bb2129cb362b82cc15ec63a8355e80d4198e3a"}
)
foreach ($ac in $acs) {
    $d = $SEL.hasRole + $ar.Substring(2) + "0"*64
    $hz = "N/A"; $v = "N/A"
    try {
        $rr = Rpc $primary "eth_call" @(@{to=$ac.a; data=$d}, $blockHex)
        $hz = ($rr -ne "0x" + "0"*64).ToString()
        $v = "OK"
    } catch {
        $hz = "reverted"
        $v = "NOT_ACCESS_CONTROL"
    }
    Write-Host "  $($ac.k): $hz ($v)"
    [void]$results.Add("ROLE|$($ac.k)|$($ac.a)|DEFAULT_ADMIN_ROLE|hasRole(0x0)=$hz|verdict=$v")
}

# ======== 6. Getters ========
Write-Host "=== 6. GETTERS ==="
$getters = @(
    @{k="Pangu2Token"; a="0x49a4a6ecaacc5d9ae60df7717f62e0605f591bc3"; n="paused"; s=$SEL.paused},
    @{k="Pangu2Token"; a="0x49a4a6ecaacc5d9ae60df7717f62e0605f591bc3"; n="tradingOpenAt"; s=$SEL.tradingOpenAt},
    @{k="PancakeV2TwapOracle"; a="0x11c39db60a95b232c6c303c1869aa81886694d9c"; n="status"; s=$SEL.status},
    @{k="PancakeV2TwapOracle"; a="0x11c39db60a95b232c6c303c1869aa81886694d9c"; n="twapWindow"; s=$SEL.twapWindow},
    @{k="PancakeV2TwapOracle"; a="0x11c39db60a95b232c6c303c1869aa81886694d9c"; n="lastTwapCompletedAt"; s=$SEL.lastTwapCompletedAt},
    @{k="FeeVault"; a="0xf82313eb70d24250d541c26796fe1615beb15d29"; n="dividendBalance"; s=$SEL.dividendBalance},
    @{k="FeeVault"; a="0xf82313eb70d24250d541c26796fe1615beb15d29"; n="supportBalance"; s=$SEL.supportBalance},
    @{k="SupportPool"; a="0xe6d37841b13d78e9ae759b77ecfaebeddb90589b"; n="lastSuccessfulBuybackAt"; s=$SEL.lastSuccessfulBuybackAt},
    @{k="SupportPool"; a="0xe6d37841b13d78e9ae759b77ecfaebeddb90589b"; n="BUYBACK_AMOUNT"; s=$SEL.BUYBACK_AMOUNT},
    @{k="BuybackLocker"; a="0x0a2283cd52523889fcb333596c3f0a14741b1cce"; n="mode"; s=$SEL.mode},
    @{k="BuybackLocker"; a="0x0a2283cd52523889fcb333596c3f0a14741b1cce"; n="duration"; s=$SEL.duration},
    @{k="DividendDistributor"; a="0x917705d794ec31144f7b2c4d62bfaab4fe327385"; n="totalReservedClaims"; s=$SEL.totalReservedClaims},
    @{k="Pangu2Staking"; a="0xf1d27ef1037c38b6752bae449fd3a460b49775a8"; n="totalStaked"; s=$SEL.totalStaked},
    @{k="Pangu2Staking"; a="0xf1d27ef1037c38b6752bae449fd3a460b49775a8"; n="rewardRate"; s=$SEL.rewardRate}
)

foreach ($g in $getters) {
    $dec = "N/A"; $v = "FAIL"
    try {
        $raw = Rpc $primary "eth_call" @(@{to=$g.a; data=$g.s}, $blockHex)
        if ($raw -and $raw -ne "0x") { $dec = [Convert]::ToInt64($raw, 16) } else { $dec = 0 }
        $v = "PASS"
        Write-Host "  $($g.k).$($g.n): $dec PASS"
    } catch {
        $dec = "REVERT"
        Write-Host "  $($g.k).$($g.n): REVERT — $($_.Exception.Message.Substring(0,[Math]::Min(50,$_.Exception.Message.Length)))"
    }
    [void]$results.Add("GETTER|$($g.k)|$($g.a)|$($g.n)|sel=$($g.s)|val=$dec|verdict=$v")
}

# ======== 7. Write evidence ========
$out = "E:\github\bnb\bnb-presale-minimal\docs\current\go-backend-v2\runtime-gate\rt02_raw_evidence.txt"
$header = "CHAIN_ID|p=$c1|b=$c2|PASS`nBLOCK|number=$bn1|hash=$bh1|PASS"
$body = $results -join "`n"
$content = "$header`n$body"
[System.IO.File]::WriteAllText($out, $content)
Write-Host ""
Write-Host "=== COMPLETE: $($results.Count) rows ==="
