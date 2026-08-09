# BingGoPlus Flap 继承、重做与退役矩阵

状态：`V4_REVIEW_BLOCKED / V5_REMEDIATION_FIX_READY / INDEPENDENT_RETEST_PENDING`

## 1. 模块矩阵

| 现有能力 | 新产品处置 | 保留的结构 | 不再保留的语义 |
|---|---|---|---|
| Pangu2Token | `LEGACY_READ_ONLY` | 10 亿/18 位精度参考、供应守恒、真实 burn 证据 | PANGU2 专用接口、Launch Tax、Whitelist |
| TradeRouter | `PERMANENTLY_RETIRED` | deadline、minOut、价格影响、钱包签名 | 强制 PANGU2 Router、settleBuy/Sell |
| CostBasisManager | `PERMANENTLY_RETIRED` | Evidence First/fail-closed 思想 | KNOWN/UNKNOWN、盈利判税、成本迁移 |
| FeeVault | `REDESIGN_AS_REVENUE_VAULT` | 独立 Bucket、会计偿付、用途隔离 | Buy/Sell 分开入桶、PANGU2 Token 兑换路径 |
| SupportPool | `REDESIGN_AS_BUYBACK_MODULE` | 资金阈值、间隔、滑点、触发者不得获利 | 固定 Pangu Router/Oracle、Curve 阶段自动回购 |
| BuybackLocker | `REDESIGN_AS_GENERIC_LOCKER` | 批次、到期释放、固定 Recipient | PANGU2 systemTransfer/CostBasis |
| DividendDistributor | `REDESIGN` | Merkle Epoch、快照、一次领取、carry | Top100 与 35/25/25/15 |
| Pangu2Staking | `REDESIGN_LAST` | 预充值奖励、本金隔离、锁期、罚金、偿付 | PANGU2 专用转账/成本接口 |
| PancakeV2Adapter | `REFERENCE_ONLY` | Swap 安全目标 | 固定 PANGU2/WBNB 路由 |
| TWAP Oracle | `REASSESS_FOR_DEX_BUYBACK` | TWAP/低流动性/陈旧 fail-closed | PANGU2 Pair 固定参数 |
| GovernanceAdapter | `RETIRED_FOR_NEW_PRODUCT` | allowlist、最小权限、审批 | PANGU2 selector 集合 |
| Go API/Indexer | `REUSE_FOUNDATION_REBUILD_DOMAIN` | Go、PostgreSQL、Cursor/Reorg、审计 | PANGU2 v2 路由和领域模型 |
| Admin/DApp | `REUSE_FRAMEWORK_REBUILD_PAGES` | Vue、Session/CSRF、钱包、状态组件 | PANGU2 固定页面和文案 |

## 2. 经济结构矩阵

| 经济结构 | 原参数 | Flap 新模型 | 参数策略 |
|---|---|---|---|
| Token 供应 | 10 亿、18 decimals | 使用 Flap 平台实际供应结构 | 链上只读，不伪造 |
| 普通税 | Buy 4%，Sell 4% | Flap 单一 Tax Rate | 每 Token 创建时设置 |
| 盈利税 | Sell 10% | 永久取消 | 不提供参数 |
| Launch 税 | 30%/15 分钟 | 永久取消 | 使用 Flap Curve 生命周期 |
| Whitelist | 0% | 永久取消 | 不提供参数 |
| Dividend 资金 | Buy Tax | Revenue Vault Dividend Bucket | BPS 创建时设置 |
| Support/Buyback | Sell Tax | Revenue Vault Buyback Bucket | BPS 创建时设置 |
| Burn | 盈利税的一部分 | 可选“回购买回后 burn” | 默认 0，可与 lock BPS 分配 |
| 回购金额 | 0.01 BNB | 默认继承 | 后台受限治理可调 |
| 回购间隔 | 60 秒 | 默认继承 | 后台受限治理可调 |
| 回购锁仓 | 365 天 | 默认继承 | 新批次参数，旧批次不可改 |
| 分红名单 | Top100 四档 | 所有有效持有人同比例 | min balance/exclusion 可配 |
| Claim Window | 30 天 | 默认继承 | Epoch 创建时固定 |
| Staking 最低值 | 1 Token | 默认继承 | 只影响新 Position |
| Staking 最大锁期 | 730 天 | 默认继承 | Pool 创建时固定 |
| 提前退出罚金 | 10% | 默认继承 | Position 创建时固定 |

## 3. 控制逻辑矩阵

| 控制 | 新规则 |
|---|---|
| Launch Approval | 替代 PANGU2 OpenTrading；批准后仍需钱包签名 |
| Pause | 按 Launch、Vault、Buyback、Dividend、Staking 分功能暂停 |
| Unpause | 比 Pause 更严格，要求 readiness/preflight/审批 |
| Guardian | 只触发固定规则动作，不改配置、不提款 |
| Signer | 默认不开启；启用时只允许固定 Portal/Factory/selector/额度 |
| Arbitrary Call | 永久禁止 `{target,value,calldata}` 通用接口 |
| Mainnet | NO-GO |
| Existing PANGU2 | 不改、不重部署、保留历史 |

## 4. 数据与页面处置

- `binggoplus_v2` 和 PANGU2 API 在 F11 独立切换 Gate 前保留，F11 通过后只读或下线；
- 新 Flap 数据进入 `binggoplus_flap_v1`；
- PANGU2 Contract Registry、Trade、CostBasis、Top100、旧 Staking 页面逐步标记 Legacy；
- 新增 Launch Center、Tokens、Vaults、Revenue、Buyback、Locker、Dividend、Staking、Audit；
- 不迁移旧 Mock、Session、队列内部状态；
- 不删除测试网历史和审核 Evidence。

## 5. 退役完成条件

旧能力只有在以下条件全部满足后才能从运行导航中移除：

```text
FLAP_REPLACEMENT_READ_PATH = VERIFIED
FLAP_ADMIN_PATH = VERIFIED
LEGACY_DATA_EXPORT = COMPLETE
LEGACY_RUNTIME_WRITES = DISABLED
AUDIT_AND_ROLLBACK_PLAN = APPROVED
INDEPENDENT_REVIEW = APPROVED
```

“从主线退役”不等于删除源码、历史数据或链上证据。

Legacy Cutover 只能在 F11 执行，不得与 F10 通用 Staking 的开发、审核、部署或回滚合并。当前项目原地转向 Flap 是责任人已给出的产品方向；F11 仍必须以替代路径就绪和独立 Cutover Gate 为前提，不能因为 F0 文档冻结就提前关闭旧运行路径。
