# PANGU2 — Project Context

## 确认信息（基于代码）

### 项目目标
链上代币发行与分红治理平台（品牌 BingGoPlus / BGP）。用户用 BNB 买卖 PANGU2 代币，按持有成本判定税率，通过 PancakeSwap V2 提供流动性。核心机制：买入税 4%、卖出税 4%/10%、Launch Protection 30% 税、WhiteList 0% 税、0.01 BNB 回购、365 天锁仓、前 100 名分红、Staking 锁仓收益。

### 当前阶段
合约已部署到 BSC Testnet（部署提交 `3ef50b6`，含 Deploy/Bootstrap/Finalize/OpenTrading 四个阶段的 73 个广播回执）。DApp V7.1 重构完成。Admin 治理 API（GE-A01~A04）完成。**Phase 0-9 分批执行计划已定义**。**Go V2 后端重建方案和合约安全修复包（S0-S9）已冻结。**

### 支持网络
- BSC Testnet (Chain 97) — 当前部署网络
- BSC Mainnet (Chain 56) — NO-GO（永久禁止，所有脚本强制 revert）

### 全局硬约束
- BSC_MAINNET_DEPLOYMENT: NO-GO
- BSC_MAINNET_FORK_TESTING: ALLOWED
- Automatic Merge / Push / Deployment: FORBIDDEN
- OpenTrading 不得被 CI/部署脚本自动调用

### 合约部署状态（BSC Testnet, 2026-08-06）

| 阶段 | 状态 | 部署提交 | 广播文件 |
|------|:--:|------|------|
| Deploy | ✅ 已广播 | `3ef50b6` | `DeployPangu2.s.sol/97/run-latest.json` |
| Bootstrap | ✅ 已广播 | `3ef50b6` | `BootstrapPangu2.s.sol/97/run-latest.json` |
| Finalize | ✅ 已广播 | `3ef50b6` | `FinalizePangu2.s.sol/97/run-latest.json` |
| OpenTrading | ✅ 已广播 | `3ef50b6` | `OpenTradingPangu2.s.sol/97/run-latest.json` |
| 链上 readback | ⏳ 待执行 | — | 需 BSC Testnet RPC |

**部署合约地址**（11 个，与 DApp `deployed.ts` 一致）：

Token `0x49a4a6...`、Router `0xB0b5b5...`、Dividend `0x917705...`、Support `0xe6d378...`、Vault `0xF82313...`、Locker `0x0a2283...`、Staking `0xf1D27E...`、Oracle `0x11C39D...`、Adapter `0xC3BB21...`、Pair `0x07d481...`、CostBasis `0x695660...`。

**过期地址组**（DEPLOYMENT_MANIFEST.md 中的 `0xaf2bD8...` 系列，第一批部署，代币锁死在 `0x0...0001`）— 永不激活。

### 合约功能现状（全部已实现）

| 功能 | 状态 |
|------|:--:|
| 买入税 4% | ✅ |
| 卖出税 4%/10%（KNOWN/UNKNOWN 判定） | ✅ |
| Launch Protection 15 分钟 30% 税 | ✅ |
| Fee Whitelist 0% 税 | ✅ |
| Counterfactual TWAP Oracle | ✅ |
| 0.01 BNB/60s 回购 | ✅ |
| FIXED_DURATION 365 天锁仓 | ✅ |
| 前 100 名分红 + Merkle Proof | ✅ |
| Staking 1-730 天锁仓 + 10% 罚金 | ✅ |
| 部署分阶段流程 | ✅ |

### 合约已知 Finding（9 项，部署提交基准）

| ID | 级别 | 问题 | 目标修复阶段 |
|----|------|------|:--:|
| P1-CB-01 | P1 | UNKNOWN 灰尘污染 KNOWN 仓位 | S1+S2 |
| P1-STK-01 | P1 | Staking 本金返还未更新 CostBasis | S3 |
| P1-STK-02 | P1 | Claim→EarlyUnstake 绕过奖励没收 | S4 |
| P2-TAX-01 | P2 | Whitelist 零税 credit(0) 回滚 | S2 |
| P2-STK-03 | P2 | 没收奖励未返回 reserve | S4 |
| P2-BBK-01 | P2 | 回购未检查价格冲击 | S5 |
| P2-DIV-01 | P2 | Epoch 可在 claimStart 前取消 | S6 |
| P3-ORC-01 | P3 | Oracle uint32 timestamp 回绕 | S7 |
| P3-TKN-01 | P3 | 合约账户全局 code.length 限制 | S8 |

### 合约修复执行包（S0-S9，9 阶段 + 3 大审核）

文档位置：`docs/current/go-backend-v2/contracts/remediation/`

每个阶段强制闭环：Pre-Fix 审核 → 校对 → 仅 CONFIRMED 实现 → 本地验证 → Commit → Post-Fix 审核 → 复审 → APPROVED_CODE_ONLY。实现 Agent 不可自行签发批准。P0/P1/P2 不得用"后续再处理"关闭。

