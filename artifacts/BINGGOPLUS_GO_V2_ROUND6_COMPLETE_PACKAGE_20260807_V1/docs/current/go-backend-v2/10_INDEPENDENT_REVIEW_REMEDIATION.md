# BingGoPlus Go Backend V2 独立复审核查与修订报告

> 历史修订记录：本报告记录第一轮修订当时的作者侧结论。第二轮独立复审已关闭 `P1-DB-01` 与 `P1-BRAND-01`，并因 Projector 状态写入和 Dividend 固定区块数据通路发现 `P1-DB-02` 仍为 OPEN。后续修订与当前状态以 [11_INDEPENDENT_REVIEW_ROUND2_REMEDIATION.md](./11_INDEPENDENT_REVIEW_ROUND2_REMEDIATION.md) 为准。

日期：2026-08-07  
审查输入：`C:\Users\xingf\.codex\attachments\8466b2db-43bb-47d4-9bdd-e9752ff5ee4f\pasted-text.txt`  
审查方式：附件结论与本地冻结候选逐项对照；只修改文档和 SQL 冻结候选  
测试、构建、Migration、Fork、RPC、部署、签名、链上交易：均未执行

## 1. 结论

附件的三项 P1 结论均有直接证据，判断正确：

```text
ATTACHED_REVIEW = CORRECT
REMEDIATION_STATUS = FIX_READY_FOR_INDEPENDENT_REVIEW
INDEPENDENT_RETEST = REQUIRED
FROZEN_FOR_DEVELOPMENT = NO
DEVELOPMENT_START = CHANGES_REQUIRED
BSC_TESTNET_CONTRACT_REDEPLOY = FORBIDDEN
BSC_MAINNET = NO-GO
```

本轮已把三项缺陷修订为可执行的冻结候选，但没有把它们自行标为 `CLOSED`。原因是原审查为独立复审，而本轮只有作者侧静态自审；按照项目风险治理规则，P1 关闭仍需原审查方或另一独立 Agent 验证修订后的 SQL 和文档。

即使三项 P1 复验通过，`GATE-01..05` 的产品定义、固定区块 readback、依赖准入、Event/Operations 参数和责任人签署仍未完成，因此现在仍不能进入 Go G1 或标记 `FROZEN_FOR_DEVELOPMENT`。

## 2. 原审查结论核查

| Finding | 判断 | 原设计缺陷 | 修订状态 |
|---|---|---|---|
| `P1-DB-01` Raw Event 可绑定错误 Stream/实例/地址 | 正确 | `chain_raw_events` 只分别引用 Stream 和实例，未引用授权关联，冗余地址也未与实例地址绑定 | `FIX_READY / RETEST_PENDING` |
| `P1-DB-02` Audit append-only 只有文字约定 | 正确 | 原 DDL 只有表和索引；没有拒绝更新/删除的数据库约束，也没有受版本控制的运行时权限矩阵 | `FIX_READY / RETEST_PENDING` |
| `P1-BRAND-01` 品牌、Token 标识和自动回购承诺冲突 | 正确 | 上位产品文档混用 BingGoPlus、PANGU2 和未部署的 Token 别名，并把 60 秒最小间隔写成自动执行频率 | `FIX_READY / RETEST_PENDING` |

未发现附件对这三项问题的证据链或严重级别存在关键偏差。附件把尚未执行的 DDL、OpenAPI lint、测试网 readback 和测试保留为既有 Gate，而不是误报为代码 Bug，这一边界也正确。

## 3. P1-DB-01 修订：权威事件账本关系完整性

修订文件：[0001_binggoplus_v2_schema.sql](./sql/0001_binggoplus_v2_schema.sql) 与 [02_DATABASE_FREEZE.md](./02_DATABASE_FREEZE.md)。

### 3.1 新约束链

1. `deployment_sets` 增加 `(id, environment_id)` 唯一约束；
2. `contract_instances` 增加 `(id, deployment_set_id, address)` 唯一约束；
3. `chain_streams` 保证其 `deployment_set_id` 与 `environment_id` 指向同一部署批次，并以 `(deployment_set_id, stream_key)` 防止同一批次重复 Stream；
4. `chain_stream_contracts` 将以下五列固化为可引用的授权关系：
   - `environment_id`
   - `deployment_set_id`
   - `stream_id`
   - `contract_instance_id`
   - `contract_address`
5. `chain_raw_events` 以完全相同的五列建立复合外键；
6. `chain_raw_events` 另外以 `(environment_id, block_number, block_hash)` 引用 `chain_blocks`，避免事件区块号和区块 Hash 被错误拼接。

### 3.2 现在应被数据库拒绝的错误写入

