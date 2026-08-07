# S0 Design Decision Register

| Field | Value |
|---|---|
| Document ID | `S0_DDR_V1` |
| Stage | S0 |
| Status | `CANDIDATE` |
| Base Commit (deployed) | `3ef50b6` |
| Planning Review Head | `4d33669` |
| Created | 2026-08-07 |

---

## Decision 1: CostBasis Dual Ledger

**Frozen result**: Each eligible liquid user is modeled as:

```text
knownBalance   (uint256)
knownCostWbnbWei (uint256)
unknownBalance (uint256)
```

**Core invariant**:

```text
actual ERC20 balance = knownBalance + unknownBalance
knownBalance == 0 ==> knownCostWbnbWei == 0
```

**Eligibility rules**:
- Eligible liquid users: all non-zero, non-protocol EOA and approved contract accounts
- Protocol addresses excluded: Pair, System Address, TradeRouter, FeeVault, Staking custody, Locker, DividendDistributor, GovernanceAdapter, SupportPool, PancakeV2Adapter
- System addresses never use the dual ledger; their balances are always `NONE`
- UNKNOWN received tokens cannot erase existing KNOWN cost
- UNKNOWN tokens cannot consume KNOWN cost for tax calculation

**Transfer order rules**:
- KNOWN -> KNOWN: proportional cost migration (sender cost * amount / sender.trackedBalance)
- KNOWN -> UNKNOWN: sender cost deducted, receiver stays UNKNOWN
- UNKNOWN -> KNOWN: receiver cost unchanged, amount enters as zero-cost
- UNKNOWN -> UNKNOWN: both stay UNKNOWN

**Partial transfer/sell consumption order**:
- Use KNOWN balance first, then UNKNOWN balance
- KNOWN portion uses proportional cost from KNOWN balance
- Once KNOWN is exhausted, remaining is UNKNOWN (zero cost)

**Proportional cost rounding**: Use `CostMath.proportionalFloor()` — floor rounding, fail-safe (never rounds up)

**Full exit**: All remaining cost consumed; post-trade position becomes `NONE` if balance == 0

**Legacy view derivation**:
- `NONE` = knownBalance == 0 && unknownBalance == 0
- `KNOWN` = knownBalance == actualBalance (implies unknownBalance == 0)
- `UNKNOWN` = knownBalance != 0 && knownBalance < actualBalance (mixed), OR knownBalance == 0 && unknownBalance > 0

**Zero-cost inputs**: Dividend claims, staking rewards, fee collection use `REASON_ZERO_COST` — increase `unknownBalance` only

**Fail-closed**: When actual balance != knownBalance + unknownBalance, revert with `InvalidPositionState`

| **Impact** | S1+ Solidity implementation |
| **Economic baseline change** | YES (dual ledger replaces single Position struct) |
| **Status** | `FROZEN` |

---

## Decision 2: Mixed Sell and Rounding

**Frozen result**: Sell tax logic:

```text
unknownSold portion:
  -> 9% Support + 1% Burn (PROFIT_SELL_TAX_BPS always)

knownSold portion:
  TWAP_value_of_knownSold <= proportional_known_cost (rounded UP for comparison)
    -> 4% Support (NORMAL_SELL_TAX_BPS)
  TWAP_value_of_knownSold > proportional_known_cost (rounded UP for comparison)
    -> 9% Support + 1% Burn (PROFIT_SELL_TAX_BPS)
```

**Profit comparison formula** (overflow-safe):

```solidity
// Comparison uses mulDiv for TWAP conversion, then FullMath.mulDiv for cost comparison
// Must use rounding UP for knownCost to avoid false "profit" on rounding down
uint256 knownCostCompare = CostMath.proportionalCeil(costWbnbWei, knownSold, trackedBalance);
uint256 twapValue = FullMath.mulDiv(knownSold, twapQuote.amountOut, twapQuote.amountIn);
bool isProfit = twapValue > knownCostCompare;
```

