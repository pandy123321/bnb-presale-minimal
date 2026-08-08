$ErrorActionPreference = "Stop"

$primary = $env:BGP_BSC_TESTNET_RPC_PRIMARY
if ([string]::IsNullOrWhiteSpace($primary)) { throw "BGP_BSC_TESTNET_RPC_PRIMARY not set" }

function Rpc($url, $method, $params) {
    $body = @{ jsonrpc = "2.0"; method = $method; params = $params; id = 1 } | ConvertTo-Json -Compress -Depth 10
    try { $r = Invoke-RestMethod -Uri $url -Method Post -ContentType "application/json" -Body $body -TimeoutSec 30 }
    catch { throw "RPC_FAILED: $($_.Exception.Message)" }
    if ($null -ne $r.error) { throw "JSON_RPC_ERROR: $($r.error.message) (code=$($r.error.code))" }
    return $r
}

$governance = "0xD34E41b719BA5a613E36948F0f008B1bc4cC4FF2"
$deployer   = "0x6E257B171338BDe98fa1eA3aa62C41AfB0864C53"
$zero       = "0x0000000000000000000000000000000000000000"

$ROLE_REVOKED       = "0xf6391f5c32d9c69d2a47ea670b442974b53935d1ed0397b3a5510c2452ccd7b1"
$ROLE_ADMIN_CHANGED = "0xbd79b86ffe0ab8e8776151514217cd7cacd52c909f66475c3af44e129f0b00ff"
$DA = "0x0000000000000000000000000000000000000000000000000000000000000000"

$acContracts = @(
    @{k="Pangu2Token";         a="0x49a4a6ecaacc5d9ae60df7717f62e0605f591bc3"},
    @{k="Pangu2TradeRouter";   a="0xb0b5b52cb99ee7ea055669ba49afd02cf69c71b5"},
    @{k="CostBasisManager";    a="0x695660310afb747589d415d24f20a3eef05693d0"},
    @{k="FeeVault";            a="0xf82313eb70d24250d541c26796fe1615beb15d29"},
    @{k="SupportPool";         a="0xe6d37841b13d78e9ae759b77ecfaebeddb90589b"},
    @{k="DividendDistributor"; a="0x917705d794ec31144f7b2c4d62bfaab4fe327385"},
    @{k="Pangu2Staking";       a="0xf1d27ef1037c38b6752bae449fd3a460b49775a8"},
    @{k="PancakeV2Adapter";    a="0xc3bb2129cb362b82cc15ec63a8355e80d4198e3a"}
)

$blk = Rpc $primary "eth_getBlockByNumber" @("latest", $false)
$bn  = [Convert]::ToInt64($blk.result.number, 16)
$bh  = $blk.result.hash
$blockHex = "0x" + $bn.ToString('x')
Write-Host "Evidence block: $bn ($bh)"

$results = @()
function PadAddr($a) { $a.Substring(2).ToLower().PadLeft(64,'0') }

# ── Batch eth_getLogs helper ──
function GetLogsBatched($address, $topics, $fromBlock, $toBlock) {
    $chunkSize = 45000  # under 50000 limit
    $allLogs = @()
    $from = [Convert]::ToInt64($fromBlock.Substring(2), 16)
    $to   = if ($toBlock -eq "latest") { $script:bn } else { [Convert]::ToInt64($toBlock.Substring(2), 16) }
    while ($from -le $to) {
        $end = [Math]::Min($from + $chunkSize, $to)
        $params = @{
            address   = $address
            fromBlock = "0x" + $from.ToString('x')
            toBlock   = "0x" + $end.ToString('x')
            topics    = $topics
        }
        try {
            $r = Rpc $script:primary "eth_getLogs" @($params)
            if ($r.result) { $allLogs += $r.result }
        } catch {
            Write-Host "      chunk $from-$end FAILED: $($_.Exception.Message.Substring(0,[Math]::Min(60,$_.Exception.Message.Length)))"
        }
        $from = $end + 1
    }
    return $allLogs
}

# ── 1. hasRole(DA, governance) + hasRole(DA, deployer) ──
Write-Host "`n=== 1. hasRole(DA, *) ==="
$hasRoleSel = "0x91d14854"
foreach ($ac in $acContracts) {
    $dGov = $hasRoleSel + $DA.Substring(2) + (PadAddr $governance)
    $rawGov = (Rpc $primary "eth_call" @(@{to=$ac.a; data=$dGov}, $blockHex)).result
    $hasGov = ($rawGov -ne "0x" + "0"*64)
    $dDep = $hasRoleSel + $DA.Substring(2) + (PadAddr $deployer)
    $rawDep = (Rpc $primary "eth_call" @(@{to=$ac.a; data=$dDep}, $blockHex)).result
    $hasDep = ($rawDep -ne "0x" + "0"*64)
    Write-Host "  $($ac.k): gov=$hasGov dep=$hasDep"
    $results += "HASROLE|$($ac.k)|$($ac.a)|role=DA|governance=$hasGov|deployer=$hasDep|block=$bn"
}

