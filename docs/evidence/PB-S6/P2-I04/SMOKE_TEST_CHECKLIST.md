# PANGU2 BSC Testnet Smoke Test Checklist

- **Network:** BSC Testnet (Chain ID: 97)
- **Date:** TBD (execute after deployment)
- **Tester:** TBD

## Prerequisites

- [ ] Deployer wallet funded with testnet BNB (https://testnet.bnbchain.org/faucet)
- [ ] All 9 contracts deployed (see DEPLOYMENT_MANIFEST.md)
- [ ] Backend `.env` configured with testnet RPC + contract addresses
- [ ] Chain Worker running and scanning from deployment block
- [ ] Mock API server pointing to testnet config

---

## Section 1: Contract Verification

### 1.1 Address Resolution
- [ ] **Test:** `GET /api/v1/projects/pangu2/config` returns `chain_id: 97, chain_name: "BSC Testnet"`
- [ ] **Test:** `GET /api/v1/projects/pangu2/contracts` returns all 9 contracts with non-zero addresses

### 1.2 BscScan Verification
- [ ] **Test:** Each contract address resolves on https://testnet.bscscan.com
- [ ] **Test:** Contract source code is verified (green checkmark on BscScan)
- [ ] **Evidence:** BscScan screenshots for each contract

### 1.3 Admin Contract View
- [ ] **Test:** Admin `/assets` page displays all 9 contracts with correct addresses
- [ ] **Test:** Admin `/assets` page shows ABI version and deployment block for each
- [ ] **Evidence:** Admin UI screenshot

---

## Section 2: Transaction Verification

### 2.1 Buy Transaction
- [ ] **Test:** `POST /api/v1/projects/pangu2/quotes/buy` returns valid buy quote
- [ ] **Test:** DApp TradeView shows quote with correct testnet tax rate
- [ ] **Test:** Execute buy transaction via wallet (MetaMask on BSC Testnet)
- [ ] **Test:** Transaction confirmed on BscScan within 2 minutes
- [ ] **Test:** Backend indexes the `BuyExecuted` event
- [ ] **Test:** `GET /api/v1/projects/pangu2/wallets/{addr}/transactions` shows the buy
- [ ] **Evidence:** BscScan tx link + DApp confirmation screenshot

### 2.2 Sell Transaction
- [ ] **Test:** `POST /api/v1/projects/pangu2/quotes/sell` returns valid sell quote with wallet-specific tax rate
- [ ] **Test:** Execute sell transaction (approval + sell) via wallet
- [ ] **Test:** Approval tx and sell tx both confirmed on BscScan
- [ ] **Evidence:** BscScan tx links + TransactionProgress confirmation screenshot

### 2.3 Claim Transaction
- [ ] **Test:** `GET /api/v1/projects/pangu2/dividend/epochs/current` returns current epoch
- [ ] **Test:** `GET /api/v1/projects/pangu2/dividend/epochs/{id}/proof/{addr}` returns valid Merkle proof
- [ ] **Test:** Claim dividends via wallet signature
- [ ] **Test:** `DividendClaimed` event emitted and indexed
- [ ] **Evidence:** BscScan tx link + DApp confirmation screenshot

---

## Section 3: Admin Dashboard

### 3.1 KPI Display
- [ ] **Test:** Login to Admin console
- [ ] **Test:** Dashboard `/admin-api/v1/projects/pangu2/dashboard` returns real KPIs (not MOCK_DATA)
- [ ] **Test:** KPI values reflect actual on-chain state:
  - `total_transactions` > 0
  - `currrent_epoch_id` > 0
  - `total_buybacks` > 0 (if executed)

### 3.2 Job Status
- [ ] **Test:** `GET /admin-api/v1/projects/pangu2/jobs` shows chain-sync as HEALTHY or RUNNING
- [ ] **Test:** Block lag is within acceptable range (< 20 blocks)
- [ ] **Evidence:** Admin dashboard screenshot

---

## Section 4: Data Consistency

### 4.1 Chain → Database → API → UI
- [ ] **Test:** Pick a confirmed buy transaction from BscScan
- [ ] **Test:** Verify same tx_hash appears in `chain_raw_events` table
- [ ] **Test:** Verify same tx_hash appears in `transaction_projections` table  
- [ ] **Test:** Verify same tx_hash appears in API response `GET /wallets/{addr}/transactions`
- [ ] **Test:** Verify same tx_hash appears in Admin TradesView

### 4.2 Reorg Detection
- [ ] **Test:** Chain Worker reorg detector is running (visible in jobs list)
- [ ] **Test:** Manually trigger a brief Anvil reorg simulation (if test infrastructure available)
- [ ] **Test:** Events in reorged blocks are marked REORGED

---

## Section 5: DApp Integration

### 5.1 Wallet Connection
- [ ] **Test:** Connect MetaMask on BSC Testnet (Chain 97)
- [ ] **Test:** DApp topbar shows "BSC Testnet · 97"
- [ ] **Test:** `canTransact` is true

### 5.2 Trade Flow
- [ ] **Test:** Buy quote displays contract-sourced rate (not MOCK_DATA)
- [ ] **Test:** Sell quote displays wallet-specific tax tier
- [ ] **Test:** TransactionProgress overlay shows all phases
- [ ] **Evidence:** DApp screenshots at each phase

### 5.3 Dividend Flow
- [ ] **Test:** DividendView shows current epoch with real data
- [ ] **Test:** Tier ranking and allocation display correctly
- [ ] **Test:** Claim flow shows Merkle proof verification

---

## Section 6: Security

### 6.1 No Key Leakage
- [ ] **Test:** Search all deployed config for private keys: `rg "0x[a-fA-F0-9]{64}" config/` returns zero results
- [ ] **Test:** Search logs for private keys: zero results
- [ ] **Test:** Search database for private keys: zero results

### 6.2 RPC Safety
- [ ] **Test:** Only public RPC URLs in config (no API keys)
- [ ] **Test:** `ALLOW_MAINNET_WRITES=false` in testnet environment

---

## Sign-off

| Role | Name | Date | Signature |
|---|---|---|---|
| Deployer | TBD | TBD | |
| QA/Tester | TBD | TBD | |
| Reviewer | TBD | TBD | |

---

## Appendix: Quick Validation Commands

```bash
# 1. Check chain ID from RPC
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  https://data-seed-prebsc-1-s1.binance.org:8545 | jq '.result'

# 2. Check contract code exists at address
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_getCode","params":["TBD_CONTRACT_ADDRESS","latest"],"id":1}' \
  https://data-seed-prebsc-1-s1.binance.org:8545 | jq '.result' | wc -c
# Expected: > 4 (non-empty bytecode)

# 3. Admin Dashboard KPI
curl -s http://localhost:8080/admin-api/v1/projects/pangu2/dashboard \
  -H "Authorization: Bearer TBD_TOKEN" | jq '.data'

# 4. DApp config
curl -s http://localhost:8080/api/v1/projects/pangu2/config | jq '.data.chain_id'
# Expected: 97
```
