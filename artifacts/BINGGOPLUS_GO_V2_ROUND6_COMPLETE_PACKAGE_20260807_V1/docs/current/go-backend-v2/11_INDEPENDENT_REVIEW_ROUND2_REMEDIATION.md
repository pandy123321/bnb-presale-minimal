# BingGoPlus Go Backend V2 第二轮独立复审核查与修订报告

> 历史记录：本文件记录第二轮当时的 42 表/2 Trigger 候选状态。当前冻结候选已由 [12_INDEPENDENT_CLOUD_ROUND3_REMEDIATION.md](./12_INDEPENDENT_CLOUD_ROUND3_REMEDIATION.md) 修订，不应以本文件中的计数或 `FIX_READY` 声明代表最新状态。

日期：2026-08-07  
审查输入：`C:\Users\xingf\.codex\attachments\03e6b5a4-e48d-44c7-8956-16d3fe29fb31\pasted-text.txt`  
模式：证据核查后修改冻结候选；未运行测试、构建、Migration、数据库、RPC、Fork、部署或链上交易

## 1. Verdict

附件的结论正确。两个新 P1 和一个 P2 都能从当前 SQL、权限矩阵、状态机、API 与产品文档直接推导，不是推测性问题。

```text
ATTACHED_REVIEW = CORRECT
P1-DB-01 = CLOSED_BY_INDEPENDENT_REVIEW
P1-BRAND-01 = CLOSED_BY_INDEPENDENT_REVIEW
P1-DB-02 = ROUND2_FIX_READY / INDEPENDENT_RETEST_PENDING
P1-DB-PRIV-01 = FIX_READY / INDEPENDENT_RETEST_PENDING
P1-DB-PRIV-02 = FIX_READY / INDEPENDENT_RETEST_PENDING
P2-DOC-01 = FIX_READY / INDEPENDENT_RETEST_PENDING
FROZEN_FOR_DEVELOPMENT = NO
DEVELOPMENT_START = NO
BSC_TESTNET_CONTRACT_REDEPLOY = FORBIDDEN
BSC_MAINNET = NO-GO
```

`P1-DB-01` 和 `P1-BRAND-01` 已由第二轮独立审核正式关闭，本轮不重新打开。`P1-DB-02` 的 Audit Trigger 和直接 Audit 权限本身已经通过独立静态复核；保持 OPEN 的原因是同一运行权限冻结未闭合 Projector 与 Dividend Builder 的职责。以下修订只标记为 `FIX_READY`，仍须另一轮独立复验才能关闭。

## 2. 附件结论核查

| Finding | 判断 | 证据 |
|---|---|---|
| `P1-DB-PRIV-01` Projector 无法完成 Raw Event `PROJECTED` | 正确 | 原 State/DDL 声明 `CONFIRMED -> PROJECTED`，但 Projector 对 Raw Event 只有 SELECT；Indexer 虽可 UPDATE，却不能证明对应 projector/version 已完成 |
| `P1-DB-PRIV-02` Dividend Builder 无固定区块历史数据通路 | 正确 | 原权限只允许读取不断变化的 `token_balances_current/staking_positions`，不能重放 Epoch 固定 block/hash 的历史输入 |
| `P2-DOC-01` 团队/推荐/佣金仍列为当前功能 | 正确 | 产品功能表将其列为正式能力，而 API 和业务冻结明确无合约、Endpoint、事实源或资金来源，且不进入 V2 |

附件对非问题的判断也正确：事件复合约束链、Audit Trigger、Audit 直接 GRANT、品牌/PANGU2 边界、回购语义与 Mainnet NO-GO 均不需要回滚。

## 3. `P1-DB-PRIV-01` 修订

选择的方案：**Raw Event 不再保存单一 `PROJECTED` 状态；投影完成度只由 versioned Projection Receipt 集合表达。**

理由：同一 Raw Event 可以被 `token_ledger`、`trades`、`fee_flow` 等多个 projector 消费，也可以同时存在不同 projector version。单个 `PROJECTED` 布尔式状态无法说明“哪个 projector 的哪个版本已经成功”。向 Projector 授予 Raw Event 整表 UPDATE 还会扩大原始证据篡改面。

具体修订：

- 从 `chain_raw_events.status` 删除 `PROJECTED`；
- 从 Raw Event 状态机删除 `CONFIRMED -> PROJECTED`；
- Raw Event 状态只表达 `OBSERVED/CONFIRMED/DECODE_FAILED/ORPHANED`；
- 所需 projector/version 的 `APPLIED` receipt 集合代表完成；`FAILED/REVERTED` 代表失败和撤销；
- Projector 对 Raw Event 保持只读；
- Indexer 的 Raw Event UPDATE 收窄到 `event_name/decoded/status/canonical/confirmed_at`，不能更新原 topic/data/address/hash；
- Indexer 对 Block 的 UPDATE 收窄到 `canonical/finalized`；
- versioned Token ledger 和 Staking history 对 Projector 只允许 SELECT/INSERT，不允许删除。

