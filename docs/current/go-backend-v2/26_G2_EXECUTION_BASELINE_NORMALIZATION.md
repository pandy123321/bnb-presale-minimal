# G2 执行基线归一与恢复条件

状态：`HISTORICAL / SUPERSEDED_FOR_CURRENT_EXECUTION_BY_FLAP_F0`

> 本文件保留旧 PANGU2 G2 执行冲突和恢复条件。它不再是当前阶段入口；当前阶段为 `FLAP-F0`，见 [27_FLAP_PRODUCT_PIVOT_DECISION.md](./27_FLAP_PRODUCT_PIVOT_DECISION.md) 与 [30_FLAP_F0_F11_EXECUTION_PLAN.md](./30_FLAP_F0_F11_EXECUTION_PLAN.md)。旧依赖、RPC、范围漂移 Finding 仍作为历史风险和复用代码审查输入，不得伪造为已关闭。

```text
CURRENT_STAGE = G2
G2_ENTRY_AUTHORIZATION = DISPUTED_PENDING_DEPENDENCY_GATE_RECONCILIATION
G2_IMPLEMENTATION_COMPLETE = NO
G2_DEPENDENCY_CONSUMING_WORK = PAUSED
CURRENT_WORKTREE_STAGE_ISOLATION = REQUIRED
AUTO_ADVANCE_TO_G3 = PAUSED
FLAP_D0_DRAFT = NOT_ALLOWED_UNTIL_STEP_00_COMPLETE
FLAP_IMPLEMENTATION = FORBIDDEN
BSC_MAINNET = NO-GO
```

本文件不改写 G0/G1、RT-GATE-01/02/03 的历史原始记录；最终状态以 Legacy Runtime Gate 状态文件为准，其中 RT02 仍为 `BLOCKED_EVIDENCE`、RT03 仍待独立复验。它记录 G2 开始后发现的执行冲突，不授权恢复旧 G2。

## 1. 当前 Finding 裁决

| Finding | 裁决 | 当前处置 |
|---|---|---|
| `P1-G2-DEPENDENCY-01` | `CONFIRMED` | go-ethereum 条件许可证 Gate 没有正式关闭，依赖型 G2 实现暂停 |
| `P1-G2-RPC-01` | `CONFIRMED_ON_LOCAL_EVIDENCE` | G2 必须形成链采集能力；具体库/API 方法不由审核 Agent冻结 |
| `P1-G2-SCOPE-02` | `CONFIRMED_ON_LOCAL_EVIDENCE` | 本地存在跨阶段 Public/Quote/Admin 候选代码；不得进入 G2 Commit |
| `P1-STATE-AUTHORITY-03` | `CONFIRMED / FIX_READY` | 当前权威关系已开始归一，仍需独立复验 |
| `P2-AUTO-GATE-DOC-04` | `LOCAL_CONFLICT_WAS_PRESENT / FIX_READY` | 本地旧规则曾写“不得自动进入”；现已改为审核后满足条件才自动推进 |
| `P1-FLAP-CONTEXT-05` | `LOCAL_OCCURRENCE_CONFIRMED / FIX_READY` | 本地错误 Factory/自动部署十合约假设已删除 |
| `P2-FLAP-DATA-MODEL-06` | `BLOCKING_DESIGN` | 当前 Schema 不是多 Launch 平台；仅允许候选模型设计 |
| `P2-LEGACY-STATE-07` | `FIX_READY` | Laravel 统一为代码冻结，运行时下线到 G9 独立跟踪 |
| `P2-CONTEXT-FRESHNESS-08` | `FIX_READY` | 动态文件数量不再作为手工权威事实 |
| `P1-BGPLUS-LAUNCH-TOKEN-09` | `CONFIRMED / BLOCKS_FULL_SUITE_ONLY` | Full Suite 通用发币 Token Template 未定义，不阻断当前 PANGU2 G2，但阻断 H0-H5 |

## 2. STEP-00：执行基线归一

### 2.1 唯一 Current Authority

当前阶段状态由以下文件共同约束：

1. `runtime-gate/00_RUNTIME_GATE_STATUS.md`：Runtime Gate 历史与当前执行 Hold；
2. 本文件：G2 开始后发现的执行冲突与恢复条件；
3. `25_FLAP_INTEGRATION_EXECUTION_PLAN.md`：Flap 仅设计支线边界；
4. `RULES_MASTER.md` 与 `24_AI_CODE_REVIEW_AUTOMATION_PROTOCOL.md`：审核和自动推进规则。

旧 Round、自审、计划和证据文件保留当时结论；若状态已被后续 Gate 替代，必须标注 `HISTORICAL / SUPERSEDED`，不得改写历史正文冒充当时已经通过。

### 2.2 依赖 Decision

必须新增由有权责任人签署的 Dependency Decision，至少包含：

