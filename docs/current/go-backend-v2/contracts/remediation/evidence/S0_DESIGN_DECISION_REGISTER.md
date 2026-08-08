# S0 Design Decision Register

| Field | Value |
|---|---|
| Document ID | `S0_DDR_V2` |
| Stage | S0 |
| Status | `CANDIDATE (REVISED)` |
| Base Commit (deployed) | `3ef50b6d77a31c092e9353e255e672836f36ece8` |
| Planning Review Head | `4d33669b41568fa573e9c0e5865be8b1cea803c3` |
| S0 Review Commit (revised) | `ff8d693179fbea11f80ed3e491a41b8054f2693a` |
| Initial S0 Candidate Commit | `046e40291a66904a4141b1c083561f381daec265` |
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
- Eligible liquid users: all non-zero, non-protocol EOA addresses only
- Contract account support: NOT SUPPORTED — permanent V2 boundary (D-11 FROZEN)
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
| **Economic baseline change** | NO (dual ledger is an internal accounting representation change; all tax rates, supply, and economic semantics are unchanged. See INTERNAL_REPRESENTATION_CHANGE_ONLY below.) |
| **Internal representation change** | YES (dual ledger replaces single Position struct for CostBasis internal storage; legacy `positionOf()` view preserved for backward compatibility) |
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

**Buy**:
```text
amount (uint256) — BNB amount sent with the transaction
maxTax (uint256) — revert if actual tax tokens > maxTax; unit: PANGU2 token wei
minNet (uint256) — revert if net tokens received < minNet; unit: PANGU2 token wei
deadline (uint256) — revert if block.timestamp > deadline
```

- `actualTax <= maxTax` always enforced
- `netAmount >= minNet` always enforced
- maxTax and minNet are user-supplied limits; user may supply more generous bounds than preview (e.g., maxTax higher than preview, minNet lower than preview) — but actual economic result is bounded by protocol rules, not by user limits
- execute MUST re-read current tax/state/oracle at execution time (not cached from preview)
- deadline uses strict `>`: revert if `block.timestamp > deadline`

**Sell**:
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
if elapsed >= MAX_TWAP_AGE:
    discard old completion candidate
    re-anchor to current counterfactual cumulative
    status = ACCUMULATING
    DO NOT produce READY quote in this update
```

**Boundary rules**:
- Comparator: `>=` (elapsed >= MAX_TWAP_AGE triggers re-anchor). This is the sole canonical comparator.
- `elapsed = MAX_TWAP_AGE - 1` (= 8999): window is complete but not yet expired; READY may be produced if reserves OK
- `elapsed = MAX_TWAP_AGE` (= 9000): re-anchor, DO NOT produce READY
- `elapsed = MAX_TWAP_AGE + 1` (= 9001): re-anchor, DO NOT produce READY
- Implementation MUST use `>=` as the comparison operator; `>` is INCORRECT per this frozen specification
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

**Frozen result**: **NOT SUPPORTED — EOA-only.** Contract accounts (smart wallets, multisigs, counterfactual addresses) are not supported in the PANGU2 V2 baseline. This is a permanent product boundary for V2.

**Decision Evidence**:

```text
Decision ID: D-11
Decision Owner: pandy123321 (Project Owner, session 2026-08-07/BNB合约)
Decision: Contract Accounts NOT SUPPORTED in PANGU2 V2
EOA-only: YES
Smart Wallet / Multisig / Counterfactual Support: NO
Accepted Risk: smart wallets and counterfactual addresses cannot interact;
their assets would be permanently locked — documented V2 limitation
ACCEPTED_DEVIATION: YES (P3-TKN-01 closed by user-approved deviation)
Decision Date: 2026-08-07
Evidence Reference: S0-P2-10 revision (this document)
```

**Rationale**: The deployed baseline at `3ef50b6` does not support contract accounts. Adding contract account support would require a full lifecycle (APPROVED/EXIT_ONLY/REVOKED), identity constraints (initCodeHash, trusted factory), and deep integration across Token, CostBasis, TransferContext, and Router. This scope exceeds V2 remediation objectives.

**Implementation Impact**: No contract-account compatibility Solidity implementation in V2. All contract-account-related ABI items (ContractStatus enum, setContractStatus, contractStatus, ContractStatusUpdated event, InvalidContractState error) are permanently REMOVED from S0 freeze.

**Finding Closure Impact**: P3-TKN-01 closed via `ACCEPTED_DEVIATION` with user approval evidence above. S8 (Contract Account Lifecycle stage) REQUIRED — must document this deviation and verify no regression. M3 REQUIRED — the ACCEPTED_DEVIATION must be re-verified at final code exit gate. S9 cannot proceed until M3 is complete.

**Consequences**:
- All contract-account-related ABI items are REMOVED from S0 freeze
- REG-INV-02 (revocation) is DEFERRED / NOT_APPLICABLE to V2 EOA-only baseline
- Smart wallets and counterfactual addresses cannot interact with PANGU2 V2; their assets would be permanently locked — this is a documented V2 limitation
- Contract account support MAY be considered for a future V3 scope, with a full design freeze

| **Implementation Impact** | No contract-account support implementation in V2 |
| **Finding Closure Impact** | S8 REQUIRED (document deviation) + M3 REQUIRED (re-verify at S9 gate) |
| **Economic baseline change** | NO |
| **P3-TKN-01 Status** | `ACCEPTED_DEVIATION` (user-approved) |
| **Status** | `FROZEN` |

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

## Economic Baseline Summary

| Parameter | Status |
|---|---|
| All tax rates (Buy 4%, Sell 4%/10%, Launch 30%) | UNCHANGED |
| Supply (1B) | UNCHANGED |
| Buyback (0.01 BNB, 60s) | UNCHANGED |
| Dividend (30-day testnet window) | UNCHANGED |
| Launch Protection (15 min) | UNCHANGED |
| Staking economic params | UNCHANGED |
| Dual ledger | INTERNAL REPRESENTATION CHANGE ONLY |
| Contract accounts | NOT SUPPORTED (permanent V2 boundary) |
| **Economic Baseline Changed** | **NO** |
