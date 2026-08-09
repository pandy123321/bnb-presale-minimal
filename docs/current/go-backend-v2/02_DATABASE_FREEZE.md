# BingGoPlus Go Backend V2 数据库冻结候选

状态：`LEGACY_PANGU2_SCHEMA / REFERENCE_FOR_FLAP_F2`

> `binggoplus_v2` 不再承载新 Flap 多 Launch 产品；新 Schema 必须在 F2 独立冻结。本文和 SQL 继续作为 Legacy PANGU2、权限分离与不变量参考，不得直接扩表冒充 Flap Freeze。

数据库：`binggoplus_go`  
应用 Schema：`binggoplus_v2`  
机器规范：

- [sql/0001_binggoplus_v2_schema.sql](./sql/0001_binggoplus_v2_schema.sql)：Schema、表、约束与不可变触发器；
- [sql/0002_binggoplus_v2_runtime_privileges.sql](./sql/0002_binggoplus_v2_runtime_privileges.sql)：运行时数据库角色与最小权限矩阵。

## 1. 冻结结论

V2 使用全新 PostgreSQL 数据库，不迁移 Laravel 与旧 Chain Worker 的业务表、Cursor、Session、Job 或投影数据。BSC Testnet 的历史从已核验部署区块重新扫描，链下管理员账号、Session、审批与幂等记录重新初始化。

这不是丢弃历史：链上事实由 canonical block/log 重建，昨天实测产生的交易、税费、质押、分红、回购、锁仓、角色与控制事件必须进入新库。旧库只读归档，用于差异调查，不作为 V2 启动数据源。

## 2. 原模型审核结论

旧模型存在以下结构性冲突，禁止原样继承：

- `chain_sync_cursors` 与 `chain_cursors` 重复，且 Cursor 语义不统一；
- `contract_event_logs` 与 `chain_raw_events` 重复；
- `nonces` 与 `wallet_nonces` 重复；
- Laravel 与 Worker 的 `transaction_projections` 字段和唯一性约束不兼容；
- 仅按 `(chain_id, tx_hash)` 唯一会吞掉同一交易的多条 Log；
- Worker Migration 存在同编号文件以及删除后重建 Checkpoint 表的历史；
- 旧 Queue、Session 和 Mock 数据没有迁移价值。

V2 以单一 Migration 目录为唯一 DDL 来源，不允许应用启动时自行改表。

## 3. 通用类型

| 概念 | PostgreSQL | Go | JSON |
|---|---|---|---|
| 地址 | `varchar(42)` + lowercase check | `common.Address`/值对象 | `0x` 小写字符串 |
| 交易/区块 Hash | `varchar(66)` + lowercase check | `common.Hash`/值对象 | `0x` 小写字符串 |
| Token/Wei 数量 | `numeric(78,0)` | `big.Int` | 十进制整数字符串 |
| BPS | `integer`，范围 `0..10000` | `uint16`/值对象 | integer |
| Chain ID | `bigint` | `uint64` | integer |
| Block Number | `bigint` | `uint64` | 十进制字符串 |
| 时间 | `timestamptz` | `time.Time` | RFC 3339 UTC |
| 主键 | 应用生成 UUID | UUID 值对象 | UUID 字符串 |

禁止 `float/double` 表示任何金额、比率或价格。`jsonb` 只用于原始证据、ABI 解码结果、错误详情和不可稳定结构，不代替可查询业务列。

## 4. 数据所有权

| 数据类别 | 唯一写入者 | 可否重建 | 事实来源 |
|---|---|---|---|
| Deployment/Contract Evidence | 配置导入器 + 只读验证器 | 是 | Foundry 回执、部署 Commit、链上 `eth_getCode/getter` |
| Block/Raw Event/Cursor | Indexer | 是 | BSC Testnet canonical chain |
| Domain Projection | Projector | 是 | Confirmed canonical raw events |
| Dividend Artifact | Dividend Builder | 可确定性重建 | finalized canonical snapshot block/hash + 固定 projector manifest + 历史账本重放 + 冻结算法 |
| Governance Command | API/Reconciler | 否，必须保留 | 管理员请求、审批、签名和链上回执 |
| Admin Audit | API/Reconciler | 否，append-only | 管理操作 |
| Session/Challenge | Auth | 否，可过期删除 | 新 V2 认证 |
| Job/Anomaly | 各进程 | 否，保留证据 | 运行状态 |

旧 Worker 与 Go V2 不得连接同一 Database/Schema。每个环境只有一个 Indexer Writer 和一个 Signer/Reconciler Writer。

## 5. 表目录

### 5.1 环境与部署证据

