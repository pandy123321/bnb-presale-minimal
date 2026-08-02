# PANGU2 Development Guide

```text
Updated: 2026-08-02
```

## 依赖版本

| 工具 | 需安装版本 |
|---|---|
| Node.js | 22+ |
| pnpm | 10.34.5 |
| PHP | 8.4+ |
| Composer | 2.x |
| Foundry | v1.7.1 (含 forge + cast) |
| Docker | 27+ (含 compose v2) |

## 快速启动：完整环境

```bash
docker compose -f infra/local/docker-compose.local.yml up -d
make -C infra/local status
```

## 快速启动：模块独立开发

```bash
# From project root (pnpm workspace resolves workspace:* deps)
pnpm install

# DApp → http://localhost:5173
cd apps/dapp && pnpm dev

# Admin → http://localhost:5174
cd apps/admin && pnpm dev

# Mock API → http://localhost:4000
cd packages/mock-api && pnpm dev
```

## 智能合约

```bash
cd contracts
forge build
forge test --no-match-path "*/fork/*"

# BSC Testnet 分叉测试
export FORK_RPC="<testnet_archive_url>"
export FORK_BLOCK="122688000"

forge test \
  --match-path "*/fork/*" \
  --fork-url "$FORK_RPC" \
  --fork-block-number "$FORK_BLOCK"

# BSC Mainnet 分叉测试 (部署 NO-GO 但分叉测试允许)
export FORK_RPC="<mainnet_archive_url>"
export FORK_BLOCK="<approved_mainnet_block>"

forge test \
  --match-path "*/fork/*" \
  --fork-url "$FORK_RPC" \
  --fork-block-number "$FORK_BLOCK" \
  --chain-id 56
```

## 后端

```bash
cd backend
cp .env.example .env
# Edit .env: DB_USERNAME=bnb DB_PASSWORD=bnb_dev_pass DB_DATABASE=bnb_presale
composer install
php artisan migrate
php artisan serve --port=8080
```

## 运行测试

```bash
# Contracts
cd contracts && forge test --no-match-path "*/fork/*"

# Backend
cd backend && php artisan test

# Frontend + packages (from root)
pnpm -r typecheck
pnpm -r test
pnpm -r build
```

## 端口

| 服务 | 端口 | 健康检查 |
|---|---|---|
| Anvil | 8545 | `curl -s -X POST http://localhost:8545 -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'` |
| PostgreSQL | 5432 | `pg_isready -U bnb -d bnb_presale` |
| Redis | 6379 | `redis-cli PING` |
| Laravel API | 8080 | `curl localhost:8080/up` |
| Mock API | 4000 | `curl localhost:4000/health` |
| DApp | 5173 | `curl -I localhost:5173` |
| Admin | 5174 | `curl -I localhost:5174` |

## 环境变量

```text
backend/.env.example → backend/.env
  DB_USERNAME=bnb
  DB_PASSWORD=bnb_dev_pass
  DB_DATABASE=bnb_presale
```

## 禁止事项

- 不将生产 Secret 提交至仓库
- 不直接在 `packages/api-types/src/` 手工编辑（由 OpenAPI 生成）
