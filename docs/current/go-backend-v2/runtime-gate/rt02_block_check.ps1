$primary = "https://bsc-testnet-rpc.publicnode.com"
$backup = "https://bsc-testnet.drpc.org"

function Rpc($url, $method, $params) {
    $body = @{ jsonrpc = "2.0"; method = $method; params = $params; id = 1 } | ConvertTo-Json -Compress -Depth 10
    return Invoke-RestMethod -Uri $url -Method Post -ContentType "application/json" -Body $body -TimeoutSec 30
}

# Get latest from Primary, then verify same block on Backup
$blk1 = Rpc $primary "eth_getBlockByNumber" @("latest", $false)
$bn1 = [Convert]::ToInt64($blk1.result.number, 16)
$bh1 = $blk1.result.hash
$blockHex = "0x" + $bn1.ToString('x')

Write-Host "Primary latest: block=$bn1 hash=$bh1"

# Check same block on Backup
$blk2 = Rpc $backup "eth_getBlockByNumber" @($blockHex, $false)
$bh2 = $blk2.result.hash
$match = ($bh1 -eq $bh2)
Write-Host "Backup same block: hash=$bh2 match=$match"

# Also check Backup latest
$blk3 = Rpc $backup "eth_getBlockByNumber" @("latest", $false)
$bn3 = [Convert]::ToInt64($blk3.result.number, 16)
$bh3 = $blk3.result.hash
Write-Host "Backup latest: block=$bn3 hash=$bh3"

Write-Host ""
Write-Host "=== VERDICT ==="
if ($match) {
    Write-Host "BLOCK_CONSENSUS = PASS (same block $bn1 identical on both RPCs)"
    Write-Host "EVIDENCE_BLOCK = $bn1"
    Write-Host "EVIDENCE_BLOCK_HASH = $bh1"
} else {
    Write-Host "BLOCK_CONSENSUS = FAIL"
    Write-Host "Primary block=$bn1 hash=$bh1"
    Write-Host "Backup block=$bn1 hash=$bh2"
}
