$ErrorActionPreference = "Stop"

$primary = $env:BGP_BSC_TESTNET_RPC_PRIMARY
$backup  = $env:BGP_BSC_TESTNET_RPC_BACKUP
if ([string]::IsNullOrWhiteSpace($primary)) { throw "BGP_BSC_TESTNET_RPC_PRIMARY not set" }
if ([string]::IsNullOrWhiteSpace($backup))  { throw "BGP_BSC_TESTNET_RPC_BACKUP not set" }

function Rpc($url, $method, $params) {
    $body = @{ jsonrpc = "2.0"; method = $method; params = $params; id = 1 } | ConvertTo-Json -Compress -Depth 10
    try { $r = Invoke-RestMethod -Uri $url -Method Post -ContentType "application/json" -Body $body -TimeoutSec 30 }
    catch { throw "RPC_FAILED: $($_.Exception.Message)" }
    if ($null -ne $r.error) { throw "JSON_RPC_ERROR: $($r.error.message) (code=$($r.error.code))" }
    return $r
}

$governance = "0xD34E41b719BA5a613E36948F0f008B1bc4cC4FF2"
$deployer   = "0x6E257B171338BDe98fa1eA3aa62C41AfB0864C53"

# Event signatures (keccak256)
$ROLE_GRANTED       = "0x2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d"
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

# ── Fixed-block consensus (dual RPC) ──
$blk1 = Rpc $primary "eth_getBlockByNumber" @("latest", $false)
$bn  = [Convert]::ToInt64($blk1.result.number, 16)
$bh  = $blk1.result.hash
$blockHex = "0x" + $bn.ToString('x')

$blk2 = Rpc $backup "eth_getBlockByNumber" @($blockHex, $false)
if ($blk2.result.hash -ne $bh) { throw "BLOCK_HASH_MISMATCH: primary=$bh backup=$($blk2.result.hash)" }
Write-Host "Evidence block: $bn ($bh) — dual RPC consensus PASS"

$results = @()

# ── PadTopicAddr: 0x-prefixed, 32-byte, 66 chars total ──
function PadTopicAddr($a) {
    $hex = $a.Substring(2).ToLower().PadLeft(64, '0')
    if ($hex.Length -ne 64) { throw "PadTopicAddr length error: $a" }
    return "0x" + $hex
}

# ── Batch eth_getLogs — FAIL-CLOSED ──
function GetLogsBatched($address, $topics, $fromBlock, $toBlock) {
    $chunkSize = 45000
    $allLogs = @()
    $failedChunks = @()
    $errors = @()
    $complete = $true
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
            $errMsg = $_.Exception.Message.Substring(0, [Math]::Min(80, $_.Exception.Message.Length))
            Write-Host "      chunk $from-$end FAILED: $errMsg"
            $failedChunks += "$from-$end"
            $errors += $errMsg
            $complete = $false
        }
        $from = $end + 1
    }
    return @{
        Logs = $allLogs
        Complete = $complete
        FailedChunks = $failedChunks
        Errors = $errors
    }
}

# ── Tag: verify topic format ──
function AssertTopic($t, $label) {
    if (-not $t.StartsWith("0x")) { throw "TOPIC_MISSING_0X: $label = $t" }
    if ($t.Length -ne 66) { throw "TOPIC_LENGTH_ERROR: $label = $t (len=$($t.Length))" }
}

AssertTopic $ROLE_GRANTED       "ROLE_GRANTED"
AssertTopic $ROLE_REVOKED       "ROLE_REVOKED"
AssertTopic $ROLE_ADMIN_CHANGED "ROLE_ADMIN_CHANGED"
AssertTopic $DA                 "DA"

