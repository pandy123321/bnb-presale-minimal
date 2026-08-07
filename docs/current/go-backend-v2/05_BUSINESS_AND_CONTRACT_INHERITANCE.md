# 业务、经济与合约控制逻辑继承冻结候选

状态：`FREEZE_CANDIDATE`

本文件不创造新的经济模型。已部署 source commit `3ef50b6` 的运行语义高于旧经济文档。后端只负责读取、投影、构造经过批准的交易和 fail-closed，不得替代合约判税或结算。

## 1. Token 与交易税

### 1.1 供应量

- 名称/符号：PANGU2；
- decimals：18；
- 初始供应：`1_000_000_000 ether`；
- 后端没有 mint 能力；
- burn 必须来自链上 `_burn` 与 `ProtocolBurn/Transfer(to=0)` 事实。

### 1.2 税率优先级

| 阶段 | 地址 | 买入 | 卖出 | 卖出资金拆分 |
|---|---|---:|---:|---|
| Trading 未开启 | 任意 | 执行失败 | 执行失败 | 无 |
| Launch 15 分钟 | Whitelist | 0 | 0 | 全额 swap |
| Launch 15 分钟 | 非 Whitelist | 3000 bps | 3000 bps | 2900 bps Support + 100 bps Burn + 7000 bps swap |
| Normal | Whitelist | 0 | 0 | 全额 swap |
| Normal | 非 Whitelist | 400 bps | 400 或 1000 bps | 400 Support；或 900 Support + 100 Burn |

优先级固定为：`trading open gate -> whitelist -> launch -> normal cost-basis tax`。

Launch 税和 whitelist 已包含在部署提交中。旧 `ECONOMIC_MODEL.md` 中“NOT_IMPLEMENTED”以及“UNKNOWN 走 4%”是过期内容，不得继承。

### 1.3 Normal Sell 判定

合约 `Pangu2TradeRouter._previewSell` 的规则：

- `CostBasis status == KNOWN` 且卖出数量的 TWAP 价值 `<= proportional cost`：400 bps；
- `KNOWN` 且 TWAP 价值 `> proportional cost`：1000 bps；
- `UNKNOWN`、数量超过 tracked balance 或任何无法证明成本的状态：1000 bps（fail-closed）；
- Launch/Whitelist 最终可覆盖上述 base tax。

后端 Quote 只能调用：

- 买入：`previewBuyFor(account, bnbAmount)`；
- 卖出：`previewSell(account, tokenAmount)`。

禁止后端复制上述公式后返回 `LIVE`。

### 1.4 执行与防绕过

- 用户买卖必须走 Pangu2TradeRouter；
- Token 阻止用户/Pair/未注册合约直接交互绕过 settlement；
- 买入税进入 FeeVault `DIVIDEND` bucket；
- 普通/盈利卖出 Support 部分进入 `SUPPORT` bucket，Burn 直接减少 totalSupply；
- 用户 sell 先将 token 转入 Router，Router consume cost、settle tax、只 swap `swapTokens`；
- deadline 最大窗口 5 分钟；amount/minimum 必须非零；
- DApp 继续由钱包直接签名链上 buy/sell，后端只提供 preview/readiness。

## 2. Cost Basis

状态：`NONE / KNOWN / UNKNOWN`。

- `NONE`：实际余额、tracked balance 和 cost 均为 0；
- `KNOWN`：实际余额等于 tracked balance，可按比例 floor 迁移/消费成本；
- `UNKNOWN`：实际余额与账本不一致、未知来源或无法证明完整成本，卖出走最高 Normal 税率；
- 用户间转账：来源 KNOWN 时按 token 比例迁移 cost；任一不可证明路径按 UNKNOWN 处理；
- 买入：增加 WBNB cost 与 net token tracked balance；
- 分红 claim：零成本增加 KNOWN balance，不增加 cost；
- Staking deposit/return：本金成本随系统上下文迁移，不能当普通 transfer；
- Locker release：`SYSTEM_CREDIT_UNKNOWN`，收款人必须标记 UNKNOWN；
- LP 路径保留部署合约当前的 tokenId 模型，不由 Go 修正合约模型；
- 后端数据库中的 cost projection 仅用于解释和监控，税率权威仍是链上 preview。

