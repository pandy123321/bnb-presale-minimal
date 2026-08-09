# BingGoPlus Flap 产品主线转向决策

状态：`V6_REVIEW_CHANGES_REQUIRED / V7_P1_REMEDIATION_FIX_READY / INDEPENDENT_RETEST_PENDING / IMPLEMENTATION_NOT_AUTHORIZED`

```text
DECISION_ID = BGP-FLAP-PIVOT-2026-001
DECISION_DATE = 2026-08-09
RESPONSIBLE_OWNER = pd123
OWNER_DIRECTION = APPROVED_IN_CURRENT_USER_SESSION
CURRENT_STAGE = FLAP-F0
F0_FREEZE_STATUS = REOPENED_BY_OWNER_ECONOMIC_MODEL_CHANGE
F1_ENTRY_AUTHORIZED = NO
FLAP_IMPLEMENTATION_START = NO
EXTERNAL_REVIEW_SUBMISSION = USER_MANUAL
BSC_TESTNET_DEPLOYMENT = NOT_AUTHORIZED
BSC_MAINNET = NO-GO
```

本决策记录项目负责人要求：BingGoPlus 从“单一 PANGU2 协议治理产品”转为“以 Flap 为唯一发币入口、支持多 Token Launch 与 BingGoPlus 扩展经济模块的平台”。本文件是作者侧冻结候选，不自行宣布独立审核通过。

本轮产品方向的责任人原始输入为：

```text
“在现在这个项目的基础上直接转做 Flap”
“发币和重做都要”
“可以在后台直接调用 Flap 的接口或合约发币”
“尽可能保留现状的经济模型结构，参数可以调整”
“那我要按照上面的经济模型执行”
“尽量保留之前的开盘的15%那个部分”
```

最后一句与仓库旧模型的机器证据存在用词偏差：旧模型实际为“开盘后 15 分钟、买卖税 30%”，不是“开盘税 15%”。本轮按已存在的 Solidity 常量和产品文档保留其真实业务意图，并将 `15 minutes / 3000 bps` 作为新产品的候选默认值，而不是把口误固化为 15% 税率。确切可用性仍须由 F1 证明。

因此本决策是**当前 BingGoPlus 项目的原地产品转向**，不是创建一个与本仓库、Go 后端、Admin、DApp、数据库迁移计划完全无关的新项目。若以后要拆成独立产品或改成普通用户自助钱包发币，必须由责任人另行批准新的 Product Change Gate；外部审核 Agent 不得替代责任人改变该产品方向。

## 1. 当前主线

```text
PRODUCT_MAINLINE = FLAP
FLAP_LAUNCH_REQUIRED = YES
FLAP_PORTAL_OR_VAULTPORTAL = REQUIRED_LAUNCH_ENTRY
FLAP_CHAIN_EVENT_AND_RECEIPT = RUNTIME_AUTHORITY
PANGU2_V2 = LEGACY_READ_ONLY
OLD_G2_TO_G9 = SUPERSEDED_FOR_CURRENT_EXECUTION
NEW_STAGE_PROGRAM = FLAP-F0_TO_F11
```

任何新 Token 必须由已审核、已绑定 Chain ID、地址、ABI 与 runtime bytecode hash 的 Flap `Portal` 或 `VaultPortal` 创建。禁止把普通 ERC-20、私有 Factory 或现有 PANGU2 部署脚本包装成“Flap 发币”。

## 2. 支持的产品模式

| 模式 | 入口 | 能力 | 当前状态 |
|---|---|---|---|
| `FLAP_STANDARD` | Flap Portal | 普通 Token、Bonding Curve、DEX Migration | `CANDIDATE_PENDING_F1_BASELINE` |
| `FLAP_TAX_SPLIT` | Flap VaultPortal + 官方 Split Vault | Tax Token、固定税率、最多 10 个固定 BPS 收款人 | `MVP_CANDIDATE_PENDING_F1_BASELINE` |
| `FLAP_TAX_BGPLUS` | Flap VaultPortal + `BGPlusVaultFactoryV1` | Tax Token、资金桶、回购、锁仓、简化分红与后续通用质押 | `NEW_SOLIDITY_REQUIRED` |

官方文档当前描述了 Portal/VaultPortal、Split Vault 1～10 个收款人和 `vaultDataSchema()` 等能力，但 F0 不把网页描述当成测试网运行基线。F1 必须固定当前地址、ABI、selector、默认值、runtime hash 与链上行为后，才能把候选状态改为 `SUPPORTED`。