**Key rules**:
- Comparison uses ceiling-rounded known cost (not floored proportional cost)
- We support + burn + swapTokens = sellAmount (SELL-INV-02 invariant)
- Split trade must not pay less aggregate tax than single trade under same oracle snapshot
- All execute failures must fully revert (atomic: CostBasis + tax + token transfers)

| **Impact** | S1 Solidity implementation |
| **Economic baseline change** | CLARIFIED (tax rates unchanged, comparison precision specified) |
| **Status** | `FROZEN` |

---

## Decision 3: Preview vs Execute Semantics

**Frozen result**: **Option A — Diagnostic Only**

Preview functions return a constant maximum-tax bound that the executor promises not to exceed. The user reads the preview and supplies exact limit parameters to the execute call.

**User-constraining parameters on execute**:

```text
maximumSupport (uint256) — revert if actual support > this
maximumBurn (uint256) — revert if actual burn > this
minimumSwapTokens (uint256) — revert if swapTokens < this
slippageBps (uint16) — revert if effective price deviation > this
deadline (uint256) — revert if block.timestamp > this
```

**Constraints guaranteed by the protocol**:
- actual support <= preview.support
- actual burn <= preview.burn
- actual swapTokens >= preview.swapTokens (never less)

**No revision/optimistic lock**: The system does not use sequence numbers or revision counters to block racing. The user's limit parameters serve as the sole economic constraint.

| **Impact** | S1 Solidity: add limit params to execute functions |
| **Economic baseline change** | NO (adds user-facing parameters only) |
| **Status** | `FROZEN` |

---

## Decision 4: Canonical Tax Control Surface

**Frozen result**:

```text
WHITELIST_CANONICAL_CONTRACT = Pangu2Token
WHITELIST_STORAGE = Pangu2Token.feeWhitelist (mapping)
WHITELIST_ADMIN_ROLE = GOVERNANCE_ROLE

TRADING_GATE_SOURCE = Pangu2Token.tradingOpenAt
LAUNCH_STATE_SOURCE = Pangu2Token.isInLaunchProtection()
BUY_RATE_SOURCE = Pangu2Token.resolveBuyTaxBps(address buyer, uint256 amount)
SELL_RATE_SOURCE = Pangu2Token.resolveSellTaxBps(address seller, uint256 amount)

ZERO_TAX_EXECUTION = TradeRouter -> Pangu2Token.settleBuy / settleSell
```

**Tax resolution order** (frozen):

```text
1. Trading Gate — revert if not open
2. Fee Whitelist — if address in feeWhitelist, rate = 0 (skip steps 3-4)
3. Launch Protection — if active, use LAUNCH_BUY_TAX_BPS / LAUNCH_SELL_TAX_BPS
4. Normal Cost-Basis Tax — use BUY_TAX_BPS / NORMAL_SELL_TAX_BPS / PROFIT_SELL_TAX_BPS
```

**Whitelist boundaries**:
- Fee whitelist only exempts TAX — it does not bypass Trading Gate, Pause, Pair protection, balance checks, or any other safety check
- Zero-tax transactions must NOT call FeeVault.credit() (which rejects zero amounts)

| **Impact** | S1 Solidity: add resolveBuyTaxBps/resolveSellTaxBps |
| **Economic baseline change** | NO (fee whitelist exists, tax rates unchanged) |
| **Status** | `FROZEN` |

---

## Decision 5: Staking Phase Boundaries

**Frozen result**:

```text
P1-STK-01A — principal CostBasis migration -> S3
P1-STK-01B — reward zero-cost typed position credit -> S4A
```

**S3 scope (principal only)**:
- Implement and close principal amount/cost migration from liquid user positions to per-staking-position
- Define typed reward ABI/context for S4A consumption (signatures only, not activated)
- Must NOT activate reward credit
- Must NOT claim P1-STK-01B is closed

**S4A scope (reward)**:
- Account-level reward -> per-position reward migration
- Activate and verify typed zero-cost reward credit
- Close P1-STK-01B