## 3. FeeVault 与资金路径

- `_dividendBalance` 与 `_supportBalance` 独立记账；
- `actual token balance >= total accounted` 是偿付不变量；
- Buy tax credit `DIVIDEND`；Sell support credit `SUPPORT`；
- Governance 可从 Dividend bucket 向 DividendDistributor 拨款；
- Keeper 可在额度、deadline、TWAP、protocol minOut 和 bucket balance 约束下转换 Support token；
- 转换结果 WBNB unwrap 成 BNB，只能发送到 SupportPool；
- Go 必须分别投影 credit、fund、convert、bucket balance 与 reconciliation anomaly。

已审核但未由部署成功自动关闭的 FeeVault 风险，例如 pause 期间 credit、invalid enum、zero quote，必须保留在 Admin 风险提示与独立合约审核台账中；后端不能伪装成合约已修复。

## 4. SupportPool 与 BuybackLocker

### SupportPool

- `BUYBACK_AMOUNT = 0.01 BNB`，不可配置；
- `MIN_BUYBACK_INTERVAL = 60 seconds`，只在成功回购后更新；
- 任意地址可调用 `buyback()`；Admin 的 trigger 只是便利入口，不代表权限；
- 必须有足够 BNB、Locker 已配置、未暂停、cooldown 已过、Oracle 可用、quote/minOut 非零；
- 回购 token 的 recipient 固定为 Locker，不是触发者；
- 触发者不能获得 token 或 BNB。

### Locker（实测部署参数）

- Mode：`FIXED_DURATION`；
- Duration：31,536,000 秒（365 天）；
- 每次 buyback 对应唯一 batch；
- `registerBuyback` 仅 SupportPool 可调用并检查实际 backing；
- 到期后任意人可触发 release，但资产只能发送固定 `releaseRecipient`；
- release 使用 `SYSTEM_CREDIT_UNKNOWN`，收款人成本状态 fail-closed；
- 后端不得增加“管理员指定 release 收款地址”字段。

## 5. Dividend

### 5.1 链上不变量

- Leaf V1 绑定：`chainId + distributor + epochId + rewardToken + account + amount`；
- claim window 必须恰好 30 days（本次测试网部署）；
- snapshot block 必须非零且不大于发布时 block；
- Governance 先批准完整 commitment；Root Publisher 只能发布完全相同参数；
- 发布时余额必须覆盖所有 reserved claims；
- 同地址同 epoch 只能 claim 一次；
- claim 后通过 Merkle proof、更新 reserved accounting、零成本转账；
- close 只能在 claimEnd 后，未领取金额进入 `nextEpochCarry`；
- 已有任何 claim 的 epoch 不可 cancel；
- 已消费 commitment 不可 revoke。

### 5.2 链下 Top 100 规则

- Tier 1：rank 1-10，35%；
- Tier 2：rank 11-30，25%；
- Tier 3：rank 31-60，25%；
- Tier 4：rank 61-100，15%；
- 档内按有效持币量比例分配；
- snapshot 必须固定 `block_number + block_hash`；
- snapshot block/hash 必须来自 canonical + finalized 区块；Builder 锁定 `token_ledger` 与 `staking` projector 的精确版本，并确认目标块及之前相关事件都有 `APPLIED` receipt；
- Wallet Token 余额和 active staked principal 只能从 canonical 历史账本按 `(block_number, tx_index, log_index)` 重放到目标块；禁止用 current 表回填过去快照；
- 排名 tie-break、整数尾差和 artifact serialization 必须确定性；
- 同输入必须生成同 checksum/root/proof。

### 5.3 尚需产品签署的唯一经济定义

