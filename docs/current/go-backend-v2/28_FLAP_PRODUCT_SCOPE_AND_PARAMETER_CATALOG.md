# BingGoPlus Flap 产品范围与参数目录

状态：`V4_REVIEW_BLOCKED / V5_REMEDIATION_FIX_READY / INDEPENDENT_RETEST_PENDING / IMPLEMENTATION_NOT_AUTHORIZED`

## 1. 产品能力范围

### 1.1 发币与生命周期

- Admin 创建、编辑、校验、审批和取消 Launch Draft；
- 计划通过 Flap Portal/VaultPortal 发 `STANDARD` 或 `TAX` Token；具体地址、ABI、selector、runtime bytecode 和行为必须由 F1 证明；
- 计划支持官方 Split Vault 与自建 BGPlus Vault；官方能力在 F1 前仅为 `DOCUMENTED_BY_FLAP / PENDING_F1_RUNTIME_BASELINE`，自建 BGPlus Vault 另受 F7 Entry 与独立 Solidity Gate 约束；
- 索引 `TokenCreated` 及同交易的 Version、Curve、Tax、Quote、Migrator、Extension、DEX Preference 等补充事件；
- 跟踪 Bonding Curve、进度、价格、储备、DEX Migration、Pool 和 Vault；
- 链上交易只能在 receipt、event、bytecode、参数绑定和 finality 均通过后进入成功状态；
- Flap 官方 API 只可用于非权威元数据补充，链上合约和事件是状态权威。

### 1.2 BGPlus 扩展

- Tax Revenue 独立资金桶；
- 回购资金积累与 DEX Migration 后的受控回购；
- 回购 Token 锁仓或按批准比例销毁；
- 所有符合条件持有人按快照余额同比例 Merkle 分红；
- 通用 ERC-20 质押与预充值奖励；
- Admin 审批、任务、审计、余额和状态监控。

### 1.3 明确不做

- 成本基础、盈利判定、4%/10% 动态卖出税；
- PANGU2 Router/settlement/systemTransfer 兼容；
- PANGU2 Launch Protection、Fee Whitelist；
- 前 100 名 35/25/25/15；
- 自动部署或重部署整套 PANGU2；
- 任意 target/selector/calldata；
- BSC Mainnet。

## 2. 参数生命周期

| 分类 | 定义 | 后台行为 |
|---|---|---|
| `DRAFT_EDITABLE` | 链上提交前可以修改 | 修改后重新校验并产生新 request hash |
| `LAUNCH_IMMUTABLE` | 发币确认后不得修改 | 只读展示链上值 |
| `GOVERNANCE_ADJUSTABLE` | 合约允许在边界内修改 | 必须新 Command、审批、延时/前置检查和事件 |
| `OPERATION_INPUT` | 每次执行时输入 | 受最大值、deadline、幂等和状态限制 |
| `SYSTEM_ALLOWLISTED` | 由安全基线管理 | 普通 Admin 不可修改 |

“后台可设置”表示后台提供合法输入和生命周期管理，不表示链上确认后仍可任意修改。

## 3. Flap Launch 参数

下列字段为能力候选。F1 必须按精确 ABI 确认 `SUPPORTED / UNSUPPORTED / DEFAULTED`，未确认字段不得出现在生产表单中。

本文件提到的 Portal、VaultPortal、Split Vault、1～10 个收款人和 `vaultDataSchema()` 均标记为：

```text
CAPABILITY_STATUS = DOCUMENTED_BY_FLAP / PENDING_F1_RUNTIME_BASELINE
```

F1 未完成前，它们可以用于产品候选设计，不能被后台声明为测试网可用能力。