- `environments`：环境、chain ID、RPC 别名、写入开关；DDL 拒绝 `chain_id=56`。
- `deployment_sets`：部署集 ID、项目、环境、source commit、ABI manifest hash、状态。
- `contract_instances`：合约类型、地址、部署交易、区块、区块 Hash、部署序号、构造参数、是否权威。
- `deployment_actions`：Deploy/Bootstrap/Finalize/OpenTrading 的交易与回执证据。
- `contract_evidence_checks`：runtime code hash、getter、角色、暂停、开盘、Allowance 等只读检查及 observed block/hash。

`deployment_sets.status`：`DISCOVERED | STATIC_VERIFIED | LIVE_VERIFIED | ACTIVE | SUPERSEDED | DEACTIVATED | REJECTED`。同一环境只允许一个 `ACTIVE` 部署集。

### 5.2 链扫描与证据

- `chain_streams`：每个部署批次的事件流定义和起始区块；同名 Stream 可在后续部署批次重新登记，但不能在同一部署批次重复。
- `chain_stream_contracts`：按环境、部署批次、事件流、合约实例和真实合约地址建立授权绑定。
- `chain_leases`：单写者租约、fencing token、过期时间。
- `chain_cursors`：`next_block`、最近确认 block/hash、最近 finalized block/hash。
- `chain_blocks`：区块号/hash/parent hash/time、canonical/finalized 状态。
- `chain_raw_events`：完整 Log、topic/data、ABI event、解码值、confirmation 状态；复合外键必须命中一条已授权的 `chain_stream_contracts` 绑定。
- `projection_receipts`：每个 projector 对每条 raw event 的应用结果和版本。

关键语义：

- `next_block` 是下一次尚未扫描的区块，不再使用含糊的 `last_scanned_block + 1`；
- raw event 身份为 `(environment_id, block_hash, tx_hash, log_index)`；
- raw event 的 `(environment_id, deployment_set_id, stream_id, contract_instance_id, contract_address)` 必须整体匹配同一授权绑定；数据库同时保证 Stream 属于该环境/部署批次、实例属于该部署批次且地址与实例登记值一致；
- raw event 的 `(environment_id, block_number, block_hash)` 必须命中已登记的 `chain_blocks`，防止区块号与 Hash 被错误拼接；
- `(environment_id, tx_hash, log_index)` 只对 canonical 行建立条件唯一索引；
- Reorg 时旧 block/event 标记 `canonical=false`、event 标记 `ORPHANED`，不可物理删除；
- 投影器必须支持反向补偿或从 checkpoint 全量重建；
- 未达到确认深度的 Log 不进入面向用户的最终投影。

### 5.3 领域投影

- `token_balance_ledger`、`token_balances_current`：Token 变化账本与当前余额；
- `cost_basis_events`、`cost_basis_current`：`NONE/KNOWN/UNKNOWN`、Token 成本和 WBNB 成本；
- `trades`：买卖方向、输入输出、税费桶、成本状态、交易和 Log 定位；
- `staking_events`、`staking_positions`：Stake/Unstake/Claim/Penalty/Reward；
- `dividend_epochs`、`dividend_artifacts`、`dividend_allocations`、`dividend_claims`、`dividend_approvals`、`dividend_publish_preflights`；
- `dividend_finalized_blocks_v1`：只暴露 canonical + finalized 的候选快照区块；
- `dividend_projection_coverage_v1`：只暴露 confirmed canonical Raw Event 与各 projector/version receipt 的覆盖关系；
- `dividend_token_balance_history_v1`、`dividend_staking_history_v1`：只暴露可按固定区块、交易序号和 Log 序号重放的 canonical 历史输入；
- `buybacks`、`locker_batches`、`fee_vault_movements`、`oracle_events`；
- `protocol_control_events`：Pause、Trading、Pair/System、Whitelist、参数变化；
- `role_events`：Grant/Revoke/Renounce；
- `system_anomalies`：守恒、覆盖率、地址、状态或确认异常。

所有投影行必须保留 `source_raw_event_id` 或 `source_block_number/source_block_hash/source_tx_hash/source_log_index`，不得只保存聚合结果。

### 5.4 身份、治理与运行

- `admin_users`、`admin_sessions`；
- `wallet_challenges`、`wallet_sessions`；
- `admin_audit_logs`：append-only；DDL 触发器拒绝任何 `UPDATE/DELETE`，运行时写入角色仅获 `SELECT/INSERT`；
- `idempotency_records`：作用域、请求 Hash、响应/资源 ID 和过期时间；
- `governance_commands`：显式 action、参数、目标合约、selector、状态；
- `governance_approvals`：审批人与决策；
- `governance_tx_attempts`：nonce、gas、raw tx hash、tx hash、回执、替换关系；
- `signer_nonces`：每个 signer/chain 的串行 nonce 租约；
- `job_runs`：Indexer/Projector/Reconcile/Dividend/Readback 作业证据。

