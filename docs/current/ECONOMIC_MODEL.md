# PANGU2 Economic Model

- **Version:** 2.0.0
- **Status:** AUTHORITATIVE — supersedes all previous economic documents
- **Network:** BSC Testnet (chain 97) only; Mainnet (chain 56) permanently blocked
- **Source Commit:** `a155e3e` (HEAD, local only — 7 commits ahead of `origin/main` at `cd7bde9`)
- **Last Updated:** 2026-08-06

---

## 1. Tax Regime

### 1.1 Launch Period — First 15 Minutes After Trading Opens

> **STATUS: NOT_IMPLEMENTED** — no `tradingOpenAt` timestamp or launch-tax logic exists in current contracts.

| Direction | Tax Rate | Tax Destination | Rationale |
|-----------|----------|-----------------|-----------|
| Buy | **30%** | FeeVault → DividendDistributor | Anti-sniper: heavily tax front-running bots at open |
| Sell | **30%** | 90% SupportPool + 10% Burn *(same ratio as NORMAL)* | Prevents immediate dump |
| Whitelisted (Buy) | **0%** | — | Whitelisted addresses pay no tax during launch |
| Whitelisted (Sell) | **0%** | — | Whitelisted addresses pay no tax during launch |

**Whitelist priority:** If an address is on the whitelist, whitelist rules (0%) override launch rules (30%) and normal rules (4%/10%). The whitelist check is evaluated **first** in the tax determination path.

Implementation requirement:
- Add `uint256 public tradingOpenAt` timestamp to `Pangu2Token` or `Pangu2TradeRouter`
- Add `mapping(address => bool) public isWhitelisted`
- Add `function setTradingOpenAt(uint256 ts) external onlyRole(GOVERNANCE_ROLE)`
- Add `function setWhitelisted(address account, bool enabled) external onlyRole(GOVERNANCE_ROLE)`
- In `previewBuyTax` / `previewSellTax` / `buy()` / `sell()`: check `isWhitelisted[msg.sender]` first → if true, skip tax entirely

### 1.2 Normal Period — After 15 Minutes

| Direction | Tax Rate | Tax Destination | Condition |
|-----------|----------|-----------------|-----------|
| **Buy** | **4%** | FeeVault → DividendDistributor | Always |
| **Sell (PROFIT)** | **10%** | 90% SupportPool + 10% Burn | Sender has KNOWN cost basis AND TWAP value > cost basis |
| **Sell (NORMAL)** | **4%** | SupportPool → BuybackLocker | Sender has UNKNOWN cost basis OR TWAP value ≤ cost basis |

**Current Implementation Status:**

| Mechanism | Status | Evidence |
|-----------|--------|----------|
| `BUY_TAX_BPS = 400` (4%) | **IMPLEMENTED** | `Pangu2Token.sol:19` |
| `NORMAL_SELL_TAX_BPS = 400` (4%) | **IMPLEMENTED** | `Pangu2Token.sol:20` |
| `PROFIT_SELL_TAX_BPS = 1000` (10%) | **IMPLEMENTED** | `Pangu2Token.sol:21` |
| `PROFIT_SUPPORT_BPS = 900` (90%) | **IMPLEMENTED** | `Pangu2Token.sol:22` |
| `PROFIT_BURN_BPS = 100` (10%) | **IMPLEMENTED** | `Pangu2Token.sol:23` |
| CostBasisManager KNOWN/UNKNOWN determination | **IMPLEMENTED** | `CostBasisManager.sol` |
| `previewBuyTax()` preview function | **IMPLEMENTED** | `Pangu2Token.sol:192` |
| `previewSellTax()` preview function | **IMPLEMENTED** | `Pangu2Token.sol:199` |
| `settleBuy()` settlement function | **IMPLEMENTED** | `Pangu2Token.sol:222` |
| `settleSell()` settlement function | **IMPLEMENTED** | `Pangu2Token.sol:238` |
| Launch tax (30%) | **NOT_IMPLEMENTED** | No code exists |
| Whitelist (0%) | **NOT_IMPLEMENTED** | No code exists |
| `tradingOpenAt` timestamp | **NOT_IMPLEMENTED** | No code exists |

