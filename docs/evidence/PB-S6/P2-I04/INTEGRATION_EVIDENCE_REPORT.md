# PANGU2 P2-I04 — BSC Testnet Integration Evidence Report

- **Date:** TBD (after deployment + smoke tests)
- **Status:** PENDING TESTNET DEPLOYMENT

## 1. Summary

This report captures evidence from the BSC Testnet integration smoke tests.
Circular dependencies: ABI → Deploy → Config → Backend → DApp → Smoke Tests.

**All screenshots and evidence will be attached after testnet deployment.**

## 2. Prerequisites Status

| Prerequisite | Status |
|---|---|
| Docker + PHP 8.4 + PostgreSQL + Redis running | PENDING |
| Contracts compiled (`forge build`) | TBD |
| Testnet BNB faucet claimed | TBD |
| Contracts deployed to BSC Testnet | TBD |
| Backend `.env` configured with testnet addresses | TBD |
| Chain Worker running | TBD |

## 3. Evidence Collection Template

### 3.1 BscScan Screenshots

| Contract | Address | BscScan Screenshot Path |
|---|---|---|
| Pangu2Token | `TBD` | `docs/evidence/PB-S6/P2-I04/screenshots/bscscan_token.png` |
| Pangu2TradeRouter | `TBD` | `docs/evidence/PB-S6/P2-I04/screenshots/bscscan_router.png` |
| DividendDistributor | `TBD` | `docs/evidence/PB-S6/P2-I04/screenshots/bscscan_dividend.png` |
| SupportPool | `TBD` | `docs/evidence/PB-S6/P2-I04/screenshots/bscscan_support.png` |
| BuybackLocker | `TBD` | `docs/evidence/PB-S6/P2-I04/screenshots/bscscan_buyback.png` |
| FeeVault | `TBD` | `docs/evidence/PB-S6/P2-I04/screenshots/bscscan_feevault.png` |
| CostBasisManager | `TBD` | `docs/evidence/PB-S6/P2-I04/screenshots/bscscan_costbasis.png` |
| GovernanceAdapter | `TBD` | `docs/evidence/PB-S6/P2-I04/screenshots/bscscan_governance.png` |
| Timelock | `TBD` | `docs/evidence/PB-S6/P2-I04/screenshots/bscscan_timelock.png` |

### 3.2 Buy Transaction Evidence

| Item | Value | Screenshot Path |
|---|---|---|
| Tx Hash | `TBD` | `docs/evidence/PB-S6/P2-I04/screenshots/buy_bscscan.png` |
| BscScan Link | `https://testnet.bscscan.com/tx/TBD` | — |
| Block Number | `TBD` | — |
| DApp Confirmation | — | `docs/evidence/PB-S6/P2-I04/screenshots/buy_dapp.png` |
| API Response | — | `docs/evidence/PB-S6/P2-I04/screenshots/buy_api.png` |

### 3.3 Claim Transaction Evidence

| Item | Value | Screenshot Path |
|---|---|---|
| Tx Hash | `TBD` | `docs/evidence/PB-S6/P2-I04/screenshots/claim_bscscan.png` |
| BscScan Link | `https://testnet.bscscan.com/tx/TBD` | — |
| DApp Confirmation | — | `docs/evidence/PB-S6/P2-I04/screenshots/claim_dapp.png` |

### 3.4 Admin Dashboard Evidence

| View | Screenshot Path |
|---|---|
| Dashboard KPIs | `docs/evidence/PB-S6/P2-I04/screenshots/admin_dashboard.png` |
| Contracts list | `docs/evidence/PB-S6/P2-I04/screenshots/admin_contracts.png` |
| Trades view | `docs/evidence/PB-S6/P2-I04/screenshots/admin_trades.png` |
| Jobs status | `docs/evidence/PB-S6/P2-I04/screenshots/admin_jobs.png` |
| Audit logs | `docs/evidence/PB-S6/P2-I04/screenshots/admin_audit.png` |

### 3.5 Wallet Screenshots

| Screen | Screenshot Path |
|---|---|
| DApp connected (BSC Testnet) | `docs/evidence/PB-S6/P2-I04/screenshots/dapp_connected.png` |
| TradeView buy quote | `docs/evidence/PB-S6/P2-I04/screenshots/dapp_buy_quote.png` |
| TransactionProgress overlay | `docs/evidence/PB-S6/P2-I04/screenshots/dapp_tx_progress.png` |
| DividendView | `docs/evidence/PB-S6/P2-I04/screenshots/dapp_dividend.png` |

## 4. API Verification Results

| Endpoint | Expected Response | Actual | Status |
|---|---|---|---|
| `GET /config` | `chain_id: 97, chain_name: "BSC Testnet"` | TBD | PENDING |
| `GET /contracts` | 9 contracts with non-zero addresses | TBD | PENDING |
| `POST /quotes/buy` | Valid BuyQuote with `source: "contract_preview"` | TBD | PENDING |
| `POST /quotes/sell` | Valid SellQuote with correct tax rate | TBD | PENDING |
| `GET /dividend/epochs/current` | Current epoch with snapshot block | TBD | PENDING |
| `GET /wallets/{addr}/transactions` | Transaction history | TBD | PENDING |
| `GET /admin/dashboard` | Real KPIs (not MOCK_DATA) | TBD | PENDING |
| `GET /admin/jobs` | chain-sync HEALTHY/RUNNING | TBD | PENDING |

## 5. Data Consistency Verification

| Check | Chain (BscScan) | DB (chain_raw_events) | API (/wallets/...) | UI (Admin/DApp) | Consistent? |
|---|---|---|---|---|---|
| Buy tx #1 | TBD | TBD | TBD | TBD | PENDING |
| Sell tx #1 | TBD | TBD | TBD | TBD | PENDING |
| Claim tx #1 | TBD | TBD | TBD | TBD | PENDING |

## 6. Final Sign-off

- [ ] All 9 contracts deployed and verified on BscScan
- [ ] Backend connected to testnet RPC and returning LIVE data
- [ ] At least 1 buy, 1 sell, and 1 claim transaction executed and indexed
- [ ] Admin Dashboard showing real on-chain KPIs
- [ ] DApp TradeView/DividendView connected to testnet backend
- [ ] Zero private keys or API keys in committed config
- [ ] Smoke test checklist fully signed off
- [ ] All screenshots attached to this report

---

**This report will be updated with actual values, screenshots, and sign-off after BSC Testnet deployment is completed.**
