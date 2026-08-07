# S0 ABI and State Machine Freeze (31 Mandatory Items)

| Field | Value |
|---|---|
| Document ID | `S0_ABI_V2` |
| Stage | S0 |
| Status | `CANDIDATE (REVISED)` |
| Base Commit (deployed) | `3ef50b6d77a31c092e9353e255e672836f36ece8` |
| Planning Review Head | `4d33669b41568fa573e9c0e5865be8b1cea803c3` |
| S0 Review Commit | `046e40291a66904a4141b1c083561f381daec265` |

**NOTE**: 5 contract-account-related items (ABI-06, ABI-15, ABI-16, ABI-27, ABI-33) have been REMOVED pending user decision D-11. This freeze contains 31 mandatory items.

---

## Proposed New Structs

| ID | Struct | Purpose | Contract |
|---|---|---|---|
| ABI-01 | `DualPosition` | { knownBalance, knownCostWbnbWei, unknownBalance } | CostBasisManager |
| ABI-02 | `RewardAccounting` | { rewardIndex, accrued, principalClosed, rewardClaimedOrForfeited } | Pangu2Staking |
| ABI-03 | `SellPreview` | { supportBps, burnBps, maxSupport, maxBurn, minSwapTokens, twapQuote } | Pangu2TradeRouter (extend) |
| ABI-04 | `BuyPreview` | { maxTax, minNet, grossAmount } | Pangu2TradeRouter (extend) |

---

## Proposed New Enums

| ID | Enum | Values | Contract |
|---|---|---|---|
| ABI-05 | `StakingOperationKind` | { NONE, STAKE_DEPOSIT, REWARD_CLAIM, PRINCIPAL_RETURN } | TransferContext |

---

## Proposed New External/Public Functions

| ID | Function | Contract | Purpose |
|---|---|---|---|
| ABI-07 | `resolveBuyTaxBps(address, uint256)` | Pangu2Token | Canonical buy tax resolution |
| ABI-08 | `resolveSellTaxBps(address, uint256)` | Pangu2Token | Canonical sell tax resolution |
| ABI-09 | `previewBuy(uint256)` extended | Pangu2TradeRouter | Returns `BuyPreview` with maxTax/minNet |
| ABI-10 | `previewSell(address, uint256)` extended | Pangu2TradeRouter | Returns `SellPreview` with limit params |
| ABI-11 | `buy(uint256, maxTax, minNet, deadline)` | Pangu2TradeRouter | Extended with user constraints |
| ABI-12 | `sell(uint256, maxSupport, maxBurn, minSwapTokens, slippageBps, deadline)` | Pangu2TradeRouter | Extended with user constraints |
| ABI-13 | `setFeeWhitelist(address, bool)` | Pangu2Token | Governance whitelist management |
| ABI-14 | `dualPositionOf(address)` | CostBasisManager | Returns DualPosition struct |

---

## Proposed New Internal Hooks

| ID | Hook | Contract | Purpose |
|---|---|---|---|
| ABI-17 | `_update` extended: Staking context | Pangu2Token | Type-checked Staking mutation context |
| ABI-18 | `onStakingPrincipalReturn(address, uint256, uint256 positionId)` | CostBasisManager | Typed principal cost restoration |

---

## Proposed New Interface Changes

| ID | Interface | Change | Reason |
|---|---|---|---|
| ABI-19 | `ICostBasisManager` | Add `dualPositionOf`, `onStakingPrincipalReturn` | Dual ledger + Staking |
| ABI-20 | `IPangu2Token` | Add `resolveBuyTaxBps`, `resolveSellTaxBps`, `setFeeWhitelist` | Canonical tax control |
| ABI-21 | `IPangu2Staking` | Add `RewardAccounting`, typed position views | Per-position reward tracking |
| ABI-22 | `IPangu2TradeRouter` | Extend preview/buy/sell signatures | User constraint params |

---

## Proposed New Events

| ID | Event | Contract |
|---|---|---|
| ABI-23 | `FeeWhitelistUpdated(address indexed account, bool enabled)` | Pangu2Token |
| ABI-24 | `StakingContextActivated(address indexed stakingContract, address indexed account, uint256 positionId, StakingOperationKind kind)` | Pangu2Token |
| ABI-25 | `StakingContextCleared()` | Pangu2Token |
| ABI-26 | `DualPositionChanged(address indexed account, uint256 oldKnown, uint256 newKnown, uint256 oldUnknown, uint256 newUnknown)` | CostBasisManager |

---

## Proposed New Errors

