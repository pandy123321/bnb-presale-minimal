# PANGU2 Development Guide

本文件仅供开发人员快速启动本地环境，不包含架构说明或产品规则。

```text
Updated: 2026-08-02
```

## 依赖版本

| 工具 | 需安装版本 |
|---|---|
| Node.js | 22+ |
| pnpm | latest |
| PHP | 8.4+ |
| Composer | 2.x |
| Foundry | v1.7.1 (含 forge + cast) |
| Docker | 27+ (含 compose v2) |

## 快速启动：完整环境

```bash
# From project root
docker compose -f infra/local/docker-compose.local.yml up -d
```

## 快速启动：模块独立开发

### 前端（推荐统一安装后再启动）

```bash
# From project root (pnpm workspace resolves workspace:* deps)
pnpm install

# DApp
cd apps/dapp && pnpm dev      # → http://localhost:5173

# Admin
cd apps/admin && pnpm dev     # → http://localhost:5174

# Mock API
cd packages/mock-api && pnpm dev  # → http://localhost:4000
```

### 智能合约

```bash
cd contracts
forge build
forge test --no-match-path "*/fork/*"
```

### 后端

```bash
cd backend
cp .env.example .env        # 编辑 .env 填入本地数据库: DB_USERNAME=bnb, DB_PASSWORD=bnb_dev_pass
composer install
php artisan migrate
php artisan serve --port=8080
```

## 端口

| 服务 | 端口 | 健康检查 |
|---|---|---|
| Anvil | 8545 | `curl -X POST localhost:8545 -d '{"method":"eth_blockNumber"}'` |
| PostgreSQL | 5432 | `pg_isready -U bnb -d bnb_presale` |
| Redis | 6379 | `redis-cli PING` |
| Laravel API | 8080 | `curl localhost:8080/up` |
| Mock API | 4000 | `curl localhost:4000/health` |
| DApp | 5173 | `curl -I localhost:5173` |
| Admin | 5174 | `curl -I localhost:5174` |

## 合约

```bash
cd contracts
forge build
forge test --no-match-path "*/fork/*"

# BSC Testnet fork tests (需要 RPC URL)
BSC_TESTNET_RPC_URL=<url> forge test --match-path "*/fork/*" --fork-url "$BSC_TESTNET_RPC_URL"
```

## 环境变量

```text
backend/.env.example → backend/.env
  DB_USERNAME=bnb          # PostgreSQL用户（与docker compose一致）
  DB_PASSWORD=bnb_dev_pass
  DB_DATABASE=bnb_presale
```

## 禁止事项

- 不部署至 BSC Mainnet
- 不提交 `.env` 或生产密钥
- 不直接在 `packages/api-types/src/` 手工编辑（由 OpenAPI 生成）