`UNRESOLVED-BIZ-01：有效持币量`。

现有 Solidity 只声明“有效持币量”，没有定义以下边界：

- Staking 中的用户本金是否计入；
- LP 中的用户经济权益是否计入；
- Pair、Router、Vault、Pool、Locker、Distributor、Staking、burn/zero 等系统余额如何排除；
- Fee whitelist、governance、treasury 是否参与排名；
- 不足 100 人时空档份额是否留作 epoch 未领取 carry。

推荐冻结候选：`wallet balance + active staked principal`，排除所有 system/pair/zero/burn 地址，不展开 LP 份额；不足人数产生的空档份额不重分配，在 close 时 carry。该候选只有产品签署后才能成为业务规则，开发 Agent 不得自行决定。

### 5.4 确定性取整候选

- 四个 tier pool 先按 BPS floor；最后一档接收 BPS 计算的整数尾差，使四档总额等于 epoch total；
- 空档 pool 不分配；
- 档内每人先 floor；档内剩余 raw unit 按最大余数法分配，tie 依次按 rank、lowercase address；
- artifact 保存所有输入余额、排除原因、rank、tier、分子、分母、floor、remainder 和最终 amount；
- artifact 同时保存 projector manifest、规范化输入 checksum/row count、snapshot block/hash 和算法版本；
- `sum(allocation) <= epoch totalAmount`，差额由链上 close carry。

该算法不改变 35/25/25/15，只冻结整数边界；仍需产品/数据负责人签署。

## 6. Staking

- 最低 stake：1 PANGU2；
- lockSeconds：大于 0 且不超过 730 days；
- reward 按秒、按用户 stake 占比累计；
- reward rate 上限：`115740740740740` raw/second；
- rate 非零时必须有足够 reward reserve 覆盖最大 liability；
- 正常 unstake 只能在 unlockAt 之后，返还全额本金；
- early unstake penalty：1000 bps（10%），只返 90% 本金；
- 该 position 对应比例 reward 被 forfeited；penalty 回到 reward reserve；
- claim reward 不得动用 totalStaked principal；
- Admin `fundRewards`、`setRewardRate` 必须保留，但只通过 REWARD_MANAGER 对应治理 command 执行；
- 后端不得按 position 伪造链上实际为 account-level 的 reward 结论。

## 7. Oracle / Adapter

- Oracle 状态：`UNINITIALIZED / ACCUMULATING / READY / LIQUIDITY_LOW`；
- `update()` permissionless；
- 实测 window 1800s、最大 spot/TWAP deviation 300 bps；
- 储备低于 constructor minimum 时 fail-closed；
- TWAP 超过 `5 * window` 未完成更新时 fail-closed；
- Pair 为零储备、quote 为零、方向非 token/WBNB 均拒绝；
- Adapter 只允许 CALLER_ROLE 合约 swap；
- swap 强制非零 amount/minOut、合法 pair、未过期 deadline；
- Backend quote 失败不得降级为 Pancake spot quote 或本地公式。

## 8. 控制与权限

| 控制 | 合约角色/主体 | 后端规则 |
|---|---|---|
| Open trading | Token GOVERNANCE | 已执行，不再提供可重复动作 |
| Fee whitelist | Token GOVERNANCE | 显式 add/remove/batch command，batch <= 50 |
| Pair/system/liquidity manager/context | Token GOVERNANCE | 高风险 allowlist + 双审批 |
| Pause | PAUSER / emergency | 显式目标合约，允许应急单审批但强制审计 |
| Unpause | UNPAUSER / governance | 双审批 + readiness preflight |
| Fee conversion | FeeVault KEEPER | 参数上限、preview、deadline、idempotency |
| Dividend funding | FeeVault GOVERNANCE | bucket/solvency preflight |
| Root approve | Distributor GOVERNANCE | artifact checksum 固定 |
| Root publish | ROOT_PUBLISHER | 必须引用已批准 command/artifact |
| Epoch close/cancel/revoke | GOVERNANCE | 合约状态 preflight，不能覆盖 receipt |
| Buyback | permissionless | 可公开触发；Admin 只记录操作来源 |
| Locker release | permissionless after lock | recipient 不可由 API 输入 |
| Oracle update | permissionless | 无私钥也可触发，但仍作为可跟踪 job |
| Staking funding/rate | REWARD_MANAGER | 双审批、coverage preflight |

