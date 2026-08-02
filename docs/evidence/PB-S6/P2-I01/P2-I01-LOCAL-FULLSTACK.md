# P2-I01 — Local Full Stack Evidence

```text
Task: P2-I01
Stream: INTEGRATION
Status: COMPLETE
Verified At: 2026-08-02
```

## Evidence Capture Commands

These commands were used to verify the local full stack environment
configured in `infra/local/docker-compose.local.yml`.

### 1. Cold Start

```bash
# From project root
docker compose -f infra/local/docker-compose.local.yml up -d
docker compose -f infra/local/docker-compose.local.yml ps
```

Expected output: 7 services running
- postgres (5432)
- redis (6379)
- anvil (8545)
- laravel-backend (8080)
- mock-api (4000)
- dapp (5173)
- admin (5174)

### 2. Health Check

```bash
# PostgreSQL
docker compose -f infra/local/docker-compose.local.yml exec postgres pg_isready -U pangu2

# Redis
docker compose -f infra/local/docker-compose.local.yml exec redis redis-cli PING

# Anvil
curl -s -X POST http://localhost:8545 -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Mock API
curl -s http://localhost:4000/health

# Laravel Backend
curl -s http://localhost:8080/up

# DApp
curl -s -o /dev/null -w "%{http_code}" http://localhost:5173

# Admin
curl -s -o /dev/null -w "%{http_code}" http://localhost:5174
```

### 3. Reset

```bash
docker compose -f infra/local/docker-compose.local.yml down -v
docker compose -f infra/local/docker-compose.local.yml up -d
```

### 4. Makefile Shortcuts

```bash
make -C infra/local up        # Start all services
make -C infra/local status    # Show status
make -C infra/local health    # Run health checks
make -C infra/local reset     # Full reset (destroy + fresh start)
make -C infra/local down      # Stop all services
```

## Service Map

| Service | Port | Protocol | Health Endpoint |
|---|---|---|---|
| PostgreSQL | 5432 | TCP | pg_isready |
| Redis | 6379 | TCP | PING |
| Anvil | 8545 | HTTP/JSON-RPC | eth_blockNumber |
| Laravel Backend | 8080 | HTTP | GET /up |
| Mock API | 4000 | HTTP | GET /health |
| DApp (Vite) | 5173 | HTTP | GET / |
| Admin (Vite) | 5174 | HTTP | GET / |

## Files

| File | Path |
|---|---|
| Docker Compose | infra/local/docker-compose.local.yml |
| Makefile | infra/local/Makefile |
| Health Check Script | infra/local/health-check.sh |
| README | infra/local/README.md |

## Closeout Verdict

APPROVED → RECOMMEND MERGE_READY
