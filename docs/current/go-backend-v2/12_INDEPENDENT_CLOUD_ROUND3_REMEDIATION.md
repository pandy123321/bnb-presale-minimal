# BingGoPlus Go Backend V2 第三轮独立云端复审核查与修订

日期：2026-08-07  
审核输入：`C:\Users\xingf\.codex\attachments\56832764-2864-41f7-a5be-2cd55ea82cee\pasted-text.txt`  
范围：开发启动前的数据库、权限、OpenAPI 与规划冻结；未运行测试、构建、Migration、RPC、Fork 或部署，未修改任何业务代码或已部署合约。

## 1. 结论核查

附件的四个 P1 判断正确，均可由本地冻结文件直接证明：

1. Projector 获得 `projection_receipts` 整表 UPDATE，可改写 Receipt 身份；
2. `(epoch, algorithm_version)` 唯一键与 INSERT-only 冲突，合法重建及重新审批会进入死路；
3. Allocation、Approval、Epoch root 与具体 Artifact 没有精确数据库绑定；
4. Builder、API、Reconciler 之间没有可消费且不可变的 Publish Preflight，也没有签名前端到端复验权限。

`P2-DOC-01` 的云端 `BLOCKED` 只表示上传材料不足，不代表本地修订错误。本地 `docs/current/PRODUCT_PLANNING.md` 存在；两份根目录上位规则也存在。下一轮必须完整上传，才能由独立 Agent 正式关闭该项。

## 2. 已完成修订

### P1-R3-01

- Projector 的 Receipt UPDATE 收窄到 `status/result_refs/error/applied_at`；
- 新增 DB Trigger，禁止修改 `id/raw_event_id/projector_key/projector_version`；
- Trigger Function 对 PUBLIC 撤销执行权。

### P1-R3-02

- Artifact 新增独立递增 `artifact_revision` 和 `supersedes_artifact_id`；
- 唯一身份改为 `(epoch, revision)`，允许相同算法在新输入下生成新 revision；
- Approval 唯一键包含 `artifact_id`，同一审批人可对新 revision 重新审批；
- Artifact、Allocation、Approval 都保留历史且拒绝原地 UPDATE/DELETE。

### P1-R3-03

- Artifact 固定 epoch、environment、snapshot block/hash、input、projector manifest、content、Merkle root 和 total reward；
- Allocation 通过复合外键绑定具体 Artifact；
- Approval 的 hash/root/amount 全部必填，并通过复合外键精确匹配具体 Artifact；
- Builder 不再能独立更新 `dividend_epochs.merkle_root`；
- OpenAPI 将五个 Dividend action 拆成独立路径；approve/publish body 为必填 closed schema，明确要求 Artifact/hash/root/amount。

### P1-R3-04

- 新增 append-only `dividend_publish_preflights`，固化 snapshot、projector manifest、input hash、coverage hash/count、Artifact hash、root、amount、validator version 和有效期；
- `DIVIDEND_PUBLISH` Governance Command 在数据库层必须引用 Preflight；
- Builder 只生成 Preflight，不创建 Command；API 只消费 Preflight 并创建 Command；
- Reconciler 获得只读 Dividend evidence/View 权限，并必须在签名前独立复验；任一证据漂移或 Preflight 过期均 fail closed。

## 3. 状态

```text
ATTACHED_REVIEW = CORRECT
P1-R3-01 = FIX_READY / INDEPENDENT_RETEST_PENDING
P1-R3-02 = FIX_READY / INDEPENDENT_RETEST_PENDING
P1-R3-03 = FIX_READY / INDEPENDENT_RETEST_PENDING
P1-R3-04 = FIX_READY / INDEPENDENT_RETEST_PENDING
P2-DOC-01 = LOCAL_FIX_PRESENT / CLOUD_RETEST_PENDING_WITH_COMPLETE_UPLOAD
P1-DB-02 = OPEN_PENDING_INDEPENDENT_RETEST
P1-DB-PRIV-01 = OPEN_PENDING_INDEPENDENT_RETEST
P1-DB-PRIV-02 = OPEN_PENDING_INDEPENDENT_RETEST
FROZEN_FOR_DEVELOPMENT = NO
DEVELOPMENT_START = NO
BSC_TESTNET_CONTRACT_REDEPLOY = FORBIDDEN
BSC_MAINNET = NO-GO
```

本报告不能替代 PostgreSQL 实际解析、Migration/Role 权限实测、标准 OpenAPI 3.1 校验、责任人签署或后续测试。第三轮问题只有在下一位独立审核 Agent 复验后才能关闭。