禁止提供通用 `{target,value,calldata}` 公网/Admin API。每个 selector、target、value 上限和参数 schema 必须来自 deployment set allowlist。

## 9. DataStatus 与 fail-closed

- `LIVE`：active deployment 验证通过、RPC chain 正确、observed block/hash 一致、Indexer/Projection lag 在阈值内；
- `SYNCING`：正在从部署区块追历史；
- `STALE`：数据曾有效但超过 freshness；
- `DEGRADED`：部分非资金关键来源失败；
- `UNAVAILABLE`：quote、合约、链、Oracle、投影或完整性不足；
- V2 生产不返回 `MOCK_DATA`；
- Quote、Governance preflight、Dividend build 任一关键状态非 LIVE 时不得继续。

## 10. 变更规则

任何涉及税率、成本状态、资金比例、Top 100、分档、有效余额、锁仓、质押罚金/奖励、角色或 pause/open gate 的修改，必须：

1. 新业务决策记录；
2. 对照已部署合约判断是否可实现；
3. 升级 Business Contract version；
4. 升级 OpenAPI/DB/Event/State 中受影响部分；
5. 若需要改 Solidity，退出本 Go 替换范围，重新走合约审核和部署决策。

## 11. BingGoPlus 产品文档对照

参考：[docs/current/PRODUCT_PLANNING.md](../PRODUCT_PLANNING.md)。产品品牌现统一为 **BingGoPlus**，但已部署链上合约、ABI/event 名和 Token name/symbol 仍为 `Pangu2* / PANGU2`。在“不重部署”的前提下，DApp 可以展示 BingGoPlus 品牌，但钱包添加 Token、交易确认、合约证据和 API `on_chain_metadata` 必须展示真实链上元数据，不能把链上 symbol 伪造为 `BGP`。

| 产品文档能力 | 本次判定 | V2 处理 |
|---|---|---|
| Normal/Launch/Whitelist 税费 | 与部署逻辑一致 | 完整继承，以 Router preview 为权威 |
| Top 100、35/25/25/15、30 天领取 | 基本一致，有效持币量未定义 | 保留；关闭 `UNRESOLVED-BIZ-01` 后实现 |
| 0.01 BNB/60 秒、365 天 Locker | 已统一为 permissionless trigger + 最小间隔 | UI 展示实际/下次可触发，不保证每 60 秒必发生 |
| 质押 1..730 天、10% 提前退出罚金 | 与部署逻辑一致 | 预设 30/90/180/365 只是 UI 快捷值，不限制合约允许的自定义期限 |
| Staking 奖励速率上限 | 已统一为全局 rate cap | 不是每个用户固定日收益；API 返回 raw rate/coverage，不承诺收益 |
| 24h 市场、Holder、排名、价格图 | 可从链上投影生成 | 数据不足显示 null/UNAVAILABLE，不使用 Mock |
| 团队、推荐链接、推荐列表、佣金 | 无合约、无可信 API/表、无资金来源规则 | 不进入 V2 冻结；禁止从转账图猜测。若新增必须另立产品/安全/隐私/会计规格 |
| Admin 部署证据管理 | 已统一为候选部署集导入、readback 与独立激活审批 | 不能任意覆盖权威地址，激活新部署集需独立决策 |
| Open Trading 状态 | 已统一为测试网一次性执行后的只读证据 | 不再提供写 Endpoint |

产品文档中任何展示、控制或经济文案与 deployed source/readback 冲突时，必须标注差异并修订产品文档，不能让 Go 服务“兼容”错误口径。
