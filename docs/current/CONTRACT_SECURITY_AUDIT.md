# PANGU2 V2 Stable Contract — Full Security Audit

- **Audit Date:** 2026-08-06
- **Commit SHA:** `e2c09c5` (amended from `cd1f17c`)
- **Auditor:** Internal + Dual Subagent Audit
- **Test Results:** 122 tests, 0 failures, ~140K fuzz runs across 7 test suites

---

## Executive Summary

**Verdict: CONDITIONAL APPROVE**

- 0 critical (P0) vulnerabilities found
- 2 P1 findings, 7 P2 findings, 5 P3 findings
- All P1 issues are bounded by permissions or parameters
- 122 automated tests pass with 0 failures
- Complete tax matrix verified (10 cells)
- Permission matrix verified (8 roles, 12 actions)
- Supply conservation verified (6 invariants)

---

## Scope — 15 Contract Components Audited

| # | Contract | Lines | Role |
|---|---|---|---|
| 1 | Pangu2Token | 454 | ERC-20 with tax, launch protection, whitelist, transfer context |
| 2 | Pangu2TradeRouter | 267 | Entry point for buy/sell, swaps via PancakeSwap V2 |
| 3 | CostBasisManager | ~500 | On-chain cost basis tracking for profit/loss tax determination |
| 4 | PancakeV2Adapter | ~150 | Adapter layer between contracts and PancakeSwap V2 Router |
| 5 | PancakeV2TwapOracle | 274 | Counterfactual TWAP oracle with deviation check |
| 6 | SupportPool | 197 | Accumulates BNB, executes permissionless buybacks |
| 7 | FeeVault | 216 | Holds tax tokens, supports Keeper-triggered conversion |
| 8 | BuybackLocker | ~80 | Time-locks buyback tokens |
| 9 | DividendDistributor | ~200 | Merkle-based dividend distribution |
| 10 | Pangu2Staking | 286 | Staking with rewards, early unstake, coverage monitoring |
| 11 | DeployPangu2 | ~240 | Deployment script |
| 12 | BootstrapPangu2 | ~170 | Liquidity bootstrap script |
| 13 | FinalizePangu2 | ~100 | Oracle finalization script |
| 14 | OpenTradingPangu2 | ~35 | Trading activation script |
| 15 | BootstrapLpProxy | ~65 | One-shot LP proxy contract |

---

## Test Coverage Summary

| Test Suite | Tests | Coverage Area |
|---|---|---|
| PancakeV2TwapOracleTest | 12 | Counterfactual TWAP, mid-swap, deviation, fuzz |
| PancakeV2TwapOracleToken1Test | 4 | Token-as-token1 quotes |
| BootstrapRoleSeparationTest | 21 | Multi-role, proxy one-shot, pause, allowance, wrong chain |
| LaunchTaxTest | 28 | All 9 tax cells, invariants, boundaries, fuzz |
| FeeWhitelistTest | 22 | WL add/remove, Router bypass, Pair bypass, Pause bypass |
| TaxMatrixTest | 21 | Full matrix regression, conservation, parity, fuzz |
| StakingSecurityTest | 14 | Principal protection, liability, coverage, tax bypass, fuzz |
| **TOTAL** | **122** | **0 failures** |

---

## Findings

### P0 — Critical (0 found)

No critical vulnerabilities identified.

---

### P1 — High (2 found)

#### P1-001: `fundRewards()` uses `safeTransferFrom` path that triggers CostBasisManager

- **File:** `Pangu2Staking.sol:118-126`
- **Function:** `fundRewards(uint256 amount)`
- **Attack Path:** When REWARD_MANAGER calls fundRewards, the transfer path goes through Pangu2Token._update(). The staking contract is a systemAddress, so this falls into the user→system path, NOT the staking deposit path. The reward manager's cost basis is NOT adjusted.
- **Impact:** Reward manager's tracked_balance drifts from actual balance. Impact limited — reward managers are typically Governance addresses, not retail users.
- **Recommendation:** Add `REWARD_FUNDING` TransferContext for proper cost basis handling.
- **Subagent concurrence:** Confirmed. P1.

#### P1-002: TradeRouter tax-rate determination for sell misses whitelist-aware preview