| 参数 | 生命周期 | 校验/说明 |
|---|---|---|
| `launch_mode` | `DRAFT_EDITABLE` | `FLAP_STANDARD / FLAP_TAX_SPLIT / FLAP_TAX_BGPLUS` |
| `name` | `LAUNCH_IMMUTABLE` | 非空、长度和字符集按 Flap ABI/前端规范 |
| `symbol` | `LAUNCH_IMMUTABLE` | 非空、大小写原样绑定 |
| `metadata_cid` | `LAUNCH_IMMUTABLE` | 内容 Hash、CID 和上传证据绑定 |
| `creator` | `LAUNCH_IMMUTABLE` | 必须与批准签名主体/Flap 事件一致 |
| `payer` | `OPERATION_INPUT` | 明确谁支付 BNB 和 Gas |
| `token_version` | `LAUNCH_IMMUTABLE` | 只允许 F1 allowlist |
| `tax_rate_bps` | `LAUNCH_IMMUTABLE` | 只允许 Flap 支持范围；UI 同时展示 Curve 与 DEX 阶段有效费用差异 |
| `curve_type/curve_parameters` | `LAUNCH_IMMUTABLE` | 以 Portal 能力和当前默认值为准，不硬编码过期参数 |
| `quote_token` | `LAUNCH_IMMUTABLE` | BGPlus Vault V1 默认只支持原生 BNB `address(0)` |
| `migrator_type` | `LAUNCH_IMMUTABLE` | F1 allowlist |
| `dex_preference` | `LAUNCH_IMMUTABLE` | 仅当前 Chain/Portal 支持值 |
| `lp_fee_profile` | `LAUNCH_IMMUTABLE` | 仅当前 Chain/Portal 支持值 |
| `extension_id` | `LAUNCH_IMMUTABLE` | 默认关闭；启用需独立兼容性审核 |
| `initial_buy_value` | `OPERATION_INPUT` | 可为 0 或受上限限制，以 ABI 为准 |
| `deadline` | `OPERATION_INPUT` | 必须有限期，不允许无期限交易 |
| `max_total_value` | `OPERATION_INPUT` | 防止前端或 ABI 漂移导致超额支付 |
| `vault_factory` | `LAUNCH_IMMUTABLE` | 只允许固定地址和 bytecode hash allowlist |
| `vault_data` | `LAUNCH_IMMUTABLE` | 由 `vaultDataSchema()` 和本地强校验双重生成 |

建议默认 Tax 参数为产品候选，不在 F0 锁死：

```text
RECOMMENDED_FLAP_TAX_BPS = 300
STATUS = NOT_FROZEN
```

原因：若 Flap Curve 基础费为 1%，3% Tax 的 Curve 阶段总费用约为 4%，但迁移 DEX 后 Token Tax 仍可能为 3%。后台必须分别显示两阶段费用，禁止宣传“全生命周期始终 4%”。

## 4. Split Vault 参数

| 参数 | 生命周期 | 约束 |
|---|---|---|
| `recipients[]` | `LAUNCH_IMMUTABLE` | 1～10 个 |
| `recipient.address` | `LAUNCH_IMMUTABLE` | 非零、不可重复 |
| `recipient.bps` | `LAUNCH_IMMUTABLE` | 大于 0 |
| `recipient.label` | 仅数据库展示 | 不进入链上安全判断 |

硬不变量：

```text
SUM(recipient.bps) = 10000
```

## 5. BGPlus Revenue Vault 参数

### 5.1 资金桶

每个资金桶必须同时冻结 BPS、目的地、允许动作、触发角色、配置生命周期和会计流出类型：

| Bucket | BPS 参数 | Destination | Authorized Action | Who Can Trigger | 配置冻结 | Accounting Outflow |
|---|---|---|---|---|---|---|
| Dividend | `dividend_bps` | `dividend_distributor` | 只向绑定 Distributor 为已批准 Epoch 充值 | 已批准 Dividend Job；不得任意提款 | 地址/BPS 在 Launch 确认后不可变 | `funded_to_dividend_bnb` |
| Buyback | `buyback_bps` | 绑定 Token 的 DEX Swap，所得只到 Locker/Burn | 受 minOut/deadline/滑点/价格影响/间隔限制的固定回购 | 最小权限 Operator；Guardian 只作同规则备援触发 | BPS、Token、Locker/Burn 路径不可变；运行上限按治理边界 | `spent_on_buyback_bnb` |
| Treasury | `treasury_bps` | `treasury_recipient` | 仅向固定 Recipient 支付/领取 | Recipient pull 或 permissionless dispatch；触发者不得改收款人 | 地址/BPS 在 Launch 确认后不可变 | `paid_to_treasury_bnb` |
| Operations | `operations_bps` | `operations_recipient` | 仅向固定 Recipient 支付/领取 | Recipient pull 或 permissionless dispatch；触发者不得改收款人 | 地址/BPS 在 Launch 确认后不可变 | `paid_to_operations_bnb` |
| Reserve | `reserve_bps` | Vault 内保留，最终只允许 `reserve_recipient` | `HOLD_UNTIL_APPROVED_RELEASE`；不得挪作其他 Bucket | 经审批并受 Timelock/上限控制的治理 Command | 地址/BPS/释放策略在 Launch 确认后不可变 | `released_reserve_bnb` |

