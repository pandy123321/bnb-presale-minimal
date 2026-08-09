# BingGoPlus Flap F0 V3 修订作者侧自审

状态：`HISTORICAL_V3_AUTHOR_SELF_REVIEW / SUPERSEDED_BY_V3_EXTERNAL_REVIEW_AND_V4_REMEDIATION`

> 本文件保存 V3 提审前作者侧证据，不再代表当前修订状态。V3 外审裁决见文档 38，当前修订自审见文档 39。

状态：`CONTENT_FIX_READY / LOCAL_ISOLATED_COMMIT_FIX_READY / REMOTE_PUSH_PENDING / INDEPENDENT_RETEST_PENDING`

```text
SELF_REVIEW = PASS_CONTENT_WITH_EVIDENCE_BLOCKER
V2_EXTERNAL_VERDICT = BLOCKED
V2_ADJUDICATION = PARTIAL
P0_OPEN = 0
CONTENT_P1_OPEN = 0_AUTHOR_ASSESSMENT
P2_01_LOCAL_ISOLATED_COMMIT = FIX_READY_BY_COMMIT_CONTAINING_THIS_FILE
P2_01_REMOTE_RESOLVABLE = NO / PENDING_MANUAL_PUSH
F0_DOCUMENT_FREEZE = NO
F1_ENTRY_AUTHORIZED = NO
FLAP_IMPLEMENTATION_ALLOWED = NO
TESTNET_DEPLOYMENT_ALLOWED = NO
BSC_MAINNET = NO-GO
```

本文件是作者侧自审，不关闭任何 Finding，也不替代独立复验。V2 报告及二次裁决见 [35_FLAP_F0_V2_EXTERNAL_REVIEW_ADJUDICATION.md](./35_FLAP_F0_V2_EXTERNAL_REVIEW_ADJUDICATION.md)。

## 1. 外部结论处理结果

### 未执行的错误方向

- 未把当前项目拆成独立新项目；责任人明确要求在现有项目基础上直接转 Flap；
- 未把后台 Admin Wallet 发币改成普通用户自助钱包；责任人明确要求后台调用 Flap 接口/合约发币；
- 未把 BGPlus Vault/Buyback/Locker/Dividend/Staking 降为可随意删除的想法；责任人要求“发币和重做都要”。

### 已执行的正确修订

- 清除 `.project-ai` 和当前 README 中 Legacy RT02/RT03“全部 PASS/当前可开发”的错误语义；
- 补齐 RevenueVault 五个 Bucket 的目的地、允许动作、触发者、配置冻结和累计会计；
- 将 Flap 官方文档能力标为 `DOCUMENTED_BY_FLAP / PENDING_F1_RUNTIME_BASELINE`；
- Split Vault 从确定 MVP 改为候选，增加 Standard/Tax-without-Vault fallback；
- F10 只做通用 Staking，F11 单独做 Legacy Cutover；
- 手动审核无任务号时使用 `N/A_USER_MANUAL`，并记录 Artifact ID、报告 Hash、时间与 Reviewer Identity；
- F1 增加 Admin Wallet 的 `creator/payer/msg.sender/initial buyer` 身份核验。

## 2. RevenueVault 自审

每个 Bucket 已定义：

```text
SOURCE
DESTINATION
AUTHORIZED_ACTION
WHO_CAN_TRIGGER
CONFIG_FREEZE
ACCOUNTING_OUTFLOW_TYPE
FAILURE_BEHAVIOR
```

累计会计已区分：

```text
total_received_bnb
total_allocated_bnb
total_current_liability_bnb
total_executed_outflow_bnb
rounding_carry_bnb
funded_to_dividend_bnb
spent_on_buyback_bnb
paid_to_treasury_bnb
paid_to_operations_bnb
released_reserve_bnb
```

外部调用失败不得减少对应 Bucket liability；回购花费不得继续显示为 Vault 余额。具体 Solidity 存储布局、取整实现、重入保护和资产恢复仍属于 F7 独立规格与安全审核，不由 F0 提前批准。

## 3. 阶段边界自审

```text
F0-F6 = Flap Native Baseline/MVP
F7-F10 = Native MVP 后正式 BGPlus 扩展路线
F10 = Generic Staking only
F11 = Legacy Cutover/Retirement only
```

F7-F10 不阻塞 F5/F6 Native MVP，但不得被执行 Agent自行删除。F11 只有在替代路径、数据导出、写入口撤销、回滚计划和独立审核全部通过后才能执行。

## 4. 静态检查

```text
CURRENT_REVIEW_FILES = 44
MARKDOWN_FILES = 38
RELATIVE_LINKS = 89
MISSING_LOCAL_LINKS = 0
UNBALANCED_MARKDOWN_FENCES = 0
RULE_ROWS = 60
FALSE_CURRENT_RT_PASS_HITS = 0
EXECUTION_MODE_USER_WALLET_HITS = 0
EXECUTION_MODE_ADMIN_WALLET_HITS = 1
CONTEXT_VERSION = 19
```

## 5. 明确未执行

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
EXTERNAL_REVIEW_TOOL_CALL = NOT_RUN / USER_MANUAL
```

这些未执行项符合 F0 文档阶段范围，不能被写成 PASS。

## 6. 剩余证据 Gate

```text
P2_01_LOCAL_ISOLATED_COMMIT = FIX_READY_BY_COMMIT_CONTAINING_THIS_FILE
P2_01_REMOTE_RESOLVABLE = NO / PENDING_MANUAL_PUSH
```

主工作区在 F0 开始前已经包含用户修改，且 F0 期间 HEAD 已至少从 `0625b51` 前进到 `ca34373cd51000fb76548dcbe89cd11e4583e4c4`，随后又前进到 `a380f66f8b754db502dff07b6e760c53e9b2d833`。V3 已从 `a380f66...` 创建独立 `codex/flap-f0-v3-freeze` worktree，只把 F0 授权文件放入本提交，主工作区改动未被归入。提交包必须形成：

```text
ONE_F0_COMMIT
40_CHAR_REMOTE_RESOLVABLE_SHA
COMPLETE_ATTRIBUTABLE_DIFF
PAYLOAD_MANIFEST
ZIP
SEPARATE_ZIP_SHA256_COMPANION
```

本地 Commit 和完整 Diff 可由包内证据复算；远程可解析仍等待用户手动 Push。在远程 Gate 和独立审核通过前，不得把 V3 标为 `APPROVED`，也不得进入 F1。