| **Impact** | S3/S4A Solidity |
| **Economic baseline change** | NO |
| **Status** | `FROZEN` |

---

## Decision 6: Staking Typed Mutation Path

**Frozen result**: Single canonical path:

```text
Staking contract determines positionId before transfer
-> calls typed Token staking entrypoint (systemTransfer with STAKING context)
-> Token verifies caller is configured Staking
-> Token sets context: stakingContract, account, positionId, operationKind
-> Token executes balance change
-> CostBasisManager accepts mutation ONLY from Token
-> Token clears ALL context fields
```

**Forbidden operations**:
- Staking MUST NOT directly write to CostBasisManager
- No double-accounting through hook + explicit call
- No reliance on forgeable reason bytes
- Principal return must carry positionId (not just to/amount/kind)
- positionId MUST NOT be migrated across users, re-bound, or reused after close

| **Impact** | S3/S4A Solidity + TransferContext extension |
| **Economic baseline change** | NO |
| **Status** | `FROZEN` |

---

## Decision 7: Staking Reward Accounting

**Frozen result**: Per-position reward tracking:

```solidity
struct RewardAccounting {
    uint256 rewardIndex;                // snapshot of global reward index at stake/last claim
    uint256 accrued;                    // unclaimed reward for this position
    uint256 principalClosed;            // principal removed (0 until unstake)
    uint256 rewardClaimedOrForfeited;   // claimed or forfeited reward
}
```

**Rules**:
- Locked period: no reward claim before `unlockAt`
- Normal unstake: closes principal, matured rewards still claimable independently
- Early unstake: forfeits unmatured rewards for the position
- Claimed/forfeited rewards cannot be claimed again
- `totalStaked == 0` -> no new reward emission (stop accrual)
- Rounding dust -> explicit dust bucket

**Funding invariant**:

```text
stakingTokenBalance = activePrincipal + availableRewardReserve + ownedAccruedRewardLiability + explicitRoundingOrSurplus
```

**Early penalty flow**: penalty amount enters `availableRewardReserve`
**Forfeiture flow**: forfeited reward deducted from `ownedAccruedRewardLiability`, added to `availableRewardReserve`
**No-staker emission**: reward rate set to 0, emission stops
**Period close**: rounding/surplus explicitly accounted

| **Impact** | S4A Solidity + S5 for reward distribution |
| **Economic baseline change** | NO (staking reward parameters unchanged from PANGU2 V2 spec) |
| **Status** | `FROZEN` |

---

## Decision 8: Staking Pause

**Frozen result**:

```text
Pause blocks: stake, claimRewards, reward funding, non-zero reward rate update
Pause allows: setRewardRate(0) (emergency), normal/early principal exit
```

**Role separation**:
- `PAUSER_ROLE` -> can pause Staking
- `UNPAUSER_ROLE` -> can unpause Staking
- Roles MUST be different addresses
- Token global Pause is stronger (system-wide) and independent from Staking Pause

| **Impact** | S3/S4A Solidity |
| **Economic baseline change** | NO |
| **Status** | `FROZEN` |

---

## Decision 9: Oracle Rollover and Long-Gap

**Frozen result**:

```text
twapWindow = 1800 seconds (immutable)
MAX_TWAP_AGE = 5 * twapWindow = 9000 seconds
maxDeviation = 300 bps (immutable)
```

**Long-gap rule (ONLY V2 TWAP logic, frozen)**:

```text
if elapsed > MAX_TWAP_AGE:
    discard old completion candidate
    re-anchor to current counterfactual cumulative
    status = ACCUMULATING
    DO NOT produce READY quote in this update
```

**Boundary rules**:
- `elapsed == MAX_TWAP_AGE`: treat as `>` (not `>=`), discard old anchor
- `uint32` timestamp wraparound: use modular arithmetic (solidity 0.8.24 with unchecked)
- Cumulative `uint256` overflow: allowed (wrapping, standard PancakeV2 pattern)
- High-frequency permissionless update: `update()` is callable by anyone, but cannot continuously reset an uncompleted window
- Zero reserves: status -> LIQUIDITY_LOW, fail-closed
- Zero quote: revert `ZeroQuote()`
- Spot/TWAP deviation > maxDeviation: revert `ExcessiveSpotTwapDeviation()`