创建参数必须完整包含：

```text
dividend_bps
buyback_bps
treasury_bps
operations_bps
reserve_bps

dividend_distributor
buyback_locker
treasury_recipient
operations_recipient
reserve_recipient
reserve_release_policy
```

当某个 Bucket BPS 为 0 时，其 Destination 可以按 F2 规则使用零地址；BPS 大于 0 时对应 Destination 必须非零、属于正确 Chain 且通过合约/EOA 类型校验。所有非零地址必须进入批准参数快照和 request hash。

累计会计至少区分：

```text
total_received_bnb
total_allocated_bnb
total_current_liability_bnb
total_executed_outflow_bnb
rounding_carry_bnb

funded_to_dividend_bnb
spent_on_buyback_bnb
paid_to_treasury_bnb
paid_to_operations_bnb
released_reserve_bnb
```

必须满足：

```text
SUM(all_bucket_bps) = 10000
total_allocated_bnb + rounding_carry_bnb = total_received_bnb
total_current_liability_bnb + total_executed_outflow_bnb + rounding_carry_bnb = total_received_bnb
total_executed_outflow_bnb =
    funded_to_dividend_bnb
  + spent_on_buyback_bnb
  + paid_to_treasury_bnb
  + paid_to_operations_bnb
  + released_reserve_bnb
actual_vault_bnb_balance >= total_current_liability_bnb + rounding_carry_bnb
```

每个 Bucket 还必须独立满足：

```text
bucket_allocated_bnb = bucket_current_liability_bnb + bucket_executed_outflow_bnb
```

任何外部调用失败必须整笔回滚或保持对应 Bucket liability 不变；禁止先减少 liability 再吞掉转账、Swap 或 Distributor 充值错误。回购已经花掉的 BNB 必须计入 `spent_on_buyback_bnb`，不得继续显示为 Vault 可用余额。

会计事实源和未登记余额必须固定为：

```text
ACCOUNTING_SOURCE_OF_TRUTH = INTERNAL_REVENUE_LEDGER
ACTUAL_CHAIN_BALANCE = SOLVENCY_CHECK_ONLY
UNACCOUNTED_SURPLUS_BNB = NON_DISTRIBUTABLE_UNTIL_RECONCILED
```

不得使用 `address(this).balance`、`actual balance - liability` 或其他链上余额差额反推可分配收入。直接转入、强制转入或因外部退款形成但未进入内部 Revenue Ledger 的 BNB，只能进入 `UNACCOUNTED_SURPLUS_BNB` 对账状态；在形成唯一来源证据、审批记录和一次性 reconciliation identity 之前，不得分桶、支付、回购或释放。

每次资金流出必须使用不可重复的 `outflow_execution_id`，精确绑定 Launch、Vault、Bucket、业务对象、金额、Destination 和原始审批。成功执行后同一 identity 永远不得再次执行；失败重试必须复用原 identity，不得新建一个看似不同但经济含义相同的付款。只有链上成功 Receipt 与预期事件/余额变化完成绑定后，才能从 liability 转入 executed outflow。

建议默认值仅为创建表单候选：

```text
dividend_bps = 4000
buyback_bps = 4000
treasury_bps = 1000
operations_bps = 1000
reserve_bps = 0
STATUS = ADJUSTABLE_BEFORE_LAUNCH
```

创建确认后，全部 Destination、释放策略和 BPS 默认不可修改。若未来要求可修改，必须新建带 Timelock 的合约版本并重新审核，不在 V1 内提供。

### 5.2 回购与锁仓

