# BingGoPlus × Flap 集成变更控制与执行计划

状态：`HISTORICAL / SUPERSEDED_BY_27_FLAP_PRODUCT_PIVOT_DECISION`

> 本文件记录 Flap 仍是旁路设计支线时的历史方案。项目负责人已于 2026-08-09 决定把 Flap 改为产品唯一发币主线；当前权威从 [27_FLAP_PRODUCT_PIVOT_DECISION.md](./27_FLAP_PRODUCT_PIVOT_DECISION.md) 开始。以下正文保留，不得用于授权继续旧 G2-G9 或 `BGPLUS_FULL_SUITE`。

```text
LATEST_INDEPENDENT_REVIEW_VERDICT = CHANGES_REQUIRED
CORE_DECISION = CONFIRMED
ADJUDICATION = ACCEPTED_WITH_CORRECTIONS
OWNER_SCOPE_AUTHORIZATION = FLAP_D0_DESIGN_PREPARATION_ONLY
INDEPENDENT_RETEST = PENDING
FLAP_IMPLEMENTATION_START = NO
CURRENT_MAINLINE_STAGE = G2_EXECUTION_HOLD
AUTO_ADVANCE_TO_G3 = PAUSED
BSC_MAINNET = NO-GO
```

本文件把 Flap 集成加入 BingGoPlus 后续执行计划，但不修改当前已冻结的 PANGU2 V2 经济模型、已部署合约、G2 交付范围或 Mainnet Gate。

最新独立复审使用标准 Verdict `CHANGES_REQUIRED`。本文件接受其有证据结论并完成修正，当前只能进入独立复验，不能自行宣称 Flap Design Freeze 已通过。

## 1. 已确认的产品边界

必须把以下产品模式分开：

| 模式 | 定义 | 当前状态 |
|---|---|---|
| `FLAP_NATIVE` | 通过 Flap `Portal/VaultPortal` 创建并跟踪 Flap Token、Bonding Curve 和 DEX Migration | `PLANNED / DESIGN_ONLY` |
| `FLAP_WITH_BGPLUS_VAULT` | Flap Tax Token 将税收交给独立 BGPlus Vault 分配 | `PLANNED / SEPARATE_SOLIDITY_REVIEW_REQUIRED` |
| `BGPLUS_FULL_SUITE` | 为新项目部署一整套 Pangu2-compatible Token 与配套协议合约 | `PLANNED / SEPARATE_DEPLOYMENT_PROGRAM_REQUIRED` |
| `FLAP_TOKEN_AS_PANGU2TOKEN` | 把普通 Flap Token 直接传给现有 Pangu2TradeRouter/CostBasis/FeeVault/Staking 等 | `REJECTED_INCOMPATIBLE_INTERFACE` |

Flap Token 不实现 `settleBuy`、`settleSellExact`、`systemTransfer`、`stakingDeposit` 等 PANGU2 专用接口，因此不得把 `FLAP_NATIVE` 描述为“创建 Token 后自动补齐现有十个合约”。

## 2. 品牌模式冻结要求

`FLAP-D0` 必须形成 `BRAND_MODE_DECISION`：

- `FLAP_NATIVE` 页面必须明确标注由 Flap Portal/VaultPortal 创建，遵循 Flap Curve/Migration 生命周期；
- `FLAP_WITH_BGPLUS_VAULT` 只能宣称使用 BingGoPlus 扩展分配能力，不能宣称继承完整 PANGU2 成本税模型；
- `BGPLUS_FULL_SUITE` 才能使用“BingGoPlus 完整协议”表述；
- 不得把三种模式共用一个模糊的“一键发币”链上状态或部署清单。

## 3. 当前主线 G2 的唯一范围

G2 只完成现有 PANGU2 测试网部署的可信链数据入口：

```text
deployment baseline import
-> chain_id=97 runtime validation
-> block/log scan from each deployment block
-> confirmation/finality
-> reorg detection and canonical correction
-> chain_blocks / chain_raw_events / chain_cursors
```

G2 必须实现完成链身份验证、Head 发现、区块/日志读取、必要部署证据读取、确认跟踪和 Reorg 检测所需的真实只读链访问能力，不得把 Chain Acquisition 整体推迟到 G3。审核文档不冻结底层库抽象或具体 JSON-RPC 方法清单。

硬门禁保持：观察到的 Chain ID 必须为 `97`；否则 Indexer 不得写任何链数据，Readiness 必须为 false。

G2 Entry 授权不自动批准条件许可证依赖。实现 RPC 前必须二选一并形成可验证 Decision：

1. 完成 `go-ethereum` 实际使用包、链接/分发方式、NOTICE 与 LGPL/GPL 边界的正式批准；
2. 选择另一个通过开源准入的 RPC/ABI 方案。

在 Decision 缺失时可以继续不依赖该库的 G2 设计和数据库工作，但不得导入或分发未批准的条件许可证代码，也不得把 G2 标记为完成。