| ID | Error | Contract |
|---|---|---|
| ABI-28 | `BuyConstraintViolated(uint256 actual, uint256 max)` | Pangu2TradeRouter |
| ABI-29 | `SellConstraintViolated(string param, uint256 actual, uint256 limit)` | Pangu2TradeRouter |
| ABI-30 | `UnauthorizedStakingCaller(address caller)` | Pangu2Token |
| ABI-31 | `InvalidPositionId(uint256 positionId)` | Pangu2Staking |
| ABI-32 | `RewardNotMatured(uint256 unlockAt)` | Pangu2Staking |

---

## Proposed TransferContext Kind Extensions

| ID | Kind | Purpose |
|---|---|---|
| ABI-34 | `STAKING_DEPOSIT` | Stake: move principal from liquid user to Staking |
| ABI-35 | `STAKING_REWARD_CLAIM` | Staking reward: zero-cost typed credit |
| ABI-36 | `STAKING_PRINCIPAL_RETURN` | Unstake: return principal from Staking to liquid user |

---

## State Machine Freeze

### CostBasisManager: Dual Ledger State Machine

```text
State: { knownBalance, knownCostWbnbWei, unknownBalance }

Transitions:
  BUY:
    knownBalance += netTokenAmount
    knownCostWbnbWei += costWbnbWei
    unknownBalance unchanged

  SELL (full consumption):
    knownBalance = 0, knownCostWbnbWei = 0
    unknownBalance = 0

  SELL (partial — known exhausted):
    knownBalance = 0, knownCostWbnbWei = 0
    remaining unknown = unknownBalance - (sellAmount - knownBefore)
    unknownBalance = remaining unknown

  SELL (partial — known not exhausted):
    knownBalance -= knownSold
    knownCostWbnbWei -= proportional cost
    unknownBalance unchanged

  TRANSFER (known -> known):
    sender.knownBalance -= amount, sender.knownCostWbnbWei -= proportional
    receiver.knownBalance += amount, receiver.knownCostWbnbWei += proportional

  TRANSFER (unknown -> known):
    sender.unknownBalance -= amount
    receiver.unknownBalance += amount
    receiver knownBalance/cost UNCHANGED

  DIVIDEND / STAKING_REWARD:
    receiver.unknownBalance += amount

  STAKING_DEPOSIT:
    sender.knownBalance -= amount
    cost migration follows proportional cost (to Staking position)
```

### PancakeV2TwapOracle Window State Machine

```text
States: UNINITIALIZED, ACCUMULATING, READY, LIQUIDITY_LOW

UNINITIALIZED -> ACCUMULATING: anchor created, update() called
ACCUMULATING -> READY: twapWindow elapsed since anchor, reserves >= minimum
ACCUMULATING -> ACCUMULATING: re-anchor on long-gap, or window not yet complete
READY -> LIQUIDITY_LOW: reserves drop below minimum
LIQUIDITY_LOW -> READY: reserves recover
READY -> ACCUMULATING: re-anchor (update called after extending beyond prev window)
```

### Pangu2Staking Position Lifecycle

```text
NONE -> ACTIVE: stake() creates position
ACTIVE -> CLOSED_NORMAL: unstake() after lock duration
ACTIVE -> CLOSED_EARLY: earlyUnstake() before lock duration (penalty applies)
CLOSED_* -> TERMINAL: final state, positionId cannot be reused

Reward state:
  ACTIVE: accruing per-block
  CLOSED_NORMAL with matured reward: reward claimable independently
  CLOSED_EARLY: reward forfeited (except proportionally matured)
  TERMINAL: all rewards claimed or forfeited
```

---

## Legacy ABI Retention

| ABI Element | Retention | Notes |
|---|---|---|
| `Position` struct (ICostBasisManager) | KEPT | Legacy `positionOf()` returns this; new `dualPositionOf()` added alongside |
| `PositionStatus` enum | KEPT | Legacy view; new dual ledger uses different state |
| `proportionalCost()` | KEPT | Maintains backward compatibility |
| `liquidityPositionOf()` | KEPT | LP tracking unchanged |
| Existing TradeRouter buy/sell | KEPT | Overloaded with new signatures adding constraint params |
| `TransferContext.Kind` existing values | KEPT | New values appended |

---

## Compatibility Impact

| Change | Affected |
|---|---|
| `DualPosition` struct addition | Backend CostBasis read layer — needs update |
| `resolveBuyTaxBps/resolveSellTaxBps` | Backend tax preview — use canonical source |
| Extended preview/buy/sell signatures | DApp — additional params in buy/sell calls |
| New TransferContext kinds | Deployment script — register new contexts |
| `RewardAccounting` struct | Admin/Backend — display reward tracking |