修订文件：

- [0001_binggoplus_v2_schema.sql](./sql/0001_binggoplus_v2_schema.sql)
- [0002_binggoplus_v2_runtime_privileges.sql](./sql/0002_binggoplus_v2_runtime_privileges.sql)
- [04_EVENT_AND_STATE_FREEZE.md](./04_EVENT_AND_STATE_FREEZE.md)
- [binggoplus-state-machines-v2.yaml](./states/binggoplus-state-machines-v2.yaml)

## 4. `P1-DB-PRIV-02` 修订

选择的方案：**Dividend Builder 只读窄化的 canonical 历史视图，在固定 finalized block/hash 重放；禁止用 current 表构建历史 Artifact。**

### 4.1 新增窄化视图

- `dividend_finalized_blocks_v1`：只暴露 canonical + finalized 候选区块；
- `dividend_projection_coverage_v1`：暴露 confirmed canonical Raw Event 与所有 projector/version receipt 的覆盖关系；
- `dividend_token_balance_history_v1`：只暴露 `TOKEN/token_ledger` 对应版本且 receipt=`APPLIED` 的 canonical 历史变动；
- `dividend_staking_history_v1`：只暴露 `STAKING/staking` 对应版本且 receipt=`APPLIED` 的 canonical 历史事件。

这些 View 使用 `security_barrier`，由迁移角色持有；`bgp_dividend` 只获得 View 的 SELECT，不获得底层 Raw Event、Receipt、Ledger、Staking Event 或 current 表权限。

### 4.2 历史版本与 Artifact 证据

- `token_balance_ledger` 和 `staking_events` 增加 `projector_version`，唯一键包含 version，允许新算法并存而不覆盖旧输入；
- `dividend_artifacts` 增加：
  - `projector_manifest`
  - `input_sha256`
  - `input_row_count`
- Artifact 仍保存最终 `content_sha256`、算法版本、Schema 版本和完整输入/排除/排名/取整证据；
- Artifact 对 Builder 只允许 SELECT/INSERT，不能原地 UPDATE；新输入或新 projector version 必须生成新 Artifact version 并重新审批。

### 4.3 固定区块数据库边界

- `dividend_epochs` 的 `(environment_id, snapshot_block_number, snapshot_block_hash)` 引用真实 `chain_blocks`；
- `dividend_epochs_snapshot_block_guard` 拒绝非 canonical 或未 finalized 的 snapshot；
- snapshot 一旦选择不可原地更换；进入构建及之后状态时不得为空；
- Publish 前仍必须重新验证 block/hash、projector manifest、coverage 和 input/content checksum；链状态或输入变化时 fail closed。

### 4.4 构建协议

Builder 在 `REPEATABLE READ` 事务中：

1. 锁定 Epoch 和 snapshot block/hash；
2. 锁定 `token_ledger` 与 `staking` 的精确 projector version；
3. 验证目标块及之前相关 Stream 的每条 confirmed canonical Raw Event 都有对应版本的 `APPLIED` receipt；
4. 按 `(block_number, tx_index, log_index)` 从两个历史 View 重放到目标块；
5. 按已签署的有效持币量规则生成规范化输入；
6. 对稳定排序后的完整输入计算 `input_sha256`；
7. 写入 Artifact、Allocation 和构建证据；
8. 任一 coverage、version、checksum 或 target 变化都撤销旧批准。

`UNRESOLVED-BIZ-01` 仍然保留：本修订解决“能否在固定区块确定性取数”，不替产品负责人决定有效持币量公式。

修订文件：

- [0001_binggoplus_v2_schema.sql](./sql/0001_binggoplus_v2_schema.sql)
- [0002_binggoplus_v2_runtime_privileges.sql](./sql/0002_binggoplus_v2_runtime_privileges.sql)
- [01_ARCHITECTURE_AND_MIGRATION.md](./01_ARCHITECTURE_AND_MIGRATION.md)
- [02_DATABASE_FREEZE.md](./02_DATABASE_FREEZE.md)
- [03_API_FREEZE.md](./03_API_FREEZE.md)
- [04_EVENT_AND_STATE_FREEZE.md](./04_EVENT_AND_STATE_FREEZE.md)
- [05_BUSINESS_AND_CONTRACT_INHERITANCE.md](./05_BUSINESS_AND_CONTRACT_INHERITANCE.md)
- [06_DEPLOYMENT_ENVIRONMENT.md](./06_DEPLOYMENT_ENVIRONMENT.md)

## 5. `P2-DOC-01` 修订