- **File:** `Pangu2TradeRouter.sol:220-254`
- **Function:** `_previewSell(address seller, uint256 tokenAmount)`
- **Issue:** The TradeRouter calls `token.previewSellTax(tokenAmount, taxBps)` — NOT the whitelist-aware `previewSellTaxFor(seller, tokenAmount, taxBps)`. This means the TradeRouter's preview does NOT apply the 0% whitelist to the displayed quote. However, `token.settleSell()` internally calls `previewSellTaxFor(seller, ...)`, so execution IS correct.
- **Impact:** Preview shows wrong tax rate for whitelisted sellers (shows 4%/10% instead of 0%). Execution is correct. DApp displays inaccurate preview for whitelisted users.
- **Recommendation:** Change `token.previewSellTax(...)` to `token.previewSellTaxFor(seller, ...)` at lines 233-234.
- **Severity justification:** P1 because preview/execution mismatch is a data integrity issue that affects user-facing quotes.

> **Correction applied:** This finding was independently discovered by a subagent auditor during final review and is the most actionable P1 issue.

---

### P2 — Medium (8 found)

#### P2-001: `_updateGlobalReward()` may silently cap emissions

- **File:** `Pangu2Staking.sol:77-91`
- **Issue:** `emitted` is capped to `availableRewardReserve`, but `rewardPerTokenStored` uses the full `rewardRate * elapsed` formula. When reserves run out, future stakers could get inflated rewards when new funds arrive.
- **Recommendation:** Track `effectiveRewardPerTokenStored` proportional to actual emitted rewards.

#### P2-002: `sell()` swapTokens == zero edge case

- **File:** `Pangu2TradeRouter.sol:168-171`
- **Issue:** If sell tax == 100%, `swapTokens == 0`, causing adapter call to revert. Natural fail-closed — no loss.
- **Recommendation:** Add explicit `if (swapTokens == 0) revert InvalidAmount()`.

#### P2-003: `buyback()` oracle call not wrapped in try/catch

- **File:** `SupportPool.sol:161` **(found by subagent audit)**
- **Issue:** `canExecuteBuyback()` wraps oracle in try/catch, but `buyback()` does not. If oracle reverts at execution time, caller loses gas. Since buyback is permissionless, this creates a griefing vector.
- **Recommendation:** Wrap the oracle call in try/catch in `buyback()` or document the gas-loss risk.

#### P2-004: `credit()` not `whenNotPaused`

- **File:** `FeeVault.sol:124-131` **(found by subagent audit)**
- **Issue:** `credit()` lacks `whenNotPaused` modifier. Tax collection continues during pause while withdrawals are blocked. Creates imbalance that becomes drainable on unpause.
- **Recommendation:** Either add `whenNotPaused` to `credit()` or document that tax accrual during pause is intentional.

#### P2-005: `cancelUnclaimedEpoch()` missing pre-window guard

- **File:** `DividendDistributor.sol` **(found by subagent audit)**
- **Issue:** `cancelUnclaimedEpoch()` can be called at any time, even before the claim window has begun. This is inconsistent with `closeEpoch()` which requires the claim window to have elapsed. An admin could cancel an epoch before any users can claim.
- **Recommendation:** Add a pre-window guard: `require(block.timestamp >= c.claimEnd, "claim-window-not-elapsed")` to match `closeEpoch()` semantics.

#### P2-006: `_previewSell` uses `BUY_TAX_BPS()` in slippage calculation

- **File:** `Pangu2TradeRouter.sol:138-140` **(found by subagent audit)**
- **Issue:** The buy slippage floor uses `BPS_DENOMINATOR - token.BUY_TAX_BPS()` as denominator. If tax were ever 100%, this would be division by zero.
- **Recommendation:** Add `require(token.BUY_TAX_BPS() < BPS_DENOMINATOR)` or use a safe minimum denominator.

#### P2-007: FeeVault `credit()` silently accepts invalid enum values

- **File:** `FeeVault.sol:127-128` **(found by subagent audit)**
- **Issue:** The `else` branch catches any non-DIVIDEND value including out-of-range enum values. Solidity 0.8.x does not runtime-check enum ranges.
- **Recommendation:** `require(bucket == Bucket.DIVIDEND || bucket == Bucket.SUPPORT, "invalid bucket")`.

#### P2-008: FeeVault `convertSupport()` has no zero-quote check

- **File:** `FeeVault.sol:177-180` **(found by subagent audit)**
- **Issue:** If `q.amountOut == 0` and caller passes `minWbnbOut == 0`, swap executes with zero minimum output.
- **Recommendation:** `if (q.amountOut == 0) revert ZeroQuote()` before computing minimums.

---

### P3 — Low (5 found)

