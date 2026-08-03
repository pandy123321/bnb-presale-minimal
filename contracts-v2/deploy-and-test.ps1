<#
.SYNOPSIS
    PANGU2 V2 — Multi-stage Deploy + Bootstrap + Verify
.DESCRIPTION
    Stage 1: Deploy contracts (DeployPangu2.s.sol)
    Stage 2: Bootstrap liquidity + Oracle anchor (BootstrapPangu2.s.sol)
    Stage 3: Wait TWAP window (manual)
    Stage 4: Finalize Oracle readiness (FinalizePangu2.s.sol)
    Stage 5: Governance enables trading
    Set env vars GOVERNANCE_ADDRESS, DEPLOYER_PRIVATE_KEY etc. before running.
#>

param(
    [switch]$SkipDeploy,
    [switch]$Bootstrap,
    [switch]$Finalize,
    [switch]$VerifyOnly,
    [switch]$ForkTest,
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

# ── Banner ─────────────────────────────────────────────────────────
Write-Host @"

  PANGU2 V2 · BSC Testnet — Multi-stage Deployment

"@ -ForegroundColor Yellow

# ── Load .env ───────────────────────────────────────────────────────
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
    exit 1
}
Write-Pass "Foundry found"

$rpc = if ($RpcUrl) { $RpcUrl } elseif ($env:BSC_TESTNET_RPC) { $env:BSC_TESTNET_RPC } else { "https://data-seed-prebsc-1-s1.binance.org:8545" }
$depKey = $env:DEPLOYER_PRIVATE_KEY
$lpKey  = $env:LIQUIDITY_PROVIDER_PRIVATE_KEY
$gov    = $env:GOVERNANCE_ADDRESS

if (-not $depKey) { Write-Fail "DEPLOYER_PRIVATE_KEY not set"; exit 1 }

Write-Pass "RPC: $rpc"

# Verify RPC connectivity
$chain = & $CAST chain-id --rpc-url $rpc 2>$null
if ($chain -ne "97") {
    Write-Fail "Chain ID is $chain, expected 97 (BSC Testnet)"
    exit 1
}
Write-Pass "Chain ID: $chain (BSC Testnet)"

# ── Stage 1: Deploy ─────────────────────────────────────────────────
if (-not $SkipDeploy -and -not $Bootstrap -and -not $Finalize -and -not $VerifyOnly) {
    Write-Step "Stage 1: Deploying Contracts"

    Push-Location "$PSScriptRoot"
    $env:FOUNDRY_LIBS = $null

    & $FORGE script script/DeployPangu2.s.sol `
        --rpc-url $rpc `
        --broadcast `
        --private-key $depKey `
        --lib-paths ../contracts/lib `
        --gas-price 5000000000 `
        -vvvv 2>&1 | Tee-Object -Variable deployOutput | Out-Host

    Pop-Location

    Write-Info "Deploy complete. Run with -Bootstrap to add initial liquidity."
    exit 0
}

# ── Stage 2: Bootstrap ──────────────────────────────────────────────
if ($Bootstrap) {
    Write-Step "Stage 2: Bootstrap Liquidity"

    if (-not $lpKey) { Write-Fail "LIQUIDITY_PROVIDER_PRIVATE_KEY not set"; exit 1 }

    Push-Location "$PSScriptRoot"
    $env:PRIVATE_KEY = $lpKey  # temporary for forge script
    & $FORGE script script/BootstrapPangu2.s.sol `
        --rpc-url $rpc `
        --broadcast `
        --private-key $lpKey `
        --lib-paths ../contracts/lib `
        --gas-price 5000000000 `
        -vvvv 2>&1 | Out-Host
    Pop-Location

    Write-Info "Bootstrap complete. Wait for TWAP window, then run -Finalize."
    exit 0
}

# ── Stage 4: Finalize ───────────────────────────────────────────────
if ($Finalize) {
    Write-Step "Stage 4: Finalize Oracle"

    Push-Location "$PSScriptRoot"
    & $FORGE script script/FinalizePangu2.s.sol `
        --rpc-url $rpc `
        --broadcast `
        --private-key $depKey `
        --lib-paths ../contracts/lib `
        --gas-price 5000000000 `
        -vvvv 2>&1 | Out-Host
    Pop-Location

    Write-Info "Finalize complete. Governance may now enable trading."
    exit 0
}

# ── Verify Only ─────────────────────────────────────────────────────
if ($VerifyOnly) {
    Write-Step "Verifying Contracts"

    $token   = $env:PANGU2_TOKEN
    $router  = $env:PANGU2_ROUTER
    $div     = $env:PANGU2_DIVIDEND
    $pool    = $env:PANGU2_SUPPORTPOOL
    $vault   = $env:PANGU2_FEEVAULT
    $locker  = $env:PANGU2_LOCKER
    $pair    = $env:PANGU2_PAIR
    $adapter = $env:PANGU2_ADAPTER
    $oracle  = $env:PANGU2_ORACLE

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

    Write-Step "Results"
    Write-Host "  Passed: $pass  |  Failed: $fail" -ForegroundColor $(if ($fail -eq 0) { "Green" } else { "Red" })
    exit 0
}

# ── No flags: show help ─────────────────────────────────────────────
Write-Host @"

Usage:
  .\deploy-and-test.ps1              Stage 1: Deploy contracts
  .\deploy-and-test.ps1 -Bootstrap   Stage 2: Add liquidity + Oracle anchor
  .\deploy-and-test.ps1 -Finalize    Stage 4: Finalize Oracle (after TWAP window)
  .\deploy-and-test.ps1 -VerifyOnly  Verify deployed contracts

Environment variables required:
  DEPLOYER_PRIVATE_KEY
  GOVERNANCE_ADDRESS
  EMERGENCY_ADDRESS
  KEEPER_ADDRESS
  RELEASE_RECIPIENT_ADDRESS
  INITIAL_HOLDER_ADDRESS
  ROOT_PUBLISHER_ADDRESS
  MIN_TOKEN_RESERVE
  MIN_WBNB_RESERVE
  (Bootstrap:) LIQUIDITY_PROVIDER_PRIVATE_KEY, LIQUIDITY_PROVIDER_ADDRESS,
               INITIAL_LIQUIDITY_TOKENS, INITIAL_LIQUIDITY_BNB,
               MIN_LIQUIDITY_TOKENS, MIN_LIQUIDITY_BNB, LP_RECIPIENT
  (Finalize:)  ORACLE_TEST_AMOUNT

"@
exit 0
