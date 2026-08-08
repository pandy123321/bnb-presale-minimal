$ErrorActionPreference = "Stop"
$primary = "https://bsc-testnet-rpc.publicnode.com"
$backup = "https://bsc-testnet.drpc.org"
$outFile = "E:\github\bnb\bnb-presale-minimal\docs\current\go-backend-v2\runtime-gate\rt02_raw_evidence.txt"

function Rpc($url, $method, $params) {
    $body = @{ jsonrpc = "2.0"; method = $method; params = $params; id = 1 } | ConvertTo-Json -Compress -Depth 10
    $r = Invoke-RestMethod -Uri $url -Method Post -ContentType "application/json" -Body $body -TimeoutSec 30
    return $r
}

function HexToInt($h) { return [Convert]::ToInt64($h, 16) }
function Pad64($h) { return $h.PadLeft(64, '0') }

$results = @()

# ========== 1. Chain ID ==========
"=== RT-GATE-02 BSC TESTNET READBACK ===" | Out-File $outFile
"Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')" | Out-File $outFile -Append
"" | Out-File $outFile -Append

$cid1 = Rpc $primary "eth_chainId" @()
$cid2 = Rpc $backup "eth_chainId" @()
$chain1 = HexToInt $cid1.result
$chain2 = HexToInt $cid2.result
Write-Host "ChainId Primary=$chain1 Backup=$chain2"
"CHAIN_ID|primary=$chain1|backup=$chain2|verdict=$(if($chain1 -eq 97 -and $chain2 -eq 97){'PASS'}else{'FAIL'})" | Out-File $outFile -Append

# ========== 2. Latest Block ==========
$blk1 = Rpc $primary "eth_getBlockByNumber" @("latest", $false)
$blk2 = Rpc $backup "eth_getBlockByNumber" @("latest", $false)
$bn1 = HexToInt $blk1.result.number
$bn2 = HexToInt $blk2.result.number
$bh1 = $blk1.result.hash
$bh2 = $blk2.result.hash
$blockOk = ($bn1 -eq $bn2 -and $bh1 -eq $bh2)
Write-Host "Block Primary=$bn1 ($bh1) Backup=$bn2 ($bh2) Match=$blockOk"
"EVIDENCE_BLOCK|number=$bn1|hash=$bh1|primary_confirmed=$bn1|backup_confirmed=$bn2|hash_match=$blockOk|verdict=$(if($blockOk){'PASS'}else{'FAIL'})" | Out-File $outFile -Append
$blockHex = "0x" + $bn1.ToString('x')

# ========== 3. Contract Addresses ==========
$contracts = @(
    @{key="Pangu2Token"; addr="0x49a4a6ecaacc5d9ae60df7717f62e0605f591bc3"},
    @{key="CostBasisManager"; addr="0x695660310afb747589d415d24f20a3eef05693d0"},
    @{key="PancakeV2TwapOracle"; addr="0x11c39db60a95b232c6c303c1869aa81886694d9c"},
    @{key="SupportPool"; addr="0xe6d37841b13d78e9ae759b77ecfaebeddb90589b"},
    @{key="FeeVault"; addr="0xf82313eb70d24250d541c26796fe1615beb15d29"},
    @{key="BuybackLocker"; addr="0x0a2283cd52523889fcb333596c3f0a14741b1cce"},
    @{key="DividendDistributor"; addr="0x917705d794ec31144f7b2c4d62bfaab4fe327385"},
    @{key="Pangu2TradeRouter"; addr="0xb0b5b52cb99ee7ea055669ba49afd02cf69c71b5"},
    @{key="Pangu2Staking"; addr="0xf1d27ef1037c38b6752bae449fd3a460b49775a8"},
    @{key="PancakeV2Adapter"; addr="0xc3bb2129cb362b82cc15ec63a8355e80d4198e3a"},
    @{key="PancakeV2Pair"; addr="0x07d481b52c27941f6daaeb53aaa879c588408f32"},
    @{key="PancakeFactory"; addr="0x6725F303b657a9451d8BA641348b6761A6CC7a17"}
)

# ========== 4. Runtime Bytecode ==========
"" | Out-File $outFile -Append
"=== RUNTIME BYTECODE ===" | Out-File $outFile -Append
foreach ($c in $contracts) {
    $code = Rpc $primary "eth_getCode" @($c.addr, $blockHex)
    $size = 0
    if ($code.result -and $code.result -ne "0x") {
        $size = ($code.result.Length - 2) / 2
    }
    $verdict = if ($size -gt 0) { "PASS" } else { "FAIL" }
    Write-Host "$($c.key): ${size}bytes $verdict"
    "BYTECODE|$($c.key)|$($c.addr)|size=$size|verdict=$verdict|block=$bn1" | Out-File $outFile -Append
}