---

## 2. Token Supply

| Parameter | Value | Source |
|-----------|-------|--------|
| Initial supply | `1_000_000_000 ether` (1 billion PANGU2) | `Pangu2Token.sol:25` |
| Decimals | 18 | Standard ERC-20 |
| Symbol | PANGU2 | `Pangu2Token.constructor` |
| Burn mechanism | 10% of profit-sell tax | `PROFIT_BURN_BPS = 100` |

---

## 3. Fee Flow

```
Buyer → BNB
         │
    TradeRouter.buy()
         │
         ├── 4% buy tax → FeeVault (DIVIDEND bucket)
         │       └── DividendDistributor (epoch distribution)
         │
         └── 96% net → PancakeSwap V2 swap (BNB → PANGU2)

Seller → PANGU2
         │
    TradeRouter.sell()
         │
         ├── CostBasisManager.consumeSell() → determines taxBps (4% or 10%)
         │
         ├── 4% (NORMAL): tax → FeeVault (SUPPORT bucket)
         │       └── SupportPool → converts to BNB → BuybackLocker
         │
         ├── 10% (PROFIT):
         │       ├── 90% of tax → SupportPool
         │       └── 10% of tax → BURN (irreversible)
         │
         └── remaining → PancakeSwap V2 swap (PANGU2 → BNB)
```

---

## 4. Buyback Mechanism

| Parameter | Value | Source |
|-----------|-------|--------|
| Buyback trigger | Permissionless (anyone calls `SupportPool.buyback()`) | `SupportPool.sol` |
| Buyback size | Fixed `0.01 BNB` | `SupportPool.BUYBACK_AMOUNT()` |
| Min interval | 60 seconds | `SupportPool.MIN_BUYBACK_INTERVAL()` |
| Lock duration | 365 days | `BuybackLocker.LOCK_DURATION()` |
| Tax funding | 4% NORMAL sell tax → SupportPool | `FeeVault.Bucket.SUPPORT` |

---

## 5. Staking Rewards

| Parameter | Value | Source |
|-----------|-------|--------|
| Reward funding | Governance (`REWARD_MANAGER_ROLE`) calls `fundRewards(amount)` | `Pangu2Staking.sol:118` |
| Reward rate cap | `~1 token/day` (115740740740740 tokens/sec) | `Pangu2Staking.sol:33` |
| Min stake | `1 ether` (1 PANGU2) | `Pangu2Staking.sol:36` |
| Max lock | 730 days | `Pangu2Staking.sol:35` |
| Early unstake penalty | 10% (1000 bps) | `Pangu2Staking.sol:34` |
| Reward distribution | Per-second, global rate × user stake share | `Pangu2Staking._updateGlobalReward()` |

---

## 6. Dividend Distribution

| Parameter | Value | Source |
|-----------|-------|--------|
| Source | 4% BUY tax → FeeVault DIVIDEND bucket | `settleBuy()` |
| Distribution | Merkle-tree based, epoch by epoch | `DividendDistributor.sol` |
| Tier structure | Tier 1 (1-10): 35%, Tier 2 (11-30): 25%, Tier 3 (31-60): 25%, Tier 4 (61-100): 15% | `DividendTiers.sol` |

---

## 7. Verification Checklist

- [ ] Launch tax 30% implemented in contracts
- [ ] Whitelist 0% implemented in contracts
- [ ] Whitelist priority overrides launch tax
- [ ] `previewBuyTax()` returns correct whitelist/launch/normal rates
- [ ] `previewSellTax()` returns correct whitelist/launch/normal rates
- [ ] `tradingOpenAt` enforced in buy/sell paths
- [ ] 15-minute launch window enforced by `block.timestamp >= tradingOpenAt + 15 minutes`
- [ ] Backend QuoteService uses real contract `previewBuy`/`previewSell` (currently mock→UNAVAILABLE)
- [ ] DApp displays correct tax rate based on current phase