如采用 River，其内部表放在独立 Schema，只承载调度，不作为业务事实；业务状态仍写入上述 V2 表。

## 6. 不变量与约束

1. `environments.chain_id <> 56`，本阶段 Mainnet 数据不得进入新库。
2. 一个环境最多一个 ACTIVE deployment set。
3. Contract 地址、Hash 必须小写且长度正确。
4. 金额非负；需要表达差额时使用 direction + absolute amount，不用负数混淆资产流。
5. 同一 chain/deployment/epoch/account 只能有一条 Dividend allocation 和一条 successful claim。
6. Governance 的 `(scope, idempotency_key)` 唯一；相同 key 不同 request hash 必须冲突。
7. 同一 signer/chain 同一 nonce 只能有一个未被替换的 active attempt。
8. Audit Log 由 `admin_audit_logs_append_only` 触发器拒绝 `UPDATE/DELETE`；`bgp_api`、`bgp_reconciler` 仅有 `SELECT/INSERT`，其他运行角色无写权限。
9. Projection 版本必须随算法变更递增；不能静默覆盖旧算法结果。
10. Quote 不落为链上事实；可选缓存必须绑定 observed block number/hash 和短 TTL。
11. Dividend Artifact 禁止读取 `token_balances_current` 或 `staking_positions` 作为固定历史快照；必须从窄化历史视图按目标 block/hash 重放。
12. 每个 Artifact 必须固化 `projector_manifest`、规范化输入 `input_sha256/input_row_count`、算法版本和最终内容 Hash；任一项改变都必须生成新 Artifact 并重新审批。
13. `dividend_epochs_snapshot_block_guard` 在数据库层拒绝任何非 canonical 或未 finalized 的非空 snapshot block/hash；目标一旦选择即不可原地更换，进入构建后不得为空；Publish 前仍须再次 readback，防止后续链状态变化。

### 6.1 运行时权限边界

- `bgp_migrator` 是唯一 Schema/DDL 所有者，只在发布 Migration 时使用；任何应用进程不得持有该角色、继承该角色或获得 `SET ROLE` 能力；
- `bgp_api` 只写认证、Session、幂等、治理请求/审批、Dividend DRAFT intake 与 append-only Audit；Command 仅可列级更新 `state/updated_at`；
- `bgp_indexer` 只写 Block、Raw Event、Cursor、Lease 和扫描异常；Raw Event 更新限于 decode 结果、确认/canonical 状态，Block 更新限于 canonical/finalized，不得修改原 topic/data/address/hash 或物理删除证据；
- `bgp_projector` 只读 Raw Event；Token ledger 与 Staking history 按 projector version 追加且不可删除，current/其他可重建领域投影按受控重建策略维护；并对 Dividend 链上事件派生字段拥有 `dividend_epochs` 列级 UPDATE；
- `bgp_dividend` 只能读取 finalized block、projection coverage、Token ledger 和 Staking event 的窄化历史视图；不能读取 current 表生成 Artifact，并写版本化 Epoch/Artifact/Allocation/Preflight；不能写 `merkle_root`；
- `bgp_reconciler` 只读 approved Command 与 Dividend evidence，仅列级更新 Command `state/updated_at`，并写 Signer Nonce、交易尝试、Job/Anomaly 和 append-only Audit；不得 INSERT Command；
- `bgp_auditor` 与 `bgp_readonly` 只有明确列出的只读权限，不能读取 Session、Challenge 或 Signer Nonce；
- 数据库所有者或集群管理员在技术上仍可改 Schema/禁用 Trigger，因此其凭据必须独立托管；高强度审计证据还必须依赖备份/WAL、外部日志或不可变存储，不能只依赖单库 Trigger。

## 7. 重扫与切换

1. 导入 `BSC_TESTNET_DEPLOYMENT_BASELINE.md` 中的 deployment set。
2. 完成 runtime bytecode 与 getter 只读核验后将其置为 `ACTIVE`。
3. 每个合约从自己的部署区块开始扫描；Pair 从 CreatePair 交易区块开始。
4. 固定 shadow target block/hash，完成 raw event 与投影重建。
5. 与旧系统只做业务级差异分析，不复制旧主键或旧计算结果。
6. 切换前撤销旧 Worker 的写权限，再给 Go Indexer/Reconciler 写权限。
7. 切换失败时 API 可回旧读路径，但不可恢复两个链上写入者。

