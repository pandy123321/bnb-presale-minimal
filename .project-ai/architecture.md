# PANGU2 — Architecture

## 模块拓扑

```
apps/dapp (Vue 3) ──────┐
apps/admin (Vue 3) ─────┤
                         ├── packages/api-types ── OpenAPI
backend (Laravel 13) ────┤
                         └── services/chain-worker (TypeScript)
contracts-v2 (Solidity) ─┘
packages/ui/ ────→ apps/dapp (shared Vue components + CSS)

未来（Go V2）:
backend-go/ ──→ Go 模块化单体 ──→ PostgreSQL binggoplus_go
   ├── api/          (Public + Admin HTTP, :8080)
   ├── indexer/      (Block/Log/Confirmation/Reorg)
   ├── projector/    (幂等投影器)
   ├── reconciler/   (治理签名/广播/receipt)
   └── dividend-builder/
```

---

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

---

## backend/ (Laravel 13, PHP 8.4)

**路由**: `web.php`（admin-api, Session+CSRF+RBAC） + `api.php`（public API, wallet auth）
**模块**: Core/Auth(EIP-191), Core/Chain(RPC/BCMath/ChainOperatorService), Core/ContractRegistry(CRUD+Service), Core/RBAC, Pangu2/{Admin,Buyback,Dividend,Locker,Staking,Trade}
**治理面板**（GE-A01~A04）: ContractRegistry CRUD + 6 Governance Read(eth_call) + 6 Governance Write(eth_sendRawTransaction + 纯 PHP ECDSA 签名)
**ChainOperatorService**: 离线 ECDSA 签名 + EIP-155 + estimateGas 预检 + 主网默认禁止

**已知局限**:
- QuoteService 仍 mock/UNAVAILABLE
- Staking fundRewards/setRewardRate → 501
- 4 个 Job 全未实现
- 部分路由缺失 auth:web（已在 GE-A03 修复）
- DividendController 重复 chainId()（已在 FIX-01 修复）

---

## apps/dapp/ (Vue 3 + TypeScript + Vite, V7.1 完成)

**路由**: 3 条（`/` `/trade` `/portfolio`）
**页面**: HomePage（Hero+Wallet+Protocol+Why+Ranking）/ TradePage（Market+Order+Activity+trading-disabled）/ PortfolioPage（Asset+Staking+Buyback；Team/Referral/佣金为 OUT_OF_SCOPE）
**Stores & Composables**: useWallet(wagmi v2), useData, useStaking, useDataStatus, useQuote, useMarket, useTransaction, useStaking(feature)
**数据状态**: 所有 Stores/Composables 已实现，但视图层全部 `—`（未接入数据）

---

## apps/admin/ (Vue 3 + TypeScript + Vite)

**8 页面**, Session+CSRF 认证。
**治理后端已就绪但前端未完全接入**: GovernanceView 主要展示 Jobs/Audit/RBAC 硬编码，未调用 `/governance/*` 端点。Contract Registry 无管理界面。

---

## Chain Worker (TypeScript, viem)

**6 个事件流**: TRADE/DIVIDEND/STAKING/LOCKER/SUPPORT/FEE_VAULT（已从 2 扩展至 6，FIX-03）
**安全**: Fencing Token + Reorg 恢复 + BlockHash Checkpoint + log_index 唯一 + 幂等投影 + 维护租约

---

## Go Backend V2 目标架构（冻结中，未开发）

```
backend-go/
├── cmd/{api,indexer,projector,reconciler,dividend-builder}
├── api/{openapi.yaml, generated/}
├── contracts/{abi/, bindings/, deployments/}
├── db/{migrations/, queries/, generated/}
├── internal/{domain,application,chain,indexer,projector,governance,...}
```

新 API: `/api/v2/projects/binggoplus`, Admin: `/admin-api/v2/projects/binggoplus`
数据库: `binggoplus_go.binggoplus_v2`
从部署区块重建全部历史，不迁移旧 Mock/Projection/Session。

**权限与投影边界（文档冻结候选）：**
- `bgp_indexer`：写入 Raw Event / Block 确认与 canonical；不负责投影完成态。
- `bgp_projector`：Raw Event 只读；写 `projection_receipts` 与领域投影；Dividend 链上派生列（含 `merkle_root`）列级 UPDATE。
- `bgp_dividend`：只读四个历史/覆盖视图构建 Artifact；不能读 current 表冒充快照；不能写 `merkle_root`。

---

## 数据流

```
DApp → BSC Testnet RPC → TradeRouter.buy/sell (用户钱包直接签名)
Chain Worker → RPC getLogs → PostgreSQL raw_events → Projector → Backend API
Admin → Backend API (Session+CSRF+RBAC) → Dashboard/Jobs/Governance
Admin 写操作 → ChainOperatorService → eth_sendRawTransaction → BSC Testnet
```

---

## 禁止事项

- Mainnet 永久 NO-GO
- OpenTrading 不得自动执行
- 实现 Agent 不得自行签发独立批准（合约修复 S0-S9 规则）
- Go V2 未完成冻结前不得写业务代码

---

## 信息来源
- contracts-v2/src/*.sol, contracts-v2/broadcast/*/97/run-latest.json
- backend/routes/web.php, backend/app/Modules/
- apps/dapp/src/views/, apps/dapp/src/router/index.ts
- packages/ui/, services/chain-worker/src/
- docs/current/go-backend-v2/
- docs/current/BSC_TESTNET_DEPLOYMENT_BASELINE.md
