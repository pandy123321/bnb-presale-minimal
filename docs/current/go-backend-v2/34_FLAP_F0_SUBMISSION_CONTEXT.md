# BingGoPlus Flap F0 手动提审上下文

状态：`HISTORICAL_V2_SUBMISSION_CONTEXT / REVIEWED_BLOCKED / SUPERSEDED_BY_V3_REMEDIATION`

> 本文件记录 V2 工作区快照的提审上下文。V2 已经独立审核为 `BLOCKED`；当前修订和 Finding 裁决见 [35_FLAP_F0_V2_EXTERNAL_REVIEW_ADJUDICATION.md](./35_FLAP_F0_V2_EXTERNAL_REVIEW_ADJUDICATION.md)。不得把本文件继续作为新的提审身份。

## 1. 提审身份

```text
PRODUCT = BingGoPlus
PRODUCT_MAINLINE = FLAP
STAGE = FLAP-F0
SUBMISSION_MODE = USER_MANUAL
EXECUTOR_EXTERNAL_REVIEW_TOOL_CALL = FORBIDDEN_FOR_ALL_STAGES_UNTIL_OWNER_CHANGES_RULE
F1_ENTRY_AUTHORIZED = NO
FLAP_IMPLEMENTATION_ALLOWED = NO
BSC_MAINNET = NO-GO
```

本轮由用户自行把完整提审包和文档 32 的提示词交给独立审核 Agent。执行 Agent 不寻找、不调用、不等待任何外部审核通道；该手动提交流程适用于后续阶段，直到责任人书面修改规则。

## 2. Git 与工作区证据

```text
F0_START_HEAD = 0625b51
PACKAGE_BASE_HEAD = ca34373cd51000fb76548dcbe89cd11e4583e4c4
PACKAGE_BASE_SUBJECT = RT-GATE Governance Fix: Revert G2 (unauthorized), restore RT02=BLOCKED_EVIDENCE, sync RT03 with Decision/License Gates
WORKTREE_DIRTY_BEFORE_F0 = YES
F0_ISOLATED_COMMIT = NOT_AVAILABLE
SUBMISSION_ARTIFACT_TYPE = COMPLETE_WORKTREE_SNAPSHOT
```

F0 开始前已有大量用户修改和未跟踪文件。F0 整理过程中，HEAD 从 `0625b51` 前进到 `ca34373cd51000fb76548dcbe89cd11e4583e4c4`；这次前进不是 F0 文档的独立提交。审核 Agent 不得把工作区内容错误归因于该 Commit，也不得把 Commit message 当成 F0 证据。

若审核政策强制要求“单一远程 40 位 Commit + 完整可归因 Diff”，应输出：

```text
VERDICT = BLOCKED
REASON = F0_ISOLATED_COMMIT_NOT_AVAILABLE
```

不得因此虚构 Commit、Diff、测试或部署结果。

## 3. 本轮审核对象

核心新文档：

```text
27_FLAP_PRODUCT_PIVOT_DECISION.md
28_FLAP_PRODUCT_SCOPE_AND_PARAMETER_CATALOG.md
29_FLAP_TARGET_ARCHITECTURE.md
30_FLAP_F0_F11_EXECUTION_PLAN.md
31_FLAP_LEGACY_RETIREMENT_MATRIX.md
32_FLAP_F0_INDEPENDENT_REVIEW_PROMPT.md
33_FLAP_F0_SELF_REVIEW.md
34_FLAP_F0_SUBMISSION_CONTEXT.md
```

还必须审核提审包内同步后的根 README、目录 README、规则原文、Rules Master、旧冻结文档状态标记和 `.project-ai` 当前上下文。`PAYLOAD_MANIFEST.csv` 与外层 ZIP SHA-256 只证明文件完整性，不证明内容正确或阶段通过。

## 4. 不属于本轮批准的内容

```text
GO_IMPLEMENTATION = NOT_IN_SCOPE
SQL_MACHINE_FREEZE = NOT_IN_SCOPE
OPENAPI_MACHINE_FREEZE = NOT_IN_SCOPE
FRONTEND_IMPLEMENTATION = NOT_IN_SCOPE
NEW_SOLIDITY = NOT_IN_SCOPE
DEPENDENCY_DOWNLOAD = NOT_IN_SCOPE
RPC_RUNTIME = NOT_IN_SCOPE
TESTNET_TRANSACTION = NOT_IN_SCOPE
DEPLOYMENT = NOT_IN_SCOPE
MAINNET = NO-GO
```

工作区中可能存在其他阶段或历史遗留文件。它们可以作为冲突证据，但不能因为被打包而自动获得批准。

## 5. 审核结果回收规则

用户取得审核报告后，执行 Agent 必须先验证每条 Finding 的文件定位、证据、影响和修复方案是否正确：

- 正确 Finding：在 F0 授权范围内修复，记录修改位置和验收标准；
- 错误 Finding：不执行，记录 Counter-Evidence 和不执行理由；
- 无法判断：暂停对应项，请求补充证据；
- 任何超出 F0 文档范围、改变业务/合约/API/数据库/权限的建议：必须单独取得人工授权。

只有独立审核 `APPROVED`、执行方二次裁决完成且 `pd123` 完成 F0 Responsible Owner Freeze 后，才允许把 F1 标为可进入。