默认交付顺序为：优先验证并完成 `FLAP_TAX_SPLIT`；如果 Split Vault 基线不满足，则先交付 F1 证明可用的 `FLAP_STANDARD` 或不带 Vault 的 Flap Tax Launch，不阻塞核心后台发币。随后必须继续完成 `FLAP_TAX_BGPLUS` 扩展路线；它不是 Native MVP 的前置条件，但也不是被永久放弃的可选想法。

`FLAP_STANDARD` 和 `FLAP_TAX_SPLIT` 只能交付 Flap Native Launch 与其实际支持的固定分账，不能宣称已完成本决策的回购/销毁、Top100、Staking、Vesting 和开盘保护。完整 V6 经济模型只有在 `FLAP_TAX_BGPLUS` 的 F7～F10 分阶段审核、部署和绑定完成后才算交付。

## 3. 经济模型继承原则

尽可能继承现有经济结构，而不是复用不兼容的合约接口：

- Token 保持 18 decimals；Flap 当前平台 Token 的 10 亿最大供应结构与原模型一致时直接采用；
- 保留公开、可审计的 Tax 参数；
- 保留税收进入独立会计资金桶；
- 默认交易税候选为 `500 bps`，最终值必须落在 F1 验证的 Flap 支持范围内；
- 默认税收分桶为 Dividend 30%、Buyback/Burn 25%、Staking 20%、Marketing 15%、Operations 10%；五项创建前可调但合计必须为 10000 BPS，Launch 确认后不可改；
- Dividend 桶同时服务“所有有效持有人基础分红”和“Top 100 额外奖励”；Top 100 不恢复旧 35/25/25/15 四档，而采用确定性快照排名和档内按有效持币量同比例分配；
- 保留 Dividend、Buyback/Burn、Staking、Marketing、Operations 等资金用途分离；
- 保留“回购所得不能发给触发者”的约束；
- 回购所得默认 100% 销毁；回购锁仓比例可以在 Launch 前设置，确认后不可改；
- 保留 Merkle Epoch、固定快照区块/Hash、一次领取、关闭与 carry；
- Staking 的主要奖励来源改为 Staking 税收桶在 DEX Migration 后受控兑换成绑定 Flap Token；允许额外外部预充值，但任何情况下不得挪用质押本金；
- 新增团队、投资人和项目储备的独立预充值 Vesting；它不拥有铸币权，不得复用回购 Locker；
- 保留旧开盘保护的真实意图：候选默认 `15 minutes / 3000 bps`，但必须优先由 Flap 原生能力实现，或由独立审核的 BGPlus 扩展等价实现；若 F1 不能证明可安全实现，必须 Fail Closed 为 `UNSUPPORTED`；
- 保留暂停、最小权限、幂等、deadline、minOut、滑点、价格影响、Reorg 与链上证据；
- 原 `0.01 BNB / 60 seconds / 365 days / 30 days claim / 10% early-exit penalty` 作为后台建议默认值，不再作为所有新 Token 的不可变全局常量；
- 所有可配置参数必须在批准范围内，并按“创建前可编辑、创建后不可变、治理可调、单次操作输入”四类管理。

## 4. 永久退役项

以下能力不允许通过改名、后端模拟或自建 Vault 绕回：

```text
PANGU2_COST_BASIS = PERMANENTLY_REMOVED_FROM_NEW_PRODUCT
DYNAMIC_PROFIT_SELL_TAX_4_OR_10 = PERMANENTLY_REMOVED_FROM_NEW_PRODUCT
PANGU2_TRADE_ROUTER = PERMANENTLY_REMOVED_FROM_NEW_PRODUCT
PANGU2_SETTLEMENT_HOOKS = PERMANENTLY_REMOVED_FROM_NEW_PRODUCT
PANGU2_LAUNCH_PROTECTION_IMPLEMENTATION = PERMANENTLY_REMOVED_FROM_NEW_PRODUCT
PANGU2_FEE_WHITELIST = PERMANENTLY_REMOVED_FROM_NEW_PRODUCT
PANGU2_TOP100_35_25_25_15_TIERS = PERMANENTLY_REMOVED_FROM_NEW_PRODUCT
PANGU2_STAKING_IMPLEMENTATION = PERMANENTLY_REMOVED_FROM_NEW_PRODUCT
PANGU2_FULL_SUITE_NEW_DEPLOYMENT = PERMANENTLY_REMOVED_FROM_NEW_PRODUCT
```

可以重新实现通用开盘保护、所有持有人基础分红、Top 100 额外奖励、通用 ERC-20 质押、Vault 回购/销毁和 Vesting，但不得声称它们与已部署 PANGU2 的合约接口或结算语义相同。

## 5. 已部署 PANGU2 处置