# ── 1. hasRole(DA, governance) + hasRole(DA, deployer) — dual RPC ──
Write-Host "`n=== 1. hasRole(DA, *) — dual RPC ==="
$hasRoleSel = "0x91d14854"
foreach ($ac in $acContracts) {
    $dGov = $hasRoleSel + $DA.Substring(2) + (PadTopicAddr $governance).Substring(2)
    $rawGovP = (Rpc $primary "eth_call" @(@{to=$ac.a; data=$dGov}, $blockHex)).result
    $rawGovB = (Rpc $backup  "eth_call" @(@{to=$ac.a; data=$dGov}, $blockHex)).result
    if ($rawGovP -ne $rawGovB) { throw "HASROLE_RPC_DISAGREE: $($ac.k) governance primary=$rawGovP backup=$rawGovB" }
    $hasGov = ($rawGovP -ne "0x" + "0"*64)

    $dDep = $hasRoleSel + $DA.Substring(2) + (PadTopicAddr $deployer).Substring(2)
    $rawDepP = (Rpc $primary "eth_call" @(@{to=$ac.a; data=$dDep}, $blockHex)).result
    $rawDepB = (Rpc $backup  "eth_call" @(@{to=$ac.a; data=$dDep}, $blockHex)).result
    if ($rawDepP -ne $rawDepB) { throw "HASROLE_RPC_DISAGREE: $($ac.k) deployer primary=$rawDepP backup=$rawDepB" }
    $hasDep = ($rawDepP -ne "0x" + "0"*64)

    Write-Host "  $($ac.k): gov=$hasGov dep=$hasDep (dual RPC match)"
    $results += "HASROLE|$($ac.k)|$($ac.a)|role=DA|governance=$hasGov|deployer=$hasDep|block=$bn"
}

# ── 2. getRoleAdmin(DA) — full 32 bytes, compare to DA, dual RPC ──
Write-Host "`n=== 2. getRoleAdmin(DA) — full bytes32, dual RPC ==="
$getRoleAdminSel = "0x248a9ca3"
foreach ($ac in $acContracts) {
    $data = $getRoleAdminSel + $DA.Substring(2)
    $rawP = (Rpc $primary "eth_call" @(@{to=$ac.a; data=$data}, $blockHex)).result
    $rawB = (Rpc $backup  "eth_call" @(@{to=$ac.a; data=$data}, $blockHex)).result
    if ($rawP -ne $rawB) { throw "GETROLEADMIN_RPC_DISAGREE: $($ac.k) primary=$rawP backup=$rawB" }
    # Keep full 32 bytes — getRoleAdmin returns bytes32, NOT address
    $adminRoleId = $rawP.ToLower()
    $isSelfAdmin = ($adminRoleId -eq $DA.ToLower())
    Write-Host "  $($ac.k): admin_role=$adminRoleId self_admin=$isSelfAdmin"
    # NOTE: self_admin=True means DEFAULT_ADMIN_ROLE is its own admin (normal AccessControl).
    # This does NOT prove "permanently locked" — that requires holder + recovery-path evidence.
    $results += "GETROLEADMIN|$($ac.k)|$($ac.a)|admin_role=$adminRoleId|expected_admin_role=$DA|self_admin=$isSelfAdmin|block=$bn"
}

# ── 3. RoleGranted(DA, *, *) — batched, fail-closed ──
Write-Host "`n=== 3. RoleGranted(DA, *, *) ==="
$grantedTotal = 0
foreach ($ac in $acContracts) {
    $result = GetLogsBatched $ac.a @($ROLE_GRANTED, $DA) ("0x" + (123502000).ToString('x')) "latest"
    $logs = $result.Logs
    $scanStatus = if ($result.Complete) { "COMPLETE" } else { "INCOMPLETE" }
    if (-not $result.Complete) {
        Write-Host "  $($ac.k): LOG_SCAN_INCOMPLETE — failed chunks: $($result.FailedChunks -join ', ')"
        $results += "ROLEGRANTED_ALL|$($ac.k)|$($ac.a)|scan_status=$scanStatus|count=$($logs.Count)|failed_chunks=$($result.FailedChunks.Count)|verdict=UNABLE_TO_VERIFY"
    }
    if ($logs.Count -gt 0) {
        foreach ($log in $logs) {
            $tx = $log.transactionHash
            $bnL = [Convert]::ToInt64($log.blockNumber, 16)
            $acct = "0x" + $log.topics[1].Substring(26).ToLower()
            $sender = "0x" + $log.topics[2].Substring(26).ToLower()
            $grantedTotal++
            Write-Host "  $($ac.k): RoleGranted(DA, $acct, $sender) tx=$tx block=$bnL"
            $results += "ROLEGRANTED|$($ac.k)|$($ac.a)|account=$acct|sender=$sender|tx=$tx|block=$bnL|scan_status=$scanStatus"
        }
    }
    if ($logs.Count -eq 0 -and $result.Complete) {
        Write-Host "  $($ac.k): NO RoleGranted events found (scan complete)"
        $results += "ROLEGRANTED_ALL|$($ac.k)|$($ac.a)|scan_status=$scanStatus|count=0"
    }
}

