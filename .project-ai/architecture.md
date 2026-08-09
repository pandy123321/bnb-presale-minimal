# BingGoPlus — Architecture

## 当前模块拓扑与转向

```
apps/dapp (Vue 3) ──→ Flap Token 列表/详情/交易入口（F6 重做）
apps/admin (Vue 3) ──→ Go Flap API (v3) ──→ PostgreSQL binggoplus_go.binggoplus_flap_v1
Flap Portal/VaultPortal ──→ BSC Testnet 新 Token + 官方/自建 Vault
contracts-flap (规划) ──→ BGPlus Factory/Vault/Buyback/Locker/Dividend/Staking
contracts-v2 ──→ Legacy PANGU2 已部署合约，只读保留
packages/ui/ ──→ apps/dapp (shared Vue components + CSS)
```

```
Go（唯一目标后端；Laravel 代码冻结；当前处于 Flap F0 文档 Gate）:
backend-go/ — 复用工程地基，PANGU2 候选业务代码不等于 Flap 能力
   ├── cmd/api/main.go                ← HTTP entry
   ├── cmd/indexer/main.go             ← 事件扫描
   ├── cmd/projector/main.go           ← 投影器
   ├── cmd/reconciler/main.go          ← F5 Signer/交易执行与 Receipt 跟踪；真实测试网链写需独立 Gate
   ├── cmd/dividend-builder/main.go
   ├── internal/config/config.go
   ├── internal/store/pgx.go           ← PostgreSQL 连接池
   ├── internal/transport/http/health.go
   ├── internal/domain/types.go
   ├── contracts/ (Legacy PANGU2 ABI，F1 后新增固定 Flap ABI)
   ├── db/migrations/ (Legacy v2；F2 后新增 flap_v1)
   └── api/ (Legacy v2；F2 后新增 Flap v3)
```

---

## contracts-v2/ (11 合约, BSC Testnet, 部署提交 3ef50b6)

| 合约 | 部署地址 | 职责 |
|------|------|------|
| Pangu2Token | `0x49a4a6...` | ERC-20 + 税收 + Launch Protection + Whitelist |
| Pangu2TradeRouter | `0xB0b5b5...` | buy/sell + preview + TWAP |
| CostBasisManager | `0x695660...` | KNOWN/UNKNOWN 成本追踪 |
| FeeVault | `0xF82313...` | DIVIDEND/SUPPORT 双 Bucket |
| SupportPool | `0xe6d378...` | 0.01 BNB/60s 回购 |
| BuybackLocker | `0x0a2283...` | 365 天锁仓 |
| DividendDistributor | `0x917705...` | 前 100 名分红 + Merkle Proof |
| Pangu2Staking | `0xf1D27E...` | 1-730 天锁仓 + 10% 罚金 |
| PancakeV2Adapter | `0xC3BB21...` | V2 swap/quote |
| PancakeV2TwapOracle | `0x11C39D...` | TWAP + 低流动性保护 |
| Pair | `0x07d481...` | PANGU2/WBNB |

8 合约 admin 已 renounce。合约修复 F-2/F-3 已提交，F-1/F-4 待执行。

---

## 当前阶段

| Gate | 状态 |
|------|:--:|
| FLAP-F0 | `V4_REVIEW_BLOCKED / V5_REMEDIATION_FIX_READY / REMOTE_PUSH_PENDING` |
| F1 | `NOT_AUTHORIZED` |
| Flap 实现 | `NOT_STARTED` |
| BSC Mainnet | `NO-GO` |

F10 只处理通用 Staking；F11 单独处理 Legacy PANGU2 Cutover/Retirement。两者不得共用 Commit、审核包、部署或回滚单元。

---

## apps/dapp/ (Vue 3, V7.1 完成)

现有 3 页（Home / Trade / Portfolio）与动态数据 `—` 属于 Legacy PANGU2 前端。Flap 最小 Public Read/DApp 读面在 F6 Native MVP 重做；F6 之前不得将旧页面标记为 Flap 能力。

## apps/admin/ (Vue 3)

现有 8 页面和 Session+CSRF 作为 UI/Auth 地基复用。Flap Admin Launch Console 在 F6 接入 F4 Workflow/API 与 F5 Transaction Execution；旧 G6 不再是当前阶段。

## F3-F7 职责边界

```text
F3 = Chain Acquisition + Indexer + Deterministic Read Model
F4 = Launch Workflow + Admin/Public API; no signing
F5 = Signer + Transaction Execution + Receipt/Event binding
F6 = Admin Launch Console + minimal public read surface + Native MVP
F7 = BGPlus RevenueVault Solidity; entry authorization required

F6_TO_F7_AUTO_ADVANCE = FORBIDDEN
F7_ENTRY_AUTHORIZED = NO_BY_DEFAULT
```

## 数据流

```
Admin → Go Launch Draft/Validation/Approval → Transaction Intent → Admin Wallet → Flap Portal/VaultPortal
Flap/BSC Events → Go Indexer → canonical raw events → Projector → Token/Curve/Migration/Vault Read Models
Public API/DApp → Flap Token 状态与交易入口
BGPlus Tax Revenue → BGPlus Vault → Dividend/Buyback/Treasury → Locker/Distributor
```

## 禁止事项

- Mainnet 永久 NO-GO
- PANGU2 OpenTrading 已退役且不得重复；Flap Launch 必须单独审批和钱包签名
- PANGU2 参数不可修改；Flap 参数只能在目录和生命周期内设置
- 旧 Worker 与 Go V2 不得写同一 Database/Schema
- F0/F2 未完成独立审核和责任人签署前不得进入 Flap 代码
- 新 Solidity、测试网签名/广播和平台 Signer 均需独立 Gate

## 信息来源
- contracts-v2/src/*.sol, contracts-v2/broadcast/*/97/run-latest.json
- backend-go/（G1 审核基线 28 文件；当前工作区候选变更未审核）
- docs/current/go-backend-v2/
- docs/current/go-backend-v2/27_FLAP_PRODUCT_PIVOT_DECISION.md
- docs/current/go-backend-v2/28_FLAP_PRODUCT_SCOPE_AND_PARAMETER_CATALOG.md
- docs/current/go-backend-v2/29_FLAP_TARGET_ARCHITECTURE.md
- docs/current/go-backend-v2/30_FLAP_F0_F11_EXECUTION_PLAN.md
- docs/current/go-backend-v2/sql/0001_binggoplus_v2_schema.sql
