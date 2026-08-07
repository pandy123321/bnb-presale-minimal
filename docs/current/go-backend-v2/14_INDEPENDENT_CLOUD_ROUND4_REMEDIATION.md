# BingGoPlus Go Backend V2 第四轮独立云端复审核查与修订

日期：2026-08-07  
审核输入：用户粘贴的第四轮独立云端审核报告（`ROUND4_VERDICT = CHANGES_REQUIRED`）  
范围：开发启动前的数据库、权限、OpenAPI、Event/State 与规划冻结；未运行测试、构建、Migration、RPC、Fork 或部署，未修改任何业务代码或已部署合约。

## 1. 结论核查

附件的总体判断正确，均可由本地冻结文件直接证明：

1. `P1-R3-01..03` 与 `P2-DOC-01` 的关闭证据成立，本轮不再重开；
2. `P1-R3-04` 仍不能关闭：Preflight 过期刷新死路、input/projector 未精确绑定、Command 权限过宽、Epoch 后发布 writer 缺失、Preflight 可被并发消费；
3. `P1-DB-02` / `P1-DB-PRIV-02` 因上述治理/Dividend 权限与生命周期问题继续 OPEN；
4. `P1-DB-PRIV-01`、`P1-DB-01`、`P1-BRAND-01` 保持 CLOSED；
5. 三份 P2（Receipt 初态、coverage 序列化、文档漂移）正确，但不阻断机器权限的最小修复路径。

两份上位规则原文仍未进入本轮上传包时，独立 Agent 只能标 `UNABLE_TO_VERIFY`；本地根目录原文存在，但不改变本轮技术 Finding。

## 2. 已完成修订

### P1-R4-01

- Preflight 新增独立递增 `validation_revision`；
- 唯一身份改为 `(artifact_id, validation_revision)`；
- 删除 `(artifact_id, coverage_sha256, validator_version)` 永久唯一约束；
- 相同 Artifact/coverage/validator 在过期后可 INSERT 新 Preflight；旧记录 append-only 保留且永不复用。

### P1-R4-02

- Artifact 新增规范化 `projector_manifest_sha256`；
- Preflight 保存同一 hash，并通过复合外键同时绑定：

```text
content_sha256
merkle_root
total_reward_raw
input_sha256
projector_manifest_sha256
```

- 数据库不再允许“指向 Artifact A 却声称另一组 input/projector”的 Preflight。

### P1-R4-03

- `bgp_reconciler` 移除 `governance_commands` INSERT；
- API/Reconciler 对 Command 仅列级 `UPDATE (state, updated_at)`；
- Command immutable Trigger 扩展保护：

```text
environment_id
deployment_set_id
requested_by
expires_at
created_at
```

以及既有执行绑定字段；过期 Command 不得被运行角色复活。

### P1-R4-04

- `bgp_projector` 获得 `dividend_epochs` SELECT 与列级 UPDATE：

```text
state
merkle_root
claim_start
claim_end
carry_raw
updated_at
```

- 新增 `enforce_dividend_epoch_writer_boundary` Trigger：
  - Builder 只驱动发布前状态，以及 `CLAIM_OPEN -> CLOSE_QUEUED`，不能写 `merkle_root`；
  - Projector 只消费后发布事件派生转移，例如 `PUBLISH_QUEUED -> CLAIM_OPEN`、`CLOSE_QUEUED -> CLOSED/FAILED`、允许的 `CANCELLED`；
  - 禁止互相覆盖对方拥有的生命周期。

### P1-R4-05

- 新增条件唯一索引：同一 `DIVIDEND_PUBLISH` Preflight 最多创建一个 Command；
- HTTP 重试必须返回原 Command；若旧 Command 在签名前永久失效，必须先生成新的 Preflight revision。

### P2-R4-01

- State YAML 将 `projection_receipt.initial` 改为 `[APPLIED, FAILED]`，允许第一次处理直接失败。

### P2-R4-02

- `04_EVENT_AND_STATE_FREEZE.md` 冻结 coverage checksum 的排序键、canonical JSON 字段顺序、NULL Receipt 编码、换行规则与 SHA-256 字节定义。

### P2-R4-03

- 纠正自审 OpenAPI 计数为 43 paths / 44 operations；
- Dividend 表目录补齐 `dividend_publish_preflights`；
- 部署角色摘要同步 Builder Preflight、Reconciler evidence read、Projector Epoch writer 与 Command 列级更新。

## 3. 状态

```text
ATTACHED_REVIEW = CORRECT
P1-R3-01 = CLOSED
P1-R3-02 = CLOSED
P1-R3-03 = CLOSED
P1-R3-04 = FIX_READY / INDEPENDENT_RETEST_PENDING
P2-DOC-01 = CLOSED
P1-DB-01 = CLOSED
P1-BRAND-01 = CLOSED
P1-DB-PRIV-01 = CLOSED
P1-DB-02 = OPEN_PENDING_INDEPENDENT_RETEST
P1-DB-PRIV-02 = OPEN_PENDING_INDEPENDENT_RETEST
P1-R4-01 = FIX_READY / INDEPENDENT_RETEST_PENDING
P1-R4-02 = FIX_READY / INDEPENDENT_RETEST_PENDING
P1-R4-03 = FIX_READY / INDEPENDENT_RETEST_PENDING
P1-R4-04 = FIX_READY / INDEPENDENT_RETEST_PENDING
P1-R4-05 = FIX_READY / INDEPENDENT_RETEST_PENDING
P2-R4-01 = FIX_READY / INDEPENDENT_RETEST_PENDING
P2-R4-02 = FIX_READY / INDEPENDENT_RETEST_PENDING
P2-R4-03 = FIX_READY / INDEPENDENT_RETEST_PENDING
FROZEN_FOR_DEVELOPMENT = NO
DEVELOPMENT_START = NO
BSC_TESTNET_CONTRACT_REDEPLOY = FORBIDDEN
BSC_MAINNET = NO-GO
```

本报告不能替代 PostgreSQL 实际解析、Migration/Role 权限实测、标准 OpenAPI 3.1 校验、责任人签署或后续测试。第四轮问题只有在下一位独立审核 Agent 复验后才能关闭。