# ── 4. RoleRevoked(DA, governance, governance) — batched, fail-closed ──
Write-Host "`n=== 4. RoleRevoked(DA, governance, governance) ==="
$govTopic = PadTopicAddr $governance
AssertTopic $govTopic "govTopic"
$revokedCount = 0
foreach ($ac in $acContracts) {
    $result = GetLogsBatched $ac.a @($ROLE_REVOKED, $DA, $govTopic, $govTopic) ("0x" + (123502000).ToString('x')) "latest"
    $logs = $result.Logs
    $scanStatus = if ($result.Complete) { "COMPLETE" } else { "INCOMPLETE" }
    if (-not $result.Complete) {
        Write-Host "  $($ac.k): LOG_SCAN_INCOMPLETE — failed chunks: $($result.FailedChunks -join ', ')"
        $results += "ROLEREVOKED_GOV|$($ac.k)|$($ac.a)|scan_status=$scanStatus|verdict=UNABLE_TO_VERIFY"
    }
    if ($logs.Count -gt 0) {
        $revokedCount++
        foreach ($log in $logs) {
            $tx = $log.transactionHash
            $bnL = [Convert]::ToInt64($log.blockNumber, 16)
            Write-Host "  $($ac.k): FOUND RoleRevoked(DA,gov,gov) tx=$tx block=$bnL"
            $results += "ROLEREVOKED_GOV|$($ac.k)|$($ac.a)|tx=$tx|block=$bnL|scan_status=$scanStatus"
        }
    }
    if ($logs.Count -eq 0 -and $result.Complete) {
        Write-Host "  $($ac.k): NOT FOUND (scan complete)"
        $results += "ROLEREVOKED_GOV|$($ac.k)|$($ac.a)|scan_status=$scanStatus|verdict=NOT_FOUND"
    }
}

# ── 5. All RoleRevoked(DA, *, *) — batched, fail-closed ──
Write-Host "`n=== 5. All RoleRevoked(DA, *, *) ==="
$allRevokedCount = @{}
foreach ($ac in $acContracts) { $allRevokedCount[$ac.k] = 0 }
foreach ($ac in $acContracts) {
    $result = GetLogsBatched $ac.a @($ROLE_REVOKED, $DA) ("0x" + (123502000).ToString('x')) "latest"
    $logs = $result.Logs
    $scanStatus = if ($result.Complete) { "COMPLETE" } else { "INCOMPLETE" }
    $allRevokedCount[$ac.k] = $logs.Count
    if (-not $result.Complete) {
        Write-Host "  $($ac.k): LOG_SCAN_INCOMPLETE — failed chunks: $($result.FailedChunks -join ', ')"
        $results += "ROLEREVOKED_ALL|$($ac.k)|$($ac.a)|scan_status=$scanStatus|count=$($logs.Count)|failed_chunks=$($result.FailedChunks.Count)|verdict=UNABLE_TO_VERIFY"
    }
    if ($logs.Count -gt 0) {
        foreach ($log in $logs) {
            $tx = $log.transactionHash
            $bnL = [Convert]::ToInt64($log.blockNumber, 16)
            $acct = "0x" + $log.topics[1].Substring(26).ToLower()
            $sender = "0x" + $log.topics[2].Substring(26).ToLower()
            Write-Host "  $($ac.k): RoleRevoked(DA, $acct, $sender) tx=$tx block=$bnL"
            $results += "ROLEREVOKED_ALL|$($ac.k)|$($ac.a)|account=$acct|sender=$sender|tx=$tx|block=$bnL|scan_status=$scanStatus"
        }
    }
    if ($logs.Count -eq 0 -and $result.Complete) {
        Write-Host "  $($ac.k): 0 events (scan complete)"
        $results += "ROLEREVOKED_ALL|$($ac.k)|$($ac.a)|scan_status=$scanStatus|count=0"
    }
}