```text
DEPENDENCY_ID
EXACT_VERSION
PACKAGES_ACTUALLY_IMPORTED
LINKAGE_AND_DISTRIBUTION_MODEL
LICENSE_ANALYSIS
NOTICE_OBLIGATION
SOURCE_DISTRIBUTION_OBLIGATION
GENERATED_CODE_LICENSE
APPROVED_USE_BOUNDARY
DECISION = APPROVED / REJECTED
DECISION_OWNER
DECISION_TIMESTAMP
EVIDENCE_REFERENCE
```

若批准 go-ethereum，必须明确精确包和使用边界；若拒绝，必须为替代 RPC/ABI 方案完成相同准入。执行 Agent不得自行签署法律或开源许可证结论。

### 2.3 自动推进语义

统一为：

```text
Implementation Complete
-> Stop Next-Stage Coding
-> Ai-Code-Review
-> Executor Adjudication
-> Finding Closure / Counter-Evidence
-> Stage Gate Registration
-> Auto Advance Only If Next Stage Is Frozen And All Gates Pass
```

“一次一个阶段”不代表审核通过后永久禁止自动推进；它禁止在审核和裁决完成前跨阶段编码。

### 2.4 当前上下文同步

必须同步 `.project-ai/context.md`、`architecture.md`、`glossary.md` 和当前 Task：

- G2 当前为执行 Hold，而非完成；
- G1 外部审核基线与本地未提交候选文件分开；
- Flap Factory/自动部署十合约错误假设删除；
- 动态文件数量来自 Commit Manifest，不再手工固定；
- Laravel 为代码冻结，不等于 G9 已完成运行时下线。

## 3. STEP-01：工作区按阶段隔离

执行 Agent 必须基于实际 Diff 生成机器可读分类清单：

```text
PATH | OWNER_STAGE | INCLUDE_IN_G2 | REASON
```

G2 Commit 只允许：

- 配置中与 Indexer/只读链连接直接相关的内容；
- deployment baseline import；
- chain identity/head/block/log acquisition；
- raw event、cursor、lease、confirmation、reorg、single-writer；
- 上述能力直接需要的 repository/query/domain 类型。

Public API、Quote、Wallet/Admin Auth、Projector 领域逻辑、治理签名广播和 Flap 实现必须隔离到其他 Stage。可以使用独立 branch/worktree/commit，但不得删除用户未提交工作，也不得把它们放入 G2 提审包。

本地 Quote 候选代码在没有真实 Router preview 时不得注册；若因开发需要暂时注册，只能 fail closed 返回 `UNAVAILABLE`，绝不能返回自行计算的 `LIVE/READY` 成功结果。

## 4. STEP-02：G2 能力验收

G2 必须交付以下能力，不冻结底层 JSON-RPC 方法或库实现细节：

- chain identity verification；
- head discovery；
- block retrieval；
- log retrieval；
- 当前 Stage 需要的 deployment/runtime evidence retrieval；
- confirmation/finality tracking；
- reorg detection and canonical correction；
- cursor/lease/single-writer；
- raw event append and immutable source fields。

硬门禁：

```text
OBSERVED_CHAIN_ID = 97
```

若不成立：

```text
INDEXER_CHAIN_WRITE = FORBIDDEN
READY = FALSE
```

## 5. STEP-03：G2 独立审核

```text
G2 Commit
-> Complete Diff
-> Manifest + SHA-256
-> Secret Scan Evidence
-> Ai-Code-Review
-> Executor Adjudication
-> Correct Findings Fix / Incorrect Findings Counter-Evidence
-> Independent Retest
```

在 `REVIEW_VERDICT = APPROVED`、二次裁决接受、依赖 Decision 闭合、工作区范围正确之前：

```text
AUTO_ADVANCE_TO_G3 = NO
```

## 6. FLAP-D0 草案的启动条件

只有 STEP-00 完成后，才允许独立任务启动：

```text
FLAP-D0_DRAFT_ONLY = ALLOWED
```

它可以与 STEP-01～03 并行，但必须使用独立 Agent/session、Commit 和提审包，且不得修改当前 Freeze、Go 业务代码、SQL Migration、OpenAPI 机器规范、Admin、Signer、Solidity 或链上状态。

G2 审核关闭、准备进入 G3 前，`FLAP-D0` 必须转入正式 Change Gate：独立审核、Owner Change Approval、新 Freeze Version。未通过时，G3-G7 只执行原 BingGoPlus 主线。

## 7. STEP-00 完成标准

```text
DEPENDENCY_GATE_DECISION = APPROVED_OR_APPROVED_ALTERNATIVE
CURRENT_STAGE_AUTHORITY = CONSISTENT
AUTO_ADVANCE_RULE = CONSISTENT
CURRENT_CONTEXT = SYNCHRONIZED
WORKTREE_CLASSIFICATION_PLAN = READY
FLAP_FACTORY_FALSE_ASSUMPTION = REMOVED
HISTORICAL_DOCUMENTS = MARKED_NOT_CURRENT
```

STEP-00 完成后只能标记：

```text
FIX_READY / INDEPENDENT_RETEST_PENDING
```

不得由执行 Agent自行将 P1 标记为 `CLOSED`。
