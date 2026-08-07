# BingGoPlus Go Backend V2 规划包自审

自审日期：2026-08-07  
自审范围：`docs/current/go-backend-v2/**`  
结论：`ROUND5_BLOCKED_ACCEPTED__ROUND6_FIX_READY_FOR_INDEPENDENT_RETEST`
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
| 数据库 | ROUND4_FIX_READY_FOR_REVIEW | 独立 `binggoplus_go.binggoplus_v2`、43 张表 + 4 个 Dividend 窄化历史视图；Receipt 身份、Artifact revision、Preflight revision、Command 单次消费、Epoch writer 边界与最小权限已进入候选 |
| API | ROUND4_FIX_READY_FOR_REVIEW | 43 paths / 44 operations，Dividend action 使用独立 required closed schema，无 Mock 成功源，无任意 calldata |
| Event/State | ROUND4_FIX_READY_FOR_REVIEW | 11 streams、8 state machines；Receipt 允许首次直接 FAILED；Dividend Epoch 写者边界已写入 invariants |
| 部署环境 | PASS_AS_CANDIDATE | 旁路、单写者、独立 DB、Signer 隔离、分域切换与回滚 |
| 开源准入 | PASS_WITH_GATE | 只列 Reference/Candidate；未下载、未批准、未写浮动版本 |
| 合约安全规范 | PASS_WITH_GATE | 资产/权限/会计/Oracle/事件响应/Mainnet Gate 已继承；测试由独立 Agent 后续接管 |
| 改动边界 | PASS | 仅修改规划文档与 SQL 冻结候选；未修改业务代码、合约、测试、部署脚本或运行环境 |

## 3. 机器/静态核验结果

### 3.1 已通过

- OpenAPI：43 个 path、44 个 operationId；无 operationId 重复；全路径使用 BingGoPlus V2 Public/Admin 前缀；本地 `$ref` 均能解析到已定义 component；
- OpenAPI 治理写入：action 是有限 enum，参数为 action-specific closed schema；请求不能提供 target、selector、calldata 或 private key；
- DTO：移除 Config/Market/Activity/Staking/Buyback/Locker/Job/Audit/Governance 的 Generic DTO；仅错误 `details` 允许开放对象；
- State Machine：8 个状态机无未知目标，无“声明终态但仍有出边”；`projection_receipt` 允许首次直接 INSERT `APPLIED` 或 `FAILED`；
- Event Catalog：11 个流地址格式正确且唯一；除 Pair 需批准外部 ABI 外，目录中所有 event signature 均存在于本地合约 ABI artifact；
- Deployment Address：11 个 Event Stream 地址全部与 `BSC_TESTNET_DEPLOYMENT_BASELINE.md` 对应实例一致；
- Business Matrix：部署 Commit、3000/400/1000 bps、900+100 拆分、0.01 BNB、60 秒、365 天、35/25/25/15、30 天 claim、Staking rate cap、UNKNOWN、preview 方法均有明确规则；
- Database：DDL 共 43 张表和 4 个 Dividend 历史/覆盖视图；Raw Event 必须整体匹配环境/部署/Stream/实例/地址授权绑定；Audit 与 Dividend 证据表有拒绝 UPDATE/DELETE 的 Trigger；权限脚本对运行角色使用显式 allowlist；
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
| `P1-DB-02` Audit append-only 与运行权限 | 原问题正确；第二轮确认 Trigger/Audit 直接权限正确，但发现 Projector 与 Dividend 工作流未闭合 | 第二轮至第四轮修订见下节与 `14_*`；Audit 不可变边界本身保留 | `FIX_READY / INDEPENDENT_RETEST_PENDING` |
| `P1-BRAND-01` BingGoPlus/PANGU2 与自动回购表述冲突 | 正确。产品文档曾混用旧别名，并把最小间隔写成自动频率 | 产品品牌统一 BingGoPlus，链上 Token 统一 PANGU2；回购改为 permissionless trigger + 60 秒最小间隔 + 前置条件 | `CLOSED_BY_INDEPENDENT_REVIEW` |

自审额外修正文档内部的四处既有冲突：盈利判断改为 TWAP 卖出价值与对应历史成本比较；Admin 地址 CRUD 改为部署证据与独立激活审批；已执行 Open Trading 改为只读证据；Staking 收益改为全局 reward-rate cap，不再承诺每用户固定日收益。数据库侧同时把 Stream 唯一性收敛到部署批次，并要求 Raw Event 的区块号/Hash 命中同一 `chain_blocks` 记录。

