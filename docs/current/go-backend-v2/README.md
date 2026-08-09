# BingGoPlus Flap 新产品与 Go 后端开发基线

状态：`FLAP-F0_V4_REVIEW_BLOCKED / V5_REMEDIATION_FIX_READY / REMOTE_PUSH_PENDING / IMPLEMENTATION_PAUSED`

本目录现在定义 BingGoPlus 从单一 PANGU2 产品转为 Flap 发币与扩展经济平台的开发基线。现有 Go、PostgreSQL、Admin 与 DApp 工程作为技术地基复用；已部署 PANGU2 合约、链上历史和审核材料保持不可改写并转为 Legacy Read-Only。

- 已部署到 BSC Testnet 的合约地址、字节码语义和链上历史；
- 可兼容 Flap 的经济结构、权限控制、暂停、资金会计和治理安全规则；
- 原 Public API、Admin API 中仍适合多 Token 平台的基础能力；
- 原数据库与 Worker 中经过审核后仍然成立的数据需求；
- 既往合约修复、审核结论和部署后脚本加固记录。

当前产品转向、永久退役项、参数目录和新阶段计划以文档 27～31 为准。旧 G2-G9 不再是当前执行主线。

## 权威顺序

新 Flap 产品发生冲突时按以下顺序判定：

1. [27_FLAP_PRODUCT_PIVOT_DECISION.md](./27_FLAP_PRODUCT_PIVOT_DECISION.md)；
2. [28_FLAP_PRODUCT_SCOPE_AND_PARAMETER_CATALOG.md](./28_FLAP_PRODUCT_SCOPE_AND_PARAMETER_CATALOG.md)；
3. [29_FLAP_TARGET_ARCHITECTURE.md](./29_FLAP_TARGET_ARCHITECTURE.md) 与 [30_FLAP_F0_F11_EXECUTION_PLAN.md](./30_FLAP_F0_F11_EXECUTION_PLAN.md)；
4. F1 将冻结的 Flap BSC Testnet 地址、ABI、runtime bytecode、交易回执和链上事件；
5. F2 将冻结的 SQL/OpenAPI/Event/State/RBAC/Signer 机器规范；
6. [31_FLAP_LEGACY_RETIREMENT_MATRIX.md](./31_FLAP_LEGACY_RETIREMENT_MATRIX.md)；
7. PANGU2 文档与链上证据仅在解释 Legacy PANGU2 时继续权威。

产品能力参考 [PRODUCT_PLANNING.md](../PRODUCT_PLANNING.md)，但它不能覆盖已经部署的合约语义。产品品牌统一为 **BingGoPlus**；`Pangu2*` 仅保留为链上合约、ABI、事件和 Token 元数据身份。

所有工作强制继承仓库根目录的《开源项目通用引用准入规则 V1.0》和《通用智能合约安全开发风险控制与漏洞治理规范 V1.0》。

旧 `backend/`、`services/chain-worker/`、`packages/api-types/` 和前端调用代码只用于发现业务能力与缺陷，不作为 Go 运行时依赖。旧 `docs/current/DEPLOYMENT_MANIFEST.md` 和 `CONTRACTS_AUTHORITY.md` 记录的是另一套未验证地址，不能作为 Go V2 地址来源。

## Legacy PANGU2 技术基线与 Flap 目标候选

- 复用代码目录：`backend-go/`，单一 Go Module，模块化单体，多进程运行；
- Legacy Public API：`/api/v2/projects/binggoplus`，只服务 PANGU2 迁移/历史兼容，不是 Flap 新接口；
- Legacy Admin API：`/admin-api/v2/projects/binggoplus`，不得新增 Flap Launch；
- 独立 PostgreSQL Database：`binggoplus_go`；
- Legacy 应用 Schema：`binggoplus_v2`，只读/迁移来源；
- Flap Target Public API Candidate：`/api/v3/flap`，必须在 F2 OpenAPI Freeze 后才成为权威；
- Flap Target Admin API Candidate：`/admin-api/v3/flap`，必须在 F2 OpenAPI Freeze 后才成为权威；
- Flap Target Schema Candidate：`binggoplus_flap_v1`，必须在 F2 SQL/Privilege Freeze 后才允许迁移；
- BSC Mainnet `chain_id=56`：配置和数据库双重禁止；
- 不复制旧链上 Projection，从每个实测合约的部署区块重新扫描；
- 不丢弃测试网历史，链上交易、质押、分红、回购、锁仓、税费和权限事件全部重建；
- 不迁移旧管理员 Session、Job 内部状态和 Mock 数据；
- 不允许旧 Worker 与 Go Worker 写同一 Database/Schema；
- 不修改、不重新部署已实测合约；合约修复另走独立审核与部署决策。