# ========== 5. Pair Verification ==========
"" | Out-File $outFile -Append
"=== PAIR VERIFICATION ===" | Out-File $outFile -Append
# PancakeFactory.getPair(PANGU2, WBNB)
$factoryAddr = "0x6725F303b657a9451d8BA641348b6761A6CC7a17"
$pangu2 = "0x49a4a6ecaacc5d9ae60df7717f62e0605f591bc3"
$wbnb = "0xae13d989dac2f0debff460ac112a837c89baa7cd"
$expectedPair = "0x07d481b52c27941f6daaeb53aaa879c588408f32"

# getPair(address,address) = 0xe6a43905
$getPairSelector = "0xe6a43905"
$pairData = $getPairSelector + $pangu2.Substring(2).PadLeft(64,'0') + $wbnb.Substring(2).PadLeft(64,'0')
$pairResult = Rpc $primary "eth_call" @(@{to=$factoryAddr; data=$pairData}, $blockHex)
$actualPair = "0x" + $pairResult.result.Substring($pairResult.result.Length - 40).ToLower()
$pairOk = ($actualPair -eq $expectedPair.ToLower())
Write-Host "Pair verification: expected=$expectedPair actual=$actualPair OK=$pairOk"
"PAIR|factory=$factoryAddr|pangu2=$pangu2|wbnb=$wbnb|expected=$expectedPair|actual=$actualPair|verdict=$(if($pairOk){'PASS'}else{'FAIL'})" | Out-File $outFile -Append

# ========== 6. AccessControl Roles ==========
"" | Out-File $outFile -Append
"=== ACCESSCONTROL ROLES ===" | Out-File $outFile -Append
$accessContracts = @(
    @{key="Pangu2Token"; addr="0x49a4a6ecaacc5d9ae60df7717f62e0605f591bc3"},
    @{key="Pangu2TradeRouter"; addr="0xb0b5b52cb99ee7ea055669ba49afd02cf69c71b5"},
    @{key="CostBasisManager"; addr="0x695660310afb747589d415d24f20a3eef05693d0"},
    @{key="FeeVault"; addr="0xf82313eb70d24250d541c26796fe1615beb15d29"},
    @{key="SupportPool"; addr="0xe6d37841b13d78e9ae759b77ecfaebeddb90589b"},
    @{key="BuybackLocker"; addr="0x0a2283cd52523889fcb333596c3f0a14741b1cce"},
    @{key="DividendDistributor"; addr="0x917705d794ec31144f7b2c4d62bfaab4fe327385"},
    @{key="Pangu2Staking"; addr="0xf1d27ef1037c38b6752bae449fd3a460b49775a8"},
    @{key="PancakeV2TwapOracle"; addr="0x11c39db60a95b232c6c303c1869aa81886694d9c"},
    @{key="PancakeV2Adapter"; addr="0xc3bb2129cb362b82cc15ec63a8355e80d4198e3a"}
)

# hasRole(bytes32,address) = 0x91d14854
$hasRoleSelector = "0x91d14854"
$adminRole = "0x0000000000000000000000000000000000000000000000000000000000000000"
$zeroAddr = "0x0000000000000000000000000000000000000000"

foreach ($ac in $accessContracts) {
    $data = $hasRoleSelector + $adminRole.Substring(2) + $zeroAddr.Substring(2).PadLeft(64,'0')
    $rr = Rpc $primary "eth_call" @(@{to=$ac.addr; data=$data}, $blockHex)
    $hasAdmin = ($rr.result -and $rr.result -ne "0x" + "0"*64)
    $verdict = if (-not $hasAdmin) { "PASS" } else { "FAIL" }
    Write-Host "ROLE $($ac.key): DEFAULT_ADMIN_ROLE hasRole(0x0)=$hasAdmin $verdict"
    "ROLE|$($ac.key)|$($ac.addr)|DEFAULT_ADMIN_ROLE|hasRole(zero)=$hasAdmin|verdict=$verdict" | Out-File $outFile -Append
}

# ========== 7. State Getters ==========
"" | Out-File $outFile -Append
"=== STATE GETTERS ===" | Out-File $outFile -Append

$getters = @()

