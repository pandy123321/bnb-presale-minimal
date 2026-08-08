# BingGoPlus Go Backend V2 第七轮独立云端复审核查与修订

日期：2026-08-07  
输入：用户提供的第七轮独立云端审核报告（`ROUND7_VERDICT = CHANGES_REQUIRED`）。  
范围：Go Backend V2 开发前冻结件中的 SQL、权限、OpenAPI、状态机和交付包；未运行测试、构建、Migration、Docker、RPC、Fork、部署、签名或链上交易，未修改 Solidity、已部署合约或运行环境。

## 1. 结论核查

附件的两个 P1 结论正确：

- `P1-R7-01`：State YAML 存在 `PUBLISH_QUEUED -> FAILED`，但原 SQL 没有唯一且可执行的 writer；发布 Command 失败会让 Epoch 停留在 `PUBLISH_QUEUED`。
- `P1-R7-02`：取消 HTTP 契约与 API/Reconciler 的列级权限之间没有不可变、可审计的交接；已批准或排队、但尚未签名的 Command 不能按既定 API 契约可靠取消。

`P2-R7-01` 也正确：旧 Round7 包同时含有错误且过期的 `SUBMISSION_MANIFEST`。该文件不再进入下一轮交付包；`PAYLOAD_MANIFEST` 是唯一权威清单。

## 2. 修订方案

### P1-R7-01：发布失败唯一 writer

- `bgp_reconciler` 仅获得 `dividend_epochs(state, updated_at)` 的列级权限；不获得证据字段或整表 UPDATE。
- `enforce_dividend_epoch_writer_boundary()` 只接受 Reconciler 的 `PUBLISH_QUEUED -> FAILED`。
- 该边必须存在绑定同一 Epoch 的 `DIVIDEND_PUBLISH` Command，且 Command 已在同一事务内进入 `FAILED`、`CANCELLED` 或 `EXPIRED`。
- Reconciler 不能改变 `merkle_root`、claim window 或 `carry_raw`。失败后仍只能依据 State YAML 的 `FAILED` 出边恢复。

### P1-R7-02：取消意图与消费

- 新增 append-only `governance_command_cancellation_requests`。
- API 只能 INSERT `REQUESTED` 的不可变 intent；不得直接将 Command 写为 `CANCELLED`。
- Reconciler 是唯一可将 intent 解析为 `CONSUMED/REJECTED` 的角色，也是唯一可在未签名前推进 Command 至 `CANCELLED` 的角色。
- Reconciler 在签名前必须锁定 Command 和 cancellation request；有 pending request 的 `QUEUED` Command 不得进入 `SIGNING`。
- request 仅能在 `CREATED/VALIDATED/PENDING_APPROVAL/APPROVED/QUEUED` 创建。进入 `SIGNING/SUBMITTED` 后不能建立 intent，链上交易继续由 Reconciler 跟踪，不存在“撤销已广播交易”的假语义。

## 3. 静态自审边界

本轮只核对冻结件的对象、状态边、FK/UNIQUE、触发器与列级 GRANT/REVOKE。未将静态核对表述为 PostgreSQL Migration、Role runtime、Go 实现、测试、RPC 或部署通过。

```text
ATTACHED_ROUND7_REVIEW = CORRECT
P1-R7-01 = FIX_READY / INDEPENDENT_RETEST_PENDING
P1-R7-02 = FIX_READY / INDEPENDENT_RETEST_PENDING
P2-R7-01 = FIX_READY / INDEPENDENT_RETEST_PENDING
P1-R4-02 = CLOSED_PENDING_INDEPENDENT_RETEST
P2-R6-01 = CLOSED_PENDING_INDEPENDENT_RETEST
P2-R6-02 = CLOSED_PENDING_INDEPENDENT_RETEST
P1-R6-01 = FIX_READY / INDEPENDENT_RETEST_PENDING
P1-R6-02 = FIX_READY / INDEPENDENT_RETEST_PENDING
P1-R3-04 = FIX_READY / INDEPENDENT_RETEST_PENDING
P1-DB-02 = FIX_READY / INDEPENDENT_RETEST_PENDING
P1-DB-PRIV-02 = FIX_READY / INDEPENDENT_RETEST_PENDING
FROZEN_FOR_DEVELOPMENT = NO
DEVELOPMENT_START = NO
BSC_TESTNET_CONTRACT_REDEPLOY = FORBIDDEN
BSC_MAINNET = NO-GO
```

独立复审应重点确认：取消 request 的创建、消费和锁顺序；Command 失败与 Epoch 失败的同事务顺序；State YAML、Trigger、GRANT 的逐边一致性；以及 Round8 包只保留一个权威 Manifest。
