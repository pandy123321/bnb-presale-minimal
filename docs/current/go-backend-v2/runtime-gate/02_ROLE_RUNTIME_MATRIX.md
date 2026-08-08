# RT-GATE-01 补充：Role Runtime 权限验证矩阵

## 状态

```text
RT-GATE-01_ROLE_RUNTIME = BLOCKED_POSTGRESQL_NOT_AVAILABLE
```

## 前置条件

Migration（`0001` + `0002`）必须先通过，且每个 LOGIN Role 已由平台创建。

## 通用验证

每个角色连接后必须执行：

```sql
SELECT current_user;
```

结果必须精确等于对应 `bgp_*` Role（例如 `bgp_api`、`bgp_indexer`），不得等于 `session_user`（如果不同）、不得依赖 INHERIT Group Role、不得通过 `SET ROLE` 隐式获取权限。

## 角色权限验证矩阵

### bgp_api

**应该成功（10 项）：**

| # | 操作 | 验证目标 |
|---|---|---|
| API-01 | SELECT environments, deployment_sets, contract_instances | 读部署证据 |
| API-02 | SELECT chain_cursors, token_balances_current, cost_basis_current, trades | 读 Public 投影 |
| API-03 | SELECT staking_positions, staking_events, dividend_epochs, dividend_artifacts, dividend_allocations, dividend_publish_preflights, dividend_claims | 读 Staking/Dividend 读模型 |
| API-04 | SELECT buybacks, locker_batches, fee_vault_movements, oracle_events, protocol_control_events, role_events | 读回购/锁仓/控制事件 |
| API-05 | SELECT governance_tx_attempts, job_runs, system_anomalies | 读治理/Job/异常 |
| API-06 | INSERT dividend_epochs (DRAFT, 含 snapshot block/hash) | 创建 DRAFT Epoch |
| API-07 | INSERT governance_commands (CREATED) | 创建 Governance Command |
| API-08 | INSERT governance_command_cancellation_requests (REQUESTED) | 创建取消意图 |
| API-09 | EXECUTE bind_current_dividend_publish_command(...) | 绑定当前 Publish Command |
| API-10 | SELECT, INSERT admin_audit_logs | 写 append-only Audit |

**必须失败（5 项）：**

| # | 禁止操作 | 原因 |
|---|---|---|
| API-F1 | UPDATE dividend_epochs 任意列（除通过 bind function） | API 不拥有 Epoch 直接 UPDATE |
| API-F2 | UPDATE governance_command_cancellation_requests | Cancellation intent 不可变 |
| API-F3 | UPDATE governance_commands 非 state/updated_at 列 | Command 执行绑定不可变 |
| API-F4 | SELECT wallet_challenges (attempt to read signer/challenge secret) | API 不读 Challenge（应验证实际权限） |
| API-F5 | INSERT chain_raw_events | API 不写 Raw Event |

### bgp_indexer

**应该成功（4 项）：**

| # | 操作 | 验证目标 |
|---|---|---|
| IDX-01 | INSERT chain_blocks | 写入新区块 |
| IDX-02 | INSERT chain_raw_events | 写入 Raw Event |
| IDX-03 | UPDATE chain_raw_events SET event_name, decoded, status, canonical, confirmed_at | 更新解码/确认列 |
| IDX-04 | UPDATE chain_blocks SET canonical, finalized | 更新区块状态 |

**必须失败（3 项）：**

| # | 禁止操作 | 原因 |
|---|---|---|
| IDX-F1 | UPDATE chain_raw_events SET topic0, topics, data, contract_address, tx_hash, block_hash, block_number | 原始证据不可改写 |
| IDX-F2 | DELETE FROM chain_raw_events | 禁止物理删除 |
| IDX-F3 | INSERT dividend_artifacts | Indexer 不写 Artifact |

### bgp_projector

**应该成功（5 项）：**

| # | 操作 | 验证目标 |
|---|---|---|
| PRJ-01 | SELECT chain_raw_events | 读 Raw Event |
| PRJ-02 | INSERT projection_receipts | 写入投影回执 |
| PRJ-03 | UPDATE projection_receipts SET status, result_refs, error, applied_at | 更新收条允许列 |
| PRJ-04 | INSERT token_balance_ledger, staking_events | 追加 versioned ledger |
| PRJ-05 | UPDATE dividend_epochs SET state, merkle_root, claim_start, claim_end, carry_raw, updated_at（限 CLAIM_OPEN/CLOSED 投影边） | 列级写链上事件派生 Epoch 字段 |

**必须失败（3 项）：**

| # | 禁止操作 | 原因 |
|---|---|---|
| PRJ-F1 | UPDATE chain_raw_events | Projector 对 Raw Event 只读 |
| PRJ-F2 | UPDATE projection_receipts SET raw_event_id, projector_key, projector_version | Receipt 身份不可变 |
| PRJ-F3 | DELETE FROM token_balance_ledger | Versioned ledger 不可删除 |

