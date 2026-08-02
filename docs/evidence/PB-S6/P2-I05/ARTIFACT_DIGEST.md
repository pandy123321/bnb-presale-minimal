# PANGU2 — Staging Artifact Digest

- **Date:** 2026-08-02
- **Environment:** BSC Testnet Staging (Chain ID: 97)
- **Status:** PENDING DEPLOYMENT

## 1. Docker Image SHAs

| Service | Image | SHA256 Digest | Build Date |
|---|---|---|---|
| PHP-FPM | local build (`docker/php`) | `TBD` (run `docker images --digests`) | TBD |
| Nginx | `nginx:1.27-alpine` | `TBD` | TBD |
| PostgreSQL | `postgres:16-alpine` | `TBD` | TBD |
| Redis | `redis:7-alpine` | `TBD` | TBD |

**Generate after build:**
```bash
docker compose -f docker-compose.yml -f infra/staging/docker-compose.staging.yml build
docker images --digests pangu2-php-staging
```

## 2. Contract Address SHAs

| Contract | Address | Tx Hash | ABI SHA256 | Verified |
|---|---|---|---|---|
| Pangu2Token | `TBD` | `TBD` | `TBD` | ☐ |
| Pangu2TradeRouter | `TBD` | `TBD` | `TBD` | ☐ |
| DividendDistributor | `TBD` | `TBD` | `TBD` | ☐ |
| SupportPool | `TBD` | `TBD` | `TBD` | ☐ |
| BuybackLocker | `TBD` | `TBD` | `TBD` | ☐ |
| FeeVault | `TBD` | `TBD` | `TBD` | ☐ |
| CostBasisManager | `TBD` | `TBD` | `TBD` | ☐ |
| GovernanceAdapter | `TBD` | `TBD` | `TBD` | ☐ |
| Timelock | `TBD` | `TBD` | `TBD` | ☐ |

**ABI SHA256:**
```bash
sha256sum contracts/out/Pangu2TradeRouter.sol/Pangu2TradeRouter.json
sha256sum contracts/out/DividendDistributor.sol/DividendDistributor.json
sha256sum contracts/out/SupportPool.sol/SupportPool.json
sha256sum contracts/out/BuybackLocker.sol/BuybackLocker.json
sha256sum contracts/out/FeeVault.sol/FeeVault.json
sha256sum contracts/out/CostBasisManager.sol/CostBasisManager.json
```

## 3. Frontend Build Hashes

| App | Build Command | Output Dir | Gzip Size | SHA256 |
|---|---|---|---|---|
| DApp | `vite build` | `apps/dapp/dist/` | `TBD` | `TBD` |
| Admin | `vite build` | `apps/admin/dist/` | `TBD` | `TBD` |

**Generate:**
```bash
cd apps/dapp && npm run build && sha256sum dist/index.html
cd apps/admin && npm run build && sha256sum dist/index.html
```

## 4. Backend Checkout Hash

```bash
git rev-parse HEAD
# Expected: current HEAD of main branch
git describe --tags
```

## 5. Infrastructure Configuration Hash

Combined hash of all deployed configuration files:
```bash
sha256sum docker-compose.yml \
  infra/staging/docker-compose.staging.yml \
  infra/staging/nginx-dapp.conf \
  infra/staging/.env.example \
  docker/php/Dockerfile \
  docker/nginx/default.conf \
  config/testnet/RPC_CONFIGURATION.md
```

## 6. End-to-End Artifact Provenance

| Artifact | Source | Build | Deploy |
|---|---|---|---|
| Smart Contracts | `contracts/src/*.sol` | `forge build` | `forge script DeployPangu2.s.sol --broadcast` |
| Backend | `backend/` | `docker compose build` | `docker compose up -d` |
| DApp | `apps/dapp/` | `vite build` | Nginx static files |
| Admin | `apps/admin/` | `vite build` | Nginx static files |
| Chain Worker | `services/chain-worker/` | `tsx src/index.ts` | Docker or systemd |

## 7. Integrity Verification

```bash
# After deployment, verify contracts match the manifest
for addr in $(grep -oP '0x[a-fA-F0-9]{40}' docs/evidence/PB-S6/P2-I04/DEPLOYMENT_MANIFEST.md | grep -v '0x000'); do
  echo "Checking $addr..."
  curl -s -X POST -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getCode\",\"params\":[\"$addr\",\"latest\"],\"id\":1}" \
    https://data-seed-prebsc-1-s1.binance.org:8545 | jq '.result | length'
done
# Expected: each returns > 4 (non-empty bytecode)

# Verify Docker image is the one we built
docker inspect pangu2-php-staging | jq '.[0].Created'

# Verify frontend hash matches build artifact
curl -s http://localhost:8080/dapp/index.html | sha256sum
```

---

**This document will be updated with actual SHAs and signatures after deployment.**