从 `PRODUCT_PLANNING.md` 当前资产页功能表移除：

- 我的团队；
- 推荐/邀请链接和二维码；
- 推荐列表、佣金记录与佣金结算。

这些能力改列为 `OUT_OF_SCOPE / ROADMAP_NOT_APPROVED`。文档明确禁止从 Token 转账图猜测推荐关系或显示 Mock 佣金；未来如需新增，必须先独立冻结身份绑定、反女巫、隐私、撤销、会计和资金来源，再作为独立版本开发。

修订文件：[PRODUCT_PLANNING.md](../PRODUCT_PLANNING.md)。

## 6. 自审追加修订

在交叉检查完整职责矩阵时还收口了三个直接相关问题：

1. `bgp_api` 增加 `dividend_epochs` 的列级 INSERT，才能实现已冻结的“创建 DRAFT 并固定候选 snapshot”API；`state` 使用数据库默认 `DRAFT` 且不在 API 可写列中，不授予其 Raw Event、Signer 或 Artifact 写权限；
2. Snapshot Guard 同时负责“必须 canonical + finalized”和“一旦选择不可变”，避免 Artifact 生成后 Epoch 被原地换块；
3. 历史输入 View 直接 JOIN exact projector/version 的 `APPLIED` receipt，避免部分提交或失败版本进入 Dividend 重放输入。

这些修订没有改变 Token、税费、回购、分红档位、Staking、Oracle、治理或任何已部署合约逻辑。

## 7. 静态自审

完成以下只读静态检查：

- Schema 保持 42 张表，新增 4 个 security-barrier View；
- DDL 包含 2 个 Trigger Function 和 2 个 Trigger；
- 权限脚本引用的所有表、View 和 Function 均有定义；
- Raw Event DDL/State/说明中不再存在 `PROJECTED` 状态；
- Projector 没有 Raw Event UPDATE 权限；
- Indexer 只能更新 Raw Event/Block 的明确列；
- `bgp_dividend` 不能读取 `token_balances_current/staking_positions`，只能读取4个 Dividend View；
- 两个历史 View 都要求 exact projector version 的 `APPLIED` receipt；
- Builder 不能 UPDATE 已写入的 Artifact；
- Audit 表仍未向运行角色授予 UPDATE/DELETE/TRUNCATE；
- 产品当前功能表不再包含团队、推荐或佣金；Roadmap 明确标记未批准；
- 本规划包相对 Markdown 链接均可解析；
- SQL 文件没有 Tab 或非预期行末空白。

这些是静态作者侧自审，不等价于 PostgreSQL 实际执行、角色实测或独立 Finding 关闭。

## 8. 未执行与剩余 Gate

本轮没有运行测试、Build、Migration、PostgreSQL、RPC、readback、Fork、部署或链上操作，也没有安装依赖。

仍未关闭：

- 本轮两个 P1 和一个 P2 的独立复验；
- `UNRESOLVED-BIZ-01`；
- 测试网固定区块 readback；
- Pair ABI、confirmation depth、reorg lookback 签署；
- Go 依赖准入；
- 标准 OpenAPI/PostgreSQL 解析与实际权限验证；
- DB/API/Event/State/Environment/RBAC/Signer 责任人签署；
- 后续测试、外部合约审核、发布演练、监控、备份恢复和事件响应；
- Mainnet 永久保持本基线 `NO-GO`。

## 9. 独立复验重点

下一轮 Review Agent 至少应验证：

1. `PROJECTED` 是否已从 DDL、State 和说明规范完全移除，且 receipt 集合足以表达多 projector/version 完成度；
2. `bgp_projector` 是否仍对 Raw Event 只读；Indexer 列级更新是否足够且不能改原始 topic/data/address/hash；
3. 四个 Dividend View 是否只暴露 canonical、confirmed、finalized/`APPLIED` 的必要字段；
4. View 默认权限、owner 和 `security_barrier` 是否避免 Builder 获得底层表权限；
5. `bgp_dividend` 是否能验证 coverage、选择 projector version、按目标块重放 Token/Staking 历史，并且不能使用 current 表；
6. Epoch Snapshot Guard、FK、状态 CHECK、Artifact manifest/checksum 是否形成固定输入闭环；
7. API、Builder、Projector 的 GRANT 是否满足各自必要工作流而无明显过度授权；
8. 产品 Roadmap 是否已与 API/DB 范围统一；
9. 本轮是否引入新的 P0/P1/P2。

## 10. 最终结论

附件审核：`CORRECT`。  
本轮修订：`ROUND2_FIX_READY_FOR_INDEPENDENT_REVIEW`。  
冻结开发：`NO`。  
进入 Go G1：`NO`。  
测试网合约重部署：`FORBIDDEN`。  
Mainnet：`NO-GO`。
