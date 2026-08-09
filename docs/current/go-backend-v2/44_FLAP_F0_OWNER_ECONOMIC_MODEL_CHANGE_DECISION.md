# BingGoPlus Flap F0 Owner 经济模型变更决策

状态：`OWNER_AUTHORIZED_SCOPE_CHANGE / F0_REOPENED / V6_INDEPENDENT_REVIEW_PENDING`

```text
DECISION_ID = BGP-FLAP-ECON-2026-002
DECISION_DATE = 2026-08-09
OWNER = pd123
AUTHORITY = PROJECT_TOTAL_OWNER
CHANGE_SCOPE = FLAP_F0_PRODUCT_AND_ECONOMIC_MODEL
V5_CONTENT_APPROVAL = HISTORICAL / SUPERSEDED_FOR_FREEZE
F0_DOCUMENT_FREEZE = REOPENED
F1_ENTRY_AUTHORIZED = NO
FLAP_IMPLEMENTATION_ALLOWED = NO
BSC_MAINNET = NO-GO
```

## 1. Owner 输入与解释边界

责任人明确要求：

```text
“那我要按照上面的经济模型执行”
“尽量保留之前的开盘的15%那个部分”
“之前能保留的机制尽量保留”
```

“上面的经济模型”指：Flap 负责发币、Bonding Curve 交易和 DEX Migration；BGPlus 负责交易税收入的分桶、持币分红、Top 100 额外奖励、回购/销毁、Staking 奖励、团队/投资人/项目锁仓、市场和运营资金。

仓库中旧开盘保护的机器事实是：

```text
LAUNCH_PROTECTION_DURATION = 15 minutes
LAUNCH_BUY_TAX_BPS = 3000
LAUNCH_SELL_TAX_BPS = 3000
```

因此 Owner 输入中的“15%”不被静默解释成 1500 BPS。本决策保留的是旧机制真实意图：候选默认 `15 minutes / 3000 bps`。如果 Owner 后续确实要 15% 税，必须作为显式参数修订重新审核。

## 2. V6 默认经济模型

### 2.1 Token Tax

```text
recommended_tax_rate_bps = 500
lifecycle = DRAFT_EDITABLE -> LAUNCH_IMMUTABLE
supported_range = PENDING_F1
```

500 BPS 是后台建议默认值，不是对 Flap 当前链上能力的声明。F1 必须确认 Curve fee、Token Tax 和 DEX Migration 后费用的真实关系。

### 2.2 Revenue 五桶

```text
dividend_bps = 3000
buyback_bps = 2500
staking_bps = 2000
marketing_bps = 1500
operations_bps = 1000
sum = 10000
```

五项可在 Launch Draft 阶段由后台调整，但必须合计 10000。Launch 确认后 BPS、绑定 Token、合约目的地和固定收款地址全部不可改。V1 不保留 Treasury/Reserve 第六、第七桶；如未来新增，必须重新进入经济模型 Change Gate。

### 2.3 Dividend 与 Top 100

Dividend 桶内部再分为：

```text
base_holder_share_bps = 8000
top100_bonus_share_bps = 2000
sum = 10000
```

这两个值也是 Launch 前可调、确认后冻结的候选默认值。

- 所有满足最低余额且未被排除的地址按有效持币量领取基础分红；
- 有效持币量为钱包余额加有效 Staking principal；
- Top 100 按有效持币量降序，持币量相同时按规范化地址升序；
- Top 100 额外池按榜内有效持币量同比例分配；
- Top 100 地址同时获得基础分红和额外奖励；
- 不恢复旧 35/25/25/15 四档；
- Snapshot block/hash、Projector version、输入 Hash、Merkle Root、总额、Claim 和 carry 必须确定性绑定。

### 2.4 Buyback/Burn

```text
buyback_burn_bps = 10000
buyback_lock_bps = 0
sum = 10000
```

默认回购所得 100% 销毁。若 Launch 前把部分比例配置到 Locker，确认后不得改。回购只在 Token 已 `MIGRATED/ACTIVE` 后执行；Curve 阶段只积累资金。继续保留旧机制中 `0.01 BNB`、`60 seconds`、`365 days` 作为后台建议默认值，但它们不再是所有 Token 的全局常量。

