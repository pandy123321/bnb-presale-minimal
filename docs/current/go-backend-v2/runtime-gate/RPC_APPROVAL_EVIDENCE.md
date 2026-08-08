# RPC Approval Evidence — RT-GATE-02 BSC Testnet Readback

## Owner Decision Record

| Field | Value |
|---|---|
| OWNER_DECISION_ID | RT02-RPC-2026-001 |
| OWNER_IDENTITY | Project Owner (pandy123321) |
| DECISION_TIMESTAMP | 2026-08-08 18:20+08 |
| DECISION_SOURCE | Owner explicit signoff in execution session (Fix Cycle 3) |
| SOURCE_CONVERSATION_ID | e9294865-10ed-4d01-9374-c3726a246e49 |
| SOURCE_REFERENCE | "确定批准 RPC" — direct Owner message |
| SCOPE | RT-GATE-02 BSC Testnet Fixed-Block Readback |
| CHAIN_ID | 97 (BSC Testnet) |

## Approved RPC Endpoints

| Role | Host | URL |
|---|---|---|
| PRIMARY | data-seed-prebsc-1-s1.binance.org | https://data-seed-prebsc-1-s1.binance.org:8545 |
| BACKUP | data-seed-prebsc-2-s1.binance.org | https://data-seed-prebsc-2-s1.binance.org:8545 |

## Evidence Sources (repo .env files)

- `contracts-v2/.env` — `RPC_URL=https://data-seed-prebsc-1-s1.binance.org:8545`
- `backend/.env` — `PANGU2_RPC_URL=https://data-seed-prebsc-1-s1.binance.org:8545`
- `services/chain-worker/.env` — `RPC_URL=https://data-seed-prebsc-1-s1.binance.org:8545`
- `apps/dapp/.env` — `VITE_RPC_URL=https://data-seed-prebsc-1-s1.binance.org:8545`

## Environment Variable Binding

Script `rt02_readback.ps1` reads from `$env:BGP_BSC_TESTNET_RPC_PRIMARY` / `BGP_BSC_TESTNET_RPC_BACKUP`.
Missing env → `throw` with `BLOCKED_APPROVED_RPC_REQUIRED`.

## Constraints

- NO fallback to hardcoded URLs
- NO auto-discovery
- NO silent default
- Execution agent does NOT create Owner Decision — only records it