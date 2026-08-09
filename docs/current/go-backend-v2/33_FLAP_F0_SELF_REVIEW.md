# BingGoPlus Flap F0 作者侧自审

状态：`HISTORICAL_V2_AUTHOR_SELF_REVIEW / SUPERSEDED_BY_V2_EXTERNAL_ADJUDICATION`

> 本文件保存 V2 提审前作者侧自审。V2 外部报告已返回 `BLOCKED`，当前裁决和修订状态以 [35_FLAP_F0_V2_EXTERNAL_REVIEW_ADJUDICATION.md](./35_FLAP_F0_V2_EXTERNAL_REVIEW_ADJUDICATION.md) 为准，不得继续引用本文件的旧 `PASS_WITH_EVIDENCE_LIMITATION` 作为当前结论。

自审日期：2026-08-09
F0 开始时 HEAD：`0625b51`
打包前当前 HEAD：`ca34373cd51000fb76548dcbe89cd11e4583e4c4`
当前阶段：`FLAP-F0`
自审性质：文档与规则静态检查，不是独立批准

## 1. 结论

```text
SELF_REVIEW = PASS_WITH_EVIDENCE_LIMITATION
F0_DOCUMENTS = FIX_READY
F0_INDEPENDENT_REVIEW = PENDING
F0_OWNER_FREEZE = PENDING_AFTER_REVIEW
F1_ENTRY_AUTHORIZED = NO
EXTERNAL_REVIEW_SUBMISSION = USER_MANUAL
FLAP_IMPLEMENTATION = NOT_STARTED
CHAIN_WRITE = NO
BSC_MAINNET = NO-GO
```

F0 已形成产品转向、参数目录、目标架构、F0-F10 计划、Legacy 矩阵和审核提示词。作者侧没有权限把 F0 标为 `APPROVED/CLOSED/PASS`。

## 2. 已完成检查

| 检查 | 结果 | 说明 |
|---|---|---|
| 产品主线 | PASS | 当前权威统一为 `PRODUCT_MAINLINE = FLAP` |
| 当前阶段 | PASS | 当前统一为 `FLAP-F0`，F1 未授权 |
| 旧计划处置 | PASS | 文档 25/26 和旧 G2-G9 标记 Historical/Superseded，正文保留 |
| PANGU2 历史 | PASS | 合约、地址、实测、审核和数据不得删除或重部署 |
| 经济结构继承 | PASS | 资金桶、回购锁仓、Merkle、质押偿付、安全控制已进入新范围 |
| 永久退役 | PASS | CostBasis、动态盈利税、PANGU2 Router/Settlement、Launch Tax、Whitelist、Top100 四档和原 Staking 已明确退出 |
| 参数生命周期 | PASS | 区分 Draft、Launch Immutable、Governance Adjustable、Operation Input、System Allowlisted |
| Flap 真实性 | PASS_AS_DESIGN | F1 必须固定 Portal/VaultPortal/ABI/selector/runtime hash；F0 未伪造地址或 ABI |
| Guardian 边界 | PASS_AS_DESIGN | 只允许固定规则触发，不可改配置、Root 或提款 |
| 任意调用 | PASS | 明确禁止任意 target/selector/calldata |
| Mainnet | PASS | 所有当前文档保持 NO-GO |
| Markdown 相对链接 | PASS | 提审范围静态检查 81 个相对链接，0 缺失；Markdown 代码围栏 0 个不平衡 |
| 业务代码修改 | PASS | 本 F0 未修改 Go、SQL、OpenAPI、前端或 Solidity |

## 3. 经济模型继承复核

保留：

- Flap Token 实际供应结构和 18 decimals 的链上真实性；
- 单一透明 Tax 参数；
- Dividend/Buyback/Treasury/Operations/Reserve 资金桶；
- 回购资金限额、间隔、minOut、deadline、滑点、价格影响和暂停；
- 回购所得只进入 Locker 或真实 burn，不进入触发者；
- 默认 `0.01 BNB / 60 seconds / 365 days`，允许在冻结边界内调整；
- Merkle Epoch、快照 block/hash、一次领取、claim window、close/carry；
- 默认 30 天 claim window；
- Staking 本金与奖励储备隔离、默认 1 Token、最长 730 天、提前退出 10%；
- Evidence First、Fail Closed、最小权限和审计。

未恢复：

- 按成本/盈利状态判税；
- 买入/普通卖出/盈利卖出三套 PANGU2 税；
- 15 分钟 30% Launch Tax；
- Fee Whitelist；
- Top100 四档；
- PANGU2 专用转账与结算上下文。

## 4. 范围检查

本阶段新增：

```text
27_FLAP_PRODUCT_PIVOT_DECISION.md
28_FLAP_PRODUCT_SCOPE_AND_PARAMETER_CATALOG.md
29_FLAP_TARGET_ARCHITECTURE.md
30_FLAP_F0_F10_EXECUTION_PLAN.md
31_FLAP_LEGACY_RETIREMENT_MATRIX.md
32_FLAP_F0_INDEPENDENT_REVIEW_PROMPT.md
33_FLAP_F0_SELF_REVIEW.md
34_FLAP_F0_SUBMISSION_CONTEXT.md
```

本阶段还同步了根 README、Go V2 README、旧 00～09/25/26 状态、审核协议、Rules Master 和 `.project-ai` 当前上下文。同步只改变当前权威、状态和新产品规则；旧正文和历史审核结论保留。

## 5. Evidence 限制

开始 F0 前仓库已经存在大量已修改和未跟踪文件，其中部分与本阶段需要同步的 `.project-ai`、README、Runtime 状态和旧规划文件重叠。F0 整理期间，仓库 HEAD 又由其他既有工作推进到 `ca34373cd51000fb76548dcbe89cd11e4583e4c4`；F0 文件仍未形成独立 Commit。因此本轮没有自动执行 Git Commit，避免把用户此前未提交内容或其他阶段提交错误归入 F0 Commit。

```text
WORKTREE = DIRTY_BEFORE_F0
F0_COMMIT = NOT_CREATED
REMOTE_COMMIT_VERIFICATION = NOT_AVAILABLE
PACKAGE_CAN_BE_REVIEWED_AS_WORKTREE_SNAPSHOT = YES
COMPLIANT_STAGE_COMMIT = PENDING_OWNER_WORKTREE_DISPOSITION
```

独立审核必须明确其审核对象是完整工作区快照，而不是伪造的固定实现 Commit。若审核规则强制要求远程 40 位 Commit，则 Verdict 应为 `BLOCKED`，直到责任人安全隔离并提交 F0 文件。

## 6. 明确未执行

```text
GO_TEST = NOT_RUN
GO_BUILD = NOT_RUN
FRONTEND_TEST = NOT_RUN
SOLIDITY_TEST = NOT_RUN
DATABASE_MIGRATION = NOT_RUN
POSTGRESQL_RUNTIME = NOT_RUN
RPC = NOT_RUN
FORK = NOT_RUN
FLAP_API_CALL = NOT_RUN
SIGNATURE = NOT_RUN
CHAIN_BROADCAST = NOT_RUN
DEPLOYMENT = NOT_RUN
DEPENDENCY_DOWNLOAD = NOT_RUN
INDEPENDENT_REVIEW_SUBMISSION = USER_MANUAL_NOT_YET_SUBMITTED
```

## 7. 下一 Gate

用户手动提交文档 32 的审核提示词和完整提审包。收到报告后，执行 Agent 必须逐条二次裁决，只修正确 Finding；错误 Finding 记录反证。只有独立审核 `APPROVED` 且 `pd123` 完成 F0 Responsible Owner Freeze，才允许 F1。
