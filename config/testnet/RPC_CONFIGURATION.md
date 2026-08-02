# PANGU2 — BSC Testnet + Mainnet RPC Configuration

> Testnet + Mainnet Fork testing. Deployment to Mainnet: NO-GO.

## Public RPC Nodes

### BSC Testnet (Chain ID 97)

### Primary
```
URL: https://data-seed-prebsc-1-s1.binance.org:8545
Provider: Binance Official
Type: Public
Rate Limit: ~25 req/s
```

### Secondary
```
URL: https://data-seed-prebsc-2-s1.binance.org:8545
Provider: Binance Official
Type: Public
Rate Limit: ~25 req/s
```

### Fallback
```
URL: https://bsc-testnet.public.blastapi.io
Provider: Blast API
Type: Public
Rate Limit: ~10 req/s
```

## BscScan Explorer
```
URL: https://testnet.bscscan.com
API: https://api-testnet.bscscan.com/api
```

## Chain Metadata
```
Chain ID:      97
Currency:      BNB
Block Time:    ~3 seconds
Confirmations: 12 (recommended for finality)
```

### BSC Mainnet (Chain ID 56) — Fork Testing Only

| Provider | URL |
|---|---|
| Binance Official | https://bsc-dataseed1.binance.org |
| Binance Official | https://bsc-dataseed2.binance.org |

```
Chain ID:      56
Currency:      BNB
Block Time:    ~3 seconds
Confirmations: 21 (recommended for finality)
```

> ⚠️  BSC Mainnet deployment remains NO-GO. These endpoints are for fork testing only.

## Environment Variable Template

Copy to `.env` (do NOT commit `.env`):

```env
CHAIN_ID=97
CHAIN_NAME=BSC Testnet
RPC_URL=https://data-seed-prebsc-1-s1.binance.org:8545
BACKUP_RPC_URL=https://data-seed-prebsc-2-s1.binance.org:8545
EXPLORER_URL=https://testnet.bscscan.com
PANGU2_CHAIN_ID=97
PANGU2_CHAIN_NAME=BSC Testnet
PANGU2_RPC_URL=https://data-seed-prebsc-1-s1.binance.org:8545
PANGU2_BACKUP_RPC_URL=https://data-seed-prebsc-2-s1.binance.org:8545
PANGU2_SUPPORTED_NETWORKS=31337,97
```

## Backend Config (config/pangu2.php)

```php
'chain_id' => (int) env('PANGU2_CHAIN_ID', 97),
'chain_name' => env('PANGU2_CHAIN_NAME', 'BSC Testnet'),
'supported_networks' => [31337, 97],
```

## DApp Config (apps/dapp/src/features/wallet/config.ts)

```typescript
// Already configured:
import { bscTestnet } from "viem/chains";
export const SUPPORTED_CHAIN_IDS = [31337, 97, 56];
```

## Verification

```bash
# Test RPC connectivity
curl -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  https://data-seed-prebsc-1-s1.binance.org:8545

# Expected: {"jsonrpc":"2.0","id":1,"result":"0x61"}
# 0x61 = 97 = BSC Testnet
```