## 文档索引

- [00_EXISTING_BASELINE_REVIEW.md](./00_EXISTING_BASELINE_REVIEW.md)：原 API、表结构、前端调用和 Worker 的证据审查；
- [01_ARCHITECTURE_AND_MIGRATION.md](./01_ARCHITECTURE_AND_MIGRATION.md)：目标架构、开发前任务和旁路替换顺序；
- [02_DATABASE_FREEZE.md](./02_DATABASE_FREEZE.md)：数据库边界、表职责、唯一键和链上数据重建；
- [03_API_FREEZE.md](./03_API_FREEZE.md)：Public/Admin API、权限、金额、错误和异步交易语义；
- [04_EVENT_AND_STATE_FREEZE.md](./04_EVENT_AND_STATE_FREEZE.md)：事件流、确认、Reorg、Projection 和状态机；
- [05_BUSINESS_AND_CONTRACT_INHERITANCE.md](./05_BUSINESS_AND_CONTRACT_INHERITANCE.md)：经济逻辑、控制逻辑、修复与审核继承；
- [06_DEPLOYMENT_ENVIRONMENT.md](./06_DEPLOYMENT_ENVIRONMENT.md)：环境、进程、网络、密钥、发布与回滚；
- [07_FRAMEWORK_AND_DEPENDENCIES.md](./07_FRAMEWORK_AND_DEPENDENCIES.md)：Go 框架与依赖选择；
- [08_RULES_COMPLIANCE_AND_DECISIONS.md](./08_RULES_COMPLIANCE_AND_DECISIONS.md)：两份通用规则、漏洞/风险与人工决策 Gate；
- [09_SELF_REVIEW.md](./09_SELF_REVIEW.md)：本轮规划自审、剩余问题与 Verdict；
- [10_INDEPENDENT_REVIEW_REMEDIATION.md](./10_INDEPENDENT_REVIEW_REMEDIATION.md)：独立复审结论核查、修订证据与复审状态；
- [11_INDEPENDENT_REVIEW_ROUND2_REMEDIATION.md](./11_INDEPENDENT_REVIEW_ROUND2_REMEDIATION.md)：第二轮独立复审核查、权限/固定快照修订与复验状态；
- [12_INDEPENDENT_CLOUD_ROUND3_REMEDIATION.md](./12_INDEPENDENT_CLOUD_ROUND3_REMEDIATION.md)：第三轮云端复审核查、不可变 Dividend 证据链与发布前置凭证修订；
- [13_ROUND4_CLOUD_REVIEW_PROMPT.md](./13_ROUND4_CLOUD_REVIEW_PROMPT.md)：第四轮完整上传后的独立云端复验提示词；
- [14_INDEPENDENT_CLOUD_ROUND4_REMEDIATION.md](./14_INDEPENDENT_CLOUD_ROUND4_REMEDIATION.md)：第四轮云端复审核查、Preflight/Command/Epoch writer 修订；
- [15_ROUND5_CLOUD_REVIEW_PROMPT.md](./15_ROUND5_CLOUD_REVIEW_PROMPT.md)：第五轮独立云端复验提示词；
- [16_INDEPENDENT_CLOUD_ROUND5_REMEDIATION.md](./16_INDEPENDENT_CLOUD_ROUND5_REMEDIATION.md)：第五轮 `BLOCKED` 裁决、机器规范同 revision 核对与完整提审包归一；
- [17_ROUND6_CLOUD_REVIEW_PROMPT.md](./17_ROUND6_CLOUD_REVIEW_PROMPT.md)：第六轮完整包独立云端复验提示词；
- [18_INDEPENDENT_CLOUD_ROUND6_REMEDIATION.md](./18_INDEPENDENT_CLOUD_ROUND6_REMEDIATION.md)：第六轮云端复审核查、状态机/manifest/角色身份修订；
- [19_ROUND7_CLOUD_REVIEW_PROMPT.md](./19_ROUND7_CLOUD_REVIEW_PROMPT.md)：第七轮完整包独立云端复验提示词；
- [20_INDEPENDENT_CLOUD_ROUND7_REMEDIATION.md](./20_INDEPENDENT_CLOUD_ROUND7_REMEDIATION.md)：第七轮云端复审核查、发布失败 writer 与取消意图交接修订；
- [21_ROUND8_CLOUD_REVIEW_PROMPT.md](./21_ROUND8_CLOUD_REVIEW_PROMPT.md)：第八轮完整包独立云端复验提示词；
- [22_INDEPENDENT_CLOUD_ROUND9_REVIEW.md](./22_INDEPENDENT_CLOUD_ROUND9_REVIEW.md)：第九轮独立复验通过结论、范围及责任人 Freeze 前的非阻断跟进项；
- [23_RESPONSIBLE_OWNER_FREEZE_SIGNOFF.md](./23_RESPONSIBLE_OWNER_FREEZE_SIGNOFF.md)：`pd123` 已完成 GATE-01～05 Responsible Owner Freeze 签署、P2-R9-01 处置与开发冻结前提；
- [24_AI_CODE_REVIEW_AUTOMATION_PROTOCOL.md](./24_AI_CODE_REVIEW_AUTOMATION_PROTOCOL.md)：阶段提交、外部审核、结论二次裁决和自动推进规则；
- [25_FLAP_INTEGRATION_EXECUTION_PLAN.md](./25_FLAP_INTEGRATION_EXECUTION_PLAN.md)：历史 Flap 设计支线方案，已被文档 27 取代；
- [26_G2_EXECUTION_BASELINE_NORMALIZATION.md](./26_G2_EXECUTION_BASELINE_NORMALIZATION.md)：历史 G2 执行冲突与风险输入，不再是当前入口；
- [27_FLAP_PRODUCT_PIVOT_DECISION.md](./27_FLAP_PRODUCT_PIVOT_DECISION.md)：Flap 产品主线、经济继承、永久退役与当前 Gate；
- [28_FLAP_PRODUCT_SCOPE_AND_PARAMETER_CATALOG.md](./28_FLAP_PRODUCT_SCOPE_AND_PARAMETER_CATALOG.md)：产品能力、参数生命周期、默认候选和硬约束；
- [29_FLAP_TARGET_ARCHITECTURE.md](./29_FLAP_TARGET_ARCHITECTURE.md)：Go、数据库、API、Indexer、Signer 和合约目标架构；
- [30_FLAP_F0_F11_EXECUTION_PLAN.md](./30_FLAP_F0_F11_EXECUTION_PLAN.md)：F0-F11 分阶段执行与审核门禁，F10/F11 已拆分；
- [31_FLAP_LEGACY_RETIREMENT_MATRIX.md](./31_FLAP_LEGACY_RETIREMENT_MATRIX.md)：PANGU2 模块继承、重做和退役矩阵；
- [32_FLAP_F0_INDEPENDENT_REVIEW_PROMPT.md](./32_FLAP_F0_INDEPENDENT_REVIEW_PROMPT.md)：F0 完整文档独立审核提示词；
- [33_FLAP_F0_SELF_REVIEW.md](./33_FLAP_F0_SELF_REVIEW.md)：作者侧静态自审、未执行项和脏工作区证据限制；
- [34_FLAP_F0_SUBMISSION_CONTEXT.md](./34_FLAP_F0_SUBMISSION_CONTEXT.md)：手动提审对象、基线 Commit、工作区限制和审核边界；
- [35_FLAP_F0_V2_EXTERNAL_REVIEW_ADJUDICATION.md](./35_FLAP_F0_V2_EXTERNAL_REVIEW_ADJUDICATION.md)：V2 外部报告逐项二次裁决、反证和正确 Finding 修订记录；
- [36_FLAP_F0_V3_REMEDIATION_SELF_REVIEW.md](./36_FLAP_F0_V3_REMEDIATION_SELF_REVIEW.md)：正确 Finding 修订后的作者侧自审与独立 Commit 证据阻断；
- [37_FLAP_F0_V3_SUBMISSION_CONTEXT.md](./37_FLAP_F0_V3_SUBMISSION_CONTEXT.md)：V3 隔离 Commit、Package、手动 Push 与复审身份；
- [38_FLAP_F0_V3_EXTERNAL_REVIEW_ADJUDICATION.md](./38_FLAP_F0_V3_EXTERNAL_REVIEW_ADJUDICATION.md)：V3 外审 4 个 P1、2 个 P2 与证据层阻断的逐项裁决；
- [39_FLAP_F0_V4_REMEDIATION_SELF_REVIEW.md](./39_FLAP_F0_V4_REMEDIATION_SELF_REVIEW.md)：V4 内容修订、静态自审和未关闭人工证据动作；
- [40_FLAP_F0_V4_SUBMISSION_CONTEXT.md](./40_FLAP_F0_V4_SUBMISSION_CONTEXT.md)：V4 单一隔离 Commit 与手工复审包身份；
- [41_FLAP_F0_V4_EXTERNAL_REVIEW_ADJUDICATION.md](./41_FLAP_F0_V4_EXTERNAL_REVIEW_ADJUDICATION.md)：V4 外审 2 个 P1、2 个 P2 和证据阻断的执行方裁决；
- [42_FLAP_F0_V5_REMEDIATION_SELF_REVIEW.md](./42_FLAP_F0_V5_REMEDIATION_SELF_REVIEW.md)：V5 小范围修订与作者侧静态自审；
- [43_FLAP_F0_V5_SUBMISSION_CONTEXT.md](./43_FLAP_F0_V5_SUBMISSION_CONTEXT.md)：V5 单一隔离 Commit、Package 和手工 Push/复审身份；
- [contracts/BSC_TESTNET_DEPLOYMENT_BASELINE.md](./contracts/BSC_TESTNET_DEPLOYMENT_BASELINE.md)：昨天实测部署的静态证据台账；
- [openapi/binggoplus-api-v2.yaml](./openapi/binggoplus-api-v2.yaml)：Legacy PANGU2 API 机器规范，只作 F2 重新设计输入；
- [sql/0001_binggoplus_v2_schema.sql](./sql/0001_binggoplus_v2_schema.sql)：Legacy `binggoplus_v2` DDL，只作迁移/审计输入；
- [sql/0002_binggoplus_v2_runtime_privileges.sql](./sql/0002_binggoplus_v2_runtime_privileges.sql)：Legacy 最小权限证据，不授权 Flap Schema；
- [events/binggoplus-events-v2.yaml](./events/binggoplus-events-v2.yaml)：Legacy PANGU2 事件目录；
- [states/binggoplus-state-machines-v2.yaml](./states/binggoplus-state-machines-v2.yaml)：Legacy PANGU2 状态机，Flap 状态机必须在 F2 重冻。