### 2.5 Staking

```text
STAKING_REWARD_FUNDING_MODEL = TAX_BNB_SWAP_TO_BOUND_TOKEN + OPTIONAL_EXTERNAL_PREFUND
REWARD_ASSET = BOUND_FLAP_TOKEN
PRINCIPAL_USED_FOR_REWARD = NEVER
```

只有 Staking Bucket 可用于迁移后的受控 BNB→绑定 Token 兑换。兑换必须有固定 Router/Pool、`minOut`、`deadline`、滑点、价格影响、额度、间隔、暂停和唯一 execution identity。其他 Bucket 与质押本金不得支付奖励。外部预充值仍可作为补充来源，实际 Token 到账前不得增加 Reward Reserve。

### 2.6 Team/Investor/Project Vesting

新增独立 `BGPlusTokenVestingV1` 候选：

- 只锁定已实际转入的绑定 Flap Token；
- 不铸币、不拥有 Token 管理权；
- 不复用 BuybackLocker 或 Staking Reserve；
- beneficiary、amount、start、cliff、duration、interval 在 Schedule funding 后不可改；
- V1 默认不可撤销；
- Flap creator allocation/initial buy/transfer 语义未由 F1 证明时，必须标 `UNSUPPORTED`。

### 2.7 Launch Protection

尽量保留旧开盘保护，但只保留业务目的和安全边界，不复用 PANGU2 专用 Router、Whitelist 或 settlement hook：

```text
recommended_launch_protection_duration = 15 minutes
recommended_launch_protection_tax_bps = 3000
lifecycle = DRAFT_EDITABLE -> LAUNCH_IMMUTABLE
capability = PENDING_F1_AND_SOLIDITY_GATE
```

优先使用 Flap 当前版本原生、可验证的能力；如不具备，才允许设计与 Flap Tax Token/Vault 兼容的新扩展。任何无法证明在 Curve 与 DEX 两阶段都不会重复征税、漏税或阻断迁移的方案必须 Fail Closed 为 `UNSUPPORTED`。

如最终启用：保护窗口内 30% 替代普通 5%，二者不得叠加；收到的税收仍按当前五桶比例分配，不恢复旧 PANGU2 的 29% Support + 1% immediate burn 路径。这样保留防抢跑目的，同时保持新经济模型只有一套资金会计。

## 3. 旧机制继承总原则

```text
PRESERVE_BUSINESS_INTENT_AND_SECURITY_INVARIANTS = YES
REUSE_INCOMPATIBLE_PANGU2_INTERFACES = NO
```

尽量保留：开盘保护目的、税收用途隔离、回购额度/间隔/去向限制、真实销毁、Merkle Epoch、Top100 奖励目的、Staking 锁期/罚金/本金隔离、团队锁仓、暂停、最小权限、幂等、deadline、minOut、滑点、价格影响、Reorg 和 Evidence First。

永久退役：CostBasis、KNOWN/UNKNOWN、盈利动态税、PANGU2 TradeRouter/settle hooks、Fee Whitelist、Top100 35/25/25/15 四档和任何要求重部署现有 PANGU2 的路径。

## 4. Gate 影响

V5 外部审核发生在本决策之前，只能作为历史审计证据。由于本决策改变了资金桶、分红名单、Staking 资金源、回购去向、Vesting 和开盘保护，V5 不能继续授权 Owner Freeze。

```text
V5_APPROVAL_REUSED_FOR_V6 = NO
V6_INDEPENDENT_REVIEW_REQUIRED = YES
V6_EXECUTOR_ADJUDICATION_REQUIRED = YES
V6_RESPONSIBLE_OWNER_FREEZE_REQUIRED = YES
F1_ENTRY_AUTHORIZED = NO
```

本决策不授权 Go/SQL/OpenAPI/前端/Solidity 实现，不授权测试网签名、广播或部署，也不改变 Mainnet NO-GO。
