# BingGoPlus — Architecture

## 模块拓扑

```
apps/dapp (Vue 3) ──────┐
apps/admin (Vue 3) ─────┤
                         ├── packages/api-types ── OpenAPI
backend (Laravel 13) ────┤
                         └── services/chain-worker (TypeScript)
contracts-v2 (Solidity) ─┘
packages/ui/ ────→ apps/dapp (shared Vue components + CSS)

未来（Go V2, 设计冻结完成，Runtime Gate 执行中）:
backend-go/ ──→ Go 模块化单体 ──→ PostgreSQL binggoplus_go.binggoplus_v2
   ├── api/          (Public + Admin HTTP, :8081)          → bgp_api
   ├── indexer/      (Block/Log/Confirmation/Reorg)        → bgp_indexer
   ├── projector/    (幂等投影器)                           → bgp_projector
   ├── reconciler/   (治理签名/广播/receipt)                 → bgp_reconciler
   └── dividend-builder/ (快照/排名/Artifact)              → bgp_dividend

Runtime Gate 证据:
docs/current/go-backend-v2/runtime-gate/
   ├── 00_RUNTIME_GATE_STATUS.md          ← 总体状态
   ├── 01_POSTGRESQL_MIGRATION_EVIDENCE.md ← RT-GATE-01
   ├── 02_ROLE_RUNTIME_MATRIX.md          ← RT-GATE-01 权限矩阵
   ├── 03_BSC_TESTNET_READBACK_PLAN.md    ← RT-GATE-02 执行计划
   ├── 04_BSC_TESTNET_READBACK_EVIDENCE.md ← RT-GATE-02 占位
   ├── 05_GO_BUILD_STAGE_DECISION.md      ← RT-GATE-03 G0→G1
   └── evidence/                           ← 待填充（postgresql-version.txt, migration logs, readback JSON）
```

## contracts-v2/ (11 合约, BSC Testnet, 部署提交 3ef50b6)

| 合约 | 部署地址 | 职责 |
|------|------|------|
| Pangu2Token | `0x49a4a6...` | ERC-20 + 税收结算 + Transfer Hook + 白名单 + Launch Protection |
| Pangu2TradeRouter | `0xB0b5b5...` | buy/sell 入口 + preview + TWAP 价格 + 混合卖出计税 |
| CostBasisManager | `0x695660...` | WBNB 成本追踪 + KNOWN/UNKNOWN 判定 |
| FeeVault | `0xF82313...` | 税费归集 + DIVIDEND/SUPPORT 双 Bucket |
| SupportPool | `0xe6d378...` | 0.01 BNB 固定回购 + 60s 间隔 |
| BuybackLocker | `0x0a2283...` | FIXED_DURATION 365 天锁仓 |
| DividendDistributor | `0x917705...` | 前 100 名分红 + Merkle Proof + Epoch |
| Pangu2Staking | `0xf1D27E...` | 锁仓 1-730 天 + 10% 罚金 + O(1) 奖励 |
| PancakeV2Adapter | `0xC3BB21...` | PancakeSwap V2 swap/quote |
| PancakeV2TwapOracle | `0x11C39D...` | 累积价格 TWAP + 低流动性保护 |
| Pair (PANGU2/WBNB) | `0x07d481...` | PancakeSwap V2 交易对 |

### 合约修复执行包（S0-S9）

详见 `docs/current/go-backend-v2/contracts/remediation/`。9 个阶段，3 个大审核（M1/M2/M3），9 个 Finding。串行执行，不可跳过。

## backend/ (Laravel 13, PHP 8.4)

**路由**: `web.php`（admin-api, Session+CSRF+RBAC） + `api.php`（public API, wallet auth）
**模块**: Core/Auth(EIP-191), Core/Chain(RPC/BCMath/ChainOperatorService), Core/ContractRegistry(CRUD+Service), Core/RBAC, Pangu2/{Admin,Buyback,Dividend,Locker,Staking,Trade}
**治理面板**（GE-A01~A04）: ContractRegistry CRUD + 6 Governance Read(eth_call) + 6 Governance Write(eth_sendRawTransaction + 纯 PHP ECDSA 签名)
**ChainOperatorService**: 离线 ECDSA 签名 + EIP-155 + estimateGas 预检 + 主网默认禁止

**已知局限**:
- QuoteService 仍 mock/UNAVAILABLE
- Staking fundRewards/setRewardRate → 501
- 4 个 Job 全未实现

## apps/dapp/ (Vue 3 + TypeScript + Vite, V7.1 完成)

**路由**: 3 条（`/` `/trade` `/portfolio`）
**页面**: HomePage / TradePage / PortfolioPage
**Stores & Composables**: 全部已实现，视图层全部 `—`（等后端 API 接入）
**数据状态**: 所有 Stores/Composables 已实现但未接入真实数据

## apps/admin/ (Vue 3 + TypeScript + Vite)

**8 页面**, Session+CSRF 认证。GovernanceView 主要展示硬编码，未调用 `/governance/*` 端点。

## Chain Worker (TypeScript, viem)

