# BingGoPlus Flap 目标架构

状态：`V6_REVIEW_CHANGES_REQUIRED / V7_P1_REMEDIATION_FIX_READY / INDEPENDENT_RETEST_PENDING / IMPLEMENTATION_NOT_AUTHORIZED`

## 1. 总体架构

```text
apps/admin
  -> Go Admin API
  -> Launch Draft / Validation / Approval
  -> Transaction Intent
  -> Admin Wallet（MVP）或隔离 Signer（后续）
  -> Flap Portal / VaultPortal
  -> Flap Token + Split Vault / BGPlus Vault

BSC Testnet RPC
  -> Go Indexer
  -> canonical raw events / blocks / cursors
  -> Go Projector
  -> Token / Curve / Migration / Vault / Revenue / Buyback / Dividend / Top100 / Staking / Vesting Read Models
  -> Public API / Admin API
  -> apps/dapp / apps/admin
```

链上 receipt、runtime bytecode 和事件是运行事实。Flap API、网页和后台提交记录不能单独证明发币成功。

## 2. 现有代码复用

保留 `backend-go/` 单 Go Module、多进程结构：

```text
cmd/api
cmd/indexer
cmd/projector
cmd/reconciler
cmd/dividend-builder
```

复用：配置、Health、PostgreSQL 连接、整数金额类型、请求 ID、限流框架、幂等/审计/命令状态设计、Cursor/Reorg 设计和 Admin Session 方向。

不复用为新权威：PANGU2 Quote、CostBasis、TradeRouter、FeeVault、SupportPool 与 PANGU2 Governance Action 的领域对象和接口。旧 Staking、Top100 和 Launch Protection 只保留业务目的与安全不变量，必须用通用 Flap 兼容模型重新设计，不能复用专用接口。

## 3. 新代码边界

建议新包：

```text
backend-go/internal/flap/baseline
backend-go/internal/flap/launch
backend-go/internal/flap/indexer
backend-go/internal/flap/projector
backend-go/internal/flap/vault
backend-go/internal/flap/revenue
backend-go/internal/flap/buyback
backend-go/internal/flap/dividend
backend-go/internal/flap/staking
backend-go/internal/flap/vesting
```

现有 PANGU2 包在 F11 独立 Cutover Gate 前可保留只读兼容，但不得与 Flap 业务共用模糊类型或表。

阶段责任固定为：

```text
F3 = Chain Acquisition + Indexer + Deterministic Read Model
F4 = Launch Workflow + Admin/Public API; no signing
F5 = Signer + Transaction Execution + Receipt/Event binding
F6 = Admin Launch Console + minimal public read surface + Native MVP
F7 = BGPlus Factory/RevenueVault Solidity, explicit entry authorization required
```

`F6 -> F7` 必须暂停，完成 Extension Entry Review 和 Responsible Owner/Security Scope Authorization；F6 Native MVP 通过不自动授予自建金融 Solidity 开发权限。

## 4. 数据库边界

```text
database = binggoplus_go
new_schema = binggoplus_flap_v1
legacy_schema = binggoplus_v2
legacy_schema_mode = READ_ONLY_AFTER_CUTOVER
```

新 Schema 采用多 Launch、多 Token 模型。不得把 Flap Token 塞入当前“每环境一个 ACTIVE deployment_set”的单协议实例约束。

候选对象：

```text
flap_contract_baselines
launch_projects
launch_project_members
launch_drafts
launch_parameter_snapshots
launch_approvals
launch_attempts
launch_transaction_attempts
flap_tokens
flap_token_configs
flap_vaults
flap_vault_configs
flap_curve_snapshots
flap_migration_snapshots
flap_tax_revenue_events
buyback_executions
locker_batches
dividend_epochs
dividend_allocations
dividend_claims
staking_pools
staking_positions
vesting_schedules
vesting_releases
audit_events
idempotency_records
chain_sources
chain_streams
chain_cursors
chain_blocks
chain_raw_events
projection_receipts
```

表名、列、FK、UNIQUE、CHECK、writer 和角色只能在 F2 机器规范中冻结。

## 5. API 边界

F2 待冻结的新版本候选：

```text
Public = /api/v3/flap
Admin = /admin-api/v3/flap
```

核心 Launch API：

```text
POST   /launches
GET    /launches
GET    /launches/{id}
PATCH  /launches/{id}
POST   /launches/{id}/validate
POST   /launches/{id}/approve
POST   /launches/{id}/prepare-transaction
POST   /launches/{id}/submit
POST   /launches/{id}/cancel
GET    /launches/{id}/events
```

HTTP `submit` 只记录已签名交易或将批准命令入队，不能同步声称 Token 已创建。

`prepare-transaction` 必须返回并绑定：

```text
chain_id
to
value
data
selector
request_hash
expires_at
expected_portal
expected_vault_factory
parameter_snapshot_hash
```

## 6. Launch 状态机

```text
DRAFT
-> VALIDATING
-> VALIDATED
-> PENDING_APPROVAL
-> APPROVED
-> AWAITING_SIGNATURE
-> SUBMITTED
-> CONFIRMING
-> CONFIRMED
-> CURVE_ACTIVE
-> MIGRATION_PENDING
-> MIGRATED
-> ACTIVE
```

