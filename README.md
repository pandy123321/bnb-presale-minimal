# PANGU2 — BNB Presale Platform

链上代币发行与分红治理平台。智能合约 + Laravel API + Chain Worker + 用户 DApp + 运营 Admin。

**当前阶段：** 核心模块实现完成，Integration Gate 与 Closeout 证据修复中。

```
BSC_MAINNET: NO-GO
Automatic Merge: FORBIDDEN
Automatic Deployment: FORBIDDEN
```

## 目录

```
bnb-presale-minimal/
├── contracts/        Solidity 合约 (Foundry + solc 0.8.24)
├── backend/          Laravel 13 API
├── services/         Chain Worker (TypeScript 链上事件索引)
├── apps/
│   ├── dapp/         用户移动端 DApp (Vue 3 + TypeScript + Vite)
│   └── admin/        运营管理后台 (Vue 3 + TypeScript + Vite)
├── packages/
│   ├── api-types/    共享 TypeScript 类型 (OpenAPI 生成)
│   ├── mock-api/     开发期 Mock API Server
│   ├── domain/       共享领域常量
│   └── schema-validator/ Schema 契约验证工具
├── docs/
│   ├── baseline/     Phase 1 基线规范
│   ├── current/      Phase 2 执行文档 + 任务规格
│   ├── schemas/      OpenAPI / 状态机 / 错误码
│   └── evidence/     各阶段验收证据
├── infra/local/     本地全栈 Docker 编排
├── config/testnet/  BSC Testnet 部署配置
└── reports/         WP-01 证据输出
```

## 技术栈

| 模块 | 技术 |
|---|---|
| 智能合约 | Solidity 0.8.24, Foundry, OpenZeppelin v5.0.2 |
| 后端 API | Laravel 13, PHP 8.4, PostgreSQL, Redis/Horizon |
| Chain Worker | TypeScript, viem, PostgreSQL |
| DApp 前端 | Vue 3, TypeScript, Vite, wagmi/viem |
| Admin 前端 | Vue 3, TypeScript, Vite, Pinia |
| 基础设施 | Docker Compose, Anvil, GitHub Actions |

## 开发入口

- **核心文档:** [docs/current/](docs/current/)
- **模块状态:** [docs/current/MODULE_STATUS.md](docs/current/MODULE_STATUS.md)
- **开发环境:** [docs/current/DEVELOPMENT_GUIDE.md](docs/current/DEVELOPMENT_GUIDE.md)
- **API 契约:** [docs/schemas/openapi/pangu2-api-v1.yaml](docs/schemas/openapi/pangu2-api-v1.yaml)
- **本地全栈:** [infra/local/README.md](infra/local/README.md)

## 快速启动

```bash
# 本地全栈环境
docker compose -f infra/local/docker-compose.local.yml up -d

# Or use Make
make -C infra/local up
```

| 服务 | 端口 |
|---|---|
| Anvil | 8545 |
| PostgreSQL | 5432 |
| Redis | 6379 |
| API | 8080 |
| Mock Server | 4000 |
| DApp | 5173 |
| Admin | 5174 |