**6 个事件流**: TRADE/DIVIDEND/STAKING/LOCKER/SUPPORT/FEE_VAULT
**安全**: Fencing Token + Reorg 恢复 + BlockHash Checkpoint + log_index 唯一 + 幂等投影

## Go Backend V2 目标架构（设计冻结完成，代码未开始）

```
backend-go/                              ← 不存在，G1 未授权
├── cmd/{api,indexer,projector,reconciler,dividend-builder}
├── api/{openapi.yaml, generated/}
├── contracts/{abi/, bindings/, deployments/}
├── db/{migrations/, queries/, generated/}
├── internal/{domain,application,chain,indexer,projector,governance,dividend,...}
└── tools/
```

新 API: `/api/v2/projects/binggoplus`, Admin: `/admin-api/v2/projects/binggoplus`
数据库: `binggoplus_go.binggoplus_v2`，44 张表 + 4 个 Dividend security_barrier 历史视图
从部署区块重建全部历史，不迁移旧 Mock/Projection/Session。

**Runtime Gate 状态**:
- RT-GATE-01 (PostgreSQL Migration + Role): `BLOCKED_POSTGRESQL_NOT_AVAILABLE`
- RT-GATE-02 (BSC Testnet Readback): `BLOCKED_APPROVED_RPC_REQUIRED`
- RT-GATE-03 (Go Build Stage): `DECISION_READY` — G0→G1→G2 阶段推进方案已定义

**权限与投影边界（文档冻结候选）：**
- `bgp_migrator`：唯一 Schema/DDL 所有者，仅 Migration 时使用；运行进程不持有/继承该角色
- `bgp_indexer`：写入 Block/Raw Event/Lease/Cursor；Raw Event 更新限于 decode/确认/canonical；不得修改原 topic/data/address
- `bgp_projector`：Raw Event 只读；写 `projection_receipts` 与领域投影；Dividend 链上派生列列级 UPDATE（state/merkle_root/claim window/carry）；versioned ledger 只追加不可删除
- `bgp_dividend`：只读四个窄化历史/覆盖 View；写 Artifact/Allocation/Preflight（append-only）；不能读 current 表冒充快照；不能写 `merkle_root`
- `bgp_reconciler`：读 approved Command + Dividend evidence；列级更新 Command state/updated_at；写 Signer Nonce/Tx Attempt；不得 INSERT Command；只能在当前 bound Publish Command 失败时走 `PUBLISH_QUEUED -> FAILED` 边
- `bgp_api`：读写认证/Session/Idempotency/Governance intake/Dividend DRAFT；通过 `bind_current_dividend_publish_command(...)` 绑定 Publish Command；不拥有 Epoch 直接 UPDATE
- `bgp_auditor / bgp_readonly`：只读，不可写任何业务表
- 所有运行角色: LOGIN, NO SUPERUSER, NO CREATEDB, NO CREATEROLE, NO BYPASSRLS；`current_user` exact role model

## 数据流

```
DApp → BSC Testnet RPC → TradeRouter.buy/sell (用户钱包直接签名)
Chain Worker → RPC getLogs → PostgreSQL raw_events → Projector → Backend API
Admin → Backend API (Session+CSRF+RBAC) → Dashboard/Jobs/Governance
Admin 写操作 → ChainOperatorService → eth_sendRawTransaction → BSC Testnet

未来 (Go V2):
Go Indexer → RPC getLogs → binggoplus_v2.chain_raw_events (Database: binggoplus_go, Schema: binggoplus_v2)
Go Projector → chain_raw_events → projection_receipts → 领域投影
Go API → HTTP → Public/Admin 读 (LIVE only)
Admin 写 → Go API → governance_commands → Go Reconciler → Signer → BSC Testnet
Dividend → Builder → 四个窄化 View → Artifact → API approve → Reconciler publish
```

## 禁止事项

- Mainnet 永久 NO-GO
- OpenTrading 不得自动执行
- 实现 Agent 不得自行签发独立批准（合约修复 S0-S9 规则）
- Go V2 未完成 G0 Freeze 前不得写业务代码
- 开源依赖未获 APPROVE_DOWNLOAD 前不得下载/加入 go.mod
- 不得自行寻找公共 RPC 冒充批准输入（RT-GATE-02）
- API 不持有私钥；Signer/Reconciler 单独隔离
- 旧 Worker 与 Go V2 不得写同一 Database/Schema

## 信息来源
- contracts-v2/src/*.sol, contracts-v2/broadcast/*/97/run-latest.json
- backend/routes/web.php, backend/app/Modules/
- apps/dapp/src/views/, apps/dapp/src/router/index.ts
- packages/ui/, services/chain-worker/src/
- docs/current/go-backend-v2/
- docs/current/go-backend-v2/runtime-gate/
- docs/current/go-backend-v2/contracts/BSC_TESTNET_DEPLOYMENT_BASELINE.md
- docs/current/go-backend-v2/sql/0001_binggoplus_v2_schema.sql
- docs/current/go-backend-v2/sql/0002_binggoplus_v2_runtime_privileges.sql