### bgp_dividend

**应该成功（5 项）：**

| # | 操作 | 验证目标 |
|---|---|---|
| DIV-01 | SELECT dividend_finalized_blocks_v1, dividend_projection_coverage_v1 | 读 finalized block 和 coverage |
| DIV-02 | SELECT dividend_token_balance_history_v1, dividend_staking_history_v1 | 读窄化历史视图 |
| DIV-03 | INSERT dividend_artifacts | 创建不可变 Artifact |
| DIV-04 | INSERT dividend_allocations | 创建不可变 Allocation |
| DIV-05 | INSERT dividend_publish_preflights | 创建不可变 Preflight |

**必须失败（4 项）：**

| # | 禁止操作 | 原因 |
|---|---|---|
| DIV-F1 | UPDATE dividend_epochs SET merkle_root | Builder 不写 merkle_root |
| DIV-F2 | UPDATE/DELETE dividend_artifacts | Artifact append-only |
| DIV-F3 | UPDATE/DELETE dividend_allocations | Allocation append-only |
| DIV-F4 | SELECT token_balances_current (写 actual SELECT) | Builder 禁止读 current 表生成快照 |

### bgp_reconciler

**应该成功（5 项）：**

| # | 操作 | 验证目标 |
|---|---|---|
| REC-01 | SELECT governance_commands (approved/QUEUED) | 读需签名的 Command |
| REC-02 | UPDATE governance_commands SET state, updated_at | 推进 Command state |
| REC-03 | UPDATE governance_command_cancellation_requests SET state, resolved_at | 消费取消意图 |
| REC-04 | INSERT governance_tx_attempts, UPDATE signer_nonces | 写 nonce/attempt |
| REC-05 | UPDATE dividend_epochs SET state (PUBLISH_QUEUED -> FAILED only) | 发布失败边 |

**必须失败（4 项）：**

| # | 禁止操作 | 原因 |
|---|---|---|
| REC-F1 | INSERT governance_commands | Reconciler 不创建 Command |
| REC-F2 | UPDATE governance_commands SET context, expiry, requested_by | Command 绑定不可变 |
| REC-F3 | UPDATE dividend_epochs SET merkle_root | Reconciler 不写 root |
| REC-F4 | INSERT dividend_artifacts | Reconciler 不创建 Artifact |

### bgp_auditor / bgp_readonly

**应该成功（1 项）：**

| # | 操作 | 验证目标 |
|---|---|---|
| AUD-01 | SELECT 批准只读表（不含 admin_sessions, wallet_challenges, wallet_sessions, signer_nonces） | 只读访问 |

**必须失败（1 项）：**

| # | 禁止操作 | 原因 |
|---|---|---|
| AUD-F1 | 任何 INSERT/UPDATE/DELETE 对任何表 | 只读角色禁止写入 |

## 状态保护反例（Section 5）

以下反例必须在 Trigger 级验证（通过状态机 Trigger 执行，而非角色权限）：

| # | 操作 | 预期 |
|---|---|---|
| SP-01 | CANCELLED Epoch -> DRAFT | FAIL |
| SP-02 | CLOSED Epoch -> 非终态 | FAIL |
| SP-03 | CLAIM_OPEN 修改 merkle_root | FAIL |
| SP-04 | FINALIZED Command -> QUEUED | FAIL |
| SP-05 | CANCELLED Command -> SIGNING | FAIL |
| SP-06 | FAILED Command -> APPROVED | FAIL |
| SP-07 | QUEUED + pending cancellation -> SIGNING | FAIL |
| SP-08 | APPROVED + REQUESTED cancellation -> request REJECTED | FAIL |
| SP-09 | REJECTED Command + REQUESTED cancellation -> request REJECTED | SUCCESS |
| SP-10 | CANCELLED Command + REQUESTED cancellation -> request CONSUMED | SUCCESS |
| SP-11 | 历史 FAILED Publish Command 不能让当前 Publish Attempt -> FAILED | FAIL |

## 验证执行方法

每个角色独立连接 PostgreSQL 后：

1. `SELECT current_user;` 记录实际身份
2. 对每个"应该成功"项执行操作并提交
3. 对每个"必须失败"项执行操作，确认返回 `42501` (insufficient_privilege) 或 Trigger 抛出的 `55000` (object_not_in_prerequisite_state)
4. 记录每项 verdict：`PASS / FAIL`
5. 状态保护反例通过直接 SQL UPDATE 触发 Trigger 验证

## 当前结论

所有 Role Runtime 验证依赖 PostgreSQL 实例和 Migration 先通过。当前标记 `BLOCKED_POSTGRESQL_NOT_AVAILABLE`。