失败/取消：

```text
VALIDATION_FAILED
SIGNATURE_REJECTED
TRANSACTION_FAILED
EXPIRED
CANCELLED
REORG_PENDING
REORGED
```

批准后的参数快照不可变。任何编辑必须回到新 Revision 并重新校验、审批和生成 request hash。

## 7. 事件索引

至少处理：

```text
TokenCreated
FlapTokenStaged
TokenCurveSet
TokenCurveSetV2
TokenDexSupplyThreshSet
TokenQuoteSet
TokenMigratorSet
TokenVersionSet
FlapTokenTaxSet
TokenExtensionEnabled
TokenDexPreferenceSet
LaunchedToDEX
```

同一创建交易的可选事件必须先合并再生成 Token 配置。缺失事件按 F1 已冻结的 Flap 默认值处理，不能自行猜测。

BGPlus 合约还需独立事件：Revenue Received/Allocated、Buyback Executed/Burned、Lock Registered/Released、Dividend Epoch Published/Claimed/Closed、Top100 Snapshot Bound、Stake/Unstake/Reward、Vesting Funded/Released。

## 8. 签名与权限

MVP：Admin 钱包直接签名。Go 服务只构造精确交易意图，不保管私钥。这是责任人明确要求的后台一键发币模式，不得在 F0 被改写成普通用户钱包自助模式。F1 必须确认 Admin 钱包在 Flap 中实际承担的 `creator / payer / msg.sender / initial buyer` 身份，并按链上事件如实展示。

后续平台 Signer：

- 只允许固定 Chain、Portal/VaultPortal、VaultFactory 和 selector；
- 只允许由批准参数快照生成 calldata；
- 单笔/每日 BNB 限额；
- nonce 单写者和重试状态机；
- 不接受任意 calldata；
- 广播后必须持续跟踪到 finality 或明确失败；
- 私钥不得进入代码、数据库、普通 `.env`、日志和 Evidence。

## 9. 新合约信任边界

- Factory 默认不可升级；
- BGPlusVaultFactory V1 创建费和 Revenue Commission 固定为 0，不能接收任何 RevenueVault outflow；外部 Flap/Gas 费用独立展示；
- Vault 收款地址和 BPS 创建后默认不可变；
- Dividend/Buyback/Staking/Marketing/Operations 的 BPS、目的地址、Token 路径和释放策略必须进入不可变参数快照；
- Vault 会计必须分别累计当前负债、Dividend 充值、回购花费、Staking 奖励兑换、Marketing/Operations 支付和 rounding carry；
- Vault 内部 Revenue Ledger 是唯一分配事实源；链上实际余额只用于偿付检查，未登记 surplus 在完成唯一对账前不可分配；
- 每笔资金流出必须有不可重复 execution identity；成功后不得二次执行，失败重试必须复用原 identity；
- 任一资金外部调用失败不得减少对应 Bucket liability；
- Guardian 只能触发固定规则动作，不能改配置或提款；
- 回购只能在 `MIGRATED/ACTIVE` 购买绑定 Token，资产只能进入 Burn/Locker；默认 100% Burn；
- Dividend Root 必须绑定快照、输入 Hash、总额和审批；基础分红覆盖所有有效持有人，Top 100 额外奖励按确定性排名与榜内有效持币量同比例计算；
- Staking/Vesting/Locker/Vault 等 custody 地址的链上余额必须从直接持有人快照排除；Staking principal 只按 staker Position 归属一次；Vesting V1 未释放 Token 不参与 Dividend/Top100；
- Staking 使用绑定 Flap Token；奖励来自 Staking BNB Bucket 的受控 DEX 兑换和可选外部预充值，不得使用其他 Bucket 或质押本金；
- EarlyUnstake 的完整 principal liability 一次减少，净额返还用户，罚金与被没收未领取奖励留在同 Pool available Reward Reserve；无外部 penalty recipient；
- Vesting 只能锁定真实预充值的绑定 Flap Token；不得铸币，不得与回购 Locker 或 Staking Reserve 共用资金；
- 通用开盘保护候选默认 `15 minutes / 3000 bps`；仅在 F1/独立 Solidity Gate 证明 Flap 兼容且可执行时启用；
- 外部调用遵循 Checks-Effects-Interactions、ReentrancyGuard 和 Pull 模式；
- 任何 Swap 强制 deadline、minOut、价格影响与暂停检查。

## 10. 运行环境

```text
BSC_TESTNET_CHAIN_ID = 97
BSC_MAINNET_CHAIN_ID = 56
BSC_MAINNET = NO-GO
```

观察 Chain ID 不是 97、Portal bytecode 不匹配、ABI hash 不匹配、RPC 主备冲突或 Flap baseline 过期时：

```text
READY = FALSE
CHAIN_WRITE = FORBIDDEN
LAUNCH_SUBMISSION = FORBIDDEN
DATA_STATUS = UNAVAILABLE
```