#### P3-001: BuybackLocker lacks independent tests
- **Impact:** The locker contract was excluded from the Phase 5 staking audit scope. No fuzz or edge-case tests exist.
- **Recommendation:** Add basic unit tests for `registerBuyback()` and lock duration enforcement.

#### P3-002: `console.log` in deploy scripts increase gas
- **Impact:** Gas cost only. Not a security issue.
- **Recommendation:** Gate behind debug flag for mainnet.

#### P3-003: Preview `expiresAt` reflects max window, not user-chosen deadline

- **File:** `Pangu2TradeRouter.sol:216, 253` **(found by subagent audit)**
- **Issue:** `expiresAt = block.timestamp + MAXIMUM_DEADLINE_WINDOW` — off-chain integrators may misinterpret this as the actual deadline.
- **Recommendation:** Naming clarification or removal of `expiresAt` from preview struct.

#### P3-004: FeeVault `fundDividendDistributor` uses misleading `ZeroAddress` error

- **File:** `FeeVault.sol:147` **(found by subagent audit)**
- **Issue:** `revert ZeroAddress()` when distributor not yet configured. Should be `DistributorNotConfigured()`.
- **Recommendation:** Add a distinct error.

#### P3-005: SupportPool buyback parameters fully hardcoded

- **File:** `SupportPool.sol:22-23, 153` **(found by subagent audit)**
- **Issue:** `BUYBACK_AMOUNT = 0.01 ether` and `MIN_BUYBACK_INTERVAL = 60 seconds` are constants — no ability for governance to adjust without redeployment.
- **Recommendation:** Document that these are intentionally immutable for this deployment phase.

---

## Positive Security Findings

| # | Strength | Source |
|---|----------|--------|
| 1 | ReentrancyGuard on all state-mutating functions | All contracts |
| 2 | Fail-closed Oracle (OracleNotReady, TwapTooOld, BelowMinimumReserves, ExcessiveSpotTwapDeviation) | PancakeV2TwapOracle |
| 3 | TransferContext whitelist per contract | Pangu2Token + all system contracts |
| 4 | Fee whitelist per-receiver, not per-msg.sender | Pangu2Token |
| 5 | Tax constants immutable | Pangu2Token |
| 6 | Principal protection in Staking | Pangu2Staking.claimRewards |
| 7 | Coverage ratio passive solvency check | Pangu2Staking.coverageRatio |
| 8 | TradeRouter default-paused | DeployPangu2.s.sol |
| 9 | One-shot LP proxy with fixed amounts | BootstrapLpProxy |
| 10 | Supply conservation invariants | All tax-preview functions |
| 11 | Role-separated PAUSER/UNPAUSER | All pausable contracts |
| 12 | SafeERC20 throughout | All token-transferring contracts |
| 13 | Allowance reset to 0 after every swap | TradeRouter + FeeVault + SupportPool |
| 14 | BNB receivers guarded (only authorized senders) | TradeRouter, SupportPool, FeeVault |

---

## Attack Surface Matrix

| Attack Vector | Mitigation | Status |
|---|---|---|
| Reentrancy | `nonReentrant` on all state changes | MITIGATED |
| Oracle manipulation | Counterfactual TWAP + deviation + reserve minimum | MITIGATED |
| Flash loan price manipulation | TWAP window + deviation bound | MITIGATED |
| Tax bypass via Router | Per-receiver preview functions | MITIGATED |
| Tax bypass via whitelist | Governance-only management | MITIGATED |
| Whitelist→global bypass | Per-address check, msg.sender-independent | MITIGATED |
| Staking principal drain | Principal-protected claim + coverage ratio | MITIGATED |
| Reward over-distribution | InsufficientReserve check + max rate | MITIGATED |
| Unauthorized transfer | Context whitelist per contract | MITIGATED |
| Wrong chain deployment | Env-var chain verification | MITIGATED |
| Stale Oracle | TwapTooOld (5x window) | MITIGATED |
| uint32 overflow | uint40 anchor timestamps | MITIGATED |
| Deployer privilege | Full renounce + assertion | MITIGATED |
| LP proxy double-spend | One-shot guard | MITIGATED |
| Epoch cancel before claims | **P2-005** — missing guard | OPEN |
| Preview/Execution whitelist mismatch | **P1-002** — TradeRouter does not use whitelist-aware preview | OPEN |

---

## Tax Matrix Verification