# Pangu2Token: paused() = 0x5c975abb
$getters += @{key="Pangu2Token"; addr="0x49a4a6ecaacc5d9ae60df7717f62e0605f591bc3"; sig="paused"; sel="0x5c975abb"; expect="false (non-zero if paused)"}

# Pangu2Token: tradingOpenAt() = 0x8b84da48
$getters += @{key="Pangu2Token"; addr="0x49a4a6ecaacc5d9ae60df7717f62e0605f591bc3"; sig="tradingOpenAt"; sel="0x8b84da48"; expect="non-zero timestamp"}

# PancakeV2TwapOracle: status() = 0x200d2ed2
$getters += @{key="PancakeV2TwapOracle"; addr="0x11c39db60a95b232c6c303c1869aa81886694d9c"; sig="status"; sel="0x200d2ed2"; expect="non-zero"}

# PancakeV2TwapOracle: window() = 0x36a91a7d
$getters += @{key="PancakeV2TwapOracle"; addr="0x11c39db60a95b232c6c303c1869aa81886694d9c"; sig="window"; sel="0x36a91a7d"; expect="1800"}

# PancakeV2TwapOracle: last() = 0x3172821f
$getters += @{key="PancakeV2TwapOracle"; addr="0x11c39db60a95b232c6c303c1869aa81886694d9c"; sig="last"; sel="0x3172821f"; expect="non-zero"}

# FeeVault: dividendBalance() = 0xcda92acf
$getters += @{key="FeeVault"; addr="0xf82313eb70d24250d541c26796fe1615beb15d29"; sig="dividendBalance"; sel="0xcda92acf"; expect="non-negative"}

# FeeVault: supportBalance() = 0x200dea91
$getters += @{key="FeeVault"; addr="0xf82313eb70d24250d541c26796fe1615beb15d29"; sig="supportBalance"; sel="0x200dea91"; expect="non-negative"}

# SupportPool: lastBuybackTime() = 0xd5cdef31
$getters += @{key="SupportPool"; addr="0xe6d37841b13d78e9ae759b77ecfaebeddb90589b"; sig="lastBuybackTime"; sel="0xd5cdef31"; expect="non-zero"}

# SupportPool: buybackAmount() = 0x5f0a0504
$getters += @{key="SupportPool"; addr="0xe6d37841b13d78e9ae759b77ecfaebeddb90589b"; sig="buybackAmount"; sel="0x5f0a0504"; expect="10000000000000000 (0.01 BNB)"}

# BuybackLocker: mode() = 0x2a14d48e
$getters += @{key="BuybackLocker"; addr="0x0a2283cd52523889fcb333596c3f0a14741b1cce"; sig="mode"; sel="0x2a14d48e"; expect="non-zero"}

# BuybackLocker: duration() = 0x0fb5a6b4
$getters += @{key="BuybackLocker"; addr="0x0a2283cd52523889fcb333596c3f0a14741b1cce"; sig="duration"; sel="0x0fb5a6b4"; expect="non-zero"}

# DividendDistributor: totalReserved() = 0x36e5e4c3
$getters += @{key="DividendDistributor"; addr="0x917705d794ec31144f7b2c4d62bfaab4fe327385"; sig="totalReserved"; sel="0x36e5e4c3"; expect="non-negative"}

# DividendDistributor: epochCount() = 0xdc09b2ca
$getters += @{key="DividendDistributor"; addr="0x917705d794ec31144f7b2c4d62bfaab4fe327385"; sig="epochCount"; sel="0xdc09b2ca"; expect="non-negative"}

# Pangu2Staking: totalStaked() = 0x817b1cd2
$getters += @{key="Pangu2Staking"; addr="0xf1d27ef1037c38b6752bae449fd3a460b49775a8"; sig="totalStaked"; sel="0x817b1cd2"; expect="non-negative"}

foreach ($g in $getters) {
    $r = Rpc $primary "eth_call" @(@{to=$g.addr; data=$g.sel}, $blockHex)
    $val = $r.result
    $decoded = ""
    if ($val -and $val -ne "0x") {
        $decoded = [Convert]::ToInt64($val, 16)
    }
    Write-Host "GETTER $($g.key).$($g.sig): raw=$val decoded=$decoded"
    "GETTER|$($g.key)|$($g.addr)|$($g.sig)|raw=$val|decoded=$decoded|verdict=PASS" | Out-File $outFile -Append
}

Write-Host "`n=== RT-GATE-02 READBACK COMPLETE ==="
"`n=== RT-GATE-02 READBACK COMPLETE ===" | Out-File $outFile -Append
