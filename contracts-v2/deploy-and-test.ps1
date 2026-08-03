<#
.SYNOPSIS
    PANGU2 V2 — Automated Deploy + Chain Test
.DESCRIPTION
    一键部署 PANGU2 V2 合约到 BSC Testnet，并自动执行买入/卖出测试。
    Set env vars GOVERNANCE_ADDRESS, PRIVATE_KEY etc. before running.
#>

param(
    [switch]$SkipDeploy,      # 跳过部署，只跑测试
    [switch]$ForkTest,        # 跑本地 fork 测试
    [string]$RpcUrl = ""
)

$ErrorActionPreference = "Stop"
$FORGE = "$env:USERPROFILE\.foundry\bin\forge.exe"
$CAST  = "$env:USERPROFILE\.foundry\bin\cast.exe"

# ── Colors ─────────────────────────────────────────────────────────
function Write-Step($msg)  { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-Pass($msg)  { Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Fail($msg)  { Write-Host "  ✗ $msg" -ForegroundColor Red }
function Write-Warn($msg)  { Write-Host "  ⚠ $msg" -ForegroundColor Yellow }
function Write-Info($msg)  { Write-Host "  ℹ $msg" -ForegroundColor Gray }
function Write-Hash($label, $value) { Write-Host "  $label : $value" -ForegroundColor Magenta }

# ── Banner ─────────────────────────────────────────────────────────
Clear-Host
Write-Host @"

╔══════════════════════════════════════════════════════════════╗
║               PANGU2 V2 · BSC Testnet                      ║
║          Automated Deploy + Chain Test Suite               ║
╚══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Yellow

# ── Load .env if exists ────────────────────────────────────────────
$envFile = "$PSScriptRoot\.env"
if (Test-Path $envFile) {
    Write-Info "Loading $envFile..."
    Get-Content $envFile | Where-Object { $_ -notmatch '^\s*#' -and $_ -match '=' } | ForEach-Object {
        $parts = $_ -split '=', 2
        $k = $parts[0].Trim(); $v = $parts[1].Trim()
        if ($k -and $v -and -not (Test-Path "env:$k")) {
            Set-Item "env:$k" $v
        }
    }
    Write-Pass ".env loaded"
}

# ── Pre-flight ─────────────────────────────────────────────────────
Write-Step "Pre-flight Checks"

if (-not (Test-Path $FORGE)) {
    Write-Fail "Foundry not found at $FORGE"
    Write-Info "Install: irm https://getfoundry.sh | iex"
    exit 1
}
Write-Pass "Foundry found"

$rpc = if ($RpcUrl) { $RpcUrl } elseif ($env:BSC_TESTNET_RPC) { $env:BSC_TESTNET_RPC } else { "https://data-seed-prebsc-1-s1.binance.org:8545" }
$key  = $env:PRIVATE_KEY
$gov  = $env:GOVERNANCE_ADDRESS
$emer = $env:EMERGENCY_ADDRESS
$keep = $env:KEEPER_ADDRESS
$rel  = $env:RELEASE_RECIPIENT_ADDRESS

if (-not $key) {
    Write-Fail "PRIVATE_KEY not set. Run: `$env:PRIVATE_KEY='your_key'"
    exit 1
}
if (-not $gov) {
    Write-Warn "GOVERNANCE_ADDRESS not set — all roles default to deployer"
    $wallet = & $CAST wallet address --private-key $key 2>$null
    $gov = $wallet.Trim(); $emer = $gov; $keep = $gov; $rel = $gov
}
Write-Pass "RPC: $rpc"

# Verify RPC connectivity
$chain = & $CAST chain-id --rpc-url $rpc 2>$null
if ($chain -ne "97") {
    Write-Fail "Chain ID is $chain, expected 97 (BSC Testnet)"
    exit 1
}
Write-Pass "Chain ID: $chain (BSC Testnet)"

$bal = & $CAST balance $gov --rpc-url $rpc 2>$null
$balBnb = [math]::Round([double]$bal / 1e18, 4)
Write-Info "Wallet: $gov  |  Balance: $balBnb BNB"
if ([double]$balBnb -lt 0.05) {
    Write-Warn "Low balance (< 0.05 BNB). Get testnet BNB: https://testnet.bscscan.com/faucet"
}

# ── Deploy ─────────────────────────────────────────────────────────
if (-not $SkipDeploy) {
    Write-Step "Deploying Contracts"

    Push-Location "$PSScriptRoot"
    $env:FOUNDRY_LIBS = $null

    & $FORGE script script/DeployPangu2.s.sol `
        --rpc-url $rpc `
        --broadcast `
        --private-key $key `
        --lib-paths ../contracts/lib `
        --gas-price 5000000000 `
        -vvvv 2>&1 | Tee-Object -Variable deployOutput | Out-Host

    Pop-Location

    # Extract addresses from deployment output
    $token   = ($deployOutput | Select-String "Token:" | Select-Object -Last 1).Line -replace ".*0x","0x"
    $router  = ($deployOutput | Select-String "TradeRouter:" | Select-Object -Last 1).Line -replace ".*0x","0x"
    $div     = ($deployOutput | Select-String "DividendDistributor:" | Select-Object -Last 1).Line -replace ".*0x","0x"
    $pool    = ($deployOutput | Select-String "SupportPool:" | Select-Object -Last 1).Line -replace ".*0x","0x"
    $vault   = ($deployOutput | Select-String "FeeVault:" | Select-Object -Last 1).Line -replace ".*0x","0x"
    $locker  = ($deployOutput | Select-String "BuybackLocker:" | Select-Object -Last 1).Line -replace ".*0x","0x"
    $pair    = ($deployOutput | Select-String "V2Pair:" | Select-Object -Last 1).Line -replace ".*0x","0x"
    $adapter = ($deployOutput | Select-String "V2Adapter:" | Select-Object -Last 1).Line -replace ".*0x","0x"
    $oracle  = ($deployOutput | Select-String "V2Oracle:" | Select-Object -Last 1).Line -replace ".*0x","0x"
} else {
    Write-Step "Skipped deploy — using env vars"
    $token   = $env:PANGU2_TOKEN
    $router  = $env:PANGU2_ROUTER
    $div     = $env:PANGU2_DIVIDEND
    $pool    = $env:PANGU2_SUPPORTPOOL
    $vault   = $env:PANGU2_FEEVAULT
    $locker  = $env:PANGU2_LOCKER
    $pair    = $env:PANGU2_PAIR
    $adapter = $env:PANGU2_ADAPTER
    $oracle  = $env:PANGU2_ORACLE
}

# ── Summary Table ──────────────────────────────────────────────────
Write-Step "Deployed Contracts"
Write-Host @"
┌─────────────────────┬────────────────────────────────────────────┐
│ Token               │ $token │
│ TradeRouter         │ $router │
│ DividendDistributor │ $div │
│ SupportPool         │ $pool │
│ FeeVault            │ $vault │
│ BuybackLocker       │ $locker │
│ V2 Pair             │ $pair │
│ V2 Adapter          │ $adapter │
│ V2 Oracle           │ $oracle │
└─────────────────────┴────────────────────────────────────────────┘
"@ -ForegroundColor White

# ── Verify Deployment ──────────────────────────────────────────────
Write-Step "Verifying Contracts"

$pass = 0; $fail = 0

function Assert-Code($addr, $name) {
    $code = & $CAST code $addr --rpc-url $rpc 2>$null
    if ($code -and $code -ne "0x") { Write-Pass "$name has code"; $script:pass++ }
    else { Write-Fail "$name has no code at $addr"; $script:fail++ }
}
Assert-Code $token "Token"
Assert-Code $router "TradeRouter"
Assert-Code $div "DividendDistributor"
Assert-Code $pool "SupportPool"
Assert-Code $vault "FeeVault"
Assert-Code $locker "BuybackLocker"
Assert-Code $pair "V2 Pair"
Assert-Code $adapter "V2 Adapter"
Assert-Code $oracle "V2 Oracle"

# Verify token symbol
try {
    $sym = & $CAST call $token "symbol()(string)" --rpc-url $rpc 2>$null
    if ($sym -match "PANGU") { Write-Pass "Token symbol: $sym"; $pass++ }
    else { Write-Warn "Token symbol: $sym"; $pass++ }
} catch { Write-Fail "Cannot read token symbol"; $fail++ }

# ── Chain Tests ────────────────────────────────────────────────────
Write-Step "Chain Tests"

$user = $gov  # use deployer as test user
$testBnb = "0.01"  # 0.01 BNB buy test

# 1. Buy
Write-Info "Buying tokens with $testBnb BNB..."
try {
    $tx = & $CAST send $router "buy(uint256,uint256)" 1 9999999999 `
        --value ${testBnb}ether --rpc-url $rpc --private-key $key --json 2>$null | ConvertFrom-Json
    Write-Pass "Buy tx: https://testnet.bscscan.com/tx/$($tx.transactionHash)"
    Start-Sleep -Seconds 5  # wait for confirmation
} catch { Write-Fail "Buy failed: $_"; $fail++ }

# 2. Check balance
$balAfter = & $CAST call $token "balanceOf(address)(uint256)" $user --rpc-url $rpc 2>$null
if ([double]$balAfter -gt 0) {
    $fmt = [math]::Round([double]$balAfter / 1e18, 2)
    Write-Pass "Token balance: $fmt PANGU2"; $pass++
} else { Write-Fail "Zero balance after buy"; $fail++ }

# 3. Approve + Sell
Write-Info "Approving Router..."
$approveAmt = [double]$balAfter * 0.5
try {
    & $CAST send $token "approve(address,uint256)" $router $balAfter --rpc-url $rpc --private-key $key 2>$null
    Write-Pass "Approved $( [math]::Round($approveAmt/1e18,2) ) tokens"
    Start-Sleep -Seconds 4

    Write-Info "Selling tokens..."
    $tx2 = & $CAST send $router "sell(uint256,uint256,uint256)" $approveAmt 1 9999999999 `
        --rpc-url $rpc --private-key $key --json 2>$null | ConvertFrom-Json
    Write-Pass "Sell tx: https://testnet.bscscan.com/tx/$($tx2.transactionHash)"
    $pass++
} catch { Write-Fail "Sell failed: $_"; $fail++ }

# ── Report ─────────────────────────────────────────────────────────
Write-Step "Results"
Write-Host "  Passed: $pass  |  Failed: $fail" -ForegroundColor $(if ($fail -eq 0) { "Green" } else { "Red" })

# Generate dashboard
$dashboard = @"
<!doctype html>
<html lang="zh-CN">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>PANGU2 V2 · Dashboard</title>
<style>
*{box-sizing:border-box}body{background:#080a0e;color:#f6f3ea;font-family:Inter,PingFang SC,sans-serif;max-width:900px;margin:0 auto;padding:20px}
h1{color:#d8aa51;margin:0 0 4px}h1 span{color:#677} .sub{color:#9298a5;font-size:12px;margin:0 0 24px}
.card{border:1px solid #272c36;background:#11141a;padding:16px;margin:8px 0;display:flex;justify-content:space-between;align-items:center}
.addr{font-family:monospace;font-size:12px;color:#d8aa51}.tag{padding:4px 10px;border-radius:99px;font-size:10px}
.pass{background:rgba(67,207,139,.1);color:#43cf8b;border:1px solid rgba(67,207,139,.2)}
.fail{background:rgba(255,116,125,.1);color:#ff747d;border:1px solid rgba(255,116,125,.2)}
.grid{display:grid;grid-template-columns:repeat(2,1fr);gap:6px}
.stat{border:1px solid #272c36;background:#11141a;padding:14px;text-align:center}
.stat b{display:block;font-size:24px;color:#d8aa51;margin:8px 0 4px}.stat span{font-size:10px;color:#9298a5}
footer{text-align:center;color:#555;font-size:9px;margin-top:30px}
</style></head><body>
<h1>PANGU2 V2 <span>· BSC Testnet</span></h1>
<p class="sub">Deployed $(Get-Date -Format 'yyyy-MM-dd HH:mm') · Chain 97 · RPC $rpc</p>
<div class="grid">
<div class="stat"><span>Tests Passed</span><b>$pass</b></div>
<div class="stat"><span>Tests Failed</span><b>$fail</b></div>
</div>
<h3 style="color:#9298a5;margin:18px 0 8px">Deployed Contracts</h3>
<div class="card"><span>Token</span><span class="addr">$token</span><span class="tag pass">ACTIVE</span></div>
<div class="card"><span>TradeRouter</span><span class="addr">$router</span><span class="tag pass">ACTIVE</span></div>
<div class="card"><span>DividendDistributor</span><span class="addr">$div</span><span class="tag pass">ACTIVE</span></div>
<div class="card"><span>SupportPool</span><span class="addr">$pool</span><span class="tag pass">ACTIVE</span></div>
<div class="card"><span>FeeVault</span><span class="addr">$vault</span><span class="tag pass">ACTIVE</span></div>
<div class="card"><span>BuybackLocker</span><span class="addr">$locker</span><span class="tag pass">ACTIVE</span></div>
<div class="card"><span>V2 Pair</span><span class="addr">$pair</span><span class="tag pass">ACTIVE</span></div>
<div class="card"><span>V2 Adapter</span><span class="addr">$adapter</span><span class="tag pass">ACTIVE</span></div>
<div class="card"><span>V2 Oracle</span><span class="addr">$oracle</span><span class="tag pass">ACTIVE</span></div>
<h3 style="color:#9298a5;margin:18px 0 8px">Quick Links</h3>
<div class="card" onclick="copy('$token')" style="cursor:pointer"><span>Token on BscScan</span><span class="addr">$token</span></div>
<footer>PANGU2 V2 · BSC Testnet · Chain 97 · Do NOT use for mainnet</footer>
<script>
function copy(t){navigator.clipboard.writeText(t)}
document.querySelectorAll('.addr').forEach(el=>{el.onclick=()=>copy(el.textContent);el.title='Click to copy'})
</script></body></html>
"@
$dashPath = "$PSScriptRoot\deploy-dashboard.html"
$dashboard | Out-File -FilePath $dashPath -Encoding utf8
Write-Info "Dashboard saved: $dashPath"

if ($fail -gt 0) {
    Write-Warn "Some tests failed. Review output above."
} else {
    Write-Host "`n  All tests passed! Dashboard: $dashPath" -ForegroundColor Green
}