- Stream 属于环境 A，但 Raw Event 声称环境 B；
- Stream 属于部署批次 A，但实例来自部署批次 B；
- Stream 和实例分别存在，但未在 `chain_stream_contracts` 中建立授权绑定；
- `contract_instance_id` 正确，但 `contract_address` 被替换成其他已知或未知地址；
- 区块号存在、区块 Hash 也存在，但两者不是同一个已登记区块。

这比附件给出的“为 `(stream_id, contract_instance_id)` 和 `(contract_instance_id, contract_address)` 分别增加外键”更严格，因为它同时锁定环境和部署批次，避免跨部署集拼接。

## 4. P1-DB-02 修订：Audit 数据库级不可变边界

修订文件：[0001_binggoplus_v2_schema.sql](./sql/0001_binggoplus_v2_schema.sql)、[0002_binggoplus_v2_runtime_privileges.sql](./sql/0002_binggoplus_v2_runtime_privileges.sql)、[02_DATABASE_FREEZE.md](./02_DATABASE_FREEZE.md) 与 [06_DEPLOYMENT_ENVIRONMENT.md](./06_DEPLOYMENT_ENVIRONMENT.md)。

### 4.1 DDL 强制约束

- 新增 `reject_admin_audit_log_mutation()`；
- 新增 `admin_audit_logs_append_only` Trigger；
- 对 `admin_audit_logs` 的任何 `UPDATE` 或 `DELETE` 都抛出 SQLSTATE `55000`；
- 运行角色没有 `TRUNCATE`、表所有权或 DDL 权限。

### 4.2 运行时角色矩阵

新增受版本控制的权限脚本，要求由 `bgp_migrator` 执行，并在所需角色缺失、拥有 Superuser/CreateRole/CreateDB/BypassRLS 或继承 `bgp_migrator` 时 fail closed。角色边界如下：

| Role | 主要写入范围 | Audit 权限 |
|---|---|---|
| `bgp_api` | Session、Challenge、Idempotency、Command、Approval、Job intake | `SELECT, INSERT` |
| `bgp_indexer` | Block、Raw Event、Cursor、Lease、扫描异常 | 无 |
| `bgp_projector` | 可重建领域投影、Projector Job/Anomaly | 无 |
| `bgp_dividend` | Epoch、Artifact、Allocation、Builder Job/Anomaly | 无 |
| `bgp_reconciler` | Command 状态、Signer Nonce、Tx Attempt、Job/Anomaly | `SELECT, INSERT` |
| `bgp_auditor` | 无写入 | `SELECT` |
| `bgp_readonly` | 无写入 | 无 |
| `bgp_migrator` | 发布期 DDL | 不得作为应用凭据 |

脚本不创建 Login、密码、Database `CONNECT` 或 Secret；这些由部署平台提供。运行时 Login 不得拥有 Schema、继承 `bgp_migrator` 或获得 `SET ROLE` 到迁移所有者的能力。

### 4.3 保证边界

Trigger 和 GRANT/REVOKE 用于防止运行时应用账号篡改。数据库对象所有者或集群管理员在技术上仍能变更 Schema 或禁用 Trigger，因此不能宣称单库内的绝对不可篡改；其凭据必须隔离，且备份/WAL、外部审计日志或不可变存储仍是高强度证据保全的一部分。

## 5. P1-BRAND-01 修订：产品、链上身份与回购语义

修订文件：[PRODUCT_PLANNING.md](../PRODUCT_PLANNING.md) 与 [05_BUSINESS_AND_CONTRACT_INHERITANCE.md](./05_BUSINESS_AND_CONTRACT_INHERITANCE.md)。

冻结后的表达为：

- 产品品牌：**BingGoPlus**；
- 已部署合约、ABI 和事件：`Pangu2*`；
- 钱包、交易确认和链上 Token metadata：`PANGU2`；
- 不使用未部署的 Token symbol；
- 单次成功回购固定使用 `0.01 BNB`；
- `60 秒`是距上一次成功回购的最小间隔，不是定时器或发生频率承诺；
- 回购由任意地址在 SupportPool 余额、Locker、Oracle、Quote、minimumOut、滑点和冷却等条件全部满足时触发；触发者不会收到回购资产；
- 回购获得的 PANGU2 进入 Locker，并按已部署参数锁定 365 天。

## 6. 自审追加修订

在处理三项 P1 时，静态自审又发现并修正了以下同类文档冲突；这些调整只使产品文档服从已部署合约和既有继承矩阵，没有新增或改变经济逻辑：

