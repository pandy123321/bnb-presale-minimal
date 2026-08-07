# PANGU2 V2 Plan and Baselines — Combined Review Copy

This file mechanically combines every remediation and baseline Markdown document in the package. File boundaries are authoritative.

---

## FILE: baselines/05_BUSINESS_AND_CONTRACT_INHERITANCE.md

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


---

## FILE: baselines/08_RULES_COMPLIANCE_AND_DECISIONS.md

# BingGoPlus V2 通用规则继承与开发门禁

状态：`MANDATORY / FREEZE_CANDIDATE`

适用规则：

1. [开源项目通用引用准入规则V1.0.md](../../../开源项目通用引用准入规则V1.0.md)
2. [通用智能合约安全开发风险控制与漏洞治理规范 V1.0.md](../../../通用智能合约安全开发风险控制与漏洞治理规范%20V1.0.md)

这两份规则是 BingGoPlus 新基线的上位门禁，不因 Go 重写、测试网已部署、旧代码已有审核或候选项目知名而豁免。发生冲突时取更严格要求。

## 1. 开源引用准入

### 1.1 分类

- `REFERENCE_PROJECT`：只研究中立需求、状态、失败模式和指标；不复制代码、目录、接口名、文案或独特结构。
- `ADOPTION_CANDIDATE`：完成初筛，但不能下载、安装或提交。
- `CONDITIONAL_ADOPTION_CANDIDATE`：许可证/集成边界有额外风险，必须法律与安全复核。
- `APPROVED_DEPENDENCY`：精确 release/commit、许可证、POC、TCO、SBOM、回滚和人工 Decision Record 全部批准。
- `REJECTED`：不得进入代码、镜像或生成链。

执行 Agent 不得自批。没有可追踪的 `APPROVE_DOWNLOAD` 时，所有候选保持 no-download。知名项目、GitHub Star、已开源或其他项目使用不构成批准。

### 1.2 强制证据

每个正式依赖必须冻结：

- upstream、精确 tag/release/commit、发布时间和维护状态；
- direct/transitive license、NOTICE、生成代码与链接义务；
- Security Policy、Advisory/CVE 与当前处置；
- 实际 import 的 package，不以整个仓库模糊批准；
- POC、benchmark、12 个月 TCO、运行故障与退出成本；
- SBOM、版本升级/回滚计划、Decision Owner；
- 禁止浮动 branch、`latest`、来源不明压缩包和未审 submodule。

LGPL/MPL/EPL 等条件许可证必须验证静态链接、文件修改、分发、源码/重链接义务；GPL/AGPL/SSPL/BSL/source-available 默认不进入生产，除非上位规则规定的例外审批完整通过。

### 1.3 供应链 Gate

- 开发、CI、审核、发布使用相同版本与生成输入；
- OpenAPI、SQL、ABI、生成工具、Go module、容器 base image 全部固定；
- 生成 SBOM、许可证清单、NOTICE、Secret/Dependency 扫描；
- 审计后不自动升级；升级视为新采用决策并重新审核；
- 研究结论必须是项目自有的中立规格，不能把上游实现当模板复制。

## 2. 智能合约安全规范在 Go V2 的继承

Go 重写不修改合约，但它负责索引、报价、分红构建和治理交易，因此仍处于资金与控制面。以下要求必须进入设计：

### 2.1 规格、资产与权限

- 绑定已部署 Commit、bytecode、constructor、roles、address、tx/block/hash；
- 建立 Token、BNB/WBNB、Fee bucket、Support、Locker、Dividend reserve、Staking reserve/liability 资产清单；
- RBAC deny-by-default；API/Indexer/Projector/Builder/Reconciler/Signer/DB Role 分离；
- 不允许单一 EOA、单个 API 进程或任意 calldata 控制全部资金与角色；
- 开盘、Pause/Unpause、Whitelist、Pair/System、Fee conversion、Dividend、Staking 等动作有显式权限与审计。

### 2.2 经济与会计

- 后端不重算税率替代合约，不把 UNKNOWN 降为低税；
- Preview 与 Execute 绑定部署 Router、buyer/seller、observed block/hash；
- FeeVault bucket 和实际余额、Dividend reserved/carry、Staking reserve/liability 持续 reconciliation；
- 分红使用固定 snapshot、Top 100、35/25/25/15、Pull Claim、Merkle proof，不做链上遍历/Push；
- 回购仍由合约强制 0.01 BNB/60 秒、slippage、deadline、Oracle、Locker recipient；
- 数量用 `big.Int/numeric(78,0)`，每个 rounding/dust/carry 规则明确且可重放。

### 2.3 Oracle、DEX 与 MEV

- Oracle stale/LIQUIDITY_LOW/deviation/zero reserve 全部 fail closed；
- 不用 spot price 代替部署 TWAP；
- Quote/Command 固定 slippage、deadline、path、target、selector 和最大数量；
- 多 RPC 结果冲突不静默选一个；
- 不开放 arbitrary target/call/delegatecall；
- permissionless update/buyback/release 仍由合约验证所有上限，后端不把 keeper 当安全边界。

### 2.4 Reentrancy/DoS/Gas 对应的服务端控制

- 服务端不批量向所有 Holder 推送链上交易；
- Indexer、Builder、API pagination 和 Job batch 全部有上限、Cursor 和可恢复 checkpoint；
- Dividend 用 off-chain 计算 + on-chain Merkle 验证；
- 单用户 proof/claim 失败不阻断其他用户；
- RPC、DB、Signer 故障有 bounded retry/dead letter，不无限循环或吞错。

### 2.5 部署、监控与事件响应

- 部署脚本历史证据与当前链上 readback 分开；广播回执成功不等于当前 bytecode/role 安全；
- 部署后检查 source verification、runtime bytecode、constructor、roles、pause、fee、oracle、router、treasury、allowance 和 frontend address；
- 监控 Role/Owner/Pause/Fee/Oracle/Liquidity/Buyback/Dividend/Staking/余额守恒和异常交易；
- 安全事件分 SEV-0..3，保全证据、保护剩余资产、外部复核、人工批准恢复；
- 不删除异常证据，不用未经验证的紧急升级，不私自转移用户资产。

## 3. 漏洞与风险台账

### 3.1 漏洞状态

沿用：`NEW / TRIAGED / CONFIRMED / DISPUTED / FIX_IN_PROGRESS / FIX_READY / RETESTING / RESOLVED / RISK_ACCEPTED / DUPLICATE / NOT_APPLICABLE / REOPENED / DISCLOSED`。

关闭必须同时具备 Fix Commit、原 PoC 不再成功、回归/不变量、工具复测、独立审核、残余风险和受影响部署处置。仅“代码已改”不得关闭。

### 3.2 风险状态

沿用：`OPEN / MITIGATING / MONITORING / ACCEPTED / TRANSFERRED / AVOIDED / CLOSED`。每项记录 Asset、Likelihood、Impact、Existing/Required Controls、Owner、Decision Owner 和 Review Date。

### 3.3 现有合约记录继承

- 旧审计 `docs/current/CONTRACT_SECURITY_AUDIT.md` 绑定 commit `e2c09c5`，不是部署 commit `3ef50b6` 的完整批准；
- 部署后的 source/interface/script 修复必须区分：影响 runtime、只影响后续部署脚本、只影响测试/文档；
- `P1-002 preview mismatch` 后续源码已修复，但需要部署字节码/ABI readback 才能确认测试网实例包含；
- `P1-001 staking reward funding/cost basis` 及 FeeVault 等既往风险不能因“18 项已完成”口头汇总自动 RESOLVED；
- post-deploy Bootstrap/Finalize/OpenTrading 脚本加固只保护未来执行，不能反向改变已发生部署；
- 所有未具备关闭证据的项进入风险/漏洞台账，并在 Admin 展示或 API fail closed。

## 4. 测试范围的处理

用户已明确本轮不规划和执行测试，由独立 Agent 在实现后接管。因此本轮：

- 不运行 Unit/Fuzz/Invariant/Fork/Mutation/CI；
- 不把“未测试”伪装成通过；
- 数据库/API/事件/状态机冻结可以完成，但不能据此批准 Mainnet；
- 安全规范中的 Unit/Fuzz/Invariant/Fork/Static/External Audit 仍保留为后续 Testnet Release/Mainnet 硬 Gate，不被删除或降级；
- 测试 Agent 必须接收 deployment commit、业务不变量、风险台账和本目录机器规范作为输入。

## 5. Mainnet NO-GO

本基线只允许 BSC Testnet。以下任一存在时均 NO-GO：

- 规格、资产清单、依赖、编译/生成输入或 deployment evidence 未冻结；
- runtime bytecode、roles、pause、oracle、fee、allowance、frontend address 未做固定区块 readback；
- P0/P1 未关闭，P2 未修复或未经人工接受；
- 测试、静态分析、内部/外部审核、SBOM、部署演练、监控、事件响应未通过；
- Signer、Multisig/Timelock、Secret、用户退出或人工批准未就绪；
- 审计 commit、部署 commit、bytecode 不一致；
- Mainnet 私钥或 RPC Secret 进入代码、`.env` 提交或普通服务器。

`APPROVED_WITH_CONDITIONS / UNDER_REVIEW / PARTIAL / PENDING / BLOCKED / UNKNOWN` 均不得被解释为 Mainnet 批准。

## 6. 决策记录清单

开发前必须签署：

| Decision ID | 内容 | Owner |
|---|---|---|
| DR-BRAND-01 | 产品名 BingGoPlus；链上 `Pangu2*` 身份不改 | 产品 + 合约 |
| DR-CONTRACT-01 | 测试网 ACTIVE deployment set 与 readback | 合约 + 安全 |
| DR-BIZ-01 | 经济/控制继承矩阵 | 产品 + 合约 + 安全 |
| DR-BIZ-02 | Dividend 有效持币量、排除、尾差、空档 | 产品 + 数据 |
| DR-DB-01 | SQL、唯一键、Reorg、重建 | 数据 |
| DR-API-01 | OpenAPI、Auth/RBAC、Command | 前端 + 后端 + 安全 |
| DR-EVENT-01 | ABI/Event/State/confirmation | 合约 + 数据 + 运维 |
| DR-OSS-* | 每个开源依赖与下载授权 | 开源 + 法律 + 安全 |
| DR-ENV-01 | 环境、Signer、Secret、单写者、回滚 | 平台 + 安全 |
| DR-CUTOVER-01 | Endpoint 分域切换与旧系统停用 | 产品 + 工程 + 运维 |

## 7. Stage Exit 证据

每阶段记录固定 Commit、文件、工具/依赖版本、输入 Hash、命令、结果、发现、残余风险、Reviewer、Decision Record 和 Verdict。开发 Agent 不能批准自己的 Stage Exit；安全/测试/发布由独立审核者接管。


---

## FILE: baselines/09_SELF_REVIEW.md

# BingGoPlus Go Backend V2 规划包自审

自审日期：2026-08-07  
自审范围：`docs/current/go-backend-v2/**`  
结论：`CHANGES_REQUIRED_BEFORE_FROZEN_FOR_DEVELOPMENT`  
Mainnet：`NO-GO`

## 1. 结论说明

规划包已经完成 Greenfield Go 架构、旁路替换、测试网部署继承、业务/经济/控制逻辑、数据库 DDL、OpenAPI、事件目录、状态机、部署环境、依赖准入和两份通用规则的设计候选。第二轮独立复审已关闭 `P1-DB-01` 与 `P1-BRAND-01`，并确认 `P1-DB-02` 因 Projector 状态闭环和 Dividend 固定区块数据通路仍为 OPEN；对应修订已进入候选但仍需再次独立复验。规划包不能直接标记 `FROZEN_FOR_DEVELOPMENT`：仍有产品定义、链上实时 readback、依赖人工批准和运维策略需要责任人签署。

本轮没有修改任何 Solidity、Laravel、TypeScript、Vue、Go、部署脚本、测试或运行环境；没有提交、推送、部署、签名或广播交易。

## 2. 自审维度

| 维度 | 结果 | 证据/说明 |
|---|---|---|
| 品牌 | PASS | 新系统统一 BingGoPlus；`Pangu2* / PANGU2` 只作为不可变链上身份 |
| 业务继承 | PASS_WITH_GATE | 税费、成本、资金路径、回购、Locker、Dividend、Staking、Oracle、权限完整；有效持币量仍待签署 |
| 部署继承 | PASS_WITH_GATE | 地址、部署交易、区块、区块 Hash、source commit 已固化；runtime/role/getter live readback 待做 |
| 数据库 | ROUND2_FIX_READY_FOR_REVIEW | 独立 `binggoplus_go.binggoplus_v2`、42 张表 + 4 个 Dividend 窄化历史视图；Raw Event 复合绑定、Audit Trigger、职责闭环、固定区块重放和 Mainnet DDL Gate 已进入候选 |
| API | PASS_AS_CANDIDATE | 39 paths/40 operations，Public/Admin 分前缀，DTO 明确，无 Mock 成功源，无任意 calldata |
| Event/State | ROUND2_FIX_READY_FOR_REVIEW | 11 streams、8 state machines；Raw Event 只表达观察/确认/分支/解码状态，投影完成由 versioned receipt 集合表达 |
| 部署环境 | PASS_AS_CANDIDATE | 旁路、单写者、独立 DB、Signer 隔离、分域切换与回滚 |
| 开源准入 | PASS_WITH_GATE | 只列 Reference/Candidate；未下载、未批准、未写浮动版本 |
| 合约安全规范 | PASS_WITH_GATE | 资产/权限/会计/Oracle/事件响应/Mainnet Gate 已继承；测试由独立 Agent 后续接管 |
| 改动边界 | PASS | 仅修改规划文档与 SQL 冻结候选；未修改业务代码、合约、测试、部署脚本或运行环境 |

## 3. 机器/静态核验结果

### 3.1 已通过

- OpenAPI：39 个 path、40 个 operationId；无 operationId 重复；全路径使用 BingGoPlus V2 Public/Admin 前缀；本地 `$ref` 均能解析到已定义 component；
- OpenAPI 治理写入：action 是有限 enum，参数为 action-specific closed schema；请求不能提供 target、selector、calldata 或 private key；
- DTO：移除 Config/Market/Activity/Staking/Buyback/Locker/Job/Audit/Governance 的 Generic DTO；仅错误 `details` 允许开放对象；
- State Machine：8 个状态机无未知目标，无“声明终态但仍有出边”；
- Event Catalog：11 个流地址格式正确且唯一；除 Pair 需批准外部 ABI 外，目录中所有 event signature 均存在于本地合约 ABI artifact；
- Deployment Address：11 个 Event Stream 地址全部与 `BSC_TESTNET_DEPLOYMENT_BASELINE.md` 对应实例一致；
- Business Matrix：部署 Commit、3000/400/1000 bps、900+100 拆分、0.01 BNB、60 秒、365 天、35/25/25/15、30 天 claim、Staking rate cap、UNKNOWN、preview 方法均有明确规则；
- Database：DDL 共 42 张表和 4 个 Dividend 历史/覆盖视图；Raw Event 必须整体匹配环境/部署/Stream/实例/地址授权绑定；Audit 表有拒绝 UPDATE/DELETE 的 Trigger；权限脚本对运行角色使用显式 allowlist；
- 文档：无 tab、无真实 private key/mnemonic/带 API Key RPC URL 模式；
- 品牌/链上身份：产品文档不再使用未部署 Token symbol；BingGoPlus 与 `Pangu2* / PANGU2` 边界一致。

### 3.2 自审发现并已修正

1. Event Catalog 曾使用摘要中的截断地址，已改为 Foundry 部署台账完整地址。
2. BuybackLocker ABI 没有 AccessControl 事件，已从该 Stream 删除误列事件。
3. `projection_receipt.FAILED` 可重试却被标为终态，已改正。
4. Signer nonce 唯一键原未包含 environment，已增加 `environment_id`。
5. `dividend_approvals.admin_user_id` 原缺 FK，已补到 `admin_users`。
6. Admin 动态 read path 原可能和 `/commands` 产生歧义，已改为 `/governance/read/{read_model}`。
7. Governance request 原参数对象过宽，已改为每个 action 的 closed schema。
8. OpenAPI 原有 Generic DTO，已替换为明确 DTO。

### 3.3 独立复审结论与修订状态

| Finding | 对原结论的判断 | 修订 | 当前状态 |
|---|---|---|---|
| `P1-DB-01` Raw Event 可绑定错误 Stream/合约 | 正确。原 DDL 只有分散外键，不能证明五个标识属于同一授权关系 | `chain_stream_contracts` 固化环境、部署批次、Stream、实例和地址；`chain_raw_events` 以同一五列复合外键引用 | `CLOSED_BY_INDEPENDENT_REVIEW` |
| `P1-DB-02` Audit append-only 与运行权限 | 原问题正确；第二轮确认 Trigger/Audit 直接权限正确，但发现 Projector 与 Dividend 工作流未闭合 | 第二轮修订见下节；Audit 不可变边界本身保留 | `ROUND2_FIX_READY / INDEPENDENT_RETEST_PENDING` |
| `P1-BRAND-01` BingGoPlus/PANGU2 与自动回购表述冲突 | 正确。产品文档曾混用旧别名，并把最小间隔写成自动频率 | 产品品牌统一 BingGoPlus，链上 Token 统一 PANGU2；回购改为 permissionless trigger + 60 秒最小间隔 + 前置条件 | `CLOSED_BY_INDEPENDENT_REVIEW` |

自审额外修正文档内部的四处既有冲突：盈利判断改为 TWAP 卖出价值与对应历史成本比较；Admin 地址 CRUD 改为部署证据与独立激活审批；已执行 Open Trading 改为只读证据；Staking 收益改为全局 reward-rate cap，不再承诺每用户固定日收益。数据库侧同时把 Stream 唯一性收敛到部署批次，并要求 Raw Event 的区块号/Hash 命中同一 `chain_blocks` 记录。

### 3.4 第二轮独立复审与修订

| Finding | 对结论的判断 | 修订 | 当前状态 |
|---|---|---|---|
| `P1-DB-PRIV-01` Projector 无法写 Raw Event `PROJECTED` | 正确。单一 Raw Event 状态也无法表达多个 projector/version 的完成度 | 从 DDL/State 删除 `PROJECTED`；Projector 对 Raw Event 只读；完成、失败、重试、撤销全部由 versioned receipt 表达 | `FIX_READY / INDEPENDENT_RETEST_PENDING` |
| `P1-DB-PRIV-02` Dividend Builder 无固定区块历史输入 | 正确。current 表会越过 Epoch snapshot | 新增 finalized block、projection coverage、Token ledger、Staking history 四个 security-barrier 视图；Builder 只读窄视图，锁定 projector manifest 并保存 input checksum | `FIX_READY / INDEPENDENT_RETEST_PENDING` |
| `P2-DOC-01` 团队/推荐/佣金仍列为当前能力 | 正确。与 API 和业务冻结范围冲突 | 从当前资产功能表移除，改列为 `OUT_OF_SCOPE / ROADMAP_NOT_APPROVED`，禁止从转账图或 Mock 推断 | `FIX_READY / INDEPENDENT_RETEST_PENDING` |

权限自审同时收窄：Indexer 对 Raw Event 只能更新 decode/确认/canonical 列、对 Block 只能更新 canonical/finalized；Projector 对 versioned Token ledger 和 Staking history 只能追加，不能删除；Dividend Artifact 只能插入新版本，不能原地改写。

### 3.5 未执行/工具限制

- 按用户要求不运行项目 Test、Build、Migration、RPC、Fork 或部署；
- 当前工作区内没有可用 YAML/OpenAPI parser/linter，且开源规则不允许未经批准下载；因此本轮完成了结构、引用和 ABI 对照，但未运行标准 OpenAPI 3.1 lint；
- PostgreSQL DDL 未实际执行；
- 运行时权限脚本未在真实 PostgreSQL Role/Database 上应用；
- BSC Testnet live readback 未执行。

独立复审 Agent 应在不修改代码的前提下，优先使用其已批准/已有的 YAML/OpenAPI 与 PostgreSQL 工具补这三项只读验证；不得为了验证私自下载依赖。

## 4. 阻止冻结的剩余项

### GATE-01：Dividend 有效持币量

状态：`UNRESOLVED-BIZ-01`。需要产品/数据负责人确认是否采用：

`wallet balance + active staked principal`，排除 system/pair/zero/burn，不展开 LP；空档不重分配，最终 carry。

在签署前可开发通用 Indexer，但不能实现或发布 Dividend ranking/builder。

### GATE-02：测试网 Live Evidence

需要在固定 block number/hash 完成 runtime bytecode hash、Pair factory getPair、roles、pause、tradingOpenAt、Oracle、Fee bucket、Support、Locker、Staking、allowance 和关键 getter readback。失败时 deployment set 不能 ACTIVE，API 必须 UNAVAILABLE。

### GATE-03：开源依赖

Go 精确版本和所有依赖仍未获人工 `APPROVE_DOWNLOAD`。必须完成 license/NOTICE、POC、benchmark、12 月 TCO、SBOM、版本/commit 和回滚 Decision Record，尤其是 go-ethereum 与 River 的条件许可证边界。

### GATE-04：Event/Operations 策略

需批准 Pancake V2 Pair ABI 来源与 hash、`confirmation_depth=20` 和 `reorg_lookback=200`。候选值不是网络事实，未签署前不得写死到生产配置。

### GATE-05：Freeze 签署

DB、OpenAPI、Event/State、环境、RBAC/Signer 仍需各责任人签署；标准 YAML/OpenAPI lint 和 DDL parse/执行由已批准工具完成。通过后才将版本标为：

`v2-contract-1 / v2-db-1 / v2-api-1 / v2-event-1 / v2-state-1 / v2-dependencies-1`。

### GATE-06：后续测试与发布安全

本轮明确延期，不是豁免。独立测试 Agent 后续必须处理 Unit/Fuzz/Invariant/Fork/Static/Regression；外部合约审核、部署演练、监控、事件响应和 P0/P1/P2 Gate 未通过前 Mainnet 始终 NO-GO。

## 5. 自审 Verdict

```text
PLANNING_DELIVERABLE = ROUND2_FIX_READY_FOR_INDEPENDENT_REVIEW
FROZEN_FOR_DEVELOPMENT = NO
DEVELOPMENT_START = CHANGES_REQUIRED
BSC_TESTNET_CONTRACT_REDEPLOY = FORBIDDEN
BSC_MAINNET = NO-GO
```

下一步应先由独立 Review Agent 复审本规划包；然后由责任人只关闭 GATE-01..05。开发实施仍按 G0-G9 旁路阶段执行，不能绕过冻结直接开写。


---

## FILE: baselines/BSC_TESTNET_DEPLOYMENT_BASELINE.md

# BSC Testnet 实测合约继承基线

状态：`STATIC_EVIDENCE_CAPTURED / LIVE_READBACK_PENDING`

Deployment Set：`binggoplus-bsc-testnet-97-3ef50b6-20260806`

产品品牌已冻结为 **BingGoPlus**。`Pangu2Token`、`Pangu2TradeRouter`、合约地址、事件名以及链上 Token name/symbol 属于已部署且不可改写的链上身份；品牌更名不触发重部署，也不得在 API 中伪造不同的链上 Token 元数据。

该台账来自本地 Foundry 广播文件和 Git 历史的静态读取，没有访问 RPC、没有重放交易、没有部署。Go V2 只能导入这套新地址，不能导入旧 `0xaf2b...` 地址组。

## 1. 证据来源

- Source commit：`3ef50b6d77a31c092e9353e255e672836f36ece8`；
- Deploy：`contracts-v2/broadcast/DeployPangu2.s.sol/97/run-latest.json`；
- Bootstrap：`contracts-v2/broadcast/BootstrapPangu2.s.sol/97/run-latest.json`；
- Finalize：`contracts-v2/broadcast/FinalizePangu2.s.sol/97/run-latest.json`；
- Open Trading：`contracts-v2/broadcast/OpenTradingPangu2.s.sol/97/run-latest.json`；
- DApp address mirror：`apps/dapp/src/features/wallet/deployed.ts:4-14`；
- Network：BSC Testnet，`chain_id=97`。

部署广播含 73 个 receipt，静态记录的 status 均为 `0x1`。这证明广播文件记录成功，不等于已经完成当前链上 bytecode/role readback。

## 2. 长期合约实例

| 合约 | 地址 | 部署/创建区块 | 交易哈希 | 区块哈希 |
|---|---|---:|---|---|
| Pangu2Token | `0x49a4a6ecaacc5d9ae60df7717f62e0605f591bc3` | 123502176 | `0x8f6ddf160a6d010d78748095a0bfa0a576e8ca7cd93dbdcc671806b43805398f` | `0x4525982663b89b10751223f2eb461c2daf58dba5905dc2b80f7ebadfa1aae6a4` |
| CostBasisManager | `0x695660310afb747589d415d24f20a3eef05693d0` | 123502181 | `0x00dff4728b02e46d4aab34de4864ca8f260d9c3691070f8b589e039b107c489e` | `0x65d5aef0c487e83b47a61ae42f67931f2754f7130984de37421ce010103011f2` |
| Pancake V2 Pair | `0x07d481b52c27941f6daaeb53aaa879c588408f32` | 123502187 | `0x0126544f883371b8cccb5df4e8c1b5368765a27b9162186febf55a08fda8770b` | `0x06a66c470fe8cc5196a398723be1aeae11b12a341a312f970e246e1d42be125d` |
| PancakeV2Adapter | `0xc3bb2129cb362b82cc15ec63a8355e80d4198e3a` | 123502195 | `0xcc6de4cd4a191d9e16c64a73999ef7bdff3eac2748b25c511749b3214b7ebe16` | `0x971f3175daaaf9e9864adb7b4691d980148de747e854923eb6f775205e80de81` |
| PancakeV2TwapOracle | `0x11c39db60a95b232c6c303c1869aa81886694d9c` | 123502202 | `0xbd85ea70b006874a7a995ed047d1c8c83401335f61ede206de890da43e724382` | `0x6442518ec15d6cf17a36e93cc2843a458f87976a2cbf1ba294deeeda9825144b` |
| SupportPool | `0xe6d37841b13d78e9ae759b77ecfaebeddb90589b` | 123502210 | `0x5e5c58303fa25fd937fc5d099478886c0d85a677d9d8603308b57f1feaf12b63` | `0xa2cab5fe4566bb5730d00bee6807a429a950d15e906e6aa43c21255a2d241ce4` |
| FeeVault | `0xf82313eb70d24250d541c26796fe1615beb15d29` | 123502218 | `0x418e592e4f56eabff5773b93f9053ac3a13372319c71ee64dbf13130f9659312` | `0x7314d98104b6e0062e13fd3c3175fc5a8591e217cd1f43310d2e03f4335db648` |
| BuybackLocker | `0x0a2283cd52523889fcb333596c3f0a14741b1cce` | 123502225 | `0x7f299e80f5017b94d1db8c6c0783c1c397afbe03ebafd7235d6e368ce8271d1a` | `0x4cb0a505722cb87fcf245afc1f5e76a8035c189248addfedbf48d8f0b065b774` |
| DividendDistributor | `0x917705d794ec31144f7b2c4d62bfaab4fe327385` | 123502234 | `0xb749c44f0e31ec21df27b386061da518bc321dbaa9d048a33e30dc57865d5591` | `0x02bb3dde095a05f31f299c431ce8ee536e318411922bb5f2667874321b8da9ff` |
| Pangu2TradeRouter | `0xb0b5b52cb99ee7ea055669ba49afd02cf69c71b5` | 123502248 | `0x36d1b0662777c539732e726e47a0a5bc48471431f31ea0916a992a95510966bb` | `0x87ef6a1b935446026a4fa908842e81852a79cab05dd32ec9bf1a0561f8b4d719` |
| Pangu2Staking | `0xf1d27ef1037c38b6752bae449fd3a460b49775a8` | 123502253 | `0xd503e6c381fa6fe8326ab3d6299e6263e038db3d94faf6155a4a79d85f80c1bf` | `0xa5dc8ab64f77697bff1a85a6cc4bf5b5dbba1674eed3d0983b5fdd372a0c7692` |