**Forbidden**: Implementation Agent must NOT use extra-long intervals to generate READY without completing a full twapWindow.

| **Impact** | S1 Solidity |
| **Economic baseline change** | CLARIFIED (existing Oracle, long-gap rule now explicit) |
| **Status** | `FROZEN` |

---

## Decision 10: Approved User Contract and Fee Whitelist

**Frozen result**: Independent governance attributes:

```text
approved-user status DOES NOT grant feeWhitelist
feeWhitelist DOES NOT grant approved-user status
```

Only `GOVERNANCE_ROLE` can grant either, through independent, explicit operations.

**Protocol identity overlap forbidden**:
Approved-user address MUST NOT simultaneously be any of:

```text
Pair, System Address, SETTLEMENT_ROLE holder, Liquidity Manager,
TransferContext allowlist member
```

**Rights NOT granted by approved-user status**:
- systemTransfer permission
- settleBuy/settleSell permission
- CostBasis hook permission
- TransferContext creation permission
- Router/Pair bypass permission

| **Impact** | S3/S4A registry if contract accounts supported; NO change if EOA-only |
| **Economic baseline change** | NO |
| **Status** | `FROZEN` |

---

## Decision 11: Contract Account Lifecycle

**Frozen result**: `USER_DECISION_REQUIRED` — S0 cannot close this decision.

The design candidate is:

```text
NONE -> APPROVED -> EXIT_ONLY/GRACE -> REVOKED
```

But the following must be decided by the user:
- Whether to support contract accounts at all, or remain EOA-only
- If supported: trusted factory, initCodeHash, or equivalent identity constraint
- Counterfactual address pre-registration security model
- EXIT_ONLY: which operations are allowed (transfer out + official Router sell = yes; receive + buy = no)
- Balance-zero + grace period conditions
- REVOKED terminal state

**Risk of EOA-only**: Smart wallets and counterfactual addresses cannot interact; their assets would be permanently locked.

| **Impact** | S3/S4A if contracts supported; NONE if EOA-only |
| **Economic baseline change** | USER DECISION REQUIRED |
| **Status** | `BLOCKED_DECISION` |

---

## Decision 12: Support, Dividend, and Fixed Economic Parameters

**Frozen result**: The following parameters are IMMUTABLE:

```text
BUYBACK_AMOUNT = 0.01 BNB
MIN_BUYBACK_INTERVAL = 60 seconds
BUYBACK_RECIPIENT = BuybackLocker
Launch Protection = 15 minutes
Dividend claim window = 30 days (testnet baseline)
```

**Support buyback rules**:
- Uses canonical `PancakeV2Adapter.quoteExactInput()` only
- No arbitrary pair/path routing
- `canExecuteBuyback()` and `buyback()` use identical logic
- No auto-shrinking buyback amount on failure
- Shallow pool: fail-closed

**Dividend rules**:
- Epoch cancellation ONLY allowed when `block.timestamp > claimEnd`
- Epochs with existing claims MUST NOT be cancelled
- Pre-start emergency cancel: `USER_DECISION_REQUIRED` (not self-granted)
- No governance backdoor added by Implementation Agent

| **Impact** | S1 Solidity (existing, confirm frozen) |
| **Economic baseline change** | NO |
| **Status** | `FROZEN` |

---

## Unresolved Decisions

| Decision ID | Problem | User Decision Required | Affected Stages | S0 Closing Impact |
|---|---|---|---|---|
| D-11 | Contract account lifecycle — EOA-only vs smart contract support | YES (cannot self-sign ACCEPTED_DEVIATION) | S3, S4A | `BLOCKED_DECISION` — S0 cannot close until resolved |
