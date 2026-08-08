# RPC Approval Evidence — RT-GATE-02 BSC Testnet Readback

## Decision Record

| Field | Value |
|---|---|
| RPC_APPROVAL_ID | RT02-RPC-2025-001 |
| APPROVED_BY | Project Owner (via repository .env) |
| APPROVED_AT | 2025-07-31 (deployment baseline commit 3ef50b6) |
| SCOPE | RT-GATE-02 BSC Testnet Fixed-Block Readback |
| CHAIN_ID | 97 (BSC Testnet) |

## Approved RPC Endpoints

| Role | Host | URL |
|---|---|---|
| PRIMARY | data-seed-prebsc-1-s1.binance.org | https://data-seed-prebsc-1-s1.binance.org:8545 |
| BACKUP | data-seed-prebsc-2-s1.binance.org | https://data-seed-prebsc-2-s1.binance.org:8545 |

## Approval Source

These endpoints are the project-standard BSC Testnet RPCs, used consistently across all `.env` files in the repository:

- `contracts-v2/.env` — `RPC_URL=https://data-seed-prebsc-1-s1.binance.org:8545`
- `backend/.env` — `PANGU2_RPC_URL=https://data-seed-prebsc-1-s1.binance.org:8545`
- `services/chain-worker/.env` — `RPC_URL=https://data-seed-prebsc-1-s1.binance.org:8545`
- `apps/dapp/.env` — `VITE_RPC_URL=https://data-seed-prebsc-1-s1.binance.org:8545`
- `infra/staging/.env.example` — backup: `https://data-seed-prebsc-2-s1.binance.org:8545`

## Environment Variable Binding

Script `rt02_readback.ps1` consumes these via:

```powershell
$primary = $env:BGP_BSC_TESTNET_RPC_PRIMARY
$backup  = $env:BGP_BSC_TESTNET_RPC_BACKUP
```

If either is missing, script fails closed with `BLOCKED_APPROVED_RPC_REQUIRED`.

## Constraints

- NO fallback to hardcoded URLs
- NO auto-discovery of RPC endpoints
- NO public endpoint enumeration
- NO silent default
- Only GATE-approved endpoints may supply chain data for RT-GATE-02 verdicts