下列内容不得进入 G2 实现 Commit：

- Public API 业务 Handler；
- Wallet/Admin Auth；
- Quote 计算或成功响应；
- Projector 领域投影；
- Governance Signer/Reconciler 广播；
- Flap SQL、API、Admin 页面或合约调用。

真实 Router preview 尚未接通时，Quote 不得返回 `LIVE`、`READY` 或任何自行计算的成功数据。

## 4. STEP-00 与 FLAP-D0 并行规则

必须先按 [26_G2_EXECUTION_BASELINE_NORMALIZATION.md](./26_G2_EXECUTION_BASELINE_NORMALIZATION.md) 完成 STEP-00 执行基线归一。只有 STEP-00 完成后，才允许在 G2 后续工作期间准备 `FLAP-D0_DRAFT_ONLY`。这里的“并行”只表示独立设计任务，不表示同一 Agent、同一 Commit 或同一提审包跨阶段执行。

必须满足：

```text
SEPARATE_TASK = YES
SEPARATE_AGENT_OR_SESSION = YES
SEPARATE_COMMIT = YES
SEPARATE_REVIEW_PACKAGE = YES
GO_CODE_CHANGE = NO
SQL_MIGRATION_CHANGE = NO
OPENAPI_MACHINE_SPEC_CHANGE = NO
ADMIN_UI_CHANGE = NO
SIGNER_OR_CHAIN_WRITE = NO
SOLIDITY_CHANGE = NO
```

`FLAP-D0_DRAFT_ONLY` 可以读取当前 G2 设计和 Flap 官方资料，但不能修改当前 Freeze 或阻塞 G2 的既定 PANGU2 Indexer 实现。若仓库流程不支持独立任务/Commit 隔离，则顺序退化为：G2 审核通过后再执行 `FLAP-D0`。

## 5. FLAP-D0 必须冻结的内容

### 5.1 官方合约基线

- BSC Testnet `Portal`、`VaultPortal`、相关 Helper/Trigger 地址；
- 精确 ABI、ABI SHA-256、runtime bytecode hash；
- Token Version、Tax Token Version、Curve、Quote、Migrator、DEX Preference；
- 当前创建方法的准确 selector 和参数；
- `TokenCreated` 及同交易补充事件；
- 官方资料取证时间与来源。

不得使用旧文档中的 `Factory.createToken()` 或旧 `newToken()` 推断当前调用。

### 5.2 多项目数据模型

以下仅为候选对象语义，不冻结表名，也不立即创建 Migration：

```text
launch_projects
launch_project_members
token_launches
token_launch_attempts
external_tokens
token_creators
flap_instances
flap_vaults
curve_states
migration_states
deployment_workflows
deployment_steps
```

最终表名、唯一键、外键、租户边界和 writer 必须在 `FLAP-D0` 设计中完成独立审核后才能进入新 Freeze Version。

必须冻结 Tenant/Project、Creator、Fee Owner、Operator、Signer 和审计归属。不得把多 Token 生命周期硬塞进当前“每环境一个 ACTIVE deployment_set”的单协议实例模型。

### 5.3 API 与状态机

Flap Launch 必须是工作流，不是同步 `POST /flap/create-token` 成功接口。至少覆盖：

```text
DRAFT -> PENDING_APPROVAL -> APPROVED -> QUEUED
-> SIGNING -> SUBMITTED -> CONFIRMED
-> CURVE_ACTIVE -> MIGRATION_PENDING -> MIGRATED -> COMPLETED
```

同时冻结取消、超时、失败、重试、Receipt、Reorg 和幂等规则。HTTP 只能创建/审批 Launch Command，不能在请求内同步声称链上创建成功。

### 5.4 权限与资金

- 用户钱包签名和平台代签必须二选一或形成明确模式；
- 冻结谁支付 BNB、谁是链上 creator、谁接收初始 Token；
- 平台代签必须定义额度、nonce、补偿、失败和审计；
- 禁止任意 target、selector、calldata；
- 自定义 Vault 必须冻结 Flap Guardian 的最小权限；
- Guardian 不得修改分配比例、收款地址、管理员或任意提走资金。

## 6. 主线与 Flap 支线的执行顺序