```text
EXISTING_PANGU2_CONTRACTS = IMMUTABLE
EXISTING_PANGU2_REDEPLOY = FORBIDDEN
EXISTING_PANGU2_TESTNET_HISTORY = PRESERVE
EXISTING_PANGU2_DATABASE = LEGACY_READ_ONLY_AFTER_FLAP_CUTOVER
EXISTING_PANGU2_API = RETIRE_BY_FLAP_F11_AFTER_SEPARATE_CUTOVER_GATE
```

不得删除既往地址、交易回执、ABI、readback、审核和实测记录。它们只用于历史查询、安全追溯和回归参考，不再决定新 Flap Token 的业务规则。

## 6. 发币执行模式

第一版使用：

```text
EXECUTION_MODE = ADMIN_WALLET
```

Go API 保存草稿、校验参数、生成精确交易意图；Admin 钱包独立核对并签名。平台不得保存管理员私钥。

本模式是责任人要求的后台一键发币模型，不得被审核 Agent擅自改成 `USER_WALLET`。F1 必须精确确认 Flap ABI 和事件中 `creator / payer / msg.sender / initial buyer` 的语义：后台必须真实展示 Admin 钱包在链上的身份，不得把 Admin 发起的 Token 伪装成普通用户创建。若未来增加普通用户自助模式，应作为并存的新执行模式单独冻结身份、认证、限额、风控和钱包交互，不覆盖本 MVP。

后续可增加：

```text
EXECUTION_MODE = PLATFORM_SIGNER
```

但必须单独冻结额度、nonce、allowlist、双审批、补偿、审计与密钥托管，并通过 Security/Signer/Deployment Gate。不得因为后台有“一键发币”按钮就默认启用服务器私钥。

## 7. 新合约范围

允许规划但尚未授权实现：

```text
contracts-flap/src/BGPlusVaultFactoryV1.sol
contracts-flap/src/BGPlusRevenueVaultV1.sol
contracts-flap/src/BGPlusBuybackModuleV1.sol
contracts-flap/src/BGPlusLockerV1.sol
contracts-flap/src/BGPlusDividendDistributorV1.sol
contracts-flap/src/BGPlusStakingV1.sol
contracts-flap/src/BGPlusTokenVestingV1.sol
```

所有新合约必须继承《通用智能合约安全开发、风险控制与漏洞治理规范 V1.0》，并单独完成规格、不变量、威胁模型、代码审核、测试网部署 Gate。当前 F0 不创建这些文件。

## 8. 开源与外部依赖边界

Flap 官方文档、公开 ABI 和公开链上合约先作为 `REFERENCE_ONLY / EXTERNAL_PROTOCOL_INTEGRATION` 建档。任何 Flap 示例仓库、Vault 示例、SDK 或第三方 Indexer 的下载和代码采用，必须遵循《开源项目通用引用、参考、采用与开发准入规则 V1.0》，完成固定版本、License、NOTICE、SBOM、TCO、人工 Decision；不得把公开代码直接复制到正式仓库。

## 9. 当前 Gate

```text
V5_CONTENT_REVIEW = HISTORICAL_APPROVAL_SUPERSEDED_BY_OWNER_CHANGE
F0_DOCUMENTS_COMPLETE = V7_P1_REMEDIATION_FIX_READY
F0_INDEPENDENT_REVIEW = V6_CHANGES_REQUIRED / V7_INDEPENDENT_RETEST_PENDING
F0_LOCAL_ISOLATED_COMMIT = COMMIT_CONTAINING_DOC_49 / SEE_PACKAGE_COMMIT_ID
F0_SUBMISSION_CONTEXT = 49_FLAP_F0_V7_SUBMISSION_CONTEXT.md
F0_REMOTE_PUSH = USER_MANUAL_PENDING
EXTERNAL_REVIEW_SUBMISSION = USER_MANUAL
F0_RESPONSIBLE_OWNER_FREEZE = PENDING_AFTER_REVIEW
F1_ENTRY_AUTHORIZED = NO
GO_CODE_CHANGE = NO
SQL_CHANGE = NO
OPENAPI_CHANGE = NO
FRONTEND_CHANGE = NO
SOLIDITY_CHANGE = NO
CHAIN_WRITE = NO
```

V6 已完成远程证据复验，但内容审核为 `CHANGES_REQUIRED`。只有 V7 独立审核 `APPROVED`、执行方二次裁决 `ACCEPTED`、责任人对 V7 冻结 `SIGNED` 后，才允许设置 `F1_ENTRY_AUTHORIZED = YES`。独立审核 `APPROVED` 单独只允许进入 Responsible Owner Freeze，不授权 F1。