1. 盈利判断原文的两个不等式互相覆盖，现改为“当前 TWAP 卖出价值”与“对应比例历史 WBNB 成本”比较；无法证明成本时按 10% fail closed；
2. Admin 原“任意新增/修改/删除合约地址”改为候选部署集证据导入、readback 和独立激活审批；
3. 已在测试网执行的一次性 Open Trading 改为只读证据，不再描述为可重复写操作；
4. Staking 原“约 10 PANGU2/天”改为已部署合约的全局 reward-rate cap，不再承诺每个用户固定日收益；
5. Stream 唯一性从环境级改为部署批次级，使后续部署批次可以保留同名事件流历史，同时不允许同一批次重复登记。

## 7. 静态自审结果

| 检查项 | 结果 |
|---|---|
| 附件三项 P1 与修订前本地证据逐项对照 | PASS：三项均成立 |
| Schema 表数量 | PASS：仍为 42 张表 |
| 权限脚本的 Schema 对象引用 | PASS：43 个限定对象全部能在 `0001` 中解析为 42 张表或 1 个 Trigger Function |
| Audit 的运行角色 DML | PASS：未发现任何向 `admin_audit_logs` 授予 `UPDATE` 或 `DELETE` 的语句 |
| Audit 不可变对象 | PASS：1 个拒绝函数、1 个 BEFORE UPDATE/DELETE Trigger |
| Raw Event 关联 | PASS：五列授权绑定复合外键 + 三列区块复合外键均已出现，引用列顺序与唯一键一致 |
| 产品文档旧 Token 别名 | PASS：目标旧 symbol 文本匹配数为 0 |
| 产品文档“自动回购”与“每 60 秒自动” | PASS：文本匹配数均为 0 |
| 修改文档的相对链接 | PASS：静态检查未发现缺失目标 |
| 文本格式 | PASS：未发现 Tab；元数据行末两空格仅用于 Markdown 强制换行；文件均按 UTF-8 读取 |

上述 PASS 只表示静态结构和文本自审通过，不等价于 PostgreSQL 实际执行成功、权限隔离实测通过或 Finding 已被独立关闭。

## 8. 修改文件

- [PRODUCT_PLANNING.md](../PRODUCT_PLANNING.md)
- [README.md](./README.md)
- [02_DATABASE_FREEZE.md](./02_DATABASE_FREEZE.md)
- [05_BUSINESS_AND_CONTRACT_INHERITANCE.md](./05_BUSINESS_AND_CONTRACT_INHERITANCE.md)
- [06_DEPLOYMENT_ENVIRONMENT.md](./06_DEPLOYMENT_ENVIRONMENT.md)
- [09_SELF_REVIEW.md](./09_SELF_REVIEW.md)
- [0001_binggoplus_v2_schema.sql](./sql/0001_binggoplus_v2_schema.sql)
- [0002_binggoplus_v2_runtime_privileges.sql](./sql/0002_binggoplus_v2_runtime_privileges.sql)
- 本报告

未修改 Solidity、Laravel、TypeScript、Vue、Go、测试、部署脚本、ABI、广播记录或运行环境。未提交、未推送、未部署。

## 9. 独立复验清单

独立 Review Agent 应至少完成以下只读/隔离验证后再决定是否关闭 P1：

1. 在一次性隔离 PostgreSQL 中依次应用 `0001`、预建角色和 `0002`；不得连接现有开发、测试网服务或生产式数据库；
2. 验证合法 Stream/实例/地址/区块事件可以插入；五类错配事件均被复合外键拒绝；
3. 分别以 `bgp_api`、`bgp_reconciler`、`bgp_auditor` 和其他运行角色验证 Audit 的 INSERT/SELECT/UPDATE/DELETE/TRUNCATE 权限；
4. 验证运行角色不能禁用 Trigger、改表、切换到 `bgp_migrator` 或读取未授权认证/Signer 表；
5. 复核 `PRODUCT_PLANNING.md`、业务继承矩阵、OpenAPI 用户文案和前端后续实现均使用 BingGoPlus/PANGU2 边界；
6. 确认页面不会展示倒计时式或定时保证式回购承诺，只展示上次成功时间、最早可触发时间、实际条件与链上结果；
7. 复验通过后，将三个 Finding 从 `FIX_READY / RETEST_PENDING` 改为 `CLOSED`，但不要因此自动关闭 `GATE-01..05`。

## 10. 最终 Verdict

对附件的判断：`CORRECT`。  
对本轮修订的作者侧判断：`FIX_READY_FOR_INDEPENDENT_REVIEW`。  
对开发冻结的判断：`CHANGES_REQUIRED`，等待独立复验与既有 Gate 签署。  
对测试网合约的判断：继续继承现有已部署实例，不重部署。  
对 Mainnet 的判断：`NO-GO`。
