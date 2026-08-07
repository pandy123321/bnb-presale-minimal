# BingGoPlus Go Backend V2 新开发基线

状态：`FREEZE_CANDIDATE`

本目录定义 BingGoPlus 服务端从 Laravel + TypeScript Chain Worker 旁路替换为 Go 的新开发基线。链上已部署合约仍使用不可改写的 `Pangu2*` 名称和 ABI；产品、API、数据库与新代码统一使用 `BingGoPlus`。新系统不兼容旧表名、旧 Cursor、旧 Projection、旧 Session 或旧 DTO，但必须完整继承：

- 已部署到 BSC Testnet 的合约地址、字节码语义和链上历史；
- 已实现的经济逻辑、权限控制、暂停/开盘与治理规则；
- 原 Public API、Admin API 已承载的业务能力；
- 原数据库与 Worker 中经过审核后仍然成立的数据需求；
- 既往合约修复、审核结论和部署后脚本加固记录。

Go V2 是实现与数据模型的重建，不是业务规则重写，也不是合约重部署。

## 权威顺序

发生冲突时按以下顺序判定：

1. BSC Testnet `chain_id=97` 的已部署字节码、交易回执和链上状态；
2. 实测部署来源提交 `3ef50b6d77a31c092e9353e255e672836f36ece8` 及其编译 ABI；
3. [05_BUSINESS_AND_CONTRACT_INHERITANCE.md](./05_BUSINESS_AND_CONTRACT_INHERITANCE.md)；
4. [openapi/binggoplus-api-v2.yaml](./openapi/binggoplus-api-v2.yaml)；
5. [sql/0001_binggoplus_v2_schema.sql](./sql/0001_binggoplus_v2_schema.sql) 与 [sql/0002_binggoplus_v2_runtime_privileges.sql](./sql/0002_binggoplus_v2_runtime_privileges.sql)；
6. Event Catalog 与 State Machine；
7. 本目录的说明文档。

产品能力参考 [PRODUCT_PLANNING.md](../PRODUCT_PLANNING.md)，但它不能覆盖已经部署的合约语义。产品品牌统一为 **BingGoPlus**；`Pangu2*` 仅保留为链上合约、ABI、事件和 Token 元数据身份。

所有工作强制继承仓库根目录的《开源项目通用引用准入规则 V1.0》和《通用智能合约安全开发风险控制与漏洞治理规范 V1.0》。

旧 `backend/`、`services/chain-worker/`、`packages/api-types/` 和前端调用代码只用于发现业务能力与缺陷，不作为 Go 运行时依赖。旧 `docs/current/DEPLOYMENT_MANIFEST.md` 和 `CONTRACTS_AUTHORITY.md` 记录的是另一套未验证地址，不能作为 Go V2 地址来源。

## 新基线边界

- 新代码目录：`backend-go/`，单一 Go Module，模块化单体，多进程运行；
- Public API：`/api/v2/projects/binggoplus`；
- Admin API：`/admin-api/v2/projects/binggoplus`；
- 独立 PostgreSQL Database：`binggoplus_go`；
- 应用 Schema：`binggoplus_v2`；
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
- [contracts/BSC_TESTNET_DEPLOYMENT_BASELINE.md](./contracts/BSC_TESTNET_DEPLOYMENT_BASELINE.md)：昨天实测部署的静态证据台账；
- [openapi/binggoplus-api-v2.yaml](./openapi/binggoplus-api-v2.yaml)：机器可读 API 冻结候选；
- [sql/0001_binggoplus_v2_schema.sql](./sql/0001_binggoplus_v2_schema.sql)：机器可读 PostgreSQL DDL 冻结候选；
- [sql/0002_binggoplus_v2_runtime_privileges.sql](./sql/0002_binggoplus_v2_runtime_privileges.sql)：机器可读 PostgreSQL 运行时最小权限冻结候选；
- [events/binggoplus-events-v2.yaml](./events/binggoplus-events-v2.yaml)：机器可读事件目录；
- [states/binggoplus-state-machines-v2.yaml](./states/binggoplus-state-machines-v2.yaml)：机器可读状态机。

## 开发启动 Gate

- [x] 已确认实测部署来源提交和 Foundry 广播文件；
- [x] 已确认新地址组与 DApp `deployed.ts` 一致；
- [x] 已确认合约生产源码在部署后无运行时代码修改；
- [ ] 读取测试网当前 runtime bytecode 并记录 SHA-256；
- [ ] 读取当前角色、暂停、开盘、Oracle、储备与 Locker 参数并固定证据区块；
- [ ] 产品负责人批准业务继承矩阵；
- [ ] 数据负责人批准 SQL Schema、唯一键和重建策略；
- [ ] 前端与后端负责人批准 OpenAPI；
- [ ] 安全负责人批准 Admin RBAC、审批、Signer 和 Mainnet NO-GO；
- [ ] 所有 `UNRESOLVED` 项归零后，将状态改为 `FROZEN_FOR_DEVELOPMENT`。

测试计划和验收由独立 Agent 在开发后接管，不作为本轮设计冻结的执行项。

## 本轮不做

- 不写 Go Handler、Repository、Worker 或业务服务；
- 不运行测试、构建、数据库 Migration 或 RPC 验证；
- 不修改任何 Solidity 合约或部署脚本；
- 不部署、补发、重放或签名链上交易；
- 不迁移旧 Mock、旧 Session 或旧队列状态；
- 不开放 BSC Mainnet。