## 8. 保留与清理

- Canonical/Orphaned block、raw event、governance command、tx attempt、audit log：永久保留；
- Session/challenge：到期后可按策略清理；
- 可重建的 current projection：可删除重建，但必须记录 rebuild job；
- 旧数据库：只读快照归档，禁止作为 V2 运行依赖；
- 不提供破坏性 down migration；只允许向前修正或新 Schema 重建。

## 9. 冻结前人工决策

- 数据负责人批准两份 SQL、复合外键、唯一键、确认深度和 Reorg 窗口；
- 安全负责人批准治理、Audit Trigger、运行时角色矩阵与数据库所有者隔离；
- 产品负责人批准 Dividend 有效持币量与整数尾差规则；
- 运维负责人批准旧库只读归档期限；
- 所有 `UNRESOLVED` 项关闭后标记 `FROZEN_FOR_DEVELOPMENT`，再允许生成 Go Model/Query。
## 第三轮复审后的 Dividend 不可变证据链

- `projection_receipts` 的 `id/raw_event_id/projector_key/projector_version` 是不可变身份；Projector 只能更新 `status/result_refs/error/applied_at`。
- Artifact 使用 `(dividend_epoch_id, artifact_revision)` 版本化；`algorithm_version` 只表示算法，不再兼任修订号。重建必须 INSERT 新 Artifact，并通过 `supersedes_artifact_id` 保留前序关系。
- Artifact 固定 `environment + snapshot block/hash + input hash + projector manifest(+sha256) + content hash + Merkle root + total reward`；Allocation 必须引用具体 Artifact。
- Approval 必须引用具体 Artifact，并由复合外键精确绑定 content hash、Merkle root 与 total reward；同一审批人可对新 Artifact revision 重新决策，旧审批不覆盖、不复用。
- Artifact、Allocation、Approval、Publish Preflight 均为 append-only。Builder 只能 INSERT Artifact/Allocation/Preflight，不能 UPDATE 或 DELETE。
- `dividend_publish_preflights` 使用 `(artifact_id, validation_revision)` 作为唯一身份，固化 coverage checksum、input checksum、Artifact 权威 projector manifest hash、snapshot、root、amount、验证器版本与有效期；Preflight 不复制原始 manifest JSON，必须通过 `artifact_id` 读取 Artifact 的唯一权威 manifest。过期后可 INSERT 新 revision，旧 Preflight 永不复用。
- Preflight 通过复合外键精确绑定 Artifact 的 `input_sha256` 与 `projector_manifest_sha256`；`DIVIDEND_PUBLISH` Command 必须引用该凭证，且同一 Preflight 最多创建一个 Publish Command。
- Governance Command 的 environment/deployment/requester/expiry/created_at 与执行绑定字段创建后不可改写；API/Reconciler 对 Command 仅可更新 `state/updated_at`。取消采用单独的 `governance_command_cancellation_requests`：API 只能 INSERT 不可变 `REQUESTED` intent，Reconciler 是唯一可将其解析为 `CONSUMED/REJECTED` 并推进 Command 到 `CANCELLED` 的写者。
- Dividend Epoch 的链上 Root/claim/close派生字段由 `bgp_projector` 列级写入；Builder 不能写 `merkle_root`，也不能覆盖 Projector 拥有的后发布状态。`CLOSED/CANCELLED` 为永久终态；已进入 `CLAIM_OPEN` 的 root 与 claim window 不可原地改写。
- `governance_commands` 除执行绑定不可变外，还必须由数据库 Trigger 强制 State YAML 的精确边；终态不可离开，运行角色只能推进各自职责阶段。
- `DIVIDEND_PUBLISH` Command 的失败、过期或被消费的取消意图属于 Reconciler 的执行事实。API 只能通过受控 `bind_current_dividend_publish_command(...)` 在 Epoch 为 `APPROVED` 时绑定唯一、不可替换的 `current_publish_command_id`，不拥有 `dividend_epochs` 的直接 UPDATE 权限；Builder 只在该绑定存在时进入 `PUBLISH_QUEUED`。Reconciler 只能以该**当前** Command（而非同一 Epoch 的历史 Command）在 `FAILED/CANCELLED/EXPIRED` 的状态为依据，于同一事务将 `PUBLISH_QUEUED -> FAILED`；不得获得 Dividend Epoch 的任意列或任意状态写权限。失败尝试必须先经 `FAILED -> SNAPSHOT_BUILDING` 清除当前绑定并重建，才可建立下一次 Publish Attempt。