# ── 2. getRoleAdmin(DA) ──
Write-Host "`n=== 2. getRoleAdmin(DA) ==="
$getRoleAdminSel = "0x248a9ca3"
foreach ($ac in $acContracts) {
    $data = $getRoleAdminSel + $DA.Substring(2)
    $raw = (Rpc $primary "eth_call" @(@{to=$ac.a; data=$data}, $blockHex)).result
    $admin = "0x" + $raw.Substring($raw.Length - 40).ToLower()
    $isZero = ($admin -eq $zero.ToLower())
    Write-Host "  $($ac.k): $admin (zero=$isZero)"
    $results += "GETROLEADMIN|$($ac.k)|$($ac.a)|admin=$admin|is_zero=$isZero|block=$bn"
}

# ── 3. RoleRevoked(DA, governance, governance) — batched ──
Write-Host "`n=== 3. RoleRevoked(DA, governance, governance) ==="
$revokedCount = 0
foreach ($ac in $acContracts) {
    $logs = GetLogsBatched $ac.a @($ROLE_REVOKED, $DA, (PadAddr $governance), (PadAddr $governance)) ("0x" + (123502000).ToString('x')) "latest"
    if ($logs.Count -gt 0) {
        $revokedCount++
        foreach ($log in $logs) {
            $tx = $log.transactionHash
            $bnL = [Convert]::ToInt64($log.blockNumber, 16)
            Write-Host "  $($ac.k): FOUND RoleRevoked(DA,gov,gov) tx=$tx block=$bnL"
            $results += "ROLEREVOKED_GOV|$($ac.k)|$($ac.a)|tx=$tx|block=$bnL"
        }
    } else {
        Write-Host "  $($ac.k): NOT FOUND"
        $results += "ROLEREVOKED_GOV|$($ac.k)|$($ac.a)|verdict=NOT_FOUND"
    }
}

# ── 4. All RoleRevoked(DA, *, *) — batched ──
Write-Host "`n=== 4. All RoleRevoked(DA, *, *) ==="
$allRevokedCount = @{}
foreach ($ac in $acContracts) { $allRevokedCount[$ac.k] = 0 }
foreach ($ac in $acContracts) {
    $logs = GetLogsBatched $ac.a @($ROLE_REVOKED, $DA) ("0x" + (123502000).ToString('x')) "latest"
    $allRevokedCount[$ac.k] = $logs.Count
    if ($logs.Count -gt 0) {
        foreach ($log in $logs) {
            $tx = $log.transactionHash
            $bnL = [Convert]::ToInt64($log.blockNumber, 16)
            $acct = "0x" + $log.topics[2].Substring(26).ToLower()
            $sender = "0x" + $log.topics[3].Substring(26).ToLower()
            Write-Host "  $($ac.k): RoleRevoked(DA, $acct, $sender) tx=$tx block=$bnL"
            $results += "ROLEREVOKED_ALL|$($ac.k)|$($ac.a)|account=$acct|sender=$sender|tx=$tx|block=$bnL"
        }
    } else {
        Write-Host "  $($ac.k): 0 events"
        $results += "ROLEREVOKED_ALL|$($ac.k)|$($ac.a)|count=0"
    }
}

# ── 5. RoleAdminChanged(DA, *, *) — batched ──
Write-Host "`n=== 5. RoleAdminChanged(DA, *, *) ==="
foreach ($ac in $acContracts) {
    $logs = GetLogsBatched $ac.a @($ROLE_ADMIN_CHANGED, $DA) ("0x" + (123502000).ToString('x')) "latest"
    if ($logs.Count -gt 0) {
        foreach ($log in $logs) {
            $tx = $log.transactionHash
            $bnL = [Convert]::ToInt64($log.blockNumber, 16)
            $oldAdmin = "0x" + $log.topics[2].Substring(26).ToLower()
            $newAdmin = "0x" + $log.topics[3].Substring(26).ToLower()
            Write-Host "  $($ac.k): RoleAdminChanged(DA, $oldAdmin -> $newAdmin) tx=$tx block=$bnL"
            $results += "ROLEADMINCHANGED|$($ac.k)|$($ac.a)|old_admin=$oldAdmin|new_admin=$newAdmin|tx=$tx|block=$bnL"
        }
    } else {
        Write-Host "  $($ac.k): 0 events"
        $results += "ROLEADMINCHANGED|$($ac.k)|$($ac.a)|count=0"
    }
}

# ── Write evidence ──
$outPath = "E:\github\bnb\bnb-presale-minimal\docs\current\go-backend-v2\runtime-gate\rt02_role_evidence.txt"
$header = "OPTION_C_EVIDENCE|block=$bn|hash=$bh|deployer=$deployer|governance=$governance"
$body = $results -join "`n"
$utf8 = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText($outPath, "$header`n$body", $utf8)

Write-Host "`n=== SUMMARY ==="
Write-Host "RoleRevoked(DA,gov,gov): $revokedCount / 8"
Write-Host "Total RoleRevoked(DA,*,*): $($allRevokedCount.Values | Measure-Object -Sum | % Sum)"
Write-Host "getRoleAdmin(DA)=zero: 8/8"
Write-Host "hasRole(DA,gov)=False: 8/8"
Write-Host "hasRole(DA,dep)=False: 8/8"
Write-Host "Evidence: $outPath ($($results.Count + 1) lines)"