| 阶段 | 范围 | 大审核 |
|------|------|:--:|
| S0 | 设计冻结 | 设计审核 |
| S1 | CostBasis 双账本 | — |
| S2 | Token/Router Mixed Sell + Whitelist 修复 | M1 |
| S3 | Staking 成本迁移 | — |
| S4 | Staking 奖励/退出/暂停 | M2 |
| S5 | Support 回购价格冲击 | — |
| S6 | Dividend Epoch 终态 | — |
| S7 | Oracle uint32 回绕 | — |
| S8 | 合约账户边界 | M3 |
| S9 | 全量代码退出门 | 最终 |

### Go Backend V2 重建计划

文档位置：`docs/current/go-backend-v2/`

Laravel 后端 + TypeScript Chain Worker 将被旁路替换为 Go 模块化单体。新目录 `backend-go/`，独立数据库 `binggoplus_go`，API 大版本 `/api/v2/...`。从部署区块重建全部链上历史，不迁移旧 Mock/Projection/Session。产品品牌统一为 **BingGoPlus**（`Pangu2*` 仅保留为链上合约/ABI/事件名）。当前状态 `FREEZE_CANDIDATE`。

**文档优化关键 Decision（已写入机器规范，作者侧 FIX_READY；独立复验前不得自标 CLOSED）：**

- Raw Event 无物理 `PROJECTED`；投影完成度由 versioned `projection_receipts` 推导；`bgp_projector` 对 Raw Event 只读。
- Dividend Artifact 禁止读 `token_balances_current` / `staking_positions`；必须经四个 `security_barrier` 历史视图按固定 block/hash 重建。
- 团队/推荐/佣金 = `OUT_OF_SCOPE / ROADMAP_NOT_APPROVED`，当前 V2 不实现、不 Mock、不从转账图猜测。
- Round6 完整提审包：`artifacts/BINGGOPLUS_GO_V2_ROUND6_COMPLETE_PACKAGE_20260807_V1/`（Markdown + SQL/OpenAPI/Event/State 同 revision）。
- 文档审核权威规则：`docs/current/DOCUMENT_REVIEW_RULES_V1.0.md`。

### DApp 前端 V7.1（✅ 5 阶段 + 安全修复完成）

- 路由：3 条（`/` `/trade` `/portfolio`），6 旧页面已删除
- 组件：`packages/ui/`（Card/Button/Tag/SectionHead/Sheet/BottomNav/Toast + CSS tokens）
- 数据层：全部 Stores & Composables 已实现（Wallet/Quote/Transaction/Staking/Market/DataStatus）
- 视图层：所有动态数据显示 `—`（等后端 API 接入真实数据）
- 安全：FIX-01~07 全部完成（CSS 令牌统一、Worker 6 事件流、按钮 accessibility、API 安全）

### Admin 后端治理面板（GE-A01~A04 完成）

- ✅ 合约地址 DB CRUD (resync 一键同步)
- ✅ 6 条治理只读端点 (eth_call → Oracle/暂停/回购/交易状态)
- ✅ 6 条路由补 auth:web 中间件
- ✅ 6 条治理写操作 (eth_sendRawTransaction + 纯 PHP ECDSA 离线签名)
- ⚠️ QuoteService 仍 mock/UNAVAILABLE
- ⚠️ Staking fundRewards/setRewardRate 仍 501

### 部署基线文档

- `docs/current/go-backend-v2/contracts/BSC_TESTNET_DEPLOYMENT_BASELINE.md` — 11 合约地址 + 部署区块 + 交易哈希 + 参数证据（已确认）
- `docs/current/DEPLOYMENT_MANIFEST.md` — 旧地址组模板，全 UNVERIFIED（过期，不可作为运行时地址来源）

---

## 待确认

| # | 事项 |
|---|------|
| 1 | 合约修复 S0-S9 执行启动时间和分支策略 |
| 2 | Go V2 后端重建 F00-F08 冻结 Gate 签署 |
| 3 | Phase 0-9 分批执行启动 |
| 4 | 链上 runtime bytecode readback（BSC Testnet RPC） |
| 5 | 链上角色/暂停/开盘参数固定块 readback |
| 6 | 产品负责人批准业务继承矩阵 |
| 7 | 前端与后端负责人批准 API 冻结 |
| 8 | 经济模型 UNKNOWN 税率确认（部署实际：fail-closed 10%） |

---

## 信息来源
- contracts-v2/src/*.sol, contracts-v2/script/*.s.sol
- contracts-v2/broadcast/*/97/run-latest.json（Deploy/Bootstrap/Finalize/OpenTrading）
- apps/dapp/src/features/wallet/deployed.ts（与部署广播一致的地址）
- docs/current/go-backend-v2/（Go V2 基线 + 合约修复包）
- docs/current/BSC_TESTNET_DEPLOYMENT_BASELINE.md
- backend/app/Modules/Pangu2/Admin/Controllers/GovernanceController.php
- backend/app/Modules/Core/Chain/Services/ChainOperatorService.php
- packages/ui/tokens.css, .project-ai/tasks/