```text
主线 G2（PANGU2 Indexer）
    + 独立支线 FLAP-D0（仅设计准备，可并行）
    |
    +-> G2 Commit -> Ai-Code-Review -> 执行方二次裁决
    |
    +-> FLAP-D0 Commit -> Ai-Code-Review -> 执行方二次裁决
        -> Responsible Owner 对新 DB/API/Event/State/RBAC/Signer 范围签署
        -> 才允许把批准内容加入后续实现阶段

G3：PANGU2 Projector 与读模型
    + 仅实现 FLAP-D0 已冻结并获签署的 Flap 只读投影

G4：Public API 影子运行
    + Flap 仅允许只读状态，不允许 Launch 写操作

G5：DApp 分域切换
    + 不默认加入 Flap 发币写入口

G6：Admin Auth 与只读切换
    + 可实现已冻结的 Launch 草稿/审批 UI，但不得签名广播

G7：先完成既有 Governance 写路径切换
    -> 独立子阶段 FLAP-G7
    -> Portal/VaultPortal allowlist + Launch Command + Signer + Receipt

G8：Dividend Builder 与既有业务 Job，不承载完整协议部署器

G9：停用旧后端

H0-H5：独立实现 BGPLUS_FULL_SUITE Deployment Orchestrator
    -> OpenTrading 始终单独人工 Gate
```

如果 `FLAP-D0` 尚未通过独立审核和责任人签署，G3-G7 只能继续原 BingGoPlus 主线，不得实现任何 Flap 代码。

## 7. Deployment Orchestrator 边界

完整协议部署不得由 Reconciler 启动 Foundry 脚本完成。未来 `H0-H5` 必须提供独立 Deployment Orchestrator，逐步管理：

- 构造参数与部署前置检查；
- 每笔交易的 nonce、hash、receipt、finality；
- 中断恢复和幂等；
- bytecode/角色/地址验证；
- Deployment Manifest；
- `READY_TO_OPEN` 状态；
- 独立人工 `OpenTrading` 授权。

### 7.1 BGPlus Launch Token Template Gate

`BGPLUS_FULL_SUITE` 在进入 H0 前必须完成：

```text
BGPLUS_LAUNCH_TOKEN_TEMPLATE_DECISION
```

必须从以下方案中选择并冻结：

1. 新建参数化 Pangu2-compatible Token；
2. 新建 Factory/Clone-compatible Token；
3. Full Suite 继续固定 PANGU2 名称、符号和供应量，不支持任意币名；
4. 取消 Full Suite arbitrary-token launch，只保留 Flap Native。

方案 1/2 属于新 Solidity 产品，不是 Go Orchestrator 的附带改动，必须单独完成 Solidity Design Gate、接口兼容矩阵、安全审核和测试网部署授权。该 Decision 未完成时：

```text
BGPLUS_FULL_SUITE_IMPLEMENTATION = FORBIDDEN
```

## 8. 部署约束的准确表述

```text
EXISTING_PANGU2_V2_DEPLOYMENT_SET = IMMUTABLE
EXISTING_PANGU2_V2_REDEPLOY = FORBIDDEN
NEW_FLAP_OR_VAULT_TESTNET_DEPLOYMENT = NOT_AUTHORIZED
NEW_BGPLUS_SUITE_TESTNET_DEPLOYMENT = NOT_AUTHORIZED
BSC_MAINNET = NO-GO
```

`NOT_AUTHORIZED` 表示当前不得执行，但未来可在设计冻结、代码审核、测试网部署 Gate 和人工批准全部通过后另行授权；不得把它错误写成对所有未来测试网新项目的永久禁止。

## 9. 外部审核与自动推进

每个阶段/子阶段必须独立 Commit、独立提审：

```text
完成阶段
-> 生成 Manifest/Hash/完整 Diff
-> 自动提交 Ai-Code-Review
-> 等待标准 Verdict
-> 执行 Agent 独立复核外部结论
-> 只执行有证据且正确的 Finding
-> 错误 Finding 不执行，并写入下一次提审的 Adjudication
-> APPROVED + 裁决接受 + 证据完整 + 无范围外事项
-> 才能自动进入已冻结的下一阶段
```

任何 Flap 新业务、SQL、OpenAPI、Event/State、权限、Signer、Solidity 或部署边界变化都属于范围变更；未完成 `FLAP-D0` 和责任人签署时必须暂停，不能利用自动推进规则绕过。

## 10. 当前冻结状态

```text
BGPLUS_FLAP_INTEGRATION = SUPERSEDED_HISTORICAL_DESIGN
FLAP_NATIVE_MODE = PLANNED
FLAP_WITH_BGPLUS_VAULT = PLANNED_SEPARATE_REVIEW
FLAP_TOKEN_AS_PANGU2TOKEN = REJECTED_INCOMPATIBLE_INTERFACE
BGPLUS_FULL_SUITE = PLANNED_SEPARATE_PROGRAM
BGPLUS_LAUNCH_TOKEN_TEMPLATE_DECISION = REQUIRED_BEFORE_H0
AUTO_OPEN_TRADING = FORBIDDEN
PANGU2_V2_CONTRACTS = IMMUTABLE
EXISTING_PANGU2_V2_REDEPLOY = FORBIDDEN
NEW_TESTNET_DEPLOYMENT = NOT_AUTHORIZED
BSC_MAINNET = NO-GO
FLAP_IMPLEMENTATION = NOT_STARTED_AT_THIS_HISTORICAL_REVISION
```