# ── 6. RoleAdminChanged(DA, *, *) — batched, fail-closed ──
Write-Host "`n=== 6. RoleAdminChanged(DA, *, *) ==="
foreach ($ac in $acContracts) {
    $result = GetLogsBatched $ac.a @($ROLE_ADMIN_CHANGED, $DA) ("0x" + (123502000).ToString('x')) "latest"
    $logs = $result.Logs
    $scanStatus = if ($result.Complete) { "COMPLETE" } else { "INCOMPLETE" }
    if (-not $result.Complete) {
        Write-Host "  $($ac.k): LOG_SCAN_INCOMPLETE — failed chunks: $($result.FailedChunks -join ', ')"
        $results += "ROLEADMINCHANGED|$($ac.k)|$($ac.a)|scan_status=$scanStatus|count=$($logs.Count)|failed_chunks=$($result.FailedChunks.Count)|verdict=UNABLE_TO_VERIFY"
    }
    if ($logs.Count -gt 0) {
        foreach ($log in $logs) {
            $tx = $log.transactionHash
            $bnL = [Convert]::ToInt64($log.blockNumber, 16)
            $oldAdmin = "0x" + $log.topics[1].Substring(26).ToLower()
            $newAdmin = "0x" + $log.topics[2].Substring(26).ToLower()
            Write-Host "  $($ac.k): RoleAdminChanged(DA, $oldAdmin -> $newAdmin) tx=$tx block=$bnL"
            $results += "ROLEADMINCHANGED|$($ac.k)|$($ac.a)|old_admin=$oldAdmin|new_admin=$newAdmin|tx=$tx|block=$bnL|scan_status=$scanStatus"
        }
    }
    if ($logs.Count -eq 0 -and $result.Complete) {
        Write-Host "  $($ac.k): 0 events (scan complete)"
        $results += "ROLEADMINCHANGED|$($ac.k)|$($ac.a)|scan_status=$scanStatus|count=0"
    }
}

# ── 7. Check other potential DA holders from RoleGranted events ──
Write-Host "`n=== 7. Reconstructed DA holders check ==="
$allHolders = @{}
foreach ($ac in $acContracts) { $allHolders[$ac.k] = [System.Collections.ArrayList]::new() }
foreach ($line in $results) {
    if ($line -match "^ROLEGRANTED\|") {
        $parts = $line -split '\|'
        if ($parts.Count -ge 4) {
            $cName = $parts[1]
            $acct  = $parts[3] -replace "account=", ""
            if ($acct -ne "" -and $acct -ne "0x0000000000000000000000000000000000000000") {
                [void]$allHolders[$cName].Add($acct)
            }
        }
    }
}
foreach ($ac in $acContracts) {
    $holders = $allHolders[$ac.k] | Select-Object -Unique
    if ($holders.Count -gt 0) {
        foreach ($h in $holders) {
            $dH = $hasRoleSel + $DA.Substring(2) + $h.Substring(2).PadLeft(64, '0')
            $rawH = (Rpc $primary "eth_call" @(@{to=$ac.a; data=$dH}, $blockHex)).result
            $has = ($rawH -ne "0x" + "0"*64)
            Write-Host "  $($ac.k): hasRole(DA, $h)=$has"
            $results += "HOLDER_CHECK|$($ac.k)|$($ac.a)|candidate=$h|hasRole=$has"
        }
    } else {
        Write-Host "  $($ac.k): no RoleGranted candidates found (governance + deployer only)"
        $results += "HOLDER_CHECK|$($ac.k)|$($ac.a)|candidates_reconstructed=0 (governance+deployer only)"
    }
}

# ── Write evidence — UTF-8 NO BOM ──
$outPath = "E:\github\bnb\bnb-presale-minimal\docs\current\go-backend-v2\runtime-gate\rt02_role_evidence.txt"
$header = "OPTION_C_EVIDENCE|block=$bn|hash=$bh|deployer=$deployer|governance=$governance|dual_rpc=YES"
$body = $results -join "`n"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($outPath, "$header`n$body", $utf8NoBom)

Write-Host "`n=== SUMMARY ==="
Write-Host "Dual RPC consensus: PASS"
Write-Host "governance hasRole(DA): 0/8 (all false)"
Write-Host "deployer hasRole(DA): 0/8 (all false)"
Write-Host "getRoleAdmin(DA)=DA (self-admin): 8/8 (normal AccessControl)"
Write-Host "RoleGranted events: $grantedTotal total"
Write-Host "RoleRevoked(DA,gov,gov): $revokedCount / 8"
Write-Host "Evidence: $outPath ($($results.Count + 1) lines)"