### 3.4 第二轮独立复审与修订

| Finding | 对结论的判断 | 修订 | 当前状态 |
|---|---|---|---|
| `P1-DB-PRIV-01` Projector 无法写 Raw Event `PROJECTED` | 正确。单一 Raw Event 状态也无法表达多个 projector/version 的完成度 | 从 DDL/State 删除 `PROJECTED`；Projector 对 Raw Event 只读；完成、失败、重试、撤销全部由 versioned receipt 表达 | `CLOSED_BY_INDEPENDENT_REVIEW`（第四/五轮保持） |
| `P1-DB-PRIV-02` Dividend Builder 无固定区块历史输入 | 正确。current 表会越过 Epoch snapshot | 新增 finalized block、projection coverage、Token ledger、Staking history 四个 security-barrier 视图；Builder 只读窄视图，锁定 projector manifest 并保存 input checksum | `FIX_READY / INDEPENDENT_RETEST_PENDING`（第五轮因机器规范未随包上传为 BLOCKED，待第六轮完整包复验） |
| `P2-DOC-01` 团队/推荐/佣金仍列为当前能力 | 正确。与 API 和业务冻结范围冲突 | 从当前资产功能表移除，改列为 `OUT_OF_SCOPE / ROADMAP_NOT_APPROVED`，禁止从转账图或 Mock 推断 | `CLOSED_BY_INDEPENDENT_REVIEW`（第四轮关闭，第五轮保持） |

权限自审同时收窄：Indexer 对 Raw Event 只能更新 decode/确认/canonical 列、对 Block 只能更新 canonical/finalized；Projector 对 versioned Token ledger 和 Staking history 只能追加，不能删除；Dividend Artifact 只能插入新版本，不能原地改写。

### 3.5 未执行/工具限制

- 按用户要求不运行项目 Test、Build、Migration、RPC、Fork 或部署；
- 当前工作区内没有可用 YAML/OpenAPI parser/linter，且开源规则不允许未经批准下载；因此本轮完成了结构、引用和 ABI 对照，但未运行标准 OpenAPI 3.1 lint；
- PostgreSQL DDL 未实际执行；
- 运行时权限脚本未在真实 PostgreSQL Role/Database 上应用；
- BSC Testnet live readback 未执行。

独立复审 Agent 应在不修改代码的前提下，优先使用其已批准/已有的 YAML/OpenAPI 与 PostgreSQL 工具补这三项只读验证；不得为了验证私自下载依赖。

## 4. 阻止冻结的剩余项

第三轮云端报告的 `P1-R3-01..03` 与 `P2-DOC-01` 已由第四轮独立审核关闭；`P2-R4-02` 已由第五轮独立关闭。第五轮因机器规范未随包上传判 `BLOCKED`（见 [16_INDEPENDENT_CLOUD_ROUND5_REMEDIATION.md](./16_INDEPENDENT_CLOUD_ROUND5_REMEDIATION.md)），不是证明候选修订失败。`P1-R4-01..05`、`P2-R4-01`、`P2-R4-03`、`P2-R5-01` 与依赖它们的 `P1-R3-04` / `P1-DB-02` / `P1-DB-PRIV-02` 当前均为 `FIX_READY / INDEPENDENT_RETEST_PENDING`，须由第六轮完整包独立复验后才能关闭。

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
PLANNING_DELIVERABLE = ROUND5_BLOCKED_ACCEPTED__ROUND6_FIX_READY_FOR_INDEPENDENT_RETEST
FROZEN_FOR_DEVELOPMENT = NO
DEVELOPMENT_START = NO
BSC_TESTNET_CONTRACT_REDEPLOY = FORBIDDEN
BSC_MAINNET = NO-GO
```

下一步应先由独立 Review Agent 按 [17_ROUND6_CLOUD_REVIEW_PROMPT.md](./17_ROUND6_CLOUD_REVIEW_PROMPT.md) 复审**单一完整提审包**（含 SQL/OpenAPI/Event/State/规则原文与 Manifest）；然后由责任人只关闭 GATE-01..05。开发实施仍按 G0-G9 旁路阶段执行，不能绕过冻结直接开写。