## 当前执行状态

当前产品状态以文档 27 和 30 为准。`runtime-gate/`、旧 G0-G9、自审和历史计划继续保留当时证据，不得被改写为已通过，也不得覆盖当前 Flap Change Gate。

```text
PRODUCT_MAINLINE = FLAP
CURRENT_STAGE = FLAP-F0
F0_STATUS = V4_REVIEW_BLOCKED / V5_REMEDIATION_FIX_READY / INDEPENDENT_RETEST_PENDING
F0_LOCAL_ISOLATED_COMMIT = COMMIT_CONTAINING_DOC_43 / SEE_PACKAGE_COMMIT_ID
F0_SUBMISSION_CONTEXT = 43_FLAP_F0_V5_SUBMISSION_CONTEXT.md
F0_REMOTE_PUSH = USER_MANUAL_PENDING
F1_ENTRY_AUTHORIZED = NO
OLD_G2_TO_G9 = SUPERSEDED_FOR_CURRENT_EXECUTION
FLAP_IMPLEMENTATION = NOT_STARTED
EXTERNAL_REVIEW_SUBMISSION = USER_MANUAL
BSC_MAINNET = NO-GO
```

## Legacy 开发启动 Gate（历史记录）

- [x] 已确认实测部署来源提交和 Foundry 广播文件；
- [x] 已确认新地址组与 DApp `deployed.ts` 一致；
- [x] 已确认合约生产源码在部署后无运行时代码修改；
- [x] 读取测试网当前 runtime bytecode 并记录验证证据；
- [x] 读取当前角色、暂停、开盘、Oracle、储备与 Locker 参数并固定证据；
- [x] Responsible Owner `pd123` 完成 GATE-01～05 签署；
- [ ] Legacy RT-GATE 状态不得写成全部通过：RT01 PASS、RT02 `BLOCKED_EVIDENCE`、RT03 `FIX_READY / INDEPENDENT_RETEST_PENDING`；它们不授权当前 Flap 实现；
- [ ] Legacy `FROZEN_FOR_DEVELOPMENT = YES` 只是旧 PANGU2 G0 字段，已被后续未关闭 Gate 限制，且绝不授权当前 Flap 开发；当前只看 `F1_ENTRY_AUTHORIZED = NO`。

测试计划和验收由独立 Agent 在开发后接管，不作为本轮设计冻结的执行项。

## 原设计冻结轮次不做的事项（历史边界）

- 不写 Go Handler、Repository、Worker 或业务服务；
- 不运行测试、构建、数据库 Migration 或 RPC 验证；
- 不修改任何 Solidity 合约或部署脚本；
- 不部署、补发、重放或签名链上交易；
- 不迁移旧 Mock、旧 Session 或旧队列状态；
- 不开放 BSC Mainnet。
阶段执行与外部审核门禁：见 [24_AI_CODE_REVIEW_AUTOMATION_PROTOCOL.md](24_AI_CODE_REVIEW_AUTOMATION_PROTOCOL.md)。F0-F11 每个阶段必须完成独立审核和执行方二次裁决；本轮 F0 提审由用户手动提交，不由执行 Agent 寻找或调用外部审核通道。
