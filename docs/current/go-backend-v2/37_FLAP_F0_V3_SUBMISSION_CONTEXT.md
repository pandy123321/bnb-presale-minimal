# BingGoPlus Flap F0 V3 独立提交上下文

状态：`HISTORICAL_V3_SUBMISSION / EXTERNAL_REVIEW_BLOCKED / SUPERSEDED_BY_V4_SUBMISSION_CONTEXT`

> 本文件保留 V3 Commit/Package 身份，不得改写为 V4 当前状态。V3 外审裁决见文档 38，V4 权威提审身份见文档 40。

```text
PROJECT = BingGoPlus
STAGE = FLAP-F0
BRANCH = codex/flap-f0-v3-freeze
BASELINE_COMMIT = a380f66f8b754db502dff07b6e760c53e9b2d833
IMPLEMENTATION_COMMIT = COMMIT_CONTAINING_THIS_FILE / SEE_PACKAGE_COMMIT_ID
LOCAL_ISOLATED_COMMIT = YES
REMOTE_RESOLVABLE = NO / PENDING_MANUAL_PUSH
SUBMISSION_MODE = USER_MANUAL
F0_DOCUMENT_FREEZE = NO
F1_ENTRY_AUTHORIZED = NO
FLAP_IMPLEMENTATION_ALLOWED = NO
BSC_MAINNET = NO-GO
```

## 1. 隔离方法

本提交从基线 `a380f66f8b754db502dff07b6e760c53e9b2d833` 创建独立 worktree 和 `codex/flap-f0-v3-freeze` 分支，只带入 F0 文档、规则和当前上下文。主工作区原有 66 项用户/并行任务改动没有被暂存、覆盖、删除或归入本提交。

提交包中的以下证据给出实际 Commit：

```text
COMMIT_ID.txt
COMMIT_METADATA.txt
F0_COMPLETE.diff
F0_NAME_STATUS.txt
```

本文不能在同一个 Git Commit 内自引用其最终 SHA，因此以 Package Evidence 中由 Git 读取的 `COMMIT_ID.txt` 为权威绑定。

## 2. V2 报告与裁决

```text
V2_EXTERNAL_VERDICT = BLOCKED
V2_REPORT_SHA256 = f4aef98df714cb3956d07e40ec60ac5f602a17f6ce54398683553e3a2b599d8b
V2_ADJUDICATION = PARTIAL
```

逐项裁决见 [35_FLAP_F0_V2_EXTERNAL_REVIEW_ADJUDICATION.md](./35_FLAP_F0_V2_EXTERNAL_REVIEW_ADJUDICATION.md)，作者侧修订自审见 [36_FLAP_F0_V3_REMEDIATION_SELF_REVIEW.md](./36_FLAP_F0_V3_REMEDIATION_SELF_REVIEW.md)。审核 Agent 必须复验被接受的修订，也必须核对被拒绝 Finding 的责任人反证，不能把外部报告原样当作授权。

## 3. 本次核心冻结候选

```text
PROJECT_STRATEGY = IN_PLACE_FLAP_PIVOT
EXECUTION_MODE = ADMIN_WALLET
NATIVE_MVP = F1_TO_F6
BGPLUS_REQUIRED_EXTENSION_ROADMAP = F7_TO_F10
GENERIC_STAKING = F10_ONLY
LEGACY_CUTOVER = F11_ONLY
EXISTING_PANGU2_REDEPLOY = FORBIDDEN
```

F1 必须验证 Flap 地址、ABI、selector、runtime hash、默认值、事件以及 Admin Wallet 的 `creator/payer/msg.sender/initial buyer` 语义。F0 不授权任何实现、下载、RPC、签名、广播或部署。

## 4. Package 完整性规则

手动提交时必须同时上传：

```text
BINGGOPLUS_FLAP_F0_V3_ISOLATED_REVIEW_PACKAGE_20260809_V1.zip
BINGGOPLUS_FLAP_F0_V3_ISOLATED_REVIEW_PACKAGE_20260809_V1.zip.sha256
```

ZIP 内必须包含 `PAYLOAD_MANIFEST.csv` 与其独立 Hash。外层 ZIP Hash 只能由 companion 文件声明，禁止在 ZIP 内做自引用 Hash。

## 5. 当前未关闭事项

```text
REMOTE_PUSH = USER_MANUAL_PENDING
INDEPENDENT_REVIEW = PENDING
RESPONSIBLE_OWNER_FREEZE = PENDING_AFTER_APPROVED_REVIEW
F1_ENTRY_AUTHORIZED = NO
```

按照全局规则，未推送时审核 Agent 可以使用包内完整 Diff 做内容复验，但如果其 Gate 强制要求远程可解析 SHA，必须保持 `BLOCKED`，直到用户手动推送该分支。执行 Agent 不得自动 Push、Merge 或修改 Mainnet 状态。