Pair 地址来自 createPair 参数后 factory 的确定结果、后续 constructor 参数和 DApp 地址镜像；上线前仍须以 factory `getPair(token,wbnb)` 在固定块读回确认。

## 3. 实测关键参数

| 参数 | 实测部署值 | 来源 |
|---|---:|---|
| Pancake Factory | `0x6725f303b657a9451d8ba641348b6761a6cc7a17` | Adapter/Oracle constructor |
| Pancake Router | `0x9ac64cc6e4415144c455bd8e4837fea55603e5c3` | Adapter constructor |
| WBNB | `0xae13d989dac2f0debff460ac112a837c89baa7cd` | Adapter/Oracle/Pool/Vault constructor |
| TWAP window | 1800 seconds | Oracle constructor |
| Maximum spot/TWAP deviation | 300 bps | Oracle constructor |
| Minimum token reserve | `100000000000000000` raw | Oracle constructor |
| Minimum WBNB reserve | `1000000000000000` wei | Oracle constructor |
| SupportPool max slippage | 300 bps | SupportPool constructor |
| SupportPool quote deadline | 300 seconds | SupportPool constructor |
| FeeVault max conversion | `1000000000000000000000000` raw | FeeVault constructor |
| FeeVault max slippage | 300 bps | FeeVault constructor |
| Locker mode | `FIXED_DURATION` (`1`) | Locker constructor |
| Locker duration | 31,536,000 seconds（365 days） | Locker constructor |
| Bootstrap token amount | `100000000000000000000` raw | Bootstrap proxy constructor |
| Bootstrap BNB amount | `10000000000000000` wei（0.01 BNB） | Bootstrap proxy constructor |

上述地址统一以 lowercase 存储；UI 可按 checksum 格式展示。

## 4. 实测执行时间线

| 阶段 | 结果 | 区块 | 交易哈希 |
|---|---|---:|---|
| Deploy contracts/configure roles | 73 receipts，均 `0x1` | 123502176-123502752 | Deploy run-latest |
| Create temporary BootstrapLpProxy | 成功 | 123516946 | `0xd050b4f4127c124496974cbf1eebd6a120651b6a5fd018448fb897438c27b496` |
| Add initial liquidity | 成功 | 123516960 | `0x6e633fbbaafa67cd901d33bdba6904cdae63a16c90cda9237e3b65c8164c9db1` |
| Revoke proxy liquidity manager | 成功 | 123516963 | `0xd747adc6b4392661e0a5b2a14bef01fb02b483ba92c766469cd3561690963c7d` |
| Reset proxy allowance to zero | 成功 | 123516969 | `0x2675f033ed363580a5c40c2e9be8737d2f53556ddfa0b30f1526224f3b88030d` |
| Final Oracle update | 成功 | 123527088 | `0xe2fa5b878bb0f7175ee833e510f440b5f1122cbe81d9355243b11837c21872c4` |
| Open trading | 成功 | 123527207 | `0x4c780e1168abfd4e5bb6b65aa9d90f6fd924ec5667c49311fee688416470fd6a` |

Bootstrap run-latest 中最后一笔 Oracle `update()` 有 transaction 记录但没有 receipt；后续 Finalize 的独立 `update()` 有成功 receipt。V2 台账不能把缺失 receipt 的那一笔标为 confirmed。

## 5. 修复和审核继承

部署提交包含以下关键祖先修复：

- `187f59a`：Launch 15 分钟、30% 税；
- `26ec240`：0% fee whitelist；
- `e965655`：Counterfactual TWAP 与 timestamp rollover；
- `7f4d757`：whitelist-aware preview；
- `ce44425`：用户税率 preview、slippage 和事件对齐；
- 之前的 Cost Basis、Staking、Oracle、Adapter、Governance 安全修复均已在部署提交历史中。

`docs/current/CONTRACT_SECURITY_AUDIT.md` 是 `e2c09c5` 的 CONDITIONAL APPROVE，不是部署提交本身；其中 P1-002 已由 `7f4d757` 和 `ce44425` 覆盖。其他 finding 不能因为部署成功自动标为关闭，应在“继承状态”中保留原结论或显式重新审核。

部署之后的 `67c451b`、`e1721ac`、`4909680`、`28c5790`、`4d33669` 等主要加固 Bootstrap/Finalize 脚本。它们没有改变已部署长期合约的 runtime 实现，且不允许用来重跑现有部署；Go 运行手册应继承其“防重复注入、按部署 artifact 清理、严格储备检查、撤销 stale proxy”等安全约束。

当前 HEAD 相比 `3ef50b6` 的 `contracts-v2/src` 只有 `IPangu2TwapOracle.sol` 接口说明增加，没有长期合约 runtime 代码修改。上线前仍应对部署 ABI 和 current ABI 生成 hash，而不是依赖该陈述。

## 6. Go 开发前必须补录的只读证据

- 每个地址当前 `eth_getCode` 非空和 runtime bytecode SHA-256；
- Pair `token0/token1` 与 factory `getPair`；
- Token `tradingOpenAt`、pair/system/liquidity manager/fee whitelist；
- 每份 AccessControl 合约的当前 role membership；
- Router/Token/Vault/Pool/Distributor 的 pause 状态；
- Oracle status、window、last completed、reserves；
- FeeVault bucket/accounting、SupportPool balance/cooldown、Locker mode/duration/recipient/solvency；
- Staking rate/reserve/liability/coverage；
- 选定固定 evidence block 的 number/hash。

未完成上述 readback 前，API 可显示 deployment `STATIC_VERIFIED`，不得显示 `LIVE_VERIFIED`，Admin 写路径不得启用。

## 7. 禁止事项

- 禁止自动执行任何 Solidity 部署或 Bootstrap 脚本；
- 禁止把旧 `0xaf2b...` 地址组导入为 ACTIVE；
- 禁止把广播记录当成当前角色/暂停状态的替代品；
- 禁止将 `.env`、RPC Secret 或私钥写入 deployment baseline；
- BSC Mainnet 永久 NO-GO。


---

## FILE: baselines/CONTRACT_SECURITY_AUDIT.md

# PANGU2 V2 Stable Contract — Full Security Audit

- **Audit Date:** 2026-08-06
- **Commit SHA:** `e2c09c5` (amended from `cd1f17c`)
- **Auditor:** Internal + Dual Subagent Audit
- **Test Results:** 122 tests, 0 failures, ~140K fuzz runs across 7 test suites

---

## Executive Summary

**Verdict: CONDITIONAL APPROVE**

- 0 critical (P0) vulnerabilities found
- 2 P1 findings, 7 P2 findings, 5 P3 findings
- All P1 issues are bounded by permissions or parameters
- 122 automated tests pass with 0 failures
- Complete tax matrix verified (10 cells)
- Permission matrix verified (8 roles, 12 actions)
- Supply conservation verified (6 invariants)

---

## Scope — 15 Contract Components Audited

| # | Contract | Lines | Role |
|---|---|---|---|
| 1 | Pangu2Token | 454 | ERC-20 with tax, launch protection, whitelist, transfer context |
| 2 | Pangu2TradeRouter | 267 | Entry point for buy/sell, swaps via PancakeSwap V2 |
| 3 | CostBasisManager | ~500 | On-chain cost basis tracking for profit/loss tax determination |
| 4 | PancakeV2Adapter | ~150 | Adapter layer between contracts and PancakeSwap V2 Router |
| 5 | PancakeV2TwapOracle | 274 | Counterfactual TWAP oracle with deviation check |
| 6 | SupportPool | 197 | Accumulates BNB, executes permissionless buybacks |
| 7 | FeeVault | 216 | Holds tax tokens, supports Keeper-triggered conversion |
| 8 | BuybackLocker | ~80 | Time-locks buyback tokens |
| 9 | DividendDistributor | ~200 | Merkle-based dividend distribution |
| 10 | Pangu2Staking | 286 | Staking with rewards, early unstake, coverage monitoring |
| 11 | DeployPangu2 | ~240 | Deployment script |
| 12 | BootstrapPangu2 | ~170 | Liquidity bootstrap script |
| 13 | FinalizePangu2 | ~100 | Oracle finalization script |
| 14 | OpenTradingPangu2 | ~35 | Trading activation script |
| 15 | BootstrapLpProxy | ~65 | One-shot LP proxy contract |

---

## Test Coverage Summary

| Test Suite | Tests | Coverage Area |
|---|---|---|
| PancakeV2TwapOracleTest | 12 | Counterfactual TWAP, mid-swap, deviation, fuzz |
| PancakeV2TwapOracleToken1Test | 4 | Token-as-token1 quotes |
| BootstrapRoleSeparationTest | 21 | Multi-role, proxy one-shot, pause, allowance, wrong chain |
| LaunchTaxTest | 28 | All 9 tax cells, invariants, boundaries, fuzz |
| FeeWhitelistTest | 22 | WL add/remove, Router bypass, Pair bypass, Pause bypass |
| TaxMatrixTest | 21 | Full matrix regression, conservation, parity, fuzz |
| StakingSecurityTest | 14 | Principal protection, liability, coverage, tax bypass, fuzz |
| **TOTAL** | **122** | **0 failures** |

---

## Findings

### P0 — Critical (0 found)

No critical vulnerabilities identified.

---

### P1 — High (2 found)

#### P1-001: `fundRewards()` uses `safeTransferFrom` path that triggers CostBasisManager

- **File:** `Pangu2Staking.sol:118-126`
- **Function:** `fundRewards(uint256 amount)`
- **Attack Path:** When REWARD_MANAGER calls fundRewards, the transfer path goes through Pangu2Token._update(). The staking contract is a systemAddress, so this falls into the user→system path, NOT the staking deposit path. The reward manager's cost basis is NOT adjusted.
- **Impact:** Reward manager's tracked_balance drifts from actual balance. Impact limited — reward managers are typically Governance addresses, not retail users.
- **Recommendation:** Add `REWARD_FUNDING` TransferContext for proper cost basis handling.
- **Subagent concurrence:** Confirmed. P1.

#### P1-002: TradeRouter tax-rate determination for sell misses whitelist-aware preview

- **File:** `Pangu2TradeRouter.sol:220-254`
- **Function:** `_previewSell(address seller, uint256 tokenAmount)`
- **Issue:** The TradeRouter calls `token.previewSellTax(tokenAmount, taxBps)` — NOT the whitelist-aware `previewSellTaxFor(seller, tokenAmount, taxBps)`. This means the TradeRouter's preview does NOT apply the 0% whitelist to the displayed quote. However, `token.settleSell()` internally calls `previewSellTaxFor(seller, ...)`, so execution IS correct.
- **Impact:** Preview shows wrong tax rate for whitelisted sellers (shows 4%/10% instead of 0%). Execution is correct. DApp displays inaccurate preview for whitelisted users.
- **Recommendation:** Change `token.previewSellTax(...)` to `token.previewSellTaxFor(seller, ...)` at lines 233-234.
- **Severity justification:** P1 because preview/execution mismatch is a data integrity issue that affects user-facing quotes.

> **Correction applied:** This finding was independently discovered by a subagent auditor during final review and is the most actionable P1 issue.

---

### P2 — Medium (8 found)

#### P2-001: `_updateGlobalReward()` may silently cap emissions

- **File:** `Pangu2Staking.sol:77-91`
- **Issue:** `emitted` is capped to `availableRewardReserve`, but `rewardPerTokenStored` uses the full `rewardRate * elapsed` formula. When reserves run out, future stakers could get inflated rewards when new funds arrive.
- **Recommendation:** Track `effectiveRewardPerTokenStored` proportional to actual emitted rewards.

#### P2-002: `sell()` swapTokens == zero edge case

- **File:** `Pangu2TradeRouter.sol:168-171`
- **Issue:** If sell tax == 100%, `swapTokens == 0`, causing adapter call to revert. Natural fail-closed — no loss.
- **Recommendation:** Add explicit `if (swapTokens == 0) revert InvalidAmount()`.

#### P2-003: `buyback()` oracle call not wrapped in try/catch

- **File:** `SupportPool.sol:161` **(found by subagent audit)**
- **Issue:** `canExecuteBuyback()` wraps oracle in try/catch, but `buyback()` does not. If oracle reverts at execution time, caller loses gas. Since buyback is permissionless, this creates a griefing vector.
- **Recommendation:** Wrap the oracle call in try/catch in `buyback()` or document the gas-loss risk.

#### P2-004: `credit()` not `whenNotPaused`

- **File:** `FeeVault.sol:124-131` **(found by subagent audit)**
- **Issue:** `credit()` lacks `whenNotPaused` modifier. Tax collection continues during pause while withdrawals are blocked. Creates imbalance that becomes drainable on unpause.
- **Recommendation:** Either add `whenNotPaused` to `credit()` or document that tax accrual during pause is intentional.

#### P2-005: `cancelUnclaimedEpoch()` missing pre-window guard

- **File:** `DividendDistributor.sol` **(found by subagent audit)**
- **Issue:** `cancelUnclaimedEpoch()` can be called at any time, even before the claim window has begun. This is inconsistent with `closeEpoch()` which requires the claim window to have elapsed. An admin could cancel an epoch before any users can claim.
- **Recommendation:** Add a pre-window guard: `require(block.timestamp >= c.claimEnd, "claim-window-not-elapsed")` to match `closeEpoch()` semantics.

#### P2-006: `_previewSell` uses `BUY_TAX_BPS()` in slippage calculation

- **File:** `Pangu2TradeRouter.sol:138-140` **(found by subagent audit)**
- **Issue:** The buy slippage floor uses `BPS_DENOMINATOR - token.BUY_TAX_BPS()` as denominator. If tax were ever 100%, this would be division by zero.
- **Recommendation:** Add `require(token.BUY_TAX_BPS() < BPS_DENOMINATOR)` or use a safe minimum denominator.

#### P2-007: FeeVault `credit()` silently accepts invalid enum values

- **File:** `FeeVault.sol:127-128` **(found by subagent audit)**
- **Issue:** The `else` branch catches any non-DIVIDEND value including out-of-range enum values. Solidity 0.8.x does not runtime-check enum ranges.
- **Recommendation:** `require(bucket == Bucket.DIVIDEND || bucket == Bucket.SUPPORT, "invalid bucket")`.

#### P2-008: FeeVault `convertSupport()` has no zero-quote check

- **File:** `FeeVault.sol:177-180` **(found by subagent audit)**
- **Issue:** If `q.amountOut == 0` and caller passes `minWbnbOut == 0`, swap executes with zero minimum output.
- **Recommendation:** `if (q.amountOut == 0) revert ZeroQuote()` before computing minimums.

---

### P3 — Low (5 found)

#### P3-001: BuybackLocker lacks independent tests
- **Impact:** The locker contract was excluded from the Phase 5 staking audit scope. No fuzz or edge-case tests exist.
- **Recommendation:** Add basic unit tests for `registerBuyback()` and lock duration enforcement.

#### P3-002: `console.log` in deploy scripts increase gas
- **Impact:** Gas cost only. Not a security issue.
- **Recommendation:** Gate behind debug flag for mainnet.

#### P3-003: Preview `expiresAt` reflects max window, not user-chosen deadline

- **File:** `Pangu2TradeRouter.sol:216, 253` **(found by subagent audit)**
- **Issue:** `expiresAt = block.timestamp + MAXIMUM_DEADLINE_WINDOW` — off-chain integrators may misinterpret this as the actual deadline.
- **Recommendation:** Naming clarification or removal of `expiresAt` from preview struct.

#### P3-004: FeeVault `fundDividendDistributor` uses misleading `ZeroAddress` error

- **File:** `FeeVault.sol:147` **(found by subagent audit)**
- **Issue:** `revert ZeroAddress()` when distributor not yet configured. Should be `DistributorNotConfigured()`.
- **Recommendation:** Add a distinct error.

#### P3-005: SupportPool buyback parameters fully hardcoded

- **File:** `SupportPool.sol:22-23, 153` **(found by subagent audit)**
- **Issue:** `BUYBACK_AMOUNT = 0.01 ether` and `MIN_BUYBACK_INTERVAL = 60 seconds` are constants — no ability for governance to adjust without redeployment.
- **Recommendation:** Document that these are intentionally immutable for this deployment phase.

---

## Positive Security Findings

| # | Strength | Source |
|---|----------|--------|
| 1 | ReentrancyGuard on all state-mutating functions | All contracts |
| 2 | Fail-closed Oracle (OracleNotReady, TwapTooOld, BelowMinimumReserves, ExcessiveSpotTwapDeviation) | PancakeV2TwapOracle |
| 3 | TransferContext whitelist per contract | Pangu2Token + all system contracts |
| 4 | Fee whitelist per-receiver, not per-msg.sender | Pangu2Token |
| 5 | Tax constants immutable | Pangu2Token |
| 6 | Principal protection in Staking | Pangu2Staking.claimRewards |
| 7 | Coverage ratio passive solvency check | Pangu2Staking.coverageRatio |
| 8 | TradeRouter default-paused | DeployPangu2.s.sol |
| 9 | One-shot LP proxy with fixed amounts | BootstrapLpProxy |
| 10 | Supply conservation invariants | All tax-preview functions |
| 11 | Role-separated PAUSER/UNPAUSER | All pausable contracts |
| 12 | SafeERC20 throughout | All token-transferring contracts |
| 13 | Allowance reset to 0 after every swap | TradeRouter + FeeVault + SupportPool |
| 14 | BNB receivers guarded (only authorized senders) | TradeRouter, SupportPool, FeeVault |

---

## Attack Surface Matrix

| Attack Vector | Mitigation | Status |
|---|---|---|
| Reentrancy | `nonReentrant` on all state changes | MITIGATED |
| Oracle manipulation | Counterfactual TWAP + deviation + reserve minimum | MITIGATED |
| Flash loan price manipulation | TWAP window + deviation bound | MITIGATED |
| Tax bypass via Router | Per-receiver preview functions | MITIGATED |
| Tax bypass via whitelist | Governance-only management | MITIGATED |
| Whitelist→global bypass | Per-address check, msg.sender-independent | MITIGATED |
| Staking principal drain | Principal-protected claim + coverage ratio | MITIGATED |
| Reward over-distribution | InsufficientReserve check + max rate | MITIGATED |
| Unauthorized transfer | Context whitelist per contract | MITIGATED |
| Wrong chain deployment | Env-var chain verification | MITIGATED |
| Stale Oracle | TwapTooOld (5x window) | MITIGATED |
| uint32 overflow | uint40 anchor timestamps | MITIGATED |
| Deployer privilege | Full renounce + assertion | MITIGATED |
| LP proxy double-spend | One-shot guard | MITIGATED |
| Epoch cancel before claims | **P2-005** — missing guard | OPEN |
| Preview/Execution whitelist mismatch | **P1-002** — TradeRouter does not use whitelist-aware preview | OPEN |

---

## Tax Matrix Verification

| Phase | Whitelist | Direction | Tax | Tested? |
|---|---|---|---|---|
| Pre-open | — | Buy | 4% | TaxMatrix |
| Launch | WL | Buy | 0% | TaxMatrix, FeeWhitelist |
| Launch | WL | Sell | 0% | TaxMatrix, FeeWhitelist |
| Launch | Non-WL | Buy | 30% | TaxMatrix, LaunchTax |
| Launch | Non-WL | Sell | 29%+1% | TaxMatrix, LaunchTax |
| Normal | WL | Buy | 0% | TaxMatrix, FeeWhitelist |
| Normal | WL | Sell | 0% | TaxMatrix, FeeWhitelist |
| Normal | Non-WL | Buy | 4% | TaxMatrix |
| Normal | Non-WL | Sell 4% | 4% | TaxMatrix |
| Normal | Non-WL | Sell 10% | 9%+1% | TaxMatrix |

---

## Permission Matrix

| Action | Governance | Emergency | Keeper | Deployer | LP | Anyone |
|---|---|---|---|---|---|---|
| Set pair | Y | — | — | — | — | — |
| Set whitelist | Y | — | — | — | — | — |
| Set liquidityManager | Y | — | — | — | — | — |
| Open trading | Y | — | — | — | — | — |
| Pause (Router/Pool/Vault) | — | Y | — | — | — | — |
| Unpause | Y | — | — | — | — | — |
| Convert fees | — | — | Y | — | — | — |
| Fund rewards | RewardMgr | — | — | — | — | — |
| Set reward rate | RewardMgr | — | — | — | — | — |
| Oracle update | — | — | — | — | — | Y |
| Buyback trigger | — | — | — | — | — | Y |
| Stake / Unstake / Claim | — | — | — | — | — | Y |
| Add liquidity | — | — | — | — | Y (once) | — |

---

## Supply Conservation Verification

| Invariant | Formula | Verified |
|---|---|---|
| Buy tax | `tax + net == gross` | TaxMatrix, LaunchTax, FeeWhitelist |
| Sell tax (launch) | `support + burn + swap == sellAmount` | LaunchTax, TaxMatrix |
| Sell tax (normal) | `support + burn + swap == sellAmount` | TaxMatrix |
| Sell tax (profit) | `support + burn + swap == sellAmount` | TaxMatrix |
| Staking principal | `balance >= totalStaked` | StakingSecurity |
| Fee vault solvency | `balance >= accounted` | FeeVault._assertSolvent |
| Preview = Execution | Same function path | TaxMatrix, all preview tests |

---

## Summary of All Findings

