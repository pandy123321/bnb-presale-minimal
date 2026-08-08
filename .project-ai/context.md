# BingGoPlus — Project Context

## 确认信息（基于代码）

### 项目目标
链上代币发行与分红治理平台（品牌 BingGoPlus / BGP）。用户用 BNB 买卖 PANGU2 代币，按持有成本判定税率，通过 PancakeSwap V2 提供流动性。核心机制：买入税 4%、卖出税 4%/10%、Launch Protection 30% 税、WhiteList 0% 税、0.01 BNB 回购、365 天锁仓、前 100 名分红、Staking 锁仓收益。

### 当前阶段
合约已部署到 BSC Testnet（部署提交 `3ef50b6`，含 Deploy/Bootstrap/Finalize/OpenTrading 四个阶段的 73 个广播回执）。DApp V7.1 重构完成。Admin 治理 API（GE-A01~A04）完成。

**Go V2 后端重建设计冻结**已完成 10 轮独立云端复验：
- Round9 Verdict：`APPROVED_FOR_RESPONSIBLE_OWNER_FREEZE`（P1-R8-01/P1-R8-02/P1-R4-02/P1-R6-01/P2-R6-01/P2-R6-02 = CLOSED）
- Round10 Verdict：`APPROVED_FOR_RESPONSIBLE_OWNER_FREEZE`（P2-R9-01 = CLOSED）
- **Responsible Owner Freeze**：`pd123` 已签署 GATE-01~05（2026-08-08），`RESPONSIBLE_OWNER_FREEZE_SIGNOFF = COMPLETE`
- **Runtime Gate**：已执行（2026-08-08），结论 `BLOCKED` — 三个 Gate 中 RT-GATE-03 为 `DECISION_READY`，RT-GATE-01/02 因环境缺失被阻断
- `FROZEN_FOR_DEVELOPMENT = NO`，`DEVELOPMENT_START = NO`
- `G0_STATUS = BLOCKED`（RT-GATE-01/02 阻断），`G1_ENTRY_ALLOWED = NO`，`G2_ENTRY_ALLOWED = NO`
- Responsible Owner Freeze 或 Design Freeze 单独完成不能授权 G1；只有 `FROZEN_FOR_DEVELOPMENT = YES` 后才允许进入 G1
- **AI 外部审核**：Record #425（Commit `822edc9`）发现 2 P1 + 3 P2 → 修复提交 `8f2295c` → Record #426 审核通过（**建议合并**）。P1-01/P1-02/P2-01/P2-02 全部关闭。仅 P2-03（机器规范独立核验）留待 `FROZEN_FOR_DEVELOPMENT = YES` 前处理。

**合约安全修复包（S0-S9）**方案已冻结，尚未启动执行。

### 支持网络
- BSC Testnet (Chain 97) — 当前部署网络
- BSC Mainnet (Chain 56) — NO-GO（永久禁止，所有脚本强制 revert）

### 全局硬约束
- BSC_MAINNET_DEPLOYMENT: NO-GO
- BSC_MAINNET_FORK_TESTING: ALLOWED
- Automatic Merge / Push / Deployment: FORBIDDEN
- OpenTrading 不得被 CI/部署脚本自动调用
- 合约修复 S0-S9：实现 Agent 不可自行签发批准
- Go V2 依赖：当前 `NO_DOWNLOAD_AUTHORIZED`，所有开源依赖需人工 Decision Record 后批准
- `backend-go/` 不存在，G0→G1 阶段推进前不得写入业务代码

### 合约部署状态（BSC Testnet, 2026-08-06）

| 阶段 | 状态 | 部署提交 | 广播文件 |
|------|:--:|------|------|
| Deploy | ✅ 已广播 | `3ef50b6` | `DeployPangu2.s.sol/97/run-latest.json` |
| Bootstrap | ✅ 已广播 | `3ef50b6` | `BootstrapPangu2.s.sol/97/run-latest.json` |
| Finalize | ✅ 已广播 | `3ef50b6` | `FinalizePangu2.s.sol/97/run-latest.json` |
| OpenTrading | ✅ 已广播 | `3ef50b6` | `OpenTradingPangu2.s.sol/97/run-latest.json` |
| 链上 readback | ⏳ 待执行 (RT-GATE-02) | — | 需 BSC Testnet RPC |

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

### Go Backend V2 重建计划（设计冻结完成，Runtime Gate 执行中）

文档位置：`docs/current/go-backend-v2/`

Laravel 后端 + TypeScript Chain Worker 将被旁路替换为 Go 模块化单体。新目录 `backend-go/`，独立数据库 `binggoplus_go`，API 大版本 `/api/v2/...`。从部署区块重建全部链上历史，不迁移旧 Mock/Projection/Session。产品品牌统一为 **BingGoPlus**（`Pangu2*` 仅保留为链上合约/ABI/事件名）。

**Runtime Gate 执行结果（2026-08-08）：**

```text
RUNTIME_GATE_EXECUTION_RESULT = BLOCKED
RT-GATE-01 (PostgreSQL Migration + Role) = BLOCKED_POSTGRESQL_NOT_AVAILABLE
RT-GATE-02 (BSC Testnet Readback) = BLOCKED_APPROVED_RPC_REQUIRED
RT-GATE-03 (Go Build Stage) = DECISION_READY
```

**Go Build 阶段 Decision（RT-GATE-03）：**

```text
G0 = Pre-development Freeze（RT-GATE-01 + RT-GATE-02 + 依赖下载批准）
G1 = Go Skeleton / Bootstrap（仅 cmd/internal skeleton，禁止业务实现）
G2 = 业务实现
```

当前 `backend-go/` 不存在，G1 未授权。

**Runtime Gate 证据目录：** `docs/current/go-backend-v2/runtime-gate/`（6 份文件）

