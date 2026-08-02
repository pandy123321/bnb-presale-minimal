# P2-I03 — Anvil Full-Stack Integration Evidence

```text
Task: P2-I03
Stream: INTEGRATION
Status: READY (awaiting testnet deployment)
Verified At: 2026-08-02
```

## Deployment Script

```bash
forge script script/DeployLocal.s.sol --rpc-url http://localhost:8545 --broadcast
```

## Contract Verification

| Contract | Call | Expected |
|---|---|---|
| Pangu2Token | `cast call <addr> "symbol()(string)"` | "PANGU2" |
| Pangu2TradeRouter | `cast call <addr> "token()(address)"` | Token addr |
| DividendDistributor | `cast call <addr> "rewardToken()(address)"` | Token addr |
| SupportPool | `cast call <addr> "BUYBACK_AMOUNT()(uint256)"` | 0.01 ether |

## Full Chain

1. Buy → BuyExecuted → Worker index → TransactionProjection → DApp/Admin
2. Sell → approve + sell → SellExecuted → SupportPool balance
3. Dividend → publishDividendRoot → claim → DividendClaimed
4. Buyback → executeBuyback → BuybackExecuted → Locker register
5. Reorg → Worker canonical check → status → REORGED

## Closeout

AWAITING EXECUTION