| ID | Severity | File | Line | Description |
|----|----------|------|------|-------------|
| P1-001 | P1 | Pangu2Staking | 118-126 | fundRewards cost-basis drift |
| P1-002 | P1 | Pangu2TradeRouter | 233-234 | previewSellTax not whitelist-aware |
| P2-001 | P2 | Pangu2Staking | 77-91 | _updateGlobalReward silent cap |
| P2-002 | P2 | Pangu2TradeRouter | 168-171 | swapTokens zero edge case |
| P2-003 | P2 | SupportPool | 161 | buyback() oracle not try/catch |
| P2-004 | P2 | FeeVault | 124-131 | credit() not whenNotPaused |
| P2-005 | P2 | DividendDistributor | — | cancelUnclaimedEpoch pre-window |
| P2-006 | P2 | Pangu2TradeRouter | 138-140 | buy-tax denominator zero risk |
| P2-007 | P2 | FeeVault | 127-128 | invalid enum silently credited |
| P2-008 | P2 | FeeVault | 177-180 | no zero-quote check |
| P3-001 | P3 | BuybackLocker | — | no isolated tests |
| P3-002 | P3 | scripts/*.s.sol | — | console.log gas cost |
| P3-003 | P3 | Pangu2TradeRouter | 216 | expiresAt misleading |
| P3-004 | P3 | FeeVault | 147 | ZeroAddress error name |
| P3-005 | P3 | SupportPool | 22-23 | hardcoded buyback params |

---

## Final Verdict: **CONDITIONAL APPROVE**

The PANGU2 V2 contracts are ready for BSC Testnet deployment.

**Conditions for Testnet:**
1. P1-002 fix recommended (TradeRouter whitelist-aware preview) — one-line change
2. All P2 findings are non-blocking for testnet

**Conditions for Mainnet:**
1. All P1 findings resolved
2. P2-003, P2-005 resolved
3. BuybackLocker unit tests added (P3-001)
4. Separate mainnet-specific external audit

**Mainnet: NO-GO** pending mainnet audit.


---

## FILE: baselines/通用智能合约安全开发风险控制与漏洞治理规范 V1.0.md

# 通用智能合约安全开发、风险控制与漏洞治理规范 V1.0

> 文档类型：跨项目通用智能合约开发规则基线  
> 适用范围：Solidity / EVM智能合约、代币、金库、分红、回购、质押、预售、多签、治理、DEX适配、跨链、代理升级、工厂合约及相关链上系统  
> 文档状态：`SMART_CONTRACT_SECURITY_BASELINE_CANDIDATE`（智能合约安全基线候选）  
> 语言规范：中文优先；合约名、函数名、事件名、错误码、标准编号和机器状态码保留英文  
> 核心原则：资金安全优先、规范先于代码、不变量驱动、最小权限、多层防御、独立审核、可暂停但不可随意夺取用户资产  
> 主网部署：必须经过独立批准  
> 零风险声明：任何审计和测试都不能保证绝对零漏洞，本规范目标是系统性降低已知与可预见风险，并禁止未达到安全门槛的合约进入主网  

---

# 0. 中文优先与专业英文注释规则

## 0.1 显示原则

```text
面向人阅读
→ 中文优先

面向机器执行
→ 英文保持不变

专业术语
→ 中文名称（English）

机器状态
→ `ENGLISH_CODE`（中文含义）
```

## 0.2 不翻译内容

- Solidity合约名；
- 函数名；
- 事件名；
- Custom Error；
- Storage Slot；
- ABI字段；
- JSON / OpenAPI / Event Schema；
- EIP / ERC编号；
- Git Commit；
- Foundry命令；
- Slither检测器名称；
- Echidna属性名；
- 环境变量；
- 链ID、地址和交易哈希。

---

# 1. 规范目标

本规范用于确保智能合约开发同时满足：

1. 尽可能承接并实现现有合约已经可用的业务功能；
2. 不因重构、迁移或升级破坏既有经济模型和用户资产；
3. 对所有资金流、权限、升级和外部调用建立明确安全边界；
4. 在编码前定义可验证的不变量（Invariant）；
5. 在上线前完成自动化、人工和独立外部审核；
6. 在上线后具备监控、暂停、处置、迁移和复盘能力；
7. 对漏洞、风险、修复和残余风险建立统一记录；
8. 防止单点私钥、错误配置、业务逻辑和供应链漏洞造成资金损失；
9. 禁止以“已审计”“开源”或“测试通过”作为绝对安全承诺；
10. 保证任何高风险合约在证据不足时默认为`NO-GO`（禁止上线）。

---

# 2. 安全基本事实

必须接受以下事实：

```text
代码正确
≠
经济模型安全

单元测试通过
≠
不存在漏洞

静态分析无告警
≠
不存在漏洞

外部审计完成
≠
绝对安全

开源库成熟
≠
集成方式正确

管理员可信
≠
管理员密钥永不泄露

可升级
≠
一定比不可升级安全

不可升级
≠
一定更安全
```

智能合约的安全范围包括：

- 源代码；
- 编译器；
- 依赖；
- 部署脚本；
- 配置参数；
- 管理员和多签；
- 前端签名请求；
- 预言机；
- DEX和外部协议；
- 跨链消息；
- RPC和链环境；
- 经济模型；
- 升级流程；
- 监控和应急响应。

---

# 3. 安全保证等级

## 3.1 等级定义

| 等级 | 名称 | 适用场景 | 主网资金 |
|---|---|---|---|
| SC-L0 | 实验级 | 本地Demo、无真实资产 | 禁止 |
| SC-L1 | 测试级 | Testnet、受控POC | 禁止 |
| SC-L2 | 受限主网候选 | 小额、限额、可暂停、灰度 | 人工批准后有限开放 |
| SC-L3 | 正式资金级 | 正式协议和用户资产 | 必须完整审核 |
| SC-L4 | 高价值关键级 | 大额TVL、跨链、核心金库、升级控制 | 多轮外审、形式化验证候选、持续监控 |

## 3.2 默认要求

涉及以下能力时，最低要求为`SC-L3`：

- 用户存款；
- 代币铸造和销毁；
- 金库；
- 分红；
- 回购；
- 质押；
- 预售；
- 流动性管理；
- 多签；
- 升级；
- 跨链；
- 管理协议资金。

涉及以下能力时，最低要求为`SC-L4`：

- 跨链Bridge；
- 无上限铸造；
- 核心升级管理员；
- 可转移全部协议资产；
- 可修改核心经济模型；
- 可控制多个项目或多个代理合约；
- 高价值自动化执行；
- 外部预言机直接影响清算或资产兑换。

---

# 4. 智能合约安全生命周期

统一阶段：

```text
SC-A00 现有合约与资产盘点
→ SC-SPEC01 业务规格与不变量
→ SC-THREAT01 威胁建模
→ SC-ARCH01 安全架构
→ SC-DEP01 依赖与编译器冻结
→ SC-CODE01 安全编码
→ SC-TEST01 自动化测试
→ SC-ANALYSIS01 静态、模糊与形式化分析
→ SC-REVIEW01 内部独立审核
→ SC-AUDIT01 外部安全审计
→ SC-FIX01 漏洞修复与复审
→ SC-DEPLOY01 部署演练
→ SC-READY01 主网准入
→ SC-MONITOR01 上线监控
→ SC-UPGRADE01 升级治理
→ SC-IR01 事件响应与复盘
```

任何阶段不得通过口头确认替代证据。

---

# 5. SC-A00：现有合约与资产盘点

## 5.1 目标

在重构或新增合约前，确认现有合约：

- 有哪些功能；
- 管理哪些资产；
- 哪些地址已部署；
- 哪些功能正在使用；
- 哪些功能已被前端、后端和用户依赖；
- 哪些行为是历史兼容要求；
- 哪些风险已经存在；
- 哪些能力必须保留、重构、迁移或冻结。

## 5.2 合约能力矩阵

每个合约必须记录：

| 字段 | 说明 |
|---|---|
| Contract ID | 稳定合约编号 |
| Contract Name | 合约名称 |
| Deployment Address | 已部署地址 |
| Chain ID | 链编号 |
| Proxy Type | 代理类型 |
| Implementation | 实现地址 |
| Admin / Owner | 管理地址 |
| Assets Controlled | 控制资产 |
| Max Loss | 最大可能损失 |
| Functions | 功能清单 |
| Privileged Functions | 特权函数 |
| External Dependencies | 外部依赖 |
| Current Users | 当前使用方 |
| Existing Tests | 现有测试 |
| Audit Status | 审计状态 |
| Source Verification | 源码验证状态 |
| Engineering Status | 工程状态 |
| Treatment Status | 处理状态 |

## 5.3 工程状态

```text
IMPLEMENTED_VERIFIED
IMPLEMENTED_UNVERIFIED
PARTIAL
SECURITY_REMEDIATION
DEPRECATED
UNKNOWN_PENDING_EVIDENCE
```

## 5.4 处理状态

```text
KEEP_AS_IS
REFACTOR_IN_PLACE
MIGRATE
REPLACE
EXTRACT_LIBRARY
FREEZE
RETIRE_PENDING_HUMAN_APPROVAL
```

## 5.5 功能最大化原则

现有可用功能不得因为安全重构被无依据删除。

处理顺序：

```text
保留业务语义
→ 明确不变量
→ 修复实现风险
→ 增加权限和限额
→ 增加测试与监控
→ 再决定是否迁移或退役
```

只有满足以下条件，才能建议退役：

- 无法满足安全不变量；
- 维护成本明显高于重建；
- 依赖已停止维护；
- 与核心产品范围冲突；
- 存在无法隔离的系统性风险；
- 已有完整迁移和用户退出路径；
- 人工项目负责人批准。

---

# 6. SC-SPEC01：业务规格与不变量

## 6.1 规范先于代码

每个资金合约必须先定义：

- 资产来源；
- 资产去向；
- 所有余额；
- 所有费用；
- 所有角色；
- 状态机；
- 时间窗口；
- 上限和下限；
- 失败处理；
- 退款；
- 紧急退出；
- 升级；
- 退役。

不得先写代码再从代码反推业务规则。

## 6.2 不变量（Invariant）

不变量是任何合法调用序列后都必须成立的条件。

### 通用资金不变量

```text
合约实际资产
>=
所有用户可赎回资产合计
+
已确认但未领取负债
+
协议已计提负债
```

### 代币不变量

```text
totalSupply
=
所有账户余额总和
```

如存在销毁、桥接或特殊会计，应定义精确替代公式。

### 金库不变量

```text
totalAssets
>=
所有用户可赎回价值
```

### 分红不变量

```text
累计已分配
+
待领取
+
剩余分红池
<=
累计进入分红系统的可分配资产
```

### 回购不变量

```text
实际回购支出
<=
已批准回购预算
```

### 多签不变量

```text
执行签名数
>=
执行时有效阈值
```

### 权限不变量

```text
未经授权地址
永远不能执行特权操作
```

### 升级不变量

```text
升级后用户资产和负债
与升级前一致
除非有明确迁移规则
```

## 6.3 不变量要求

每个关键业务模块至少定义：

- 会计不变量；
- 权限不变量；
- 状态机不变量；
- 时间不变量；
- 上限不变量；
- 外部调用不变量；
- 升级不变量；
- 退出不变量。

---

# 7. SC-THREAT01：威胁建模

## 7.1 威胁角色

必须考虑：

- 普通恶意用户；
- 闪电贷攻击者；
- MEV搜索者；
- 区块构建者；
- 恶意Token；
- 恶意回调合约；
- 被盗管理员；
- 内部恶意管理员；
- 恶意升级者；
- 恶意预言机；
- 被攻击的外部协议；
- 恶意跨链消息；
- 前端钓鱼者；
- 供应链攻击者；
- RPC或数据提供商故障；
- 合约创建者配置错误。

## 7.2 信任边界

必须绘制：

- 用户；
- 前端；
- Desktop；
- 多签；
- Timelock；
- Proxy Admin；
- 合约；
- Token；
- DEX；
- Oracle；
- Bridge；
- Automation；
- Off-chain Worker；
- RPC；
- 外部API。

## 7.3 攻击路径

每个关键资产至少分析：

```text
资产被直接转走
资产被无限铸造
资产被错误记账
资产被永久锁定
资产被低价兑换
资产被重复领取
资产被抢先交易
资产被错误升级
资产被恶意暂停
资产无法恢复
```

---

# 8. 安全架构原则

## 8.1 最小可信面

- 合约数量不是越多越安全；
- 模块数量不是越多越安全；
- 核心资金路径应尽可能短；
- 每个外部依赖必须说明必要性；
- 不将通用管理权限扩展到所有合约；
- 不允许一个EOA控制全部系统。

## 8.2 模块化

建议分离：

- Token；
- Vault；
- Fee Router；
- Dividend Distributor；
- Buyback；
- Governance；
- Access Manager；
- Adapter；
- Treasury；
- Factory。

但不得为了模块化引入不必要的跨合约调用和复杂权限。

## 8.3 拉取优于推送

对批量分红、退款和奖励：

```text
优先 Pull Claim
而不是
循环 Push Transfer
```

避免单个失败接收者阻断全部用户。

## 8.4 状态与执行分离

高风险操作使用：

```text
Proposal
→ Validation
→ Delay
→ Approval
→ Execute
→ Receipt
```

不得在一个无审查函数中同时：

- 修改核心参数；
- 转移全部资产；
- 升级实现；
- 改变管理员。

---

# 9. 权限与管理员安全

## 9.1 禁止单EOA长期控制核心权限

核心角色应使用：

- 多签；
- 硬件钱包；
- Timelock；
- 分离的Guardian；
- 最小角色；
- 两步转移；
- 轮换和撤销。

## 9.2 角色分离

至少区分候选角色：

```text
DEFAULT_ADMIN
UPGRADER
PAUSER
UNPAUSER
TREASURY
FEE_MANAGER
ORACLE_MANAGER
OPERATOR
GUARDIAN
EMERGENCY_WITHDRAW
```

禁止把全部角色授予同一地址，除非Testnet临时使用且明确标记。

## 9.3 管理员矩阵

| 操作 | 建议控制 |
|---|---|
| 升级实现 | 多签 + Timelock |
| 修改费用 | 多签 + 延迟 + 上限 |
| 修改Oracle | 多签 + 延迟 + 健康校验 |
| 暂停 | Guardian可快速执行 |
| 解除暂停 | 多签或延迟执行 |
| 提取协议收入 | Treasury多签 |
| 提取用户资产 | 默认禁止 |
| 修改多签阈值 | 多签 + 延迟 |
| 迁移资产 | 专项Proposal + 用户退出期 |

## 9.4 所有权转移

必须使用：

- 两步转移；
- 接收方确认；
- 零地址检查；
- 合约地址能力检查；
- 事件；
- 可取消候选；
- 延迟候选。

禁止单步把核心所有权转给未经验证地址。

---

# 10. 紧急暂停与熔断

## 10.1 必须具备暂停能力的场景

- 用户存款；
- 用户兑换；
- 交易税；
- 自动回购；
- 外部DEX调用；
- Oracle依赖功能；
- 跨链；
- 升级；
- 大额资金操作。

## 10.2 暂停粒度

优先：

```text
按功能暂停
而不是
全协议永久暂停
```

必须明确：

- 暂停哪些功能；
- 是否允许用户退出；
- 是否允许领取已确认权益；
- 是否允许管理员转移资产；
- 谁可暂停；
- 谁可解除；
- 最长暂停时间；
- 审计事件。

## 10.3 安全退出优先

出现事故时，应优先保留：

- 用户赎回；
- 已确认奖励领取；
- 紧急退出；
- 退款；
- 审计查询。

除非这些路径本身已被攻击。

---

# 11. 外部调用与重入

## 11.1 Checks-Effects-Interactions

资金函数优先遵循：

```text
检查
→ 更新内部状态
→ 外部交互
```

## 11.2 ReentrancyGuard

适用于：

- 提款；
- Claim；
- Swap；
- 流动性；
- 回购；
- 回调；
- 外部Token转移后继续修改状态。

不得认为使用`nonReentrant`即可自动解决所有重入。

必须同时检查：

- 跨函数重入；
- 跨合约重入；
- 只读重入；
- ERC777 Hook；
- ERC721 / ERC1155安全接收回调；
- DEX回调；
- Flash Loan回调。

## 11.3 低级调用

使用`call`时必须：

- 检查`success`；
- 检查返回数据长度；
- 解码前验证；
- 不吞掉Revert；
- 限制目标地址；
- 限制可调用Selector；
- 记录事件；
- 考虑Gas Griefing。

## 11.4 `delegatecall`

默认禁止。

只有代理或经过专项审核的插件架构允许使用。

必须验证：

- 目标实现；
- Code Hash候选；
- Storage Layout；
- 权限；
- 不允许任意地址；
- 不允许用户控制Calldata到任意实现；
- 升级事件；
- 监控。

---

# 12. Token兼容与异常Token

不得假设所有ERC-20行为一致。

必须测试：

- 标准Token；
- 不返回`bool`；
- 返回`false`；
- Fee-on-Transfer；
- Rebase；
- ERC777 Hook；
- Blacklist；
- Pausable Token；
- Permit；
- 非18位Decimals；
- Transfer会Revert；
- Transfer到自身；
- 零金额；
- 极端供应量。

使用经过审核的SafeERC20类工具。

## 12.1 会计原则

实际到账金额必须使用：

```text
balanceAfter - balanceBefore
```

适用于不可信或可能扣税Token。

## 12.2 Allowance

必须考虑：

- Allowance Race；
- 无限授权；
- 授权目标升级；
- 授权回收；
- Permit Replay；
- Deadline；
- Nonce；
- Chain ID；
- Verifying Contract。

---

# 13. 签名安全

## 13.1 EIP-712

结构化签名必须包含候选字段：

- `name`；
- `version`；
- `chainId`；
- `verifyingContract`；
- 业务类型Hash；
- Signer；
- Nonce；
- Deadline；
- 目标资产；
- 数量；
- 接收地址；
- 关键参数Hash。

## 13.2 防重放

必须同时考虑：

- 同合约重放；
- 跨合约重放；
- 跨链重放；
- 跨版本重放；
- 同一用户Nonce；
- 批次Nonce；
- 撤销Nonce；
- Signature Expiration；
- Idempotency。

EIP-712本身不自动提供完整重放保护，业务合约必须实现Nonce和过期机制。

## 13.3 合约钱包签名

支持合约钱包时，应评估ERC-1271。

不得只使用`ecrecover`判断所有签名者。

## 13.4 签名展示

用户签名前必须展示：

- Chain；
- Contract；
- Action；
- Token；
- Amount；
- Recipient；
- Deadline；
- Fee；
- Nonce；
- 可撤销性。

---

# 14. 预言机与价格安全

## 14.1 禁止直接使用低流动性现货价

关键价格不得只依赖：

- 单池Spot Price；
- 单区块储备；
- 用户可瞬时操纵的价格；
- 未验证外部返回值。

## 14.2 预言机校验

必须检查：

- 地址；
- Chain；
- Decimals；
- 返回值正负；
- 更新时间；
- Staleness；
- Round完整性；
- Heartbeat；
- Deviation；
- Min / Max；
- 数据源暂停；
- Fallback；
- 价格变化上限；
- 业务熔断。

## 14.3 TWAP

使用TWAP时必须定义：

- 时间窗口；
- Observation数量；
- 流动性下限；
- 池地址；
- Token顺序；
- Decimals；
- 操纵成本；
- 更新频率；
- 异常回退。

## 14.4 管理员Oracle

管理员直接写价格默认禁止。

如必须使用：

- 多签；
- Timelock；
- 变化上限；
- 生效延迟；
- 双重确认；
- 事件；
- 紧急回退；
- 用户退出期。

---

# 15. MEV、抢跑和交易顺序

必须评估：

- Front-running；
- Back-running；
- Sandwich；
- Transaction Order Dependence；
- Liquidation抢跑；
- Claim抢跑；
- Signature抢跑；
- 创建地址抢占；
- Governance Proposal抢跑。

## 15.1 Swap保护

必须包含：

- `amountOutMin`；
- `amountInMax`；
- `deadline`；
- 合理滑点；
- 路径验证；
- 接收地址；
- Price Impact上限；
- Pool流动性检查。

禁止设置：

```text
amountOutMin = 0
```

作为生产默认值。

## 15.2 Commit-Reveal

用于：

- 高价值竞价；
- 随机选择；
- 防抢跑参数；
- 敏感治理提案。

必须处理：

- Reveal超时；
- 未Reveal；
- Deposit；
- 重复Commit；
- Griefing。

---

# 16. 随机性

禁止使用以下方式生成高价值随机数：

- `block.timestamp`；
- `block.number`；
- `blockhash`；
- `block.prevrandao`单独使用；
- 用户可控输入Hash；
- 区块字段简单组合。

高价值随机性应使用可验证随机函数（VRF）或经过专项设计的Commit-Reveal。

必须处理：

- Request ID；
- Callback权限；
- 重复回调；
- 超时；
- 重试；
- Callback Gas；
- 失败恢复；
- 随机结果使用顺序。

---

# 17. 数学、精度与舍入

## 17.1 固定点数学

必须定义：

- 精度基数；
- Token Decimals；
- Oracle Decimals；
- 内部计算Decimals；
- 乘除顺序；
- 舍入方向；
- 最大值；
- 最小值；
- 溢出；
- 下溢；
- Downcast。

## 17.2 金融舍入

必须明确：

- 对用户有利还是对协议有利；
- Deposit；
- Withdraw；
- Mint；
- Redeem；
- Fee；
- Dividend；
- Share；
- Exchange Rate。

禁止不同路径使用不一致舍入方向。

## 17.3 先乘后除

在不溢出的前提下优先：

```text
a * b / c
```

避免：

```text
a / c * b
```

造成精度损失。

高精度运算应使用经过审核的`mulDiv`类实现。

## 17.4 Downcast

所有窄化转换必须：

- 显式；
- 检查范围；
- 使用SafeCast候选；
- 编写边界测试。

---

# 18. 循环、Gas与拒绝服务

禁止对无界用户集合执行链上循环。

高风险场景：

- 遍历全部Holder；
- 批量分红所有用户；
- 批量退款全部用户；
- 清理无限队列；
- 对数组每项进行外部调用；
- 用户可无限增长列表。

替代方式：

- Pull Claim；
- Pagination；
- Bounded Batch；
- Checkpoint；
- Merkle Claim；
- Off-chain计算 + On-chain验证；
- Queue上限；
- 可恢复Cursor。

必须测试最坏Gas，而不是平均Gas。

---

# 19. DeFi与闪电贷风险

闪电贷通常不是根本漏洞，而是放大器。

必须假设攻击者可以在单交易中获得巨量流动性。

重点验证：

- 价格；
- 份额；
- 治理投票；
- 奖励；
- 存款后立即提取；
- LP价格；
- 抵押率；
- 清算；
- 费率；
- Snapshot；
- 首次存款；
- 资产捐赠；
- 交易路径。

不得用“攻击者没有那么多钱”作为安全假设。

---

# 20. Vault与ERC-4626类风险

必须防止：

- 首次存款操纵；
- Donation / Share Inflation；
- 份额精度不足；
- 资产与份额舍入错误；
- Total Assets统计遗漏；
- Fee-on-Transfer误记账；
- Rebase漂移；
- Withdraw Queue阻断；
- 直接转入资产导致会计变化；
- 资产损失未反映；
- Preview函数与实际执行不一致。

必须定义：

```text
previewDeposit
previewMint
previewWithdraw
previewRedeem
```

与实际路径的误差和舍入关系。

---

# 21. 税收、分红与回购合约

## 21.1 税收

必须定义：

- 买入税；
- 卖出税；
- 转账税；
- 税率上限；
- 税率变化延迟；
- 豁免地址；
- DEX识别；
- Router和Pair更新；
- 税收去向；
- 累计会计；
- 事件。

禁止：

- 管理员无限税率；
- 无延迟把税率改为极端值；
- 隐藏税率；
- Preview与执行不一致；
- 通过错误Pair识别对普通转账征税。

## 21.2 分红

必须处理：

- 排名Snapshot；
- 重复领取；
- 资格变化；
- 排除地址；
- 分母为零；
- 精度；
- 未领取余额；
- 分红Token异常；
- 分配总额上限；
- Claim失败不阻断其他用户。

## 21.3 回购

必须定义：

- 预算；
- 单次上限；
- 时间间隔；
- 滑点；
- Deadline；
- Router；
- Path；
- Price Impact；
- 最小流动性；
- 失败处理；
- 是否销毁；
- 回购资产去向；
- 暂停。

禁止无人值守私钥自动签名。

如使用Automation，合约仍必须在链上验证所有上限和条件。

---

# 22. 质押与奖励

必须验证：

- 奖励来源；
- 奖励总预算；
- Reward Rate；
- Accumulator精度；
- Deposit时间；
- Withdraw时间；
- Emergency Withdraw；
- 多次存取；
- 同区块操作；
- 未领取奖励；
- 奖励不足；
- 结束时间；
- 管理员回收；
- Fee-on-Transfer质押Token；
- Reward Token等于Stake Token；
- Reentrancy；
- Flash Stake。

核心不变量：

```text
累计发放奖励
<=
实际可用奖励预算
```

---

# 23. 预售与募资

必须定义：

- 硬顶；
- 软顶；
- 单地址上限；
- 总上限；
- 时间窗口；
- 白名单；
- 价格；
- 领取；
- 退款；
- 超募；
- 资金归属；
- 流动性；
- 未售Token；
- 管理员提现条件；
- 紧急取消。

资金在成功条件未达成前不得被项目方提走。

退款应采用Pull模式。

---

# 24. DEX和流动性适配器

适配器必须：

- 固定或白名单Router；
- 验证Factory；
- 验证Pair或Pool；
- 验证Token顺序；
- 验证Fee Tier；
- 验证Deadline；
- 验证最小输出；
- 使用实际余额差；
- 处理Refund；
- 处理原生Token包装；
- 限制Approval；
- 防止任意Calldata；
- 防止任意目标调用。

不得让普通用户通过Adapter执行任意外部调用。

---

# 25. 多签、治理与Timelock

## 25.1 多签

必须验证：

- 成员唯一；
- 阈值合法；
- 阈值不为零；
- 阈值不超过成员数；
- 成员添加和删除；
- 阈值变更；
- Nonce；
- Operation Hash；
- Chain ID；
- Contract Address；
- Signature排序候选；
- 重复签名；
- 合约钱包签名；
- 执行失败和重试；
- 取消；
- 过期。

## 25.2 Timelock

关键操作应有延迟：

- 升级；
- 税率；
- Oracle；
- Treasury；
- Mint权限；
- Router；
- 多签配置；
- 用户资金迁移。

紧急暂停可以快速，但解除暂停和升级应更严格。

## 25.3 治理攻击

必须考虑：

- Flash Loan投票；
- Quorum不足；
- Proposal重放；
- Queue碰撞；
- Execution Gas；
- 恶意提案；
- Guardian拒绝服务；
- 治理私钥泄露。

---

# 26. 可升级合约

## 26.1 默认原则

默认优先选择不可升级合约。

只有满足以下条件才使用代理：

- 业务确实需要修复或演进；
- 用户理解升级权限；
- 升级治理安全；
- Storage Layout可验证；
- 有Timelock；
- 有回滚或迁移策略；
- 有升级监控；
- 有独立审核。

## 26.2 初始化

必须：

- 使用Initializer；
- 防止重复初始化；
- 初始化所有父合约；
- 实现合约构造函数调用`_disableInitializers()`候选；
- 部署Proxy时原子初始化；
- 不留下未初始化窗口；
- 测试Front-running初始化。

## 26.3 Storage Layout

禁止：

- 改变既有变量类型；
- 改变变量顺序；
- 在旧变量前插入变量；
- 删除旧变量；
- 不安全改变继承顺序；
- Storage Slot冲突。

可采用：

- OpenZeppelin升级校验；
- ERC-7201命名空间存储；
- Storage Gap；
- Storage Layout Diff；
- Fork Upgrade Test。

## 26.4 UUPS

必须：

- `_authorizeUpgrade`正确限制；
- 升级权限归多签和Timelock；
- 不允许任意实现；
- 检查新实现代码；
- 检查Proxiable UUID候选；
- 监控`Upgraded`；
- 实现升级前后不变量测试。

## 26.5 Transparent Proxy

必须区分：

- Proxy Admin；
- Logic Owner；
- Protocol Admin。

不得使用同一个私钥控制所有权限。

## 26.6 禁止危险操作

升级实现默认禁止：

- `selfdestruct`；
- 任意`delegatecall`；
- 任意Storage写入；
- 未经验证的插件。

---

# 27. Factory、CREATE2与Clone

必须验证：

- Implementation地址；
- Initialization Data；
- Salt；
- 地址预测；
- 重复部署；
- Frontrunning；
- 初始化权限；
- Clone未初始化；
- Factory管理员；
- Template版本；
- Code Hash；
- 部署事件；
- 每个实例配置。

不得仅通过地址预测认为部署一定安全。

---

# 28. 跨链与Bridge

跨链合约最低`SC-L4`。

必须验证：

- 来源链；
- 目标链；
- 来源合约；
- 目标合约；
- Message ID；
- Lane；
- Nonce；
- Replay；
- Finality；
- Reorg；
- Proof；
- Relayer；
- Validator；
- Rate Limit；
- Daily Cap；
- Token Decimals；
- Mint / Burn；
- Lock / Release；
- Message Size；
- Gas；
- Retry；
- Failed Message；
- Emergency Pause；
- Chain Split。

不得仅相信`msg.sender`为Router就接受任意来源消息。

---

# 29. Inline Assembly与底层优化

默认禁止使用Assembly进行普通业务逻辑。

允许条件：

- 明确性能收益；
- 无安全替代方案；
- 内存安全说明；
- Storage Slot说明；
- 单独测试；
- 静态分析；
- 人工逐行审核；
- 外部审计。

必须检查：

- Free Memory Pointer；
- Return Data；
- Calldata Length；
- Overwrite；
- Dirty Bits；
- Stack；
- ABI Encoding；
- Storage Collision。

---

# 30. 编译器、依赖与供应链

## 30.1 编译器

必须：

- 固定精确Solidity版本；
- 检查该版本Known Bugs；
- 固定Optimizer；
- 固定Runs；
- 固定EVM Version；
- 固定via-IR设置；
- 开发、CI、审计和部署一致；
- 保存Standard JSON Input；
- 保存Build Info；
- 保存Bytecode Hash。

## 30.2 依赖

必须：

- 使用官方发布版本；
- 固定Tag或Commit；
- 记录License；
- 记录Upstream；
- 记录本地修改；
- 生成SBOM；
- 扫描CVE和安全公告；
- 禁止直接复制未知来源代码；
- 禁止自动升级主版本；
- 对升级版本重新测试和审核。

OpenZeppelin等成熟库也必须审核集成方式。

## 30.3 包管理

禁止：

- 浮动Git分支；
- 未锁定Commit；
- 未审查Submodule；
- 来源不明的压缩包；
- 从聊天内容直接复制安全核心代码；
- 审计后自动更新依赖。

---

# 31. 安全编码规则

必须：

- 固定Pragma；
- 显式可见性；
- 显式Mutability；
- Custom Error候选；
- NatSpec；
- Named Imports；
- Zero Address检查；
- Contract Address校验；
- 输入上限；
- 数组长度校验；
- Deadline；
- Slippage；
- Return Value；
- Event；
- Role检查；
- 状态检查；
- Nonce；
- Idempotency。

禁止：

- `tx.origin`授权；
- 不受控`delegatecall`；
- 不受控`selfdestruct`；
- 任意外部目标；
- 任意函数Selector；
- 无限循环；
- 隐藏管理员后门；
- 无上限Mint；
- 管理员随意提取用户资产；
- 生产代码中的测试后门；
- 未说明的特殊地址；
- 无事件的关键参数修改；
- 忽略外部调用返回值；
- 依赖`private`保存秘密。

---

# 32. 事件与可观测性

关键状态变化必须Emit事件：

- Ownership；
- Role；
- Upgrade；
- Pause；
- Unpause；
- Fee；
- Oracle；
- Router；
- Treasury；
- Mint；
- Burn；
- Deposit；
- Withdraw；
- Claim；
- Buyback；
- Dividend；
- Migration；
- Emergency；
- Governance。

事件必须包含足够索引字段，但不得泄露不应存在的秘密。

关键状态不得只通过事件保存，除非业务明确使用Event作为事实源且可接受链上读取方式。

---

# 33. 测试基线

## 33.1 单元测试

每个函数测试：

- 正常路径；
- Revert路径；
- 零值；
- 最大值；
- 边界值；
- 重复调用；
- 无权限；
- 状态错误；
- 时间边界；
- 恶意Token；
- 恶意接收者。

## 33.2 模糊测试（Fuzz Testing）

对以下输入使用Fuzz：

- 数量；
- 地址；
- 时间；
- 费用；
- 阈值；
- 数组；
- Signature；
- Token Decimals；
- 状态序列。

必须保存和重放Counterexample。

## 33.3 状态不变量测试

必须使用随机多调用序列验证：

- 资产守恒；
- 总供应量；
- 负债覆盖；
- 权限；
- 不重复领取；
- 预算上限；
- 退出可用；
- 升级兼容；
- 暂停状态；
- 多角色交互。

Foundry的Invariant测试应使用Handler、Ghost Variable和多Actor，避免因大量Revert造成“假通过”。

## 33.4 Fork测试

必须在接近真实环境中验证：

- 实际Token；
- 实际Router；
- 实际Pair / Pool；
- 实际Oracle；
- Proxy；
- 历史区块；
- Token异常行为；
- Gas；
- Reorg候选。

Fork测试不等于主网安全批准。

## 33.5 差分测试

对：

- 旧版和新版；
- Reference Model和合约；
- Preview和Execute；
- 自研数学和成熟库；

进行差分验证。

## 33.6 Mutation Testing

建议对SC-L3及以上执行变异测试，确认测试能发现：

- 删除权限检查；
- 改变比较符；
- 改变舍入；
- 删除事件；
- 忽略返回值；
- 改变费用；
- 移除Reentrancy保护。

## 33.7 覆盖率

覆盖率是辅助指标，不是安全证明。

必须关注：

- 分支覆盖；
- 错误路径；
- 状态组合；
- 权限矩阵；
- 不变量；
- 外部交互。

---

# 34. 自动化安全工具

最低工具候选：

- Foundry；
- Slither；
- Echidna；
- OpenZeppelin Upgrade Validation；
- ERC Conformance；
- Gas Snapshot；
- Coverage；
- Dependency Scan；
- Secret Scan。

高风险项目候选：

- Symbolic Execution；
- Formal Verification；
- Mutation Testing；
- Differential Fuzzing；
- Upgrade Diff Fuzzing。

## 34.1 工具限制

任何工具结果必须人工解释。

禁止：

- 自动忽略全部False Positive；
- 因工具无告警判定安全；
- 未保存工具版本和配置；
- 使用不同编译设置分析；
- 只分析单个合约不分析系统。

---

# 35. CI安全门控

每个Commit或Pull Request至少运行：

```text
forge fmt --check
forge lint
forge build
forge test
forge test --fuzz-runs <approved>
forge test --match-contract <InvariantSuite>
slither .
dependency scan
secret scan
```

具体命令和参数由项目冻结，不在本规范中写死。

CI必须阻断：

- 编译失败；
- 测试失败；
- 不变量失败；
- 新增高危静态告警；
- 未批准依赖；
- Storage Layout不兼容；
- 未固定编译器；
- Secret进入仓库；
- 部署Bytecode与审计版本不一致。

---

# 36. 内部代码审核

## 36.1 独立性

智能合约变更至少由：

- 实现开发者；
- 独立安全审核者；

分别完成。

SC-L3及以上建议至少两名独立审核者。

执行Agent不得批准自己。

## 36.2 审核顺序

```text
规格
→ 不变量
→ 资金流
→ 权限
→ 状态机
→ 外部调用
→ 数学
→ 升级
→ 测试
→ 部署
```

不得只逐行看代码而不审核业务逻辑。

---

# 37. 外部安全审计

## 37.1 审计前冻结

必须固定：

- Commit；
- Compiler；
- Config；
- Dependencies；
- Chain；
- Scope；
- Deployment Architecture；
- Privileged Roles；
- Invariants；
- Known Risks；
- Test Results。

## 37.2 审计范围

必须包含：

- 核心合约；
- Libraries；
- Proxy；
- Upgrade Scripts；
- Deployment Scripts；
- Access；
- Oracle；
- Adapters；
- Economic Model；
- Integration Assumptions；
- Existing Deployments候选。

## 37.3 审计后变更

审计后任何影响行为的变更必须：

- 记录Diff；
- 重新测试；
- 安全审核；
- 必要时复审。

禁止使用审计旧Commit部署新Bytecode。

## 37.4 审计轮次

建议：

| 风险等级 | 外部审核 |
|---|---|
| SC-L2 | 至少一次专项复核 |
| SC-L3 | 至少一次完整独立审计 |
| SC-L4 | 两家独立审计候选 + 形式化验证候选 + Bug Bounty |

---

# 38. 漏洞分类体系

漏洞应同时映射：

- OWASP Smart Contract Top 10；
- OWASP SCWE；
- OWASP SCSVS控制；
- CWE候选；
- 项目内部VULN ID。

## 38.1 主要漏洞类别

### A. 权限和治理

- 缺少权限检查；
- 权限混淆；
- 单EOA；
- 初始化接管；
- 升级接管；
- Timelock缺失；
- 管理员任意提取；
- Guardian滥用。

### B. 业务逻辑

- 会计错误；
- 重复领取；
- 错误状态转换；
- 不正确经济模型；
- 退款错误；
- 上限绕过；
- 排名或资格操纵。

### C. 预言机和市场

- Spot Price操纵；
- Stale Price；
- Decimal错误；
- 低流动性；
- TWAP不足；
- Oracle管理员操纵。

### D. 外部调用

- Reentrancy；
- Unchecked Call；
- Callback；
- ERC777 Hook；
- Arbitrary Call；
- Delegatecall；
- Return Data。

### E. 数学

- Overflow / Underflow；
- Downcast；
- Precision；
- Rounding；
- Division by Zero；
- Fee累计；
- Share Inflation。

### F. MEV和顺序

- Front-running；
- Sandwich；
- Signature抢跑；
- Transaction Order Dependence；
- Slippage缺失；
- Deadline缺失。

### G. 升级和代理

- Storage Collision；
- Uninitialized Implementation；
- Unauthorized Upgrade；
- Function Selector Collision；
- Unsafe Layout；
- Proxy Admin混淆。

### H. Gas和DoS

- 无界循环；
- Block Gas；
- Push Payment；
- 恶意接收者；
- Queue膨胀；
- Gas Griefing。

### I. 密码学和签名

- Replay；
- Domain错误；
- Nonce；
- Deadline；
- Signature Malleability；
- 错误Hash；
- 弱随机数。

### J. 跨链

- Message Replay；
- 来源验证；
- Proof验证；
- Decimals；
- Chain ID；
- Finality；
- Rate Limit；
- Failed Message。

### K. 供应链和部署

- 依赖污染；
- 编译器Bug；
- 配置错误；
- 错误地址；
- 错误Chain；
- 未验证源码；
- 审计Bytecode不一致；
- 私钥泄露。

---

# 39. 漏洞严重度

## 39.1 P0 致命

包括：

- 可直接盗取用户或协议资金；
- 无限铸造；
- 任意升级接管；
- 任意管理员接管；
- 私钥或Secret泄露；
- 可永久锁死主要资产；
- 跨链无限Mint；
- 无需权限提取金库；
- 可在生产立即利用的供应链恶意代码。

处理：

```text
立即停止部署或暂停受影响功能
→ 启动事件响应
→ 不公开可利用细节
→ 修复
→ 独立复审
→ 人工批准恢复
```

## 39.2 P1 高危

包括：

- 在可实现条件下造成重大资金损失；
- 高权限配置错误；
- Oracle操纵；
- 重入；
- 重复领取；
- 会计严重失衡；
- Storage Layout破坏；
- 无延迟核心参数修改；
- 关键签名重放。

P1未关闭不得主网部署。

## 39.3 P2 中危

包括：

- 有限损失；
- 特定条件DoS；
- 部分用户资产暂时不可用；
- 受限权限绕过；
- 低概率经济攻击；
- 缺少监控和事件；
- Gas问题；
- 安全降级。

P2必须修复，或由人工明确接受并设置补偿控制。

## 39.4 P3 低危

包括：

- 代码质量；
- 可维护性；
- 非关键Gas；
- 文档；
- 事件索引；
- 低影响边界问题。

## 39.5 INFO

- 最佳实践；
- 架构建议；
- 无直接安全影响的改进。

---

# 40. 漏洞登记规范

每个漏洞必须记录：

```text
Vulnerability ID
Title
Severity
Status
Source
Reporter
Affected Contract
Affected Function
Affected Commit
Affected Deployment
Asset at Risk
Maximum Loss
Weakness Category
OWASP SCWE
OWASP Top 10
CWE
Preconditions
Attack Path
Proof of Concept
Observed Impact
Potential Impact
Exploitability
Detection Method
Root Cause
Fix Commit
Fix Description
Regression Test
Invariant Added
Audit Review
Residual Risk
Disclosure Status
Owner
Due Date
Closed At
```

## 40.1 状态

```text
NEW
TRIAGED
CONFIRMED
DISPUTED
FIX_IN_PROGRESS
FIX_READY
RETESTING
RESOLVED
RISK_ACCEPTED
DUPLICATE
NOT_APPLICABLE
REOPENED
DISCLOSED
```

## 40.2 关闭条件

漏洞不得仅凭“代码已改”关闭。

必须同时有：

- Fix Commit；
- Regression Test；
- 原PoC不再成功；
- 不变量补充；
- 静态和动态工具复测；
- 独立审核；
- 残余风险记录；
- 受影响部署处置；
- 人工关闭。

---

# 41. 风险登记规范

风险与漏洞不同。

风险可能来自：

- 中心化；
- 管理员；
- Oracle；
- 流动性；
- 外部协议；
- 升级；
- 经济模型；
- 用户误操作；
- 链故障；
- 监管；
- 停止服务。

每个风险记录：

```text
Risk ID
Description
Asset
Likelihood
Impact
Risk Score
Existing Controls
Required Controls
Residual Risk
Risk Owner
Decision Owner
Review Date
Status
```

风险状态：

```text
OPEN
MITIGATING
MONITORING
ACCEPTED
TRANSFERRED
AVOIDED
CLOSED
```

---

# 42. 部署安全

## 42.1 部署脚本

必须：

- 可重复；
- 版本控制；
- 无手工临时步骤；
- 验证Chain ID；
- 验证Deployer；
- 验证Nonce候选；
- 验证地址；
- 验证余额；
- 原子初始化；
- 输出Manifest；
- 输出Bytecode Hash；
- 输出配置；
- 输出角色；
- 输出交易哈希。

## 42.2 部署前模拟

必须执行：

- Local；
- Anvil；
- Testnet；
- Fork；
- Dry Run；
- Gas；
- Role；
- Upgrade；
- Pause；
- Exit；
- Failure；
- Rollback候选。

## 42.3 部署后检查

必须：

- Source Verification；
- Bytecode匹配；
- Constructor / Initializer参数；
- Proxy和Implementation；
- Storage Slot；
- Owner；
- Roles；
- Timelock；
- Multisig；
- Paused状态；
- Cap；
- Fee；
- Oracle；
- Router；
- Treasury；
- Allowance；
- Event；
- Frontend配置。

---

# 43. 主网灰度

高价值系统不得一次性开放全部资金能力。

建议：

```text
部署
→ 暂停或受限模式
→ 小额Canary
→ 内部测试
→ 限额开放
→ 观察
→ 分阶段提高上限
```

必须预设：

- 单交易上限；
- 单日上限；
- 总TVL上限；
- 地址上限；
- Rate Limit；
- Emergency Pause；
- 用户退出。

上限提高需要人工Decision和链上事件。

---

# 44. 上线监控

必须监控：

- 大额转账；
- 余额变化；
- 总负债；
- 资产覆盖率；
- Mint / Burn；
- Fee变化；
- Role变化；
- Owner变化；
- Upgrade；
- Proxy Slot；
- Pause；
- Oracle Stale；
- Price Deviation；
- Liquidity；
- 回购；
- 分红；
- 异常Claim；
- 异常Gas；
- Failed Transaction；
- Bridge消息；
- 合约余额不变量。

监控不能只依赖前端。

---

# 45. 事件响应

## 45.1 事件等级

```text
SEV-0 资产正在被盗或权限已接管
SEV-1 高概率重大损失
SEV-2 功能异常或有限损失
SEV-3 低影响异常
```

## 45.2 SEV-0流程

```text
确认攻击
→ 暂停受影响功能
→ 保护剩余资产
→ 撤销权限和Allowance候选
→ 通知多签和安全负责人
→ 固定链上证据
→ 分析攻击路径
→ 准备修复或迁移
→ 外部复核
→ 用户沟通
→ 人工批准恢复
```

不得：

- 为隐藏问题删除证据；
- 未确认就公开攻击细节；
- 使用未经测试的紧急升级；
- 私自转移用户资产；
- 由单一人员决定恢复。

---

# 46. 升级与迁移

每次升级必须提供：

- Upgrade Proposal；
- 旧Commit；
- 新Commit；
- Diff；
- Storage Layout；
- 权限变化；
- 资金影响；
- 不变量；
- Tests；
- Slither；
- Fuzz；
- Invariant；
- Fork；
- Audit；
- Timelock；
- Rollback / Migration；
- Monitoring；
- Human Approval。

升级不得只因为“增加功能”而跳过安全流程。

---

# 47. Bug Bounty与负责任披露

SC-L3及以上上线后应建立：

- Security Contact；
- `security.txt`候选；
- 报告渠道；
- 加密通信；
- Safe Harbor候选；
- Severity；
- 奖励规则；
- 禁止公开利用；
- 修复时间；
- Disclosure时间；
- 重复报告规则。

任何奖励范围不能鼓励攻击真实用户资产。

---

# 48. 文档与NatSpec

每个公开函数必须说明：

- 功能；
- 权限；
- 参数；
- 返回值；
- Revert；
- 事件；
- 资产变化；
- 外部调用；
- 安全假设。

每个特权函数必须注明：

```text
SECURITY CRITICAL
```

每个管理员参数必须说明：

- 范围；
- 默认值；
- 最大值；
- 生效延迟；
- 风险。

---

# 49. 合约类型专项清单

## 49.1 ERC-20 / 税收Token

- Supply Cap；
- Mint；
- Burn；
- Tax；
- Exempt；
- Pair识别；
- Router；
- Blacklist；
- Pause；
- Permit；
- Allowance；
- MaxTx / MaxWallet；
- Ownership；
- Renounce影响；
- Event；
- DEX兼容。

## 49.2 Dividend

- 资金来源；
- Snapshot；
- 排名；
- 权重；
- Claim；
- 重复领取；
- Token异常；
- Dust；
- 未领取；
- 管理员回收；
- 总额守恒。

## 49.3 Buyback

- Budget；
- Interval；
- Slippage；
- Deadline；
- Path；
- Price Impact；
- Max Amount；
- Failure；
- Burn / Treasury；
- Automation权限。

## 49.4 Staking

- Stake；
- Unstake；
- Emergency；
- Reward Budget；
- Accumulator；
- End Time；
- Flash Stake；
- Fee Token；
- Reentrancy。

## 49.5 Vault

- Asset；
- Share；
- Donation；
- Inflation；
- Preview；
- Rounding；
- Debt；
- Strategy；
- Emergency Exit；
- Loss；
- Fee。

## 49.6 Presale

- Cap；
- Time；
- Refund；
- Claim；
- Oversubscription；
- Treasury；
- LP；
- Cancel；
- Unsold Token。

## 49.7 Multisig

- Members；
- Threshold；
- Nonce；
- Hash；
- Replay；
- Expiry；
- Contract Signature；
- Batch；
- Cancel；
- Failed Execution。

## 49.8 Proxy

- Initializer；
- Disable Initializers；
- Upgrade Auth；
- Storage；
- Admin；
- Timelock；
- Event；
- Implementation Verification。

## 49.9 Factory

- Template；
- Version；
- Salt；
- Initialize；
- Fee；
- Registry；
- Ownership；
- Instance Verification。

## 49.10 Bridge

- Source；
- Destination；
- Nonce；
- Replay；
- Finality；
- Rate Limit；
- Token Mapping；
- Decimals；
- Failed Message；
- Pause。

---

# 50. 开发禁止清单

以下任一项存在时，默认`NO-GO`：

- 核心资金函数无不变量；
- 单EOA控制全部资金和升级；
- 管理员可无条件提取用户资产；
- 无上限Mint；
- 无权限Upgrade；
- Proxy未初始化；
- Implementation未锁定；
- Storage Layout未验证；
- Oracle无Stale检查；
- Swap无Slippage和Deadline；
- 任意外部Call；
- 任意Delegatecall；
- 无界循环处理用户；
- 分红Push全部用户；
- 签名无Nonce或Deadline；
- 跨链无Replay保护；
- 高价值随机数使用区块字段；
- 编译器浮动；
- 依赖未固定；
- 审计Commit与部署Commit不一致；
- 主网私钥存在于代码、`.env`提交或普通服务器；
- P0 / P1未关闭；
- 外部审计范围不包含部署代码；
- 没有紧急响应负责人；
- 没有用户退出路径；
- 业务规则和实际代码不一致。

---

# 51. SC-READY01主网硬门控

必须同时满足：

```text
SPECIFICATION = FROZEN
ASSET_INVENTORY = ACCEPTED
THREAT_MODEL = ACCEPTED
INVARIANTS = IMPLEMENTED_AND_TESTED
ARCHITECTURE = APPROVED
COMPILER = PINNED
DEPENDENCIES = APPROVED
SBOM = GENERATED
UNIT_TESTS = PASS
FUZZ_TESTS = PASS
INVARIANT_TESTS = PASS
FORK_TESTS = PASS
STATIC_ANALYSIS = REVIEWED
UPGRADE_VALIDATION = PASS_OR_NOT_APPLICABLE
INTERNAL_REVIEW = APPROVED
EXTERNAL_AUDIT = APPROVED
P0_OPEN = 0
P1_OPEN = 0
P2_OPEN = 0_OR_HUMAN_ACCEPTED
DEPLOYMENT_REHEARSAL = PASS
SOURCE_VERIFICATION_PLAN = READY
MULTISIG = READY
TIMELOCK = READY_OR_JUSTIFIED
MONITORING = READY
INCIDENT_RESPONSE = READY
BUG_BOUNTY = READY_OR_JUSTIFIED
HUMAN_APPROVAL = YES
```

以下状态不得主网上线：

```text
APPROVED_WITH_CONDITIONS
UNDER_REVIEW
PARTIAL
PENDING
BLOCKED
UNKNOWN
```

---

# 52. Stage Exit证据

每个阶段退出必须记录：

```text
Stage ID
Scope
Fixed Commit
Compiler
Dependencies
Files
Tests
Commands
Results
Tool Versions
Static Analysis
Fuzz Statistics
Invariant Statistics
Coverage
Gas
Findings
Fixes
Residual Risks
Reviewers
External Review
Decision Record
Verdict
```

---

# 53. 审核结论

智能合约审核只能使用：

```text
APPROVED
APPROVED_FOR_TESTNET
APPROVED_FOR_LIMITED_MAINNET
CHANGES_REQUIRED
NO-GO
```

`APPROVED_FOR_LIMITED_MAINNET`必须明确：

- 资金上限；
- 时间；
- 用户范围；
- Chain；
- 功能；
- 监控；
- 暂停；
- 退出；
- 下一次复审。

---

# 54. 与产品和技术文档的关系

以后所有包含智能合约的产品文档必须增加：

- 合约业务目标；
- 资产；
- 权限；
- 不变量；
- 状态；
- 暂停；
- 退出；
- 升级；
- 风险；
- Out of Scope。

以后所有智能合约技术文档必须增加：

- Threat Model；
- Contract Architecture；
- Storage；
- Roles；
- External Calls；
- Oracle；
- Math；
- Testing；
- Tools；
- Deployment；
- Monitoring；
- Incident；
- Audit；
- Vulnerability Register。

没有这些章节，不得进入开发准入。

---

# 55. 公开参考基线

本规范参考以下公开、官方或行业通用基线的原则和方法：

## 55.1 官方语言与标准

- Solidity Documentation：Security Considerations、Known Bugs；
- Ethereum Improvement Proposals：
  - EIP-712 Typed Structured Data；
  - ERC-1271 Contract Signature Validation；
  - ERC-1967 Proxy Storage Slots；
  - ERC-7201 Namespaced Storage Layout；
  - 适用Token、Vault和治理标准。

## 55.2 安全标准

- OWASP Smart Contract Security Verification Standard（SCSVS）；
- OWASP Smart Contract Security Testing Guide（SCSTG）；
- OWASP Smart Contract Weakness Enumeration（SCWE）；
- OWASP Smart Contract Top 10；
- EEA EthTrust Security Levels Specification。

## 55.3 开发与安全工具

- Foundry；
- OpenZeppelin Contracts；
- OpenZeppelin Upgrades Plugins；
- Slither；
- Echidna；
- Trail of Bits Building Secure Contracts资料。

## 55.4 使用原则

这些公开项目和标准属于：

```text
REFERENCE_PROJECT
或
ADOPTION_CANDIDATE
```

具体工具是否直接采用，仍需遵循：

- License；
- 版本；
- 资源；
- 技术栈；
- POC；
- TCO；
- 人工批准。

---

# 56. 最终安全原则

> 智能合约的首要目标不是“代码能运行”，而是任何合法和恶意调用序列下，用户资产、协议资产、权限和会计不变量仍然成立。

> 能复用成熟、宽松许可、经过验证的安全组件时，不重复实现底层安全组件；涉及核心经济模型、资金流、权限和升级时，必须按本项目业务独立建模、测试和审核。

> 安全功能不能只存在于前端。金额上限、权限、Deadline、Slippage、Nonce、Rate Limit、暂停和会计规则必须由合约自身强制执行。

> 不允许用管理员可信、攻击成本高、流动性不足、目前无人利用、已经开源或已经审计等理由替代安全证明。

> 任何P0或P1未关闭、证据不完整、部署代码与审计代码不一致的智能合约，均不得进入主网。


---

## FILE: remediation/00_AUDIT_FINDINGS_BASELINE.md

# PANGU2 V2 安全 Finding 修复基线

```text
Audit Target: contracts-v2/src/**
Deployed Source Commit: 3ef50b6d77a31c092e9353e255e672836f36ece8
Planning Observed HEAD: 4d33669b41568fa573e9c0e5865be8b1cea803c3
Code Audit Verdict: CHANGES_REQUIRED
P0: 0
P1: 3
P2: 4
P3: 2
Mainnet: NO-GO
```

本文件是修复任务的 Finding 输入，不是关闭证明。每项只有在对应阶段完成实现、独立审核、审核结论校对和复审后才能改为 `CLOSED_CODE_ONLY`。

## 1. Finding 矩阵

| ID | 级别 | 问题 | 部署测试网源码影响 | 目标阶段 |
|---|---|---|---|---|
| P1-CB-01 | P1 | UNKNOWN 灰尘把接收方全部 KNOWN 仓位污染为 UNKNOWN | YES | S1 + S2 |
| P1-STK-01 | P1 | Staking 本金返还和奖励没有恢复/更新 CostBasis | YES | S3 |
| P1-STK-02 | P1 | 先 Claim 再 Early Unstake 绕过奖励没收 | YES | S4A |
| P2-TAX-01 | P2 | Whitelist 零税结算调用 `FeeVault.credit(0)` 导致回滚 | YES | S2 |
| P2-STK-03 | P2 | 没收奖励从 liability 删除但未返回 reserve | YES | S4A |
| P2-BBK-01 | P2 | 固定回购未检查自身价格冲击，初始浅池可能持续回滚 | YES；实时储备需回读 | S5 |
| P2-DIV-01 | P2 | Published Epoch 可在 claimStart 前被 Governance 取消 | YES | S6 |
| P3-ORC-01 | P3 | Oracle 未正确处理 uint32 timestamp 回绕 | YES；当前不可利用 | S7 |
| P3-TKN-01 | P3 | `code.length` 全局限制导致智能钱包不兼容/反事实地址锁定 | YES | S8A + S8B |

## 2. 不得破坏的经济基线

```text
Initial Supply = 1,000,000,000 PANGU2
Decimals = 18
No post-constructor mint

Priority:
Trading Gate → Fee Whitelist → Launch Protection → Normal Cost-Basis Tax

Whitelist Buy/Sell = 0%
Launch Buy/Sell = 30%
Launch Sell = 29% Support + 1% Burn
Normal Buy = 4% Dividend
Normal Sell KNOWN at/below proportional cost = 4% Support
Normal Sell KNOWN above proportional cost = 9% Support + 1% Burn
Normal Sell UNKNOWN = 9% Support + 1% Burn
Launch Protection = 15 minutes

Staking minimum = 1 Token
Maximum lock = 730 days
Early principal penalty = 10%

Buyback amount = 0.01 BNB
Minimum successful-buyback interval = 60 seconds
Buyback recipient = BuybackLocker

Dividend claim window = exactly 30 days
Oracle window = 1800 seconds
Oracle max deviation = 300 bps
```

任何改变以上参数或税率优先级的方案都属于经济模型变更，必须暂停阶段并请求用户批准；不得以“修复漏洞”为名顺带改变。

## 3. Finding 关闭证据

每项关闭必须同时具备：

1. Fix Commit 完整 SHA；
2. 部署 Commit 与 Fix Commit 的代码证据；
3. 原攻击路径已不可执行的逐步说明；
4. 正向功能测试；
5. 原攻击路径回归测试；
6. 相关 Fuzz/Invariant；
7. 独立审核 `APPROVED_CODE_ONLY`；
8. 校对 Agent 确认审核结论正确；
9. 未改变经济基线；
10. 明确 `CODE_FIX_REQUIRES_REDEPLOYMENT = YES`。

## 4. 历史事项处理

- 旧 `CONTRACT_SECURITY_AUDIT.md` 绑定 `e2c09c5`，不能批准部署 Commit 或本修复分支。
- 部署后的脚本/interface 修复不能反向修复测试网 runtime。
- V2 MVP 保留 V3 tokenId LP 模型是已知偏差；除非发现新的攻击路径，不在本计划中重构。
- 本计划只修合约代码；部署、迁移、链上 readback 和测试网切换必须另开任务。


---

## FILE: remediation/01_MASTER_EXECUTION_PROMPT.md

# PANGU2 V2 修复 Agent 主提示词

将下面整段提示词交给负责执行修复的 Agent。每次只允许它执行一个阶段。

---

你是 BingGoPlus / PANGU2 V2 智能合约安全修复 Agent。

项目根目录：

```text
E:\github\bnb\bnb-presale-minimal
```

你的目标是按 `docs/current/go-backend-v2/contracts/remediation/` 中的阶段计划修复 `contracts-v2`，不是重新设计经济模型，也不是部署合约。

## 强制读取顺序

1. `docs/current/go-backend-v2/contracts/BSC_TESTNET_DEPLOYMENT_BASELINE.md`
2. `docs/current/go-backend-v2/05_BUSINESS_AND_CONTRACT_INHERITANCE.md`
3. `docs/current/go-backend-v2/08_RULES_COMPLIANCE_AND_DECISIONS.md`
4. `docs/current/go-backend-v2/09_SELF_REVIEW.md`
5. `docs/current/CONTRACT_SECURITY_AUDIT.md`
6. `docs/current/go-backend-v2/contracts/remediation/README.md`
7. `docs/current/go-backend-v2/contracts/remediation/00_AUDIT_FINDINGS_BASELINE.md`
8. `docs/current/go-backend-v2/contracts/remediation/02_REVIEW_WORKFLOW_AND_PROMPTS.md`
9. `docs/current/go-backend-v2/contracts/remediation/03_STAGE_EVIDENCE_TEMPLATE.md`
10. `docs/current/go-backend-v2/contracts/remediation/05_EXTERNAL_PLAN_REVIEW_ADJUDICATION.md`
11. 本次指定的 `stages/S*.md`

所有文件必须完整读取。发现冲突时，以部署 Commit `3ef50b6d77a31c092e9353e255e672836f36ece8` 的已部署经济逻辑和 `BSC_TESTNET_DEPLOYMENT_BASELINE.md` 为优先证据，并记录冲突，不得自行选择新经济规则。

## 开始 Gate

开始前必须输出并记录：

```text
Stage ID
Stage Start Base SHA
Current HEAD SHA
Deployed Source Commit
Branch
Working Tree Status
Allowed Paths
Forbidden Paths
Dependencies
Findings Targeted
Tests Planned
```

若工作区有用户改动：保留它们，不得 reset、checkout、clean 或覆盖。若目标文件存在不属于本阶段的未提交改动，停止并报告冲突。

推荐在 `codex/pangu2-v2-security-remediation` 分支工作。不得自动 push、merge、tag 或部署。

## 阶段执行规则

1. 一次只执行一个阶段，不得提前做下一阶段。
2. 修改任何代码前，先使用 `02_REVIEW_WORKFLOW_AND_PROMPTS.md` 的“Pre-Fix 阶段目标确认提示词”提交只读审核，再由校对 Agent 判断审核结论。
3. 只有目标 Finding 被校对为 `CONFIRMED` 且拟定范围获准，才能开始实现；否则停止或按反证关闭错误结论。
4. 严格遵守阶段 Allowed Paths；发现必须扩大范围时停止并说明原因。
5. 优先最小安全改动，不做无关重构、格式化或命名清理。
6. 所有 external/public 行为变化必须更新接口、NatSpec、事件和测试。
7. 不得改变冻结税率、供应量、Launch 时间、回购金额、冷却、Claim 窗口或 Oracle 参数。
8. 不得修改 `contracts/src/**` V3 代码、Backend、DApp、数据库或本地环境。
9. 可以运行 `forge fmt`、`forge build`、Unit、Fuzz、Invariant；必须记录真实命令、exit code 和结果。
10. S1–S8B 每个 Implementation/Fix Commit 必须 `CORE_SOLIDITY_BUILD=PASS`、`INTERFACE_IMPLEMENTATION_MATCH=PASS`、`COMPILE_ERRORS=0`；编译未运行或失败时 `NEXT_STAGE_ALLOWED=NO`。
11. 禁止运行 Fork、RPC、Anvil、`forge script`、`cast call/send`、部署、广播和签名。
12. 测试未运行或工具不可用时必须写 `NOT_RUN`，不得猜测 PASS。
13. Foundry script 只允许只读检查；若已批准 ABI/constructor 改动导致完整 Build 仅因脚本签名不匹配失败，按 README 的 `COMPILE_COMPATIBILITY_EXCEPTION` 停止并申请用户批准，不得自行修改。
14. 完成代码和测试后创建单一阶段实现 Commit，记录完整 40-char SHA，然后停止进入独立审核。

## 审核闭环

阶段 Commit 后：

1. 使用 `02_REVIEW_WORKFLOW_AND_PROMPTS.md` 的“阶段独立审核提示词”交给独立只读审核 Agent。
2. 获取审核报告后，交给另一个只读校对 Agent执行“审核结论校对提示词”。
3. 对每个审核 Finding，只接受校对结果：
   - `CONFIRMED`
   - `REJECTED_WITH_EVIDENCE`
   - `DUPLICATE`
   - `NEEDS_MORE_EVIDENCE`
   - `SCOPE_EXPANSION_REQUIRED`
4. 只有 `CONFIRMED` Finding 可以直接修复。
5. `NEEDS_MORE_EVIDENCE` 或 `SCOPE_EXPANSION_REQUIRED` 必须停止并请求用户决定。
6. 修复已确认 Finding 后创建独立 Fix Commit，再交给独立审核 Agent 复审。
7. 只有审核为 `APPROVED_CODE_ONLY` 且校对结果为 `REVIEW_VERDICT_CONFIRMED=YES`，阶段才能关闭。

实现 Agent不得自行把自己的代码标记为独立批准。

## 大阶段全量审核

S2、S4B、S8B 完成后，必须立即执行对应 `PRIORITY_FULL_AUDIT`。审核读取全部 `contracts-v2/src/**`，检查修改与其他模块的逻辑、资金流、权限、漏洞、基线一致性和代码层可部署性。

开发期全量审核不检查本地部署环境、RPC、广播、私钥、Backend、DApp 或数据库，也不得授予实际部署批准。

## 阶段输出

每阶段必须输出：

```text
Stage Verdict
Base SHA
Implementation Commit SHA
Fix Commit SHA(s)
Files Changed
Findings Addressed
Economic Baseline Changed = NO / YES（YES 必须有用户批准）
Build Result
Core Solidity Build Result
Interface Implementation Match
Unit Result
Fuzz Result
Invariant Result
Tests/Fork/RPC Not Run
Independent Review Verdict
Review Adjudication Verdict
Residual Risks
Next Stage Allowed = YES / NO
Mainnet = NO-GO
```

记住：当前 BSC Testnet 合约不可升级。源码修复只会产生未来候选代码，不能描述为“已部署实例已修复”。

---


---

## FILE: remediation/02_REVIEW_WORKFLOW_AND_PROMPTS.md

# PANGU2 V2 阶段审核、结论校对与大阶段全量审核提示词

## 1. 角色分离

| 角色 | 权限 | 禁止事项 |
|---|---|---|
| Implementation Agent | 修改当前阶段允许的代码和测试 | 自行签发独立批准、越阶段修改、部署 |
| Independent Review Agent | 只读审核固定 Commit | 修改文件、替作者修复、审核本地部署环境 |
| Review Adjudication Agent | 只读核对审核报告是否正确 | 凭直觉同意、修改代码、扩大 Finding |
| Priority Full Audit Agent | 只读审核全部 V2 合约代码 | RPC、Fork、部署、把代码批准写成部署批准 |

Implementation Agent、Independent Review Agent 和 Review Adjudication Agent 必须是不同 Agent 或至少不同的独立会话，且不得共享未公开的作者推理作为审核依据。Priority Full Audit 也不得由该大阶段的 Implementation Agent签发。

若无法实现角色隔离，阶段状态必须保持：

```text
INDEPENDENT_REVIEW_REQUIRED
REVIEW_ADJUDICATION_REQUIRED
NEXT_STAGE_ALLOWED = NO
```

## 2. Pre-Fix 阶段目标确认提示词

```text
你是 PANGU2 V2 Pre-Fix 只读审核 Agent。代码尚未修改。你的任务是确认当前阶段目标 Finding 是否真实存在、严重性是否合理、阶段修复边界是否足以关闭攻击路径且不违反经济基线。

项目：E:\github\bnb\bnb-presale-minimal
阶段：<STAGE_ID>
Pre-Fix Commit：<40-char SHA>

完整读取 Finding 基线、阶段文档、部署经济基线和目标函数的全部跨合约调用链。禁止修改文件、运行部署/RPC/Fork 或审核本地部署环境。

每个目标 Finding 输出：
- Finding ID
- EXISTS_AT_PRE_FIX_COMMIT = YES / NO / UNKNOWN
- File / Line / Function
- Attack Preconditions
- Attack Path
- Severity Correct = YES / NO
- Proposed Stage Scope Sufficient = YES / NO
- Economic Baseline Conflict = YES / NO
- Cross-Contract Dependencies
- Required Tests/Invariants
- Recommendation = CONFIRM_FOR_IMPLEMENTATION / REJECT_WITH_EVIDENCE / NEEDS_MORE_EVIDENCE / SCOPE_EXPANSION_REQUIRED

最后输出：
PRE_FIX_VERDICT = CONFIRMED / CHANGES_REQUIRED / BLOCKED
IMPLEMENTATION_ALLOWED = YES / NO

这份报告还必须交给 Review Adjudication Agent 校对；你不能直接授权实现。
```

校对 Pre-Fix 报告时使用第 4 节的审核结论校对提示词。只有审核与校对均确认目标 Finding 成立时才允许实现。

## 3. 阶段独立审核提示词

```text
你是 PANGU2 V2 阶段独立代码审核 Agent，只读工作。

项目：E:\github\bnb\bnb-presale-minimal
审核阶段：<STAGE_ID>
Stage Base SHA：<40-char SHA>
Stage Review Commit：<40-char SHA>

必须完整读取：
- remediation/README.md
- remediation/00_AUDIT_FINDINGS_BASELINE.md
- 当前 stages/<STAGE>.md
- BSC_TESTNET_DEPLOYMENT_BASELINE.md
- 05_BUSINESS_AND_CONTRACT_INHERITANCE.md
- 08_RULES_COMPLIANCE_AND_DECISIONS.md
- Stage Base..Review Commit diff
- 所有被修改实现、接口、库及直接交互合约
- 新增/修改测试源码和真实执行证据

限制：
- 禁止修改任何文件。
- 禁止部署、RPC、Fork、广播、签名和链上读取。
- 开发阶段只审核合约代码、测试证据、跨合约逻辑、基线符合性及代码层可部署性。
- 不审核本地部署环境、私钥、Backend、DApp、数据库、Docker 或服务器。
- 测试文件存在不等于测试通过；只接受绑定 Review Commit 的真实结果。

逐项检查：
1. 原 Finding 的攻击路径是否确实被关闭；
2. 是否产生新的资金损失、税率绕过、会计漂移、重入、权限绕过或 DoS；
3. Preview 与 Execute 是否一致；
4. 状态更新和外部调用是否满足 CEI；
5. 角色、Pause/Unpause、一次配置和零地址检查；
6. SafeERC20、FullMath、类型转换和舍入；
7. 事件、ABI、接口实现和构造关系；
8. 是否违反冻结经济参数；
9. 是否触及阶段 Forbidden Paths 或夹带无关改动；
10. 代码是否具备编译和未来部署的逻辑完整性，但不要审核实际部署流程。
11. Implementation/Fix Commit 是否具有 `CORE_SOLIDITY_BUILD=PASS`、`INTERFACE_IMPLEMENTATION_MATCH=PASS` 和零编译错误证据；未满足时不得批准进入下一阶段。
12. 若读取 deployment scripts，只能判断 approved ABI/constructor 的编译兼容性；不得审核地址、密钥、部署执行、角色接线或迁移。

Finding 必须包含：ID、Severity、Status、File、Line/Function、Commit Evidence、Attack Preconditions、Attack Path、Impact、Root Cause、Required Fix、Regression Risk、Required Verification。

Verdict 只能是：
APPROVED_CODE_ONLY / CHANGES_REQUIRED / BLOCKED

如果没有问题，仍须列出 Verified Non-Issues、测试边界、未执行项和剩余风险。
```

## 4. 审核结论校对提示词

```text
你是 PANGU2 V2 Review Adjudication Agent。你的任务不是修代码，而是逐条判断独立审核报告是否正确。

输入：
- Stage Base SHA：<40-char SHA>
- Stage Review Commit：<40-char SHA>
- 阶段计划文件
- 独立审核报告全文
- 部署经济基线和 Finding 基线

只读检查 Review Commit 的真实代码。对审核报告每条 Finding 输出且只能输出以下分类之一：
- CONFIRMED：证据、攻击路径和严重性成立；进入修复。
- REJECTED_WITH_EVIDENCE：结论错误；给出反证文件、行号和逻辑。
- DUPLICATE：与已有 Finding 是同一根因；并入原 ID。
- NEEDS_MORE_EVIDENCE：静态证据不足，不能修也不能关闭。
- SCOPE_EXPANSION_REQUIRED：修复需要超出当前阶段 Allowed Paths；等待用户批准。

必须检查：
1. 审核是否使用了正确的 Commit；
2. 是否把部署 Commit、当前源码、测试结果混为一谈；
3. 是否把测试缺失误报为代码漏洞；
4. 是否给出了可执行攻击路径；
5. 严重性是否符合资产损失和可利用前提；
6. 建议修复是否违反经济基线；
7. 是否忽略跨合约影响或一次性配置；
8. 是否错误审核了本地部署环境等本阶段禁区。

最后输出：
REVIEW_VERDICT_CONFIRMED = YES / NO
FIX_ALLOWED = YES / NO
CONFIRMED_FINDINGS = [...]
REJECTED_FINDINGS = [...]
BLOCKING_EVIDENCE_GAPS = [...]

只有 REVIEW_VERDICT_CONFIRMED=YES 且 FIX_ALLOWED=YES 时，实现 Agent 才能修复 CONFIRMED Findings。
```

## 5. 修复后复审提示词

```text
你是 PANGU2 V2 修复后独立复审 Agent。

审核固定的 Stage Base、原 Stage Commit 和 Fix Commit。逐条重放所有 CONFIRMED Finding 的攻击路径，并检查修复是否产生回归。不得只确认 diff 中出现了预期代码；必须检查完整调用链和相邻合约。

输出：
- 每条 Finding：CLOSED_CODE_ONLY / STILL_OPEN / REGRESSION_FOUND
- New Findings
- Verified Non-Issues
- Build/Test Evidence Bound to Commit
- CODE_DEPLOYABILITY = YES / NO / UNKNOWN
- Verdict = APPROVED_CODE_ONLY / CHANGES_REQUIRED / BLOCKED

APPROVED_CODE_ONLY 不得被描述为已部署、测试网 GO 或 Mainnet GO。
```

## 6. PRIORITY_FULL_AUDIT 提示词

```text
你是 PANGU2 V2 大阶段优先全量代码审核 Agent，只读审核固定 Commit。

Macro Gate：<M1/M2/M3/FINAL>
Audit Commit：<40-char SHA>

必须逐行阅读全部 contracts-v2/src/**，包括接口和库；读取全部相关测试及绑定该 Commit 的结果。审核不是只看 diff。

必须复核：
- Buy：BNB→Adapter/Pair→gross→税→FeeVault→net→CostBasis；
- Sell：Cost consume→税/燃烧→swapTokens→BNB；
- Support：Support bucket→conversion→SupportPool→buyback→Locker；
- Dividend：bucket→fund→commit→publish→claim→carry；
- Staking：principal→cost lot→reward→normal/early exit；
- 所有角色、Pause、Context、一次配置和事件；
- 禁止项、重入、CEI、算术、SafeERC20、假充值；
- 原 9 个 Finding 和本大阶段新增路径；
- 经济基线参数和优先级；
- ABI、接口和构造连接的代码层可部署性。
- 每个阶段 mandatory Build Gate 和 compile-surface 兼容性；

禁止审核或执行：本地部署、RPC、Fork、广播、签名、Backend、DApp、数据库、服务器和实际迁移。

每个 Finding 必须有文件、行号、攻击前提、路径、影响和修复建议。最后输出：
Verdict = APPROVED_CODE_ONLY / CHANGES_REQUIRED / BLOCKED
CODE_DEPLOYABILITY = YES / NO / UNKNOWN
BASELINE_COMPLIANCE = PASS / FAIL
ORIGINAL_FINDINGS_CLOSED = [...]
NEW_FINDINGS = [...]
TEST_EVIDENCE_STATUS
DEPLOYMENT_OR_RUNTIME_APPROVAL = NOT_GRANTED
MAINNET = NO-GO
```


---

## FILE: remediation/03_STAGE_EVIDENCE_TEMPLATE.md

# PANGU2 V2 阶段证据模板

复制本模板到 `remediation/evidence/<STAGE_ID>_CLOSEOUT.md`。不得覆盖其他阶段证据。

## 1. Stage Identity

```text
Stage ID:
Stage Title:
Stage Start Base SHA:
Implementation Commit SHA:
Fix Commit SHA(s):
Final Review Commit SHA:
Branch:
Prepared At:
Prepared By:
```

### Chronology

| Event | Agent/Role | Full Commit SHA | Started At | Completed At | Verdict |
|---|---|---|---|---|---|
| Pre-Fix Review | | | | | |
| Pre-Fix Adjudication | | | | | |
| Implementation | | | | | |
| Post-Fix Review | | | | | |
| Post-Fix Adjudication | | | | | |
| Fix | | | | | |
| Re-Review | | | | | |

Implementation、Review、Adjudication 必须记录不同 Agent/session identity；缺少角色隔离时不得关闭阶段。

## 2. Scope

```text
Findings Targeted:
Allowed Paths:
Files Changed:
Forbidden Paths Touched = NO
Economic Baseline Changed = NO
```

## 3. Implementation Evidence

### 3.1 Pre-Fix Review Gate

```text
Pre-Fix Review Agent:
Pre-Fix Commit:
Pre-Fix Review Verdict:
Pre-Fix Report Path/ID:
Pre-Fix Adjudication Agent:
Pre-Fix Adjudication Verdict:
IMPLEMENTATION_ALLOWED:
```

### 3.2 Code Changes

| Finding/Requirement | Before | After | File/Function | Attack Path Closed By |
|---|---|---|---|---|
| | | | | |

## 4. Validation Evidence

| Check | Exact Command | Commit | Exit Code | Result | Evidence File |
|---|---|---|---|---|---|
| Format | | | | PASS/FAIL/NOT_RUN | |
| Build | | | | PASS/FAIL/NOT_RUN | |
| Core Solidity Build | | | | PASS/FAIL | |
| Interface Implementation Match | | | | PASS/FAIL | |
| Unit | | | | PASS/FAIL/NOT_RUN | |
| Regression | | | | PASS/FAIL/NOT_RUN | |
| Fuzz | | | | PASS/FAIL/NOT_RUN | |
| Invariant | | | | PASS/FAIL/NOT_RUN | |

测试源码存在、`out/` 存在或旧报告存在不能填写 PASS。

S1–S8B 的 `Core Solidity Build` 和 `Interface Implementation Match` 不允许填写 `NOT_RUN` 后继续下一阶段。若 Forge 完整编译仅被 approved ABI/constructor 导致的 script 签名不兼容阻止，记录编译错误并启动 `COMPILE_COMPATIBILITY_EXCEPTION`，不得自行扩大范围。

## 5. Independent Review

```text
Review Agent:
Review Commit:
Review Verdict:
Review Report Path/ID:
Findings Raised:
```

## 6. Review Adjudication

| Review Finding | Classification | Evidence | Fix Allowed |
|---|---|---|---|
| | CONFIRMED/REJECTED_WITH_EVIDENCE/DUPLICATE/NEEDS_MORE_EVIDENCE/SCOPE_EXPANSION_REQUIRED | | YES/NO |

```text
REVIEW_VERDICT_CONFIRMED:
FIX_ALLOWED:
```

## 7. Re-Review

```text
Fix Commit:
Re-Review Verdict:
Review Adjudication Verdict:
New Findings:
```

## 8. Stage Exit

```text
Original Findings Closed:
Residual Risks:
CODE_DEPLOYABILITY:
CORE_SOLIDITY_BUILD:
INTERFACE_IMPLEMENTATION_MATCH:
BASELINE_COMPLIANCE:
Stage Verdict:
Next Stage Allowed:
ROLE_SEPARATION_VERIFIED:
Deployment Approval = NOT_GRANTED
BSC Testnet Runtime Fixed = NO
Mainnet = NO-GO
```


---

## FILE: remediation/04_CLOUD_REVIEW_SUBMISSION_CHECKLIST.md

# PANGU2 V2 云端方案复审提交清单

```text
Purpose: prevent incomplete review packages
Review Type: remediation plan re-review
Solidity Implementation: FORBIDDEN UNTIL S0 APPROVAL
Deployment Approval: NOT_GRANTED
Mainnet: NO-GO
```

## 1. 必传修复方案文档

提交前逐项确认，不能只上传 `stages/`：

```text
remediation/README.md
remediation/00_AUDIT_FINDINGS_BASELINE.md
remediation/01_MASTER_EXECUTION_PROMPT.md
remediation/02_REVIEW_WORKFLOW_AND_PROMPTS.md
remediation/03_STAGE_EVIDENCE_TEMPLATE.md
remediation/04_CLOUD_REVIEW_SUBMISSION_CHECKLIST.md
remediation/05_EXTERNAL_PLAN_REVIEW_ADJUDICATION.md

remediation/stages/S0_DESIGN_AND_INVARIANT_FREEZE.md
remediation/stages/S1_COST_BASIS_DUAL_LEDGER.md
remediation/stages/S2_TOKEN_ROUTER_MIXED_SETTLEMENT_AND_WHITELIST.md
remediation/stages/S3_STAKING_COST_BASIS_BRIDGE.md
remediation/stages/S4A_STAKING_REWARD_EXIT.md
remediation/stages/S4B_STAKING_PAUSE_AND_EMERGENCY_CONTROL.md
remediation/stages/S5_SUPPORT_BUYBACK_PRICE_IMPACT.md
remediation/stages/S6_DIVIDEND_EPOCH_FINALITY.md
remediation/stages/S7_ORACLE_UINT32_ROLLOVER.md
remediation/stages/S8A_CONTRACT_ACCOUNT_LIFECYCLE.md
remediation/stages/S8B_CONTRACT_ACCOUNT_BYPASS_REGRESSION.md
remediation/stages/S9_FINAL_CODE_EXIT_GATE.md
```

旧文件 `S4_STAKING_REWARD_EXIT_AND_PAUSE.md` 和 `S8_CONTRACT_ACCOUNT_BOUNDARY.md` 已被拆分，不能与新文件同时提交，避免审核方使用过期阶段。

## 2. 必传权威基线

```text
contracts/BSC_TESTNET_DEPLOYMENT_BASELINE.md
go-backend-v2/05_BUSINESS_AND_CONTRACT_INHERITANCE.md
go-backend-v2/08_RULES_COMPLIANCE_AND_DECISIONS.md
go-backend-v2/09_SELF_REVIEW.md
docs/current/CONTRACT_SECURITY_AUDIT.md
通用智能合约安全开发风险控制与漏洞治理规范 V1.0.md
```

如果云端无法访问 Git commit，至少同时上传目标 Solidity 源码快照或归档，并在 manifest 中记录：

```text
Deployed Source Commit = 3ef50b6d77a31c092e9353e255e672836f36ece8
Planning/Review Head = <full 40-char SHA>
Source Archive SHA-256 = <hash>
```

## 3. 提交 Manifest

上传前为每个文件计算 SHA-256，随审核请求附上：

| Relative Path | SHA-256 | Git Blob/Commit（如有） | Required |
|---|---|---|---|
| | | | YES |

不得只用附件文件名证明版本；相同名称的修订文件必须用 hash 区分。

## 4. 云端审核边界

要求云端审核者明确：

- 本轮只审核修复方案和 S0 Gate；
- 未收到的源码不得猜测；
- GitHub public main 不得自动替代本地 `3ef50b6/Review HEAD`；
- `SOURCE_CODE_VERIFICATION_REQUIRED` 与 `PLAN_DEFECT` 必须分开；
- 不运行 RPC、Fork、部署或链上写入；
- 不授予 Solidity implementation、部署或 Mainnet 批准。

## 5. 复审期望输出

```text
Plan Review Verdict = APPROVED_FOR_S0_DESIGN_GATE / CHANGES_REQUIRED / BLOCKED
S0_GATE_APPROVAL = GRANTED / NOT_GRANTED
SOLIDITY_IMPLEMENTATION_ALLOWED = NO
MISSING_REQUIRED_DOCUMENTS = []
DOCUMENT_HASHES_VERIFIED = YES / NO
PLAN_P0/P1/P2/P3
BASELINE_COMPLIANCE
ROLE_SEPARATION_WORKFLOW
MANDATORY_BUILD_GATE
STAGE_SPLIT_VERDICT
DEPLOYMENT_APPROVAL = NOT_GRANTED
MAINNET = NO-GO
```

只有云端方案复审通过、且其结论再次由本地校对确认后，才能开始执行 S0。S0 本身批准前仍不得修改 Solidity。



---

## FILE: remediation/05_EXTERNAL_PLAN_REVIEW_ADJUDICATION.md

# 外部方案审核结论校对记录

```text
Review Input: cloud plan review pasted-text.txt
Review Verdict Received: CHANGES_REQUIRED
Adjudication Verdict: REVIEW_VERDICT_CONFIRMED = YES
Fix Allowed: YES, documentation plan only
Solidity Changes: NONE
Solidity Implementation Allowed: NO
S0 Gate Approval: NOT_GRANTED; RE-REVIEW_REQUIRED
Deployment Approval: NOT_GRANTED
Mainnet: NO-GO
```

## 1. 总体判断

云端报告的总体 `CHANGES_REQUIRED` 正确：mandatory Build Gate、Staking typed position context、资金恒等式、舍入规则、Preview revision 语义和合约账户生命周期需要在 S0 批准前补强。

报告没有收到 README、00/01/02/03 和权威基线，因此它拒绝签发 S0 Gate 也是正确的证据边界。但这是“上传包不完整”，不是这些文件在本地不存在。本轮增加独立提交清单，防止复审再次遗漏。

云端使用的 GitHub public main 与本地目标 Commit 不同。涉及 whitelist 和 Oracle 当前实现的结论必须以本地 `3ef50b6/Review HEAD` 为准，不能直接继承云端辅助快照。

## 2. Finding 校对

| 外部结论 | 校对分类 | 本地证据/判断 | 已执行修改 |
|---|---|---|---|
| PLAN-P1-01 Build 可 NOT_RUN 仍推进 | CONFIRMED | 原 S1 确实允许 `BUILD=PASS or NOT_RUN_WITH_BLOCKER` | S1–S8B 改为 mandatory Build；失败/未运行不得推进 |
| PLAN-P1-02 Staking mutation path 不唯一 | CONFIRMED | 当前 `systemTransfer(to,amount,kind)` 不携带 positionId；原计划未完全禁止双写 | S0/S3 冻结 typed context 和 onlyToken 单一路径 |
| PLAN-P1-03 Staking 资金状态不完整 | CONFIRMED | 原计划没有完整冻结 normal exit reward、penalty、no-staker liability、dust | S0/S4A 增加完整状态和恒等式 |
| PLAN-P1-04 S8 lifecycle 不足 | CONFIRMED | 原 S8 只有原则，没有可编码的 revoke/exit 状态机 | 新 S8A 使用 NONE→APPROVED→EXIT_ONLY→REVOKED；S8B 隔离防绕过 |
| PLAN-P2-01 proportional floor/split tax | CONFIRMED | 原规则没有防止 4%/10% 分类受取整影响的精确定义 | S0 增加精确有理数利润比较、carry/remainder 和 canonical split 性质 |
| PLAN-P2-02 CostBasis 等式范围 | CONFIRMED | 原 `actual=known+unknown` 未限定 eligible liquid users | S0 明确排除 Pair/System/协议托管和 staked lots |
| PLAN-P2-03 revision 语义不明确 | CONFIRMED | 原 S2 同时写 revision/quote block，未定义是 diagnostic 还是 lock | S0 强制二选一；S2 必须按冻结语义实现 |
| PLAN-P2-04A canonical whitelist source 未写入计划 | CONFIRMED | 计划此前没有列出 storage/admin/trading/launch 单一来源 | S0/S2 增加 canonical source mapping 和目标 SHA 复核 |
| PLAN-P2-04B 本地目标源码可能没有 whitelist/launch | REJECTED_WITH_EVIDENCE | 本地 `Pangu2Token` 明确包含 `feeWhitelist`、`tradingOpenAt`、`resolveBuyTaxBps`、`resolveSellTaxBps` | 不删除 Finding；只要求执行时核对目标 SHA |
| S4 应拆 Reward 与 Pause | CONFIRMED | 原 S4 同时改奖励状态机和角色/暂停，风险面过大 | 拆为 S4A、S4B；M2 在 S4B 后 |
| S8 FIX 应拆 lifecycle 与 bypass regression | CONFIRMED | Registry 生命周期和 Pair/Router 攻击面不同 | 拆为 S8A、S8B；M3 在 S8B 后 |
| deployment scripts 绝对禁止修改会阻断 Build | CONFIRMED_WITH_SCOPE_CONTROL | Foundry `script="script"`；constructor/interface 变化可能破坏完整编译 | 新增需用户批准的 `COMPILE_COMPATIBILITY_EXCEPTION`；仍禁止部署逻辑/执行 |
| S5 优先复用 Adapter canonical quote | CONFIRMED | 本地 Adapter 已有固定 Token/WBNB `quoteExactInput` | S5 明确优先复用，不开放任意 pair/path |
| current Oracle 已部分/完全处理 uint32 rollover | REJECTED_FOR_TARGET_SNAPSHOT | 本地目标代码仍有 `if (ts > uint32(block.timestamp)) revert PairTimestampAhead(ts)` | 保留 S7，并增加 long-gap/re-anchor 规则 |
| 缺少 README/00/01/02/03 | CONFIRMED_AS_SUBMISSION_GAP | 文件本地存在，但云端未收到 | 新增完整上传清单和 hash manifest 要求 |

## 3. 阶段结构变更

修订后顺序：

```text
S0
→ S1 → S2 → M1
→ S3 → S4A → S4B → M2
→ S5 → S6 → S7
→ S8A → S8B → M3
→ S9 / FINAL
```

S1–S8B 每阶段必须：

```text
CORE_SOLIDITY_BUILD = PASS
INTERFACE_IMPLEMENTATION_MATCH = PASS
COMPILE_ERRORS = 0
```

Unit/Fuzz/Invariant 可以因工具不可用标记 NOT_RUN，但 Build 不能在未通过时推进。

## 4. 仍未授予的权限

本轮只是修复计划文档，不是 S0 设计成果本身。下一步必须把完整修订包重新提交独立方案审核。

```text
PLAN_REMEDIATION_STATUS = READY_FOR_EXTERNAL_RE_REVIEW
S0_GATE_APPROVAL = NOT_GRANTED
SOLIDITY_IMPLEMENTATION_ALLOWED = NO
DEPLOYMENT_APPROVAL = NOT_GRANTED
BSC_TESTNET_RUNTIME_FIXED = NO
MAINNET = NO-GO
```



---

## FILE: remediation/README.md

# PANGU2 V2 合约安全修复执行包

```text
Document ID: PANGU2-V2-SECURITY-REMEDIATION-PLAN
Status: PLANNING_READY
Planning Observed HEAD: 4d33669b41568fa573e9c0e5865be8b1cea803c3
Deployed Source Commit: 3ef50b6d77a31c092e9353e255e672836f36ece8
Chain ID: 97
Mainnet: NO-GO
Automatic Merge: FORBIDDEN
Automatic Push: FORBIDDEN
Automatic Deployment: FORBIDDEN
```

本目录把 PANGU2 V2 合约安全修复拆成短阶段，供另一个 Agent 逐阶段执行。它不授权部署、迁移、RPC、广播、签名、推送或合并。

## 1. 权威输入

执行 Agent 必须按以下顺序读取：

1. `../BSC_TESTNET_DEPLOYMENT_BASELINE.md`
2. `../../05_BUSINESS_AND_CONTRACT_INHERITANCE.md`
3. `../../08_RULES_COMPLIANCE_AND_DECISIONS.md`
4. `../../09_SELF_REVIEW.md`
5. `../../../CONTRACT_SECURITY_AUDIT.md`
6. `00_AUDIT_FINDINGS_BASELINE.md`
7. `01_MASTER_EXECUTION_PROMPT.md`
8. `02_REVIEW_WORKFLOW_AND_PROMPTS.md`
9. `03_STAGE_EVIDENCE_TEMPLATE.md`
10. `05_EXTERNAL_PLAN_REVIEW_ADJUDICATION.md`
11. 当前阶段文件

若执行时 HEAD 不再是上面的 Planning Observed HEAD，必须先记录新 HEAD，并比较 `3ef50b6..HEAD` 的 `contracts-v2/src/**` 差异。不得假设本计划生成后的新代码已经安全。

## 2. 修复阶段

| 顺序 | 阶段 | 主要范围 | 关闭目标 | 大阶段审核 |
|---|---|---|---|---|
| 0 | `S0` 设计冻结 | 经济规则、ABI、状态机、不变量 | 所有实现前决策 | 设计审核 |
| 1 | `S1` CostBasis 双账本 | CostBasis、接口、数学库 | P1-CB-01 核心账本 | 阶段审核 |
| 2 | `S2` Token/Router 结算 | Token、Router、CostBasis 接口 | P1-CB-01、P2-TAX-01 | **M1 优先全量代码审核** |
| 3 | `S3` Staking 成本迁移 | Token、CostBasis、Staking | P1-STK-01 | 阶段审核 |
| 4A | `S4A` Staking 奖励/退出 | Staking、接口、测试 | P1-STK-02、P2-STK-03 | 阶段审核 |
| 4B | `S4B` Staking 暂停 | Staking、角色、测试 | 暂停加固 | **M2 优先全量代码审核** |
| 5 | `S5` Support 回购 | SupportPool、Adapter/接口 | P2-BBK-01 | 阶段审核 |
| 6 | `S6` Dividend 终态 | DividendDistributor | P2-DIV-01 | 阶段审核 |
| 7 | `S7` Oracle 回绕 | PancakeV2TwapOracle | P3-ORC-01 | 阶段审核 |
| 8A | `S8A` 合约账户生命周期 | Pangu2Token | Registry、revoke、exit 或偏差决策 | 阶段审核 |
| 8B | `S8B` Pair/Router 防绕过 | Token、Router、Context 测试 | P3-TKN-01 | **M3 优先全量代码审核** |
| 9 | `S9` 最终代码退出门 | 全部 `contracts-v2/src/**` | 所有代码 Finding | **最终全量代码审核** |

阶段文件位于 `stages/`。必须按顺序执行；不得因为某阶段修改较小而跳过审核闭环。

## 3. 每个阶段的强制闭环

```text
Stage Start Snapshot
→ Pre-Fix Read-Only Review
→ Pre-Fix Review Adjudication
→ 仅对 CONFIRMED Finding 执行 Implementation
→ Local Code Validation
→ Commit（完整 40-char SHA）
→ Post-Fix Independent Read-Only Review
→ Post-Fix Review Adjudication
→ 仅修复 CONFIRMED Findings
→ Fix Commit
→ Independent Re-Review
→ APPROVED_CODE_ONLY
→ Stage Closeout
```

规则：

- 实现 Agent 不得给自己的阶段签发独立批准。
- 阶段开始时，必须先独立确认原 Finding、根因和拟定修复边界；未确认前禁止改代码。
- 审核 Agent 只读，不修改代码。
- 校对 Agent 必须逐条检查审核 Finding 是否有文件、行号、攻击路径和基线冲突证据。
- `CHANGES_REQUIRED` 不等于所有审核意见都正确；只有校对为 `CONFIRMED` 的 Finding 才能进入修复。
- `APPROVED_CODE_ONLY` 只表示代码阶段通过，不表示可部署、已部署、可扩大测试网或 Mainnet GO。
- P0/P1/P2 不得用“后续再处理”关闭。P3 只有用户书面批准 `ACCEPTED_DEVIATION` 才能不改代码。

## 4. 开发期审核边界

审核必须覆盖：

- Solidity 实现、接口、库和与修改直接相关的测试；
- 跨合约调用和资金流；
- 权限、暂停、重入、CEI、算术、状态机和事件；
- 构造函数、immutable、一次性配置和接口兼容性；
- 是否符合部署基线中的经济参数和控制逻辑；
- 代码层可部署性：能否编译、接口是否完整、构造参数和连接关系是否自洽。

开发期审核不覆盖：

- 本地部署流程、私钥、`.env`、Docker、数据库、Backend、DApp；
- RPC、Fork、广播回执、链上角色和真实 runtime；
- 实际部署脚本执行、签名、交易或迁移执行；
- 把测试文件存在、Build 产物存在或旧广播 `status=1` 当作本阶段通过。

实现 Agent可以运行本地 `forge fmt/build/test`、Fuzz 和 Invariant 作为代码验证；不得运行 `forge script`、Fork、RPC、`cast send/call`、Anvil 或任何部署命令。本目录不授权修改部署脚本，除非用户以后单独建立部署/迁移阶段。

## 5. Git 和证据规则

- 推荐分支：`codex/pangu2-v2-security-remediation`。
- 每阶段开始记录 Base SHA、HEAD、状态和允许路径。
- 保留用户原有未跟踪文件；不得清理或覆盖无关改动。
- 每阶段至少一个实现 Commit；审核修复使用独立 follow-up Commit。
- 报告必须记录完整 40 字符 SHA，不能只写短 SHA。
- 不自动 push、merge、tag 或部署。

## 6. 大阶段全量审核定义

M1、M2、M3 和 S9 的 `PRIORITY_FULL_AUDIT` 必须：

1. 阅读全部 `contracts-v2/src/**`，而不只看 diff；
2. 复核本大阶段代码对 Buy、Sell、Support、Dividend、Staking 的影响；
3. 复核其他未修改合约是否因接口、状态或权限变化被破坏；
4. 搜索新增绕过、重入、错误税率、会计漂移、角色接管和永久 DoS；
5. 检查基线参数未被未经批准地改变；
6. 判断 `CODE_DEPLOYABILITY = YES / NO`，但不得宣称实际部署通过；
7. 输出 `APPROVED_CODE_ONLY / CHANGES_REQUIRED / BLOCKED`。

## 7. 强制编译 Gate

S1–S8B 的每个 Implementation/Fix Commit 都必须满足：

```text
IMPLEMENTATION_COMMIT_SHA = full 40-char SHA
CORE_SOLIDITY_BUILD = PASS
INTERFACE_IMPLEMENTATION_MATCH = PASS
COMPILE_ERRORS = 0
NEXT_STAGE_ALLOWED = NO if CORE_SOLIDITY_BUILD != PASS
```

Unit/Fuzz/Invariant 因工具或环境缺失可以记录 `NOT_RUN_WITH_BLOCKER`，但核心 Solidity 编译失败或未执行不能关闭阶段。没有可用编译器时，阶段保持 `BLOCKED_BUILD_EVIDENCE`。

Foundry 会把 `contracts-v2/script/**` 纳入完整编译面。部署执行始终不在本计划范围内，但允许只读检查脚本的类型和 constructor 调用。如果已经批准的 Solidity ABI/constructor 变化导致完整 Build 仅因脚本签名不匹配而失败，可以申请 `COMPILE_COMPATIBILITY_EXCEPTION`：

- 必须先提供编译错误和最小影响文件证据；
- 必须由 Review Adjudication 标记 `SCOPE_EXPANSION_REQUIRED` 并取得用户批准；
- 只允许更新 Solidity 类型、接口或 constructor 参数位置；
- 使用独立 Commit 和独立代码审核；
- 禁止修改地址、私钥、环境变量、角色策略、部署顺序、迁移逻辑、广播或链上操作；
- 该补丁只证明编译兼容，不构成部署脚本审核或部署批准。


---

## FILE: remediation/stages/S0_DESIGN_AND_INVARIANT_FREEZE.md

# S0 — 修复架构、经济规则与不变量冻结

```text
Stage ID: PANGU2-V2-S0
Type: DESIGN_GATE
Code Changes: FORBIDDEN
Prerequisite: README and Finding Baseline read completely
Exit: APPROVED_DESIGN_BASELINE
```

## 1. 目标

在改 Solidity 前冻结跨合约设计，避免 CostBasis、Staking、Token 和 Router 分别修复后互相冲突。本阶段只生成设计候选文档，不修改合约、接口、测试或部署脚本。

## 2. Allowed Paths

```text
docs/current/go-backend-v2/contracts/remediation/evidence/S0_*.md
```

## 3. 必须形成的设计决策

### 3.1 CostBasis 双账本

推荐模型：每个账户内部同时保存：

```text
knownBalance
knownCostWbnbWei
unknownBalance

actual ERC20 balance == knownBalance + unknownBalance
knownBalance == 0 => knownCostWbnbWei == 0
```

该等式只适用于 `CostBasis-eligible liquid user account`。Pair、System、Router、FeeVault、Staking custody、Locker 和其他协议托管地址不使用普通用户账本，由各自资金守恒不变量覆盖。Staking position lot 不计入用户 liquid ERC20 balance。

必须冻结：

- UNKNOWN 输入不能删除既有 KNOWN 成本；
- UNKNOWN Token 不能使用 KNOWN 成本逃税；
- 推荐 transfer/sell 都优先消费 UNKNOWN，再按比例消费 KNOWN；
- KNOWN 的成本使用 proportional floor，完整消费时迁移全部剩余成本；
- Dividend 和 Staking Reward 作为零成本 KNOWN 输入，不能污染已有成本；
- legacy `NONE/KNOWN/UNKNOWN` view 如何从双账本派生；
- mixed position 的 Preview/Execute 如何公开分项数据；
- 拆分转账和拆分卖出不能增加总成本或降低应缴税。

必须冻结可验证的舍入规范：

- 利润分类不得直接依赖已经向下取整的 proportional cost；推荐使用 overflow-safe 的精确有理数比较：`knownQuote * knownBalance` 与 `knownCost * knownSold`；
- 成本消费的 remainder 留在剩余 known position，完整退出消费全部剩余成本；
- 在相同起始账本和相同 Oracle 价格快照下，等价拆分不能比 canonical unsplit execution 获得更低 aggregate tax；
- 必须给出明确的 wei 级容差。默认不允许因为分类跨越 4%/10% 边界产生可盈利容差；
- 如果 proportional floor 无法满足，设计必须引入 carry/remainder 或其他确定性方法，而不是把差异留给测试解释。

若不采用该模型，必须证明替代方案同时阻止：灰尘污染、UNKNOWN 成本屏蔽、拆分舍入套利和实际余额失配。

### 3.2 Mixed Sell 税费

冻结以下分项：

```text
unknownSold → 9% Support + 1% Burn
knownSold and TWAP <= proportional known cost → 4% Support
knownSold and TWAP > proportional known cost → 9% Support + 1% Burn
```

同一笔 mixed sell 必须允许不同部分采用不同税率，再汇总 support、burn 和 swapTokens。禁止把 1 wei UNKNOWN 扩大成全仓 10%，也禁止把 UNKNOWN 合并进 KNOWN 成本。

必须冻结 Preview revision/quoteBlock 的唯一语义，S0 未选择前不得进入 S2：

```text
Option A — diagnostic only:
execute 始终重算 live CostBasis/Oracle，用户通过 deadline、minimumOut 和明确的 maximum protocol deduction 约束经济结果。

Option B — optimistic lock:
用户提交 expected CostBasis revision/quote constraint，任何不匹配都回滚。
```

不得同时把 revision 当展示字段和隐式执行锁。若选择 Option A，必须冻结 `maximumTax/maxSupport/maxBurn/minSwapTokens` 中至少一种足以限制协议扣减的用户保护；若选择 Option B，必须评估灰尘导致 revision 变化的 griefing 风险。

当前目标源码的 canonical 控制面必须在 S0 证据中重新确认并固定：

```text
WHITELIST_CANONICAL_CONTRACT = Pangu2Token
WHITELIST_STORAGE = Pangu2Token.feeWhitelist
WHITELIST_ADMIN_ROLE = GOVERNANCE_ROLE
TRADING_GATE_SOURCE = Pangu2Token.tradingOpenAt
LAUNCH_STATE_SOURCE = Pangu2Token.isInLaunchProtection
BUY_RATE_SOURCE = Pangu2Token.resolveBuyTaxBps
SELL_RATE_SOURCE = Pangu2Token.resolveSellTaxBps
ZERO_TAX_EXECUTION = TradeRouter → Pangu2Token.settleBuy/settleSell
```

如果执行阶段目标 SHA 与上述 mapping 不一致，标记 `SOURCE_CODE_VERIFICATION_REQUIRED` 并停止，Implementation Agent不得自行发明另一套 whitelist/launch 架构。

### 3.3 Staking 成本引用

冻结 `account + staking contract + positionId` 唯一引用及以下迁移：

- Stake：液态 known/unknown lot 迁入对应 position；
- Normal Unstake：原比例本金和成本完整迁回；
- Early Unstake：只迁回 net principal 对应 lot；penalty 对应成本作为真实损失移除；
- Reward：零成本 KNOWN；
- positionId 不得重用或迁到其他用户；
- Token hook 必须携带不可混淆的 position reference；
- Staking 不能直接任意修改其他账户 CostBasis。

唯一权威 mutation path 必须冻结为：

```text
Staking 在 transfer 前确定 positionId
→ 调用 typed Token staking entrypoint
→ Token 建立带 stakingContract + account + positionId + operationKind 的认证 context
→ Token 执行余额变化
→ CostBasis 只接受 Token 的单一路径 mutation
→ Token 清除完整 typed context
```

禁止同时由 Staking 直接写 CostBasis、又由 Token hook 重复写；禁止用未类型化或可伪造的 reason bytes 携带 positionId。`STAKING_PRINCIPAL_RETURN` 必须使用相同 typed reference，不能只携带 account/amount。

### 3.4 Staking 奖励

推荐 per-position reward accounting：

- position 记录 reward index、accrued、claimed/closed；
- 锁定期内奖励不可领取；
- normal maturity 后领取；
- early exit 没收该 position 未成熟奖励并返回 available reserve；
- 多个不同锁期 position 不共享可绕过的 account-level claim；
- totalStaked 为 0 时不能产生无人归属 liability；
- actual balance、principal、available reserve、liability 和显式 surplus 守恒。

必须冻结完整状态迁移：

- Normal Unstake 只关闭 principal；已成熟 reward 可以独立领取，不能因本金退出而丢失，也不能重复领取；
- Early principal penalty 固定进入 `availableRewardReserve`，不得进入未记账 surplus；
- Early forfeited reward 执行 `ownedLiability -= forfeited` 且 `availableRewardReserve += forfeited`；
- `totalStaked == 0` 时，已经绑定到具体 position 的 matured liability 仍可存在；不得继续产生无人归属的新 emission；
- global reward index 的除法 dust 必须进入显式 `roundingLiability/surplus`，并在 period close/no-staker 路径确定性返回 reserve；
- position 至少区分 `principalClosed` 与 `rewardClaimedOrForfeited`，避免 normal exit 后奖励丢失。

冻结恒等式：

```text
stakingTokenBalance
= activePrincipal
+ availableRewardReserve
+ ownedAccruedRewardLiability
+ explicitRoundingOrSurplus
```

若保留 account-level reward，必须给出能阻止 `claim→earlyUnstake` 和多 position 混淆的完整证明。

### 3.5 Pause 策略

冻结 Staking 专用暂停语义：

- Pause 阻止新增 Stake、Reward Claim、Funding 和非零 rate 更新；
- `setRewardRate(0)` 必须能用于事故止损；
- 是否允许 normal/early principal exit 必须明确，推荐 Staking 单独暂停时仍允许本金退出；
- Token 全局 pause 仍可作为更强事故措施；
- PAUSER_ROLE 和 UNPAUSER_ROLE 必须是独立角色。

### 3.6 Support/Dividend/Oracle/合约账户

- 固定回购仍为 0.01 BNB；修复目标是准确预检价格冲击，不是自动缩小金额；
- Dividend 默认只能在 claimEnd 后取消；若要 emergency pre-start cancel，必须用户单独批准；
- Oracle 采用 uint32 modular elapsed，不削弱 1800 秒窗口、300 bps 偏差或最低储备；
- 合约账户策略必须保持直接 Pair/未授权 Router 防绕过。推荐治理预登记 approved user contract；如果选择保留现状，必须由用户签署 `ACCEPTED_DEVIATION`。

若选择 approved user contract，S0 必须冻结生命周期：

```text
NONE → APPROVED → EXIT_ONLY/GRACE → REVOKED
```

- approved user contract 与 System、Pair、Settlement、Liquidity Manager、Fee Whitelist 完全正交；
- `APPROVED → REVOKED` 不得立即锁死已有余额；先进入 EXIT_ONLY，只允许转出/官方卖出，禁止新增接收/买入；
- 余额归零并满足宽限条件后才能完成 REVOKED；
- counterfactual registration 必须冻结授权主体以及 trusted factory、initCodeHash 或 expected code identity 约束；
- Direct Pair 永远 fail-closed；approved user contract 不获得任何 context 或协议调用权限。

如果无法冻结该状态机，S8A 必须为 `BLOCKED_DECISION`，或由用户本人签署 `ACCEPTED_DEVIATION`。

### 3.7 ABI 和版本

列出所有拟新增/变更：

- structs；
- external/public functions；
- interfaces；
- events/errors；
- context kinds；
- legacy view compatibility；
- DApp/Backend 将来需要适配的 ABI，但本阶段不修改应用。

## 4. 必须定义的不变量

至少包括：

```text
CB-INV-01 for each eligible liquid user: actualBalance = knownBalance + unknownBalance
CB-INV-02 transfer cannot increase aggregate known cost
CB-INV-03 unknown input cannot reduce recipient known cost
CB-INV-04 unknown tokens cannot consume known cost
CB-INV-05 equivalent split actions cannot lower canonical aggregate tax under the same quote snapshot
SELL-INV-01 preview components sum to execute settlement
SELL-INV-02 support + burn + swapTokens = sellAmount
STK-INV-01 liquid lots + staked lots conserve principal lots
STK-INV-02 actual staking balance covers principal + reward liabilities
STK-INV-03 locked reward cannot be claimed before maturity
STK-INV-04 forfeited reward returns to available reserve
STK-INV-05 only Token may mutate CostBasis under an authenticated typed position context
STK-INV-06 no new unowned reward liability accrues while totalStaked = 0
FEE-INV-01 actual FeeVault balance covers both buckets
DIV-INV-01 reserved + claimed + carry conservation
```

## 5. 审核与退出

1. 实现 Agent提交设计文档 Commit。
2. 独立审核 Agent检查经济基线、攻击路径和可实现性。
3. 校对 Agent逐条确认审核结论。
4. 修订所有 CONFIRMED 问题并复审。

退出条件：

```text
DESIGN_VERDICT = APPROVED_DESIGN_BASELINE
ECONOMIC_BASELINE_CHANGED = NO
UNRESOLVED_P0_P1_P2_DECISIONS = 0
S1_ALLOWED = YES
```


---

## FILE: remediation/stages/S1_COST_BASIS_DUAL_LEDGER.md

# S1 — CostBasis 双账本与安全转账

```text
Stage ID: PANGU2-V2-S1
Findings: P1-CB-01 (part 1/2)
Prerequisite: S0 APPROVED_DESIGN_BASELINE
Macro Gate: none; M1 occurs after S2
```

## 1. 目标

实现 S0 冻结的 known/unknown 双账本和安全转账规则，使 UNKNOWN 灰尘只影响其自身数量，不能覆盖接收方已有 KNOWN 成本，也不能使用 KNOWN 成本逃税。

本阶段不修改 Token/Router 的混合卖出结算；S1 Commit 是中间开发候选，不得标记为可部署版本。

## 2. Allowed Paths

```text
contracts-v2/src/CostBasisManager.sol
contracts-v2/src/interfaces/ICostBasisManager.sol
contracts-v2/src/libraries/CostMath.sol（仅在确有必要时）
contracts-v2/test/*CostBasis*.t.sol
contracts-v2/test/*Invariant*.t.sol
remediation/evidence/S1_*.md
```

Forbidden：Token、Router、Staking、FeeVault、部署脚本、V3 `contracts/src/**` 及应用代码。

## 3. 实现步骤

1. 在不改变冻结税率的前提下引入 account lot 数据：known balance/cost、unknown balance。
2. 为 legacy `positionOf` 等 view 定义兼容派生语义；不得让旧调用方静默得到虚假 KNOWN。
3. 重写 `onUserTransfer()`：
   - 基于 transfer 后实际余额验证 source/recipient；
   - 按 S0 冻结顺序拆分 unknown/known transfer；
   - recipient 分别增加 unknown 和 known lot；
   - 完整 known transfer 迁移全部剩余成本；部分 transfer 使用 proportional floor；
   - source 余额归零时清零所有成本；
   - 不把接收方已有 KNOWN 改写为 UNKNOWN。
4. 更新 `recordBuy()`：只增加 known lot 和真实 WBNB cost。
5. 更新 `recordZeroCost()`：增加零成本 known lot，不删除原成本。
6. 更新 `onSystemCreditUnknown()`：只增加 unknown lot。
7. 保持遗留 LP tokenId 逻辑不变，除非接口编译必须适配；禁止趁机重写 LP 模型。
8. 为 lot 变化增加足够事件：旧值、新值、known cost、unknown amount、reason；不得泄漏成只有聚合 status 的不可追溯事件。
9. 所有 external hook 保持严格调用者校验、零地址和零金额规则。

## 4. 必须验证的攻击路径

- UNKNOWN 地址向已有 KNOWN 余额地址发送 1 wei；接收方 known cost 不变，只有 1 wei unknown。
- UNKNOWN 大额转入 KNOWN，不得获得 KNOWN 成本。
- KNOWN→KNOWN 完整/部分迁移。
- KNOWN→UNKNOWN/mixed 接收方的 lot 分离。
- 拆成 N 次转账和一次转账不能增加 aggregate known cost。
- 在相同 Oracle/账本快照下，拆分行为不能因 proportional floor 把 4%/10% 分类变成更低 aggregate tax；利润分类使用 S0 冻结的精确比较。
- source 实际余额和账本不一致时 fail-closed，但不能无条件删除无关接收方成本。
- zero-cost Token 转入已有 known/mixed 地址。

## 5. 测试要求

至少新增：

- Unit：所有 lot 转换矩阵；
- Fuzz：随机 known/unknown 数量、部分转账、多个接收方；
- Invariant：实际余额守恒、成本不增加、unknown 不消耗 known cost；
- 回归：原 KNOWN→KNOWN 成本比例迁移；
- AccessControl：普通用户不能直接 record/consume/hook。

若 Forge 不可用，记录 `NOT_RUN`，但阶段不能因测试源码存在而称 PASS。

## 6. 阶段审核重点

- 舍入是否可通过拆分增加成本；
- actual balance 的 before/after 推导是否在 Token hook 时序下正确；
- 双方为同一地址、零数量、全部余额、余额不一致等边界；
- 存储升级无意义：这是新地址候选，不得设计成对旧地址原地升级；
- 接口改变是否为 S2 留出 mixed sell 分项。

## 7. 退出条件

```text
P1-CB-01_LEDGER = CLOSED_CODE_ONLY
P1-CB-01_SETTLEMENT = OPEN_UNTIL_S2
IMPLEMENTATION_COMMIT_SHA = full 40-char SHA
CORE_SOLIDITY_BUILD = PASS
INTERFACE_IMPLEMENTATION_MATCH = PASS
COMPILE_ERRORS = 0
UNIT/FUZZ/INVARIANT = PASS or explicitly NOT_RUN
INDEPENDENT_REVIEW = APPROVED_CODE_ONLY
REVIEW_VERDICT_CONFIRMED = YES
S2_ALLOWED = YES only if CORE_SOLIDITY_BUILD = PASS
DEPLOYMENT_APPROVAL = NOT_GRANTED
```


---

## FILE: remediation/stages/S2_TOKEN_ROUTER_MIXED_SETTLEMENT_AND_WHITELIST.md

# S2 — Token/Router Mixed Sell 结算与 Whitelist 零税修复

```text
Stage ID: PANGU2-V2-S2
Findings: P1-CB-01 (part 2/2), P2-TAX-01
Prerequisite: S1 APPROVED_CODE_ONLY
Macro Gate: M1 PRIORITY_FULL_AUDIT REQUIRED
```

## 1. 目标

把 S1 双账本接入 Preview、Consume 和实际 Token settlement；同一笔 mixed sell 对 unknown、known-profit、known-nonprofit 分项计税。同时修复 whitelist 零税仍调用 `FeeVault.credit(0)` 的执行回滚。

## 2. Allowed Paths

```text
contracts-v2/src/Pangu2Token.sol
contracts-v2/src/Pangu2TradeRouter.sol
contracts-v2/src/CostBasisManager.sol
contracts-v2/src/interfaces/IPangu2Token.sol
contracts-v2/src/interfaces/IPangu2TradeRouter.sol
contracts-v2/src/interfaces/ICostBasisManager.sol
contracts-v2/src/libraries/CostMath.sol（仅必要时）
contracts-v2/test/*TradeRouter*.t.sol
contracts-v2/test/*Tax*.t.sol
contracts-v2/test/*CostBasis*.t.sol
contracts-v2/test/*Invariant*.t.sol
remediation/evidence/S2_*.md
```

Forbidden：Staking、SupportPool、Dividend、Oracle、部署脚本、应用代码。

## 3. Mixed Sell 实现要求

1. Preview 必须返回至少：
   - unknown sold；
   - known sold；
   - proportional known cost；
   - known TWAP quote；
   - support amount；
   - burn amount；
   - swapTokens；
   - S0 已冻结语义的 CostBasis revision/quote constraint 或 diagnostic 字段。
2. UNKNOWN 部分固定 10% 路径；KNOWN 部分只用其自身 quote 与 proportional cost 比较。
3. 不允许 1 wei unknown 把全部卖出量变成 10%。
4. 不允许 mixed position 把 unknown quote 与 known cost 比较从而降低税率。
5. `support + burn + swapTokens == sellAmount`，每个组成部分由 `FullMath.mulDiv` 或明确舍入规则计算。
6. Preview 和 Execute 使用同一 seller，而不是 `msg.sender`/recipient 混淆。
7. Execute 必须在当前交易中重新验证 CostBasis 和 Oracle；前端 preview 不能作为可信税额输入。
8. quote block、deadline、minimumOut 和 maximum 5 分钟窗口继续有效。
9. CostBasis consume 与 Token transfer/settlement 必须原子化；任何 Adapter/FeeVault/BNB payout 失败都回滚成本消费。
10. 10% 路径只 swap 90%，1% burn 和 9% support 各扣一次。
11. 必须严格实现 S0 选择的 Preview 语义：diagnostic live-recompute 路径必须有显式 maximum protocol deduction；optimistic-lock 路径必须校验 expected revision/quote constraint。

## 4. Whitelist 修复要求

1. 继续保持优先级：Trading Gate → Whitelist → Launch → Normal。
2. Whitelist buy/sell 税费为 0，但仍必须通过 Trading Gate、Pause、deadline、minimumOut、Pair/System 和 Adapter 安全检查。
3. 当 tax/support/burn 为 0 时，Token 跳过对应零额 transfer 和 `FeeVault.credit()` 调用。
4. FeeVault 不需要为了该修复接受任意异常零额记账；优先在 Token 调用点跳过。
5. Preview 与真实 buy/sell 都必须覆盖 whitelist。
6. 重新核验并记录 canonical source：whitelist/trading/launch 存储和 rate resolver 均来自目标 Commit 的 Pangu2Token；若不一致停止并标记 `SOURCE_CODE_VERIFICATION_REQUIRED`。

## 5. 测试要求

- 1 wei unknown + 大额 known 的 mixed sell；只对 1 wei 部分使用 UNKNOWN 税率。
- mixed known profit/nonprofit 边界：TWAP 等于、低于、高于 proportional cost。
- 拆分 sell 与一次 sell 的成本/税费一致性，允许明确的向上取整差但不得可盈利。
- whitelist buy/sell 真实经过 Router、Token、FeeVault，不允许只测 preview。
- whitelist 在 pre-open、paused、launch、deadline 过期、minOut 不足时仍 fail-closed。
- 4%、10%、30%、0% 的完整 Tax Matrix。
- Fuzz：mixed balances、Oracle quote、部分 sell。
- Invariant：settlement 守恒、CostBasis consume 不增加成本、Preview/Execute 组件一致。

## 6. M1 优先全量代码审核

阶段复审批准后，立即使用 `02_REVIEW_WORKFLOW_AND_PROMPTS.md` 的 PRIORITY_FULL_AUDIT 提示词执行 M1。

M1 必须逐行阅读全部 `contracts-v2/src/**`，重点检查：

- 新 CostBasis 接口对 Dividend、Staking、Locker、LP 遗留路径的影响；
- Token `_update` Context 和 direct Pair 防绕过；
- Router buy/sell、refund、approval、BNB payout 和重入；
- FeeVault bucket credit 是否仍守恒；
- 税率优先级和全部冻结参数；
- ABI/接口/构造关系的代码层可部署性。

M1 不审核本地部署脚本执行、RPC 或广播。

## 7. 退出条件

```text
P1-CB-01 = CLOSED_CODE_ONLY
P2-TAX-01 = CLOSED_CODE_ONLY
STAGE_REVIEW = APPROVED_CODE_ONLY
M1_PRIORITY_FULL_AUDIT = APPROVED_CODE_ONLY
M1_BASELINE_COMPLIANCE = PASS
M1_CODE_DEPLOYABILITY = YES
IMPLEMENTATION_COMMIT_SHA = full 40-char SHA
CORE_SOLIDITY_BUILD = PASS
INTERFACE_IMPLEMENTATION_MATCH = PASS
COMPILE_ERRORS = 0
S3_ALLOWED = YES
DEPLOYMENT_OR_RUNTIME_APPROVAL = NOT_GRANTED
MAINNET = NO-GO
```


---

## FILE: remediation/stages/S3_STAKING_COST_BASIS_BRIDGE.md

# S3 — Staking 本金 CostBasis 迁移闭环

```text
Stage ID: PANGU2-V2-S3
Findings: P1-STK-01
Prerequisite: M1 APPROVED_CODE_ONLY
Macro Gate: none; M2 occurs after S4B
```

## 1. 目标

为每个 Staking position 建立不可混淆的成本引用，使 Stake、正常退出、提前退出和 Reward credit 都能保持 CostBasis 一致。该阶段只修本金/成本桥；奖励成熟与没收规则在 S4A 完成，暂停策略在 S4B 完成。

## 2. Allowed Paths

```text
contracts-v2/src/Pangu2Token.sol
contracts-v2/src/CostBasisManager.sol
contracts-v2/src/Pangu2Staking.sol
contracts-v2/src/interfaces/IPangu2Token.sol
contracts-v2/src/interfaces/ICostBasisManager.sol
contracts-v2/src/interfaces/IPangu2Staking.sol
contracts-v2/src/libraries/TransferContext.sol
contracts-v2/test/*Staking*.t.sol
contracts-v2/test/*CostBasis*.t.sol
contracts-v2/test/*Invariant*.t.sol
remediation/evidence/S3_*.md
```

Forbidden：Router 税率逻辑、Support、Dividend、Oracle、部署脚本和应用代码。

## 3. 实现要求

### 3.1 Position 引用

- 在发生 Token transfer 前确定唯一 `positionId` 或 position key；
- key 至少绑定 chain-local Staking address、account、positionId；
- positionId 不得重复绑定、跨用户迁移或在关闭后重用；
- Token hook 不能仅凭可伪造的 reason bytes 修改任意 position。

唯一 mutation authority 必须严格实现为：

```text
Staking creates/reserves positionId before transfer
→ typed Token entrypoint authenticates msg.sender as configured Staking
→ Token context binds stakingContract + account + positionId + operationKind
→ Token changes ERC20 balances
→ CostBasisManager mutates only through an onlyToken hook
→ Token clears every typed context field before returning
```

Staking 不得直接调用 CostBasis mutation；Token hook 与显式调用不得双重记账。`STAKING_PRINCIPAL_RETURN` 和 Reward 也必须走 typed entrypoint，不得退化为只有 `to/amount/kind` 的无 position reference 路径。

### 3.2 Stake

- `stakingDeposit` 只允许已配置 Staking 调用；
- 从用户液态双账本按 S0 规则迁出 known/unknown lot；
- 将迁出的 known balance/cost、unknown balance 绑定到 position；
- Staking 实际收到数量必须与 CostBasis 记录一致；
- 任一检查失败，Token transfer、Staking position 和 CostBasis 全部回滚。

### 3.3 Normal Unstake

- 只能返回调用者自己的、未关闭、已到期 position；
- 将 position 剩余 principal lot 和 known cost 全部迁回用户；
- 迁回后 position 成本账本归零并永久关闭；
- 不得把本金返还标成 UNKNOWN 或零成本。

### 3.4 Early Unstake

- 10% penalty 基于 position principal 计算；
- net principal 对应的 known/unknown lot 和 known cost 按比例迁回；
- penalty 对应成本从用户经济成本中移除，不得转成未来领取人的历史成本；
- 完整退出时 position 所有 lot 清零；
- 舍入剩余必须有确定归属，不能留下 `balance=0, cost>0`。

### 3.5 Reward

- 为 S4A 预留或实现明确的 `STAKING_REWARD` zero-cost hook；
- Reward 增加用户零成本 known balance，不覆盖原 known/unknown lot；
- 普通 Staking 合约不能调用该 hook 给任意账户伪造本金成本。

### 3.6 事件和权限

事件至少绑定 account、staking contract、positionId、token amount、known cost、unknown amount、操作类型。所有新 external hook 必须有 caller、零地址、amount 和 position state 校验。

## 4. 测试要求

- KNOWN Stake→normal exit→sell，成本恢复且税率正确；
- UNKNOWN、mixed Stake→normal exit；
- KNOWN/mixed Early Unstake，net lot 与 penalty cost 正确；
- Reward credit 不改变既有成本；
- 多 position 不串位；跨用户 positionId 攻击失败；重复退出失败；
- transfer/CostBasis/Staking 任一步 revert 时全局回滚；
- Fuzz：amount、lock、known/unknown 组合和舍入；
- Invariant：liquid lots + active staking lots 守恒，关闭 position 无残余成本。

测试必须使用真实 CostBasisManager，不得用空 hook Mock 作为关闭证据。

## 5. 阶段审核重点

- Token `_update` 和显式 staking function 是否双重记账；
- hook 在 transfer 前后读取实际余额的时序；
- Staking 重入保护和 Token external hook 回调；
- position 状态是否先 effects 后 interaction，并在 revert 时原子回滚；
- reward zero-cost 是否可能成为低权限伪造 KNOWN 的入口；
- 旧 V3 LP tokenId 代码没有被误改。

## 6. 退出条件

```text
P1-STK-01 = CLOSED_CODE_ONLY
IMPLEMENTATION_COMMIT_SHA = full 40-char SHA
CORE_SOLIDITY_BUILD = PASS
INTERFACE_IMPLEMENTATION_MATCH = PASS
COMPILE_ERRORS = 0
REAL_COST_BASIS_INTEGRATION_TEST = PASS or NOT_RUN_WITH_BLOCKER
INDEPENDENT_REVIEW = APPROVED_CODE_ONLY
REVIEW_VERDICT_CONFIRMED = YES
S4A_ALLOWED = YES only if CORE_SOLIDITY_BUILD = PASS
DEPLOYMENT_APPROVAL = NOT_GRANTED
```


---

## FILE: remediation/stages/S4A_STAKING_REWARD_EXIT.md

# S4A — Staking Per-Position 奖励与退出会计

```text
Stage ID: PANGU2-V2-S4A
Findings: P1-STK-02, P2-STK-03
Prerequisite: S3 APPROVED_CODE_ONLY
Macro Gate: none; M2 occurs after S4B
```

## 1. 目标

将奖励归属到具体 position，阻止锁定期内先领取再提前退出；把没收奖励和本金 penalty 正确记入 available reserve；冻结 normal exit、no-staker 和 reward dust 的完整会计。暂停控制不在本阶段实现，由 S4B 单独处理。

## 2. Allowed Paths

```text
contracts-v2/src/Pangu2Staking.sol
contracts-v2/src/interfaces/IPangu2Staking.sol
contracts-v2/src/Pangu2Token.sol（仅 reward typed context 适配确有必要时）
contracts-v2/src/CostBasisManager.sol（仅 zero-cost reward hook 适配确有必要时）
contracts-v2/test/*Staking*.t.sol
contracts-v2/test/*Invariant*.t.sol
remediation/evidence/S4A_*.md
```

不得在本阶段新增 Pausable/角色，不得重新修改 S2 税费或 S3 principal lot 规则。需要扩大范围时标记 `SCOPE_EXPANSION_REQUIRED`。

## 3. Per-Position Reward 要求

1. 奖励必须可归因到具体 position；不得继续使用可在锁定期提前领取的 account-level bucket 混合不同锁期。
2. 每个 position 至少记录 reward index、accrued reward、`principalClosed`、`rewardClaimedOrForfeited`。
3. stake、claim、normal exit、early exit 前先更新 global index 和目标 position reward。
4. 锁定期内不可领取该 position 奖励。
5. 到期后允许 position-level claim；重复 claim 不得重复付款。
6. Normal Unstake 只关闭 principal；已经成熟的奖励保持独立可领取，不能因为本金退出而丢失，也不能再次累积本金奖励。
7. Early Unstake：
   - 计算该 position 全部未成熟/未领取奖励；
   - `ownedAccruedRewardLiability -= forfeitedReward`；
   - `availableRewardReserve += forfeitedReward`；
   - 不向用户支付该奖励；
   - 不影响其他 position。
8. 10% principal penalty 固定加入 `availableRewardReserve`；其历史 CostBasis 按 S3 规则作为经济损失移除。
9. `totalStaked == 0` 时停止产生无人归属的新 emission；已经绑定 position 的成熟 liability 仍可领取。
10. global index 除法 dust 必须进入显式 rounding liability/surplus，并按 S0 规则确定性返回 reserve，不能形成永久账外 Token。
11. `fundRewards()` 继续使用实际到账余额差；reward-rate cap 数值不变。
12. 所有 reward payment 使用 S3 的 typed zero-cost hook，不得直接污染用户 CostBasis。

## 4. 资金恒等式

每次状态改变后必须满足：

```text
stakingTokenBalance
= activePrincipal
+ availableRewardReserve
+ ownedAccruedRewardLiability
+ explicitRoundingOrSurplus
```

所有右侧 bucket 都必须可追溯；禁止使用“实际余额更多所以仍然 solvency”掩盖账外余额。

## 5. 测试要求

- `accrue→claim before unlock` 必须 revert；
- `accrue→earlyUnstake`：reward 和 penalty 都进入 reserve；
- 多 position 不同锁期：到期 position 可领取，未到期 position 不可领取；
- normal principal exit 后成熟 reward 仍能且只能领取一次；
- claim 后重复 claim、exit 后 claim、重复 exit；
- no staker、periodFinish、rate=0、reserve 恰好覆盖、极小 reward；
- global index rounding dust 和 period close；
- Reward typed context 与真实 CostBasisManager 集成；
- 恶意 receiver/reentrant attempt；
- Fuzz：多个 position、时间、rate、funding、claim/exit 顺序；
- Invariant：实际余额恒等式、paid + reserve + owned liability 守恒。

## 6. 阶段审核重点

- position-level reward 是否真正替代旧 account-level claim 路径；
- principalClosed/rewardClosed 两个终态是否独立且不可重复；
- no-staker emission 和 rounding dust；
- S3 typed context、CostBasis 和 Token 时序；
- 旧公开 API 是否留下可绕过的新旧双入口；
- 不得以 Pause 逻辑掩盖奖励状态机问题。

## 7. 退出条件

```text
P1-STK-02 = CLOSED_CODE_ONLY
P2-STK-03 = CLOSED_CODE_ONLY
P1-STK-01_REGRESSION = PASS
IMPLEMENTATION_COMMIT_SHA = full 40-char SHA
CORE_SOLIDITY_BUILD = PASS
INTERFACE_IMPLEMENTATION_MATCH = PASS
COMPILE_ERRORS = 0
INDEPENDENT_REVIEW = APPROVED_CODE_ONLY
REVIEW_VERDICT_CONFIRMED = YES
S4B_ALLOWED = YES only if CORE_SOLIDITY_BUILD = PASS
DEPLOYMENT_APPROVAL = NOT_GRANTED
```



---

## FILE: remediation/stages/S4B_STAKING_PAUSE_AND_EMERGENCY_CONTROL.md

# S4B — Staking 暂停与紧急止损控制

```text
Stage ID: PANGU2-V2-S4B
Findings: Staking Pausable hardening
Prerequisite: S4A APPROVED_CODE_ONLY
Macro Gate: M2 PRIORITY_FULL_AUDIT REQUIRED
```

## 1. 目标

在不重写 S4A reward accounting 的前提下，为 Staking 增加独立 PAUSER/UNPAUSER 控制和可恢复的事故响应语义。本阶段保持本金安全退出，不把 Pause 变成资产锁死机制。

## 2. Allowed Paths

```text
contracts-v2/src/Pangu2Staking.sol
contracts-v2/src/interfaces/IPangu2Staking.sol
contracts-v2/test/*StakingPause*.t.sol
contracts-v2/test/*Staking*.t.sol（仅暂停回归）
remediation/evidence/S4B_*.md
```

禁止修改 CostBasis、Token、Reward 计算、税率和部署脚本。若 constructor 变化造成完整 Build 的 script 签名错误，按 `COMPILE_COMPATIBILITY_EXCEPTION` 处理。

## 3. Pause 语义

默认冻结为：

- 新增独立 `PAUSER_ROLE` 和 `UNPAUSER_ROLE`；
- Pause 阻止新 Stake、Reward Claim、fundRewards 和非零 reward-rate 更新；
- Pause 时允许 `setRewardRate(0)`，用于立即停止未来 emission；
- Staking 单独 Pause 时，normal/early principal exit 继续可用；
- principal exit 必须继续执行 S3 CostBasis typed context 和 S4A reward/forfeiture 会计；
- Token 全局 Pause 可以作为更强措施并阻止 system transfer，但不由本阶段改变；
- Pause、Unpause、Emergency Rate Stop 都发出事件；
- role admin 关系明确，普通 REWARD_MANAGER 不自动获得 Unpause。

若 constructor 参数不足以把角色授予预期地址，保持角色类型和 admin 分离并记录未来部署接线；不得自行修改地址或部署策略。

## 4. 测试要求

- Pause 下 stake/claim/fund/nonzero rate 被阻止；
- Pause 下 `setRewardRate(0)` 成功；
- Pause 下 normal/early principal exit 按设计可用；
- exit 仍正确执行 CostBasis、penalty 和 forfeited reward；
- 只有 PAUSER 能 pause，只有 UNPAUSER 能 unpause；
- 重复 pause/unpause、角色撤销、零地址构造/role 配置；
- Token 全局 Pause 与 Staking Pause 的组合行为；
- Pause 不能绕过 claim maturity 或 position ownership。

## 5. M2 优先全量代码审核

S4B 复审批准后对全部 `contracts-v2/src/**` 执行 M2，重点检查：

- S1/S2 双账本与 S3 position lot、S4A reward 的完整一致性；
- S4B Pause 是否造成永久本金 DoS 或新权限绕过；
- Reward payment 是否污染成本或绕过税率；
- 多 position、舍入、liability 和实际余额；
- Token Context、CostBasis caller 权限和重入；
- Buy/Sell/Dividend/Support 是否受到新接口回归影响；
- 构造、接口和 compile-surface 的代码层可部署性；
- 不审核本地部署执行、RPC、广播或地址接线结果。

## 6. 退出条件

```text
STAKING_PAUSE_POLICY = BASELINE_APPROVED
P1-STK-01/02_REGRESSION = PASS
P2-STK-03_REGRESSION = PASS
IMPLEMENTATION_COMMIT_SHA = full 40-char SHA
CORE_SOLIDITY_BUILD = PASS
INTERFACE_IMPLEMENTATION_MATCH = PASS
COMPILE_ERRORS = 0
STAGE_REVIEW = APPROVED_CODE_ONLY
M2_PRIORITY_FULL_AUDIT = APPROVED_CODE_ONLY
M2_CODE_DEPLOYABILITY = YES
M2_BASELINE_COMPLIANCE = PASS
S5_ALLOWED = YES
DEPLOYMENT_OR_RUNTIME_APPROVAL = NOT_GRANTED
```



---

## FILE: remediation/stages/S5_SUPPORT_BUYBACK_PRICE_IMPACT.md

# S5 — SupportPool 固定回购价格冲击预检

```text
Stage ID: PANGU2-V2-S5
Findings: P2-BBK-01
Prerequisite: M2 APPROVED_CODE_ONLY
Macro Gate: none
```

## 1. 目标

保留固定 0.01 BNB 回购和 60 秒成功间隔，但让 `canExecuteBuyback()` 与 `buyback()` 同时检查真实 V2 储备下的 curve expected output。浅池时应明确返回 PRICE_IMPACT/不可执行，而不是先报告 allowed、再在 swap 中回滚。

## 2. Allowed Paths

```text
contracts-v2/src/SupportPool.sol
contracts-v2/src/adapters/PancakeV2Adapter.sol（仅需要共享可信 quote 时）
contracts-v2/src/interfaces/IPangu2SwapAdapter.sol
contracts-v2/src/interfaces/ISupportPool.sol
contracts-v2/src/libraries/*V2Quote*.sol（如新增最小专用库）
contracts-v2/test/*SupportPool*.t.sol
contracts-v2/test/*PancakeV2Adapter*.t.sol
remediation/evidence/S5_*.md
```

Forbidden：改变 `BUYBACK_AMOUNT`、`MIN_BUYBACK_INTERVAL`、recipient、税率、FeeVault bucket，或修改部署脚本。

## 3. 实现要求

1. 固定读取已绑定 Pair 的 reserves，并正确处理 token0/token1 顺序。
2. 优先复用现有 `PancakeV2Adapter.quoteExactInput()`：它已经绑定 canonical Token/WBNB Pair，并通过固定 Router `getAmountsOut` 报价。只有独立审核证明该接口不满足安全要求时才允许新增专用库；不得扩展为任意 pair/path quote。
3. 继续获取经过验证的 TWAP quote。
4. 计算协议 TWAP minimumOut；如果 curve expectedOut 低于该 floor，状态为不可执行并给出明确 block reason。
5. `canExecuteBuyback()` 和 `buyback()` 必须调用同一内部判断逻辑或严格等价逻辑，避免 preview/execute 漂移。
6. 执行前重新读取储备和 Oracle；旧 view 结果不能作为可信执行授权。
7. deadline、allowance 清零、固定 Locker recipient、actual balance delta、nonReentrant 和 cooldown 规则保持不变。
8. 失败回购不得更新 `lastSuccessfulBuybackAt` 或 buybackCount。
9. 不得自动把 0.01 BNB 缩小成动态金额；这是经济模型变更，除非 S0 有明确用户批准。
10. 增加事件或 view 字段，提供 TWAP quote、curve quote、minimumOut 和拒绝原因，便于链下诊断。

## 4. 测试要求

- 部署基线浅池 `100 PANGU2 / 0.01 WBNB`：`canExecute` 明确不可执行，`buyback` 同原因 fail-closed；
- 足够深储备：view 与 execute 一致并成功进入固定 Locker；
- token0/token1 双方向；
- reserve=0、stale Oracle、deviation、insufficient BNB、cooldown；
- 储备在 view 后变化，execute 重新验证；
- swap revert 不消耗 cooldown、不残留 allowance；
- Fuzz：reserve ratio、amountOut、fee rounding；
- 回归：permissionless trigger 不能选择 recipient 或得到 Token/BNB。

## 5. 阶段审核重点

- curve formula 与 Pancake V2 实现是否一致；
- TWAP 和 curve quote 单位/方向；
- reserve 读取是否可被单块操纵，以及 spot/TWAP deviation 是否仍有效；
- 新 Adapter view 是否暴露任意 pair/path；
- `canExecute` 不得对实际无法执行状态返回 allowed；
- 不把增加流动性误报为代码修复。

## 6. 退出条件

```text
P2-BBK-01 = CLOSED_CODE_ONLY
BUYBACK_AMOUNT = 0.01 BNB
MIN_INTERVAL = 60 seconds
RECIPIENT = BUYBACK_LOCKER
IMPLEMENTATION_COMMIT_SHA = full 40-char SHA
CORE_SOLIDITY_BUILD = PASS
INTERFACE_IMPLEMENTATION_MATCH = PASS
COMPILE_ERRORS = 0
INDEPENDENT_REVIEW = APPROVED_CODE_ONLY
REVIEW_VERDICT_CONFIRMED = YES
S6_ALLOWED = YES only if CORE_SOLIDITY_BUILD = PASS
LIVE_RESERVE_STATUS = NOT_CHECKED_IN_THIS_STAGE
DEPLOYMENT_APPROVAL = NOT_GRANTED
```


---

## FILE: remediation/stages/S6_DIVIDEND_EPOCH_FINALITY.md

# S6 — Dividend Epoch 发布终态和取消边界

```text
Stage ID: PANGU2-V2-S6
Findings: P2-DIV-01
Prerequisite: S5 APPROVED_CODE_ONLY
Macro Gate: none
```

## 1. 目标

确保 Governance 不能在 Published Epoch 的 claimStart 前撤销已经通过两步 commitment 发布的分配。默认只允许 claimEnd 后、且尚无 Claim 的 Epoch 被取消并转入 carry。

## 2. Allowed Paths

```text
contracts-v2/src/DividendDistributor.sol
contracts-v2/src/interfaces/IDividendDistributor.sol
contracts-v2/src/libraries/MerkleLeafV1.sol（仅接口证明确需时，原则上不改）
contracts-v2/test/*Dividend*.t.sol
remediation/evidence/S6_*.md
```

Forbidden：更改 30 天窗口、Merkle leaf schema、commitment 字段、reward token、Governance/Root Publisher 分工或 FeeVault funding。

## 3. 实现要求

1. `cancelUnclaimedEpoch()` 仅在 `block.timestamp > claimEnd` 时允许。
2. 仍要求 status=PUBLISHED 且 `totalClaimed==0`。
3. claimStart 前、claimStart、claimEnd 以及窗口内全部不能取消。
4. Cancel 后状态不可逆，reserved 扣减与 carry 增加必须守恒。
5. 不引入 Governance 直接提取 reserved Token 的路径。
6. 不默认增加 emergency pre-start cancel；如业务要求，必须回到 S0 做独立经济/治理决策，采用不同角色、Timelock、原因和事件。
7. 保持 commitment 绑定 chainId、distributor、epochId、rewardToken、root、amount、snapshot、窗口、schema 和 checksum。
8. 保持 claimed 状态在外部 transfer 前更新和 `nonReentrant`。

## 4. 测试要求

- publish 后、claimStart 前 cancel 必须失败；
- claimStart、claimStart+1、claimEnd、claimEnd+1 精确边界；
- claimEnd 后无 Claim 可取消；已有任意 Claim 不可取消；
- CLOSED/CANCELLED 不可重开或重复取消；
- reserved/claimed/carry 守恒；
- commitment consume/revoke/publish/cancel 组合；
- 跨 chain/distributor/token proof 重放仍失败；
- Fuzz：epoch 时间、amount、claim 顺序；
- Invariant：开放 Epoch reserve 总额等于 `totalReservedClaims`。

## 5. 阶段审核重点

- 时间边界是否 off-by-one；
- 取消是否能在 pause 状态成为治理绕过；
- Root Publisher 与 Governance 权限是否仍分离；
- 新事件是否足够追踪；
- 不把链下 Top 100/分层排名误加入合约逻辑。

## 6. 退出条件

```text
P2-DIV-01 = CLOSED_CODE_ONLY
CLAIM_WINDOW = 30 days
COMMITMENT_SCHEMA_CHANGED = NO
IMPLEMENTATION_COMMIT_SHA = full 40-char SHA
CORE_SOLIDITY_BUILD = PASS
INTERFACE_IMPLEMENTATION_MATCH = PASS
COMPILE_ERRORS = 0
INDEPENDENT_REVIEW = APPROVED_CODE_ONLY
REVIEW_VERDICT_CONFIRMED = YES
S7_ALLOWED = YES only if CORE_SOLIDITY_BUILD = PASS
DEPLOYMENT_APPROVAL = NOT_GRANTED
```


---

## FILE: remediation/stages/S7_ORACLE_UINT32_ROLLOVER.md

# S7 — Pancake V2 Oracle uint32 时间回绕

```text
Stage ID: PANGU2-V2-S7
Findings: P3-ORC-01
Prerequisite: S6 APPROVED_CODE_ONLY
Macro Gate: none
```

## 1. 目标

按照 Pancake V2 累计价格模型的模运算语义处理 uint32 timestamp 回绕，同时保持窗口、最低储备、stale 和 spot/TWAP deviation 全部 fail-closed。

## 2. Allowed Paths

```text
contracts-v2/src/oracle/PancakeV2TwapOracle.sol
contracts-v2/src/interfaces/IPangu2TwapOracle.sol
contracts-v2/src/libraries/*Oracle*.sol（仅必要时）
contracts-v2/test/*Oracle*.t.sol
remediation/evidence/S7_*.md
```

Forbidden：改变 1800 秒 window、300 bps deviation、最低储备、Pair、Token/WBNB 方向或管理权限。

## 3. 实现要求

1. 使用明确的 unchecked uint32 modular subtraction 计算 elapsed；
2. 证明普通时间、刚好回绕和跨回绕后的 elapsed 正确；
3. 与 V2 Pair counterfactual cumulative 的 uint32 语义一致；
4. 不把任意 Pair timestamp ahead 都默认为合法回绕；需要用窗口/stale/状态机约束异常值；
5. cumulative price uint256 overflow 也按 V2 预期语义处理，不能引入 Solidity 0.8 意外 revert；
6. update 仍为 permissionless，频繁调用不能重置未完成窗口；
7. 储备为零、低流动性、quote 为零、spot/TWAP 偏差和超过 5×window stale 继续 fail-closed；
8. token0/token1 双方向 quote 不变。
9. 冻结 long-gap/re-anchor 语义：当 anchor 距当前时间超过允许的最大年龄时，不能悄悄把一个远大于 1800 秒的平均值当作新的标准窗口。推荐重新 anchor 并进入 ACCUMULATING；如果选择长区间完成，必须证明其符合 1800 秒经济基线和 stale 语义。

## 4. 测试要求

- timestamp=`2^32-1` 前后回绕；
- anchor 在回绕前、current 在回绕后；
- elapsed 小于、等于、大于 window；
- stale 5×window 边界跨回绕；
- 超过 5×window 的 long-gap update/re-anchor；
- cumulative uint256 接近 overflow；
- 无 swap、储备变化、低储备、恢复流动性；
- 高频 permissionless update 不阻止 READY；
- bidirectional quote differential；
- Fuzz：uint32 timestamps、reserves、cumulatives。

## 5. 阶段审核重点

- unchecked 范围是否最小且有证明；
- 攻击者是否能伪造“回绕”绕过窗口；
- READY/ACCUMULATING/LIQUIDITY_LOW 恢复路径；
- Math 精度和 quote zero；
- 不得因远期问题削弱当前 Oracle 安全阈值。

## 6. 退出条件

```text
P3-ORC-01 = CLOSED_CODE_ONLY
WINDOW = 1800 seconds
MAX_DEVIATION = 300 bps
MIN_RESERVES_CHANGED = NO
IMPLEMENTATION_COMMIT_SHA = full 40-char SHA
CORE_SOLIDITY_BUILD = PASS
INTERFACE_IMPLEMENTATION_MATCH = PASS
COMPILE_ERRORS = 0
INDEPENDENT_REVIEW = APPROVED_CODE_ONLY
REVIEW_VERDICT_CONFIRMED = YES
S8A_ALLOWED = YES only if CORE_SOLIDITY_BUILD = PASS
DEPLOYMENT_APPROVAL = NOT_GRANTED
```


---

## FILE: remediation/stages/S8A_CONTRACT_ACCOUNT_LIFECYCLE.md

# S8A — 合约账户 Registry、撤销和安全退出生命周期

```text
Stage ID: PANGU2-V2-S8A
Findings: P3-TKN-01 (part 1/2)
Prerequisite: S7 APPROVED_CODE_ONLY
Decision: FIX or USER-SIGNED ACCEPTED_DEVIATION
Macro Gate: none; M3 occurs after S8B
```

## 1. 目标

如果 S0 批准智能钱包兼容修复，本阶段实现 approved user contract 的独立 registry 和不锁资产的撤销生命周期。若用户选择保留 EOA-only，则本阶段只记录签署的 `ACCEPTED_DEVIATION`，Agent不能代签。

本阶段不完成 Direct Pair/Router/Context 的全量攻击回归；该工作由 S8B 隔离执行。

## 2. Allowed Paths

FIX 路径：

```text
contracts-v2/src/Pangu2Token.sol
contracts-v2/src/interfaces/IPangu2Token.sol
contracts-v2/test/*ContractAccount*.t.sol
contracts-v2/test/*Launch*.t.sol（仅 registry 生命周期必要回归）
remediation/evidence/S8A_*.md
```

偏差路径：

```text
remediation/evidence/S8A_ACCEPTED_DEVIATION.md
```

## 3. 生命周期

FIX 路径必须实现 S0 冻结的独立状态机：

```text
NONE → APPROVED → EXIT_ONLY/GRACE → REVOKED
```

规则：

1. `APPROVED` 合约按普通用户参与 transfer/buy/sell、税费和 CostBasis；不获得协议权限。
2. Governance 撤销时先进入 `EXIT_ONLY/GRACE`，不得直接锁死已有 Token。
3. EXIT_ONLY 允许转出和通过官方 Router 卖出现有余额；禁止普通接收和买入新增余额。
4. 余额归零且宽限条件满足后才进入 REVOKED。
5. 状态转换不可跳过、重复或回退；每次转换发出包含 account、old/new state、operator 的事件。
6. approved user contract mapping 与以下状态完全正交：
   - System Address；
   - Pair；
   - Settlement Role；
   - Liquidity Manager；
   - TransferContext allowlist；
   - Fee Whitelist。
7. 已经属于上述协议角色的地址不能登记为普通 user contract；普通 user contract 也不能因此调用 settle/systemTransfer/hook。

## 4. Counterfactual 授权

必须按 S0 冻结结果实现：

- 明确只有哪个 Governance/Registry Role 可预登记；
- 绑定 trusted factory、initCodeHash、expected runtime codehash 或 S0 批准的等价身份；
- 部署后验证实际 code identity，不匹配时不得进入 APPROVED；
- 未部署地址不能利用预登记身份成为未来 Pair/Router 绕过入口；
- 不得提供 permissionless 任意地址自注册。

如果这些条件无法在当前范围内安全实现，停止并输出 `BLOCKED_DECISION`，不得用一个只按 address 的永久 allowlist 代替。

## 5. 测试要求

- NONE→APPROVED→EXIT_ONLY→REVOKED 完整状态机；
- APPROVED 可收、转、买、卖，按普通用户计税和记 CostBasis；
- EXIT_ONLY 不能接收/买入，但能转出/官方卖出直到余额归零；
- Governance 不能让有余额合约直接 REVOKED；
- Pair/System/Settlement/Whitelist 地址不能登记；
- counterfactual identity 匹配和不匹配；
- 未授权调用、重复转换、零地址；
- 事件完整性；
- Fuzz：状态、余额、code deployment 时序。

## 6. 退出条件

FIX 路径：

```text
P3-TKN-01_LIFECYCLE = CLOSED_CODE_ONLY
IMPLEMENTATION_COMMIT_SHA = full 40-char SHA
CORE_SOLIDITY_BUILD = PASS
INTERFACE_IMPLEMENTATION_MATCH = PASS
COMPILE_ERRORS = 0
INDEPENDENT_REVIEW = APPROVED_CODE_ONLY
REVIEW_VERDICT_CONFIRMED = YES
S8B_ALLOWED = YES
```

偏差路径：

```text
P3-TKN-01 = ACCEPTED_DEVIATION
USER_APPROVAL_EVIDENCE = PRESENT
SMART_WALLET_SUPPORT = NO
COUNTERFACTUAL_LOCK_WARNING = DOCUMENTED
CORE_SOLIDITY_BUILD = PASS
S8B_ALLOWED = YES
```

无用户批准时不得使用偏差路径。



---

## FILE: remediation/stages/S8B_CONTRACT_ACCOUNT_BYPASS_REGRESSION.md

# S8B — 合约账户与 Pair/Router/TransferContext 防绕过回归

```text
Stage ID: PANGU2-V2-S8B
Findings: P3-TKN-01 (part 2/2)
Prerequisite: S8A APPROVED_CODE_ONLY or USER-SIGNED ACCEPTED_DEVIATION
Macro Gate: M3 PRIORITY_FULL_AUDIT REQUIRED
```

## 1. 目标

独立验证 S8A 的 registry/lifecycle 没有削弱 Launch Protection、直接 Pair 禁令、Router settlement、TransferContext 或角色边界。若 S8A 采用偏差路径，本阶段验证保留的 EOA-only 防线没有因前序阶段回归。

## 2. Allowed Paths

```text
contracts-v2/src/Pangu2Token.sol（只修复本阶段确认的 bypass）
contracts-v2/src/Pangu2TradeRouter.sol（只修复本阶段确认的 bypass）
contracts-v2/src/libraries/TransferContext.sol（只修复本阶段确认的 bypass）
contracts-v2/src/interfaces/IPangu2Token.sol
contracts-v2/test/*ContractAccount*.t.sol
contracts-v2/test/*TransferContext*.t.sol
contracts-v2/test/*Launch*.t.sol
contracts-v2/test/*TradeRouter*.t.sol
contracts-v2/test/*Invariant*.t.sol
remediation/evidence/S8B_*.md
```

不得增加任意 target/path/call，不能把 approved user contract 变成 system address。

## 3. 必须验证的攻击路径

- approved/EXIT_ONLY 合约不能直接向 Pair 转账或直接调用 Pair swap 绕过 settle；
- 未登记 CREATE2 Pair、恶意 Router、伪 Safe、callback receiver 不能绕过税费；
- approved contract 不能调用 `systemTransfer`、`settleBuy/settleSell`、CostBasis hooks 或建立 TransferContext；
- approved contract 买卖使用自身真实 buyer/seller 参与 whitelist/launch/normal 税率判断；
- Pair/System/approved 状态不能重叠；
- Registry revoke/grace 不得被用作临时免税或清除 CostBasis；
- 用户向 counterfactual address 转账、部署匹配/不匹配代码后的行为；
- `msg.sender`、from、to、context operator 不可混淆；
- Pause、Trading Gate 和 Launch 15 分钟窗口仍生效；
- S1/S2 mixed CostBasis 与合约账户行为一致。

## 4. 测试要求

- 真实 Token/Router/CostBasis 集成，不使用空 hook Mock 关闭 Finding；
- APPROVED、EXIT_ONLY、REVOKED 与 EOA 的差分测试；
- 直接 Pair、其他 Router、delegate/callback 组合攻击；
- whitelist、launch、paused、pre-open 组合矩阵；
- Fuzz：角色/状态、transfer direction、mixed lot、pair/system 地址；
- Invariant：只有 Settlement 路径能完成用户交易；approved user contract 永远没有协议权限。

## 5. M3 优先全量代码审核

S8B 复审批准后逐行审核全部 `contracts-v2/src/**`，覆盖：

- S5 Support curve preflight 与 FeeVault/Adapter/Locker；
- S6 Epoch finality 与 FeeVault funding/CostBasis claim；
- S7 Oracle rollover/long-gap 与 Router/FeeVault/Support consumers；
- S8A/S8B contract lifecycle 与 Token/Router/Pair 防绕过；
- M1/M2 已关闭 Finding 是否出现回归；
- 全部权限、Pause、事件、ABI 和冻结经济参数；
- mandatory Build、interface match 和代码层可部署性；
- 不审核实际部署流程、地址、RPC、广播或迁移执行。

## 6. 退出条件

```text
P3-TKN-01 = CLOSED_CODE_ONLY or USER-SIGNED ACCEPTED_DEVIATION
DIRECT_PAIR_BYPASS = NOT_FOUND
IMPLEMENTATION_COMMIT_SHA = full 40-char SHA
CORE_SOLIDITY_BUILD = PASS
INTERFACE_IMPLEMENTATION_MATCH = PASS
COMPILE_ERRORS = 0
STAGE_REVIEW = APPROVED_CODE_ONLY
M3_PRIORITY_FULL_AUDIT = APPROVED_CODE_ONLY
M3_CODE_DEPLOYABILITY = YES
M3_BASELINE_COMPLIANCE = PASS
S9_ALLOWED = YES
DEPLOYMENT_OR_RUNTIME_APPROVAL = NOT_GRANTED
```



---

## FILE: remediation/stages/S9_FINAL_CODE_EXIT_GATE.md

# S9 — PANGU2 V2 最终代码退出门

```text
Stage ID: PANGU2-V2-S9
Type: FINAL_CODE_GATE
Prerequisite: M1 + M2 + M3 APPROVED_CODE_ONLY
New Features: FORBIDDEN
Deployment/RPC/Fork: OUT_OF_SCOPE
Mainnet: NO-GO
```

## 1. 目标

对修复后的完整 `contracts-v2/src/**` 做最终代码级闭环：确认所有原 Finding 已关闭、没有跨阶段回归、经济基线未变化，并判断未来候选代码是否具备进入“独立部署/迁移规划阶段”的资格。

本阶段不能授予实际部署批准。

## 2. Allowed Paths

默认只允许：

```text
contracts-v2/src/**（仅修复最终审核 CONFIRMED Finding）
contracts-v2/test/**
docs/current/go-backend-v2/contracts/remediation/evidence/S9_*.md
```

禁止修改广播、应用、Backend、数据库、V3 `contracts/src/**` 或经济基线文档。部署脚本默认只读；若 approved ABI/constructor 改动导致完整 Build 仅因脚本签名不兼容失败，只能按 README 的 `COMPILE_COMPATIBILITY_EXCEPTION` 单独申请、单独 Commit 和单独审核。不得把该例外扩展为部署执行审核。

## 3. 最终静态审核范围

必须逐行阅读：

```text
contracts-v2/src/Pangu2Token.sol
contracts-v2/src/Pangu2TradeRouter.sol
contracts-v2/src/CostBasisManager.sol
contracts-v2/src/FeeVault.sol
contracts-v2/src/SupportPool.sol
contracts-v2/src/BuybackLocker.sol
contracts-v2/src/DividendDistributor.sol
contracts-v2/src/Pangu2Staking.sol
contracts-v2/src/GovernanceAdapter.sol
contracts-v2/src/adapters/PancakeV2Adapter.sol
contracts-v2/src/oracle/PancakeV2TwapOracle.sol
contracts-v2/src/interfaces/**
contracts-v2/src/libraries/**
```

必须重新扫描：

- `tx.origin`、`delegatecall`、`selfdestruct`、Proxy/upgrade、硬编码秘密；
- 所有 external/public 权限；
- Reentrancy、CEI 和低级调用；
- SafeERC20、FullMath、downcast、舍入；
- TransferContext、Epoch、Staking position、Oracle 状态机；
- Pause/Unpause 分离；
- 构造、零地址、code check、immutable 和一次性配置；
- 事件和链上溯源字段；
- Rescue/withdraw/任意 target/selector；
- ABI 和 interface 实现一致性。

## 4. 原 Finding 重放

逐条重放并输出证据：

```text
P1-CB-01 UNKNOWN dust
P1-STK-01 staking cost return/reward
P1-STK-02 claim-before-early-exit
P2-TAX-01 whitelist zero credit
P2-STK-03 forfeited reward reserve
P2-BBK-01 buyback price impact
P2-DIV-01 pre-start cancel
P3-ORC-01 uint32 rollover
P3-TKN-01 smart wallet/counterfactual boundary
```

每项只能是：

```text
CLOSED_CODE_ONLY
STILL_OPEN
REGRESSION_FOUND
ACCEPTED_DEVIATION（仅 P3 且有用户证据）
```

## 5. 跨合约资金流

最终审核必须对以下资金流做数量和状态守恒检查：

### Buy

```text
User BNB → Router → Adapter/Pair → gross Token
→ Token settlement → Dividend fee → FeeVault → net Token → CostBasis lots
```

### Sell

```text
User known/unknown lots → CostBasis consume
→ support/burn/swapTokens → Adapter/Pair → BNB payout
```

### Support

```text
Support tax → FeeVault support bucket → conversion
→ SupportPool → fixed buyback preflight → Adapter → Locker
```

### Dividend

```text
Dividend bucket → fund → commitment → publish
→ claim → zero-cost lot → close/cancel-after-end → carry
```

### Staking

```text
Liquid lots → position lots → reward accrual
→ normal exit / early penalty+forfeiture → liquid lots
```

## 6. 最终代码验证建议

如果环境可用，应运行并记录绑定最终 Commit 的：

- `forge fmt --check`；
- `forge build`；
- 全部 Unit/Regression；
- Fuzz，安全关键目标建议至少 10,000 runs；
- Invariant，按合理深度和 runs 记录配置；
- 合约大小、ABI/interface 一致性和静态分析。

本阶段仍禁止 Fork、RPC、Anvil、部署和广播。没有运行的项目必须为 `NOT_RUN`。

最终 `CORE_SOLIDITY_BUILD` 不允许为 `NOT_RUN`。完整 Build 必须覆盖 Foundry compile surface，并把 src/interface 实现不匹配和 script compile compatibility 与实际部署逻辑明确分开。

## 7. 代码层可部署性

`CODE_DEPLOYABILITY=YES` 只在以下条件全部满足时给出：

- 全部实现满足接口；
- 构造参数、immutable 和一次配置关系无循环锁死；
- 新旧 ABI 变化完整记录；
- 合约大小和编译器目标没有代码级 blocker；
- 新地址图和必须重部署范围已列出；
- 没有未关闭 P0/P1/P2；
- P3 要么关闭，要么有用户接受证据；
- Build/Test 证据真实绑定最终 Commit，或未运行项明确导致 `UNKNOWN`。

它不代表部署脚本、链上角色、RPC、测试网或 Mainnet 已验证。

## 8. 最终审核和校对

1. Implementation Agent只整理必要代码和证据，不新增功能。
2. Priority Full Audit Agent执行 FINAL 全量审核。
3. Review Adjudication Agent校对每条 Finding 和最终 Verdict。
4. 只修复校对为 CONFIRMED 的最终问题。
5. Fix Commit 后重新执行 FINAL 全量审核和校对。

## 9. 退出条件

```text
FINAL_VERDICT = APPROVED_CODE_ONLY
ORIGINAL_P0_OPEN = 0
ORIGINAL_P1_OPEN = 0
ORIGINAL_P2_OPEN = 0
NEW_P0_P1_P2_OPEN = 0
BASELINE_COMPLIANCE = PASS
CODE_DEPLOYABILITY = YES
CORE_SOLIDITY_BUILD = PASS
INTERFACE_IMPLEMENTATION_MATCH = PASS
COMPILE_ERRORS = 0
INDEPENDENT_REVIEW = APPROVED_CODE_ONLY
REVIEW_VERDICT_CONFIRMED = YES
CODE_FIX_REQUIRES_REDEPLOYMENT = YES
READY_FOR_SEPARATE_MIGRATION_AND_DEPLOYMENT_PLANNING = YES
BSC_TESTNET_RUNTIME_FIXED = NO
MAINNET = NO-GO
```

任何一项不满足时，输出 `CHANGES_REQUIRED` 或 `BLOCKED`，不得降低 Gate。