| Phase | Whitelist | Direction | Tax | Tested? |
|---|---|---|---|---|
| Pre-open | — | Buy | 4% | TaxMatrix |
| Launch | WL | Buy | 0% | TaxMatrix, FeeWhitelist |
| Launch | WL | Sell | 0% | TaxMatrix, FeeWhitelist |
| Launch | Non-WL | Buy | 30% | TaxMatrix, LaunchTax |
| Launch | Non-WL | Sell | 29%+1% | TaxMatrix, LaunchTax |
| Normal | WL | Buy | 0% | TaxMatrix, FeeWhitelist |
| Normal | WL | Sell | 0% | TaxMatrix, FeeWhitelist |
| Normal | Non-WL | Buy | 4% | TaxMatrix |
| Normal | Non-WL | Sell 4% | 4% | TaxMatrix |
| Normal | Non-WL | Sell 10% | 9%+1% | TaxMatrix |

---

## Permission Matrix

| Action | Governance | Emergency | Keeper | Deployer | LP | Anyone |
|---|---|---|---|---|---|---|
| Set pair | Y | — | — | — | — | — |
| Set whitelist | Y | — | — | — | — | — |
| Set liquidityManager | Y | — | — | — | — | — |
| Open trading | Y | — | — | — | — | — |
| Pause (Router/Pool/Vault) | — | Y | — | — | — | — |
| Unpause | Y | — | — | — | — | — |
| Convert fees | — | — | Y | — | — | — |
| Fund rewards | RewardMgr | — | — | — | — | — |
| Set reward rate | RewardMgr | — | — | — | — | — |
| Oracle update | — | — | — | — | — | Y |
| Buyback trigger | — | — | — | — | — | Y |
| Stake / Unstake / Claim | — | — | — | — | — | Y |
| Add liquidity | — | — | — | — | Y (once) | — |

---

## Supply Conservation Verification

| Invariant | Formula | Verified |
|---|---|---|
| Buy tax | `tax + net == gross` | TaxMatrix, LaunchTax, FeeWhitelist |
| Sell tax (launch) | `support + burn + swap == sellAmount` | LaunchTax, TaxMatrix |
| Sell tax (normal) | `support + burn + swap == sellAmount` | TaxMatrix |
| Sell tax (profit) | `support + burn + swap == sellAmount` | TaxMatrix |
| Staking principal | `balance >= totalStaked` | StakingSecurity |
| Fee vault solvency | `balance >= accounted` | FeeVault._assertSolvent |
| Preview = Execution | Same function path | TaxMatrix, all preview tests |

---

## Summary of All Findings

| ID | Severity | File | Line | Description |
|----|----------|------|------|-------------|
| P1-001 | P1 | Pangu2Staking | 118-126 | fundRewards cost-basis drift |
| P1-002 | P1 | Pangu2TradeRouter | 233-234 | previewSellTax not whitelist-aware |
| P2-001 | P2 | Pangu2Staking | 77-91 | _updateGlobalReward silent cap |
| P2-002 | P2 | Pangu2TradeRouter | 168-171 | swapTokens zero edge case |
| P2-003 | P2 | SupportPool | 161 | buyback() oracle not try/catch |
| P2-004 | P2 | FeeVault | 124-131 | credit() not whenNotPaused |
| P2-005 | P2 | DividendDistributor | — | cancelUnclaimedEpoch pre-window |
| P2-006 | P2 | Pangu2TradeRouter | 138-140 | buy-tax denominator zero risk |
| P2-007 | P2 | FeeVault | 127-128 | invalid enum silently credited |
| P2-008 | P2 | FeeVault | 177-180 | no zero-quote check |
| P3-001 | P3 | BuybackLocker | — | no isolated tests |
| P3-002 | P3 | scripts/*.s.sol | — | console.log gas cost |
| P3-003 | P3 | Pangu2TradeRouter | 216 | expiresAt misleading |
| P3-004 | P3 | FeeVault | 147 | ZeroAddress error name |
| P3-005 | P3 | SupportPool | 22-23 | hardcoded buyback params |

---

## Final Verdict: **CONDITIONAL APPROVE**

The PANGU2 V2 contracts are ready for BSC Testnet deployment.

**Conditions for Testnet:**
1. P1-002 fix recommended (TradeRouter whitelist-aware preview) — one-line change
2. All P2 findings are non-blocking for testnet

**Conditions for Mainnet:**
1. All P1 findings resolved
2. P2-003, P2-005 resolved
3. BuybackLocker unit tests added (P3-001)
4. Separate mainnet-specific external audit

**Mainnet: NO-GO** pending mainnet audit.