| 参数 | 建议默认 | 生命周期 | 安全边界 |
|---|---:|---|---|
| `buyback_amount_wei` | `0.01 BNB` | `GOVERNANCE_ADJUSTABLE` | 不超过 Vault 余额和单次上限 |
| `buyback_min_interval` | `60 seconds` | `GOVERNANCE_ADJUSTABLE` | 只在成功回购后更新 |
| `max_slippage_bps` | 待 F2 冻结 | `GOVERNANCE_ADJUSTABLE` | 合约硬上限 |
| `max_price_impact_bps` | 待 F2 冻结 | `GOVERNANCE_ADJUSTABLE` | 超限 fail closed |
| `minimum_execution_balance` | 待 F2 冻结 | `GOVERNANCE_ADJUSTABLE` | 防止碎片操作 |
| `lock_duration` | `365 days` | 新批次创建参数 | 已存在批次不可修改 |
| `buyback_lock_bps` | `10000` | `LAUNCH_IMMUTABLE` | 与 burn BPS 合计 10000 |
| `buyback_burn_bps` | `0` | `LAUNCH_IMMUTABLE` | 只有真实买回 Token 后才能 burn |

第一版只允许 `MIGRATED/ACTIVE` Token 执行回购。Curve 阶段只积累资金，不实现双交易路径。

### 5.3 分红

| 参数 | 建议默认 | 生命周期 |
|---|---:|---|
| `epoch_duration` | 待 F2 冻结 | 后续 Epoch 可调 |
| `claim_window` | `30 days` | Epoch 创建时固定 |
| `minimum_eligible_balance` | 可配置 | Epoch 创建时固定 |
| `excluded_addresses` | 系统地址自动排除 + 审批列表 | Snapshot 固定 |
| `unclaimed_policy` | `CARRY_FORWARD` | Epoch 创建时固定 |

新分红规则：

```text
eligible_amount = wallet_balance + active_staked_principal
allocation = epoch_total * eligible_amount / total_eligible_amount
```

不排名、不设前 100、不设 35/25/25/15。快照、投影版本、取整、Merkle、一次领取、关闭与 carry 继续采用 Evidence First 和确定性规则。

### 5.4 通用质押

| 参数 | 建议默认 | 生命周期 |
|---|---:|---|
| `minimum_stake` | `1 token` | Pool 治理可调，只影响新 Position |
| `max_lock_duration` | `730 days` | Pool 创建时固定 |
| `lock_options` | `30/90/180/365 days` | UI 默认，可允许范围内自定义 |
| `early_exit_penalty_bps` | `1000` | Position 创建时固定 |
| `reward_rate` | 由奖励储备约束 | 治理可调 |
| `reward_budget` | 预充值 | 只能增加或按偿付规则回收剩余 |

Staking 奖励资金模型冻结为：

```text
STAKING_REWARD_FUNDING_MODEL = EXTERNAL_PREFUND_ONLY
REWARD_ASSET = BOUND_FLAP_TOKEN
REVENUE_VAULT_LIABILITY_USED_FOR_STAKING = NO
STAKING_PRINCIPAL_USED_FOR_REWARD = NEVER
PREFUND_ACTOR = APPROVED_PROJECT_OR_ADMIN_FUNDING_PATH
PREFUND_EVIDENCE = CONFIRMED_ON_CHAIN_RECEIPT
REWARD_LIABILITY <= CONFIRMED_REWARD_RESERVE
```

RevenueVault 的 Dividend/Buyback/Treasury/Operations/Reserve BNB 不得被实现方隐式挪给 Staking，也不得自动执行 BNB→Token 兑换。若责任人未来决定用 Tax Revenue 支付 Staking，必须新增独立经济变更、资金 Bucket、兑换路径、滑点/Oracle/失败会计和 Owner Freeze，不能作为 F10 普通参数调整。

不变量：本金不能支付奖励；奖励负债不得超过已确认奖励储备；Prefund 到账前不得增加可领取奖励；剩余奖励回收必须在所有负债结清后按冻结权限执行。Fee-on-Transfer Token 兼容性必须在 F8/F10 单独决定。

## 6. 后台系统参数

- Chain ID 与 Mainnet 拒绝；
- Flap Portal/VaultPortal/VaultFactory 地址、ABI hash、runtime bytecode hash；
- RPC 主备与确认数、Reorg 深度、最大扫描范围；
- 每笔/每日 Launch BNB 限额；
- Signer allowlist、限额和 nonce 策略；
- 支持 Token Version、Curve、Migrator、DEX、Extension 的 allowlist；
- IPFS Provider、CID/内容 Hash 策略；
- 功能暂停开关；
- DataStatus freshness/lag 阈值。

关键系统参数不得由普通 Admin 直接修改，必须审计并按 F2 RBAC 冻结。