**文档冻结关键 Decision：**

- Raw Event 无物理 `PROJECTED`；投影完成度由 versioned `projection_receipts` 推导；`bgp_projector` 对 Raw Event 只读。
- Dividend Artifact 禁止读 `token_balances_current` / `staking_positions`；必须经四个 `security_barrier` 历史视图按固定 block/hash 重建。
- 团队/推荐/佣金 = `OUT_OF_SCOPE / ROADMAP_NOT_APPROVED`，当前 V2 不实现、不 Mock、不从转账图猜测。
- PostgreSQL 共 8 个 LOGIN Roles：7 个运行时角色（bgp_api/indexer/projector/dividend/reconciler/auditor/readonly）+ 1 个 migration-only 角色（bgp_migrator），`current_user` exact role model，NO INHERIT。bgp_migrator 不由任何运行时角色继承或持有。
- 文档审核权威规则：`docs/current/DOCUMENT_REVIEW_RULES_V1.0.md`。

### DApp 前端 V7.1（✅ 5 阶段 + 安全修复完成）

- 路由：3 条（`/` `/trade` `/portfolio`），6 旧页面已删除
- 组件：`packages/ui/`（Card/Button/Tag/SectionHead/Sheet/BottomNav/Toast + CSS tokens）
- 数据层：全部 Stores & Composables 已实现（Wallet/Quote/Transaction/Staking/Market/DataStatus）
- 视图层：所有动态数据显示 `—`（等后端 API 接入真实数据）
- 安全：FIX-01~07 全部完成

### Admin 后端治理面板（GE-A01~A04 完成）

- ✅ 合约地址 DB CRUD (resync 一键同步)
- ✅ 6 条治理只读端点 (eth_call → Oracle/暂停/回购/交易状态)
- ✅ 6 条路由补 auth:web 中间件
- ✅ 6 条治理写操作 (eth_sendRawTransaction + 纯 PHP ECDSA 离线签名)
- ⚠️ QuoteService 仍 mock/UNAVAILABLE
- ⚠️ Staking fundRewards/setRewardRate 仍 501

### 部署基线文档

- `docs/current/go-backend-v2/contracts/BSC_TESTNET_DEPLOYMENT_BASELINE.md` — 11 合约地址 + 部署区块 + 交易哈希 + 参数证据（已确认）
- `docs/current/DEPLOYMENT_MANIFEST.md` — 旧地址组模板，全 UNVERIFIED（过期）

### 当前活动任务

| 任务 | 内容 | 状态 |
|------|------|:--:|
| TASK-20260805-001 | DApp V7.1 Frontend Refactor | ✅ COMPLETED |
| TASK-20260807-001 | Contract Remediation S0-S9 | ⏳ 待用户批准 S0 |
| TASK-20260807-002 | Go Backend V2 Migration | ⏳ RESPONSIBLE_OWNER_FREEZE_COMPLETE_RUNTIME_GATE_BLOCKED |
| TASK-20260807-003 | Go V2 Round5 提审包归一 | ✅ FIX_READY |
| TASK-20260808-001 | Runtime Gate 准备与执行 | ✅ EXECUTED (BLOCKED) |
| TASK-20260808-002 | AI Code Review 闭环（Commit 822edc9 + 8f2295c） | ✅ MERGED — Record #425/#426 外部审核通过 |

---

## 待确认

| # | 事项 |
|---|------|
| 1 | 合约修复 S0-S9 执行启动时间和分支策略 |
| 2 | PostgreSQL 16+ 隔离环境搭建（解除 RT-GATE-01） |
| 3 | BSC Testnet 批准 RPC endpoint（解除 RT-GATE-02） |
| 4 | Go 精确版本 pin + 所有开源依赖 APPROVE_DOWNLOAD（解除 RT-GATE-03 G1） |
| 5 | 链上 runtime bytecode readback（依赖 RPC 批准） |
| 6 | 链上角色/暂停/开盘参数固定块 readback（依赖 RPC 批准） |
| 7 | 产品负责人批准 Dividend 有效持币量（UNRESOLVED-BIZ-01） |
| 8 | 前端与后端负责人批准 API 冻结 |
| 9 | 数据负责人批准 SQL Schema、唯一键和重建策略 |
| 10 | 安全负责人批准 Admin RBAC、审批、Signer 和 Mainnet NO-GO |
| 11 | Pancake V2 Pair ABI 来源与 hash 批准（GATE-04） |
| 12 | confirmation_depth=20 和 reorg_lookback=200 签署（GATE-04） |

---

## 信息来源
- contracts-v2/src/*.sol, contracts-v2/script/*.s.sol
- contracts-v2/broadcast/*/97/run-latest.json（Deploy/Bootstrap/Finalize/OpenTrading）
- apps/dapp/src/features/wallet/deployed.ts（与部署广播一致的地址）
- docs/current/go-backend-v2/（Go V2 基线 + 合约修复包 + Runtime Gate）
- docs/current/go-backend-v2/runtime-gate/（RT-GATE-01/02/03 证据文件）
- docs/current/go-backend-v2/contracts/BSC_TESTNET_DEPLOYMENT_BASELINE.md
- docs/current/go-backend-v2/22_INDEPENDENT_CLOUD_ROUND9_REVIEW.md
- docs/current/go-backend-v2/23_RESPONSIBLE_OWNER_FREEZE_SIGNOFF.md
- backend/app/Modules/Pangu2/Admin/Controllers/GovernanceController.php
- backend/app/Modules/Core/Chain/Services/ChainOperatorService.php
- packages/ui/tokens.css, .project-ai/tasks/
- 开源项目通用引用准入规则V1.0.md
- 通用智能合约安全开发风险控制与漏洞治理规范 V1.0.md
