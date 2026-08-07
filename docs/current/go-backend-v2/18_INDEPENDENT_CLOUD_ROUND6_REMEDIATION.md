# BingGoPlus Go Backend V2 第六轮独立云端复审核查与修订

日期：2026-08-07  
审核输入：用户提供的第六轮独立云端审核报告（`ROUND6_VERDICT = CHANGES_REQUIRED`）。  
范围：开发启动前的 SQL、权限、State、依赖准入和部署角色冻结。未运行测试、构建、Migration、RPC、Fork、部署、签名或链上交易；未修改 Solidity、应用业务代码或已部署合约。

## 1. 结论核查

附件结论正确。

- `P1-R4-02`：Preflight 的原始 manifest 与 Artifact 原始 manifest 可以不一致，hash 一致并不能证明两份 JSON 相同；
- `P1-R6-01`：Epoch writer Trigger 比 State YAML 宽，允许终态复活、非法跳转和已发布 root/claim window 原地修改；
- `P1-R6-02`：Command 只有列级 UPDATE，没有数据库状态转换/终态保护；
- `P2-R6-01`：Dependency Decision Record 未完整编码上位规则的分类与四方案 TCO；
- `P2-R6-02`：使用 `current_user` 的 Trigger 与 Login/Group Role 部署模型未冻结。

第六轮已独立关闭的历史项保持关闭，不在本报告中重新打开。

## 2. 已完成修订

### P1-R4-02：单一权威 manifest

- 从 `dividend_publish_preflights` 删除重复的 `projector_manifest jsonb`；
- Preflight 只通过具体 Artifact 及其 `projector_manifest_sha256` 读取权威 manifest；
- 冻结 manifest 的递归排序、允许类型、整数/NULL、UTF-8、JSON 编码、换行和 SHA-256 协议。

### P1-R6-01：Epoch 精确状态边与发布后不可变性

- 重写 `enforce_dividend_epoch_writer_boundary()`，只接受 State YAML 已声明的边；
- Builder 只能推进发布前边和 `CLAIM_OPEN -> CLOSE_QUEUED`；Projector 只能推进 `PUBLISH_QUEUED -> CLAIM_OPEN` 与 `CLOSE_QUEUED -> CLOSED/FAILED`；
- `CLOSED/CANCELLED` 永久终态；发布后 Epoch 不能再回到 publish queue；
- `PUBLISH_QUEUED -> CLAIM_OPEN` 是唯一写入 root/claim window 的边；进入 `CLAIM_OPEN` 后三者不可改写。

### P1-R6-02：Command 精确状态边

- 新增 `enforce_governance_command_state_transition()`；
- API 仅驱动 intake/approval 前状态；Reconciler 仅驱动 approved 后的排队、签名、提交、确认和终结状态；
- 所有终态不可离开；same-state 仅允许既有列级 `updated_at` 更新；
- 保持既有执行绑定/expiry immutable Trigger 和 Reconciler 无 INSERT Command 权限。

### P2-R6-01：依赖准入

- Decision Record 分离 `Lifecycle Status` 与 `Upper-Rule Classification`；
- 增加四种采用方式各自的 TCO 字段；不适用项必须写 `N/A + reason`；
- 保持 `NO_DOWNLOAD_AUTHORIZED`。

### P2-R6-02：角色身份

- 运行进程必须直接以同名 `bgp_*` LOGIN Role 连接；
- 禁止通过 INHERIT Group Role 隐式满足 `current_user` Trigger；
- 连接验收必须验证 `SELECT current_user`，不匹配即 Ready=false 且不得写业务状态。

## 3. 状态

```text
ATTACHED_ROUND6_REVIEW = CORRECT
P1-R4-02 = FIX_READY / INDEPENDENT_RETEST_PENDING
P1-R6-01 = FIX_READY / INDEPENDENT_RETEST_PENDING
P1-R6-02 = FIX_READY / INDEPENDENT_RETEST_PENDING
P2-R6-01 = FIX_READY / INDEPENDENT_RETEST_PENDING
P2-R6-02 = FIX_READY / INDEPENDENT_RETEST_PENDING

P1-R3-04 = OPEN_PENDING_INDEPENDENT_RETEST
P1-DB-02 = OPEN_PENDING_INDEPENDENT_RETEST
P1-DB-PRIV-02 = OPEN_PENDING_INDEPENDENT_RETEST
FROZEN_FOR_DEVELOPMENT = NO
DEVELOPMENT_START = NO
BSC_TESTNET_CONTRACT_REDEPLOY = FORBIDDEN
BSC_MAINNET = NO-GO
```

本报告是作者侧修订记录，不替代 PostgreSQL 实际执行、运行时 Role 测试、标准 OpenAPI 校验、责任人签署或独立复验。

