# BingGoPlus Flap F0 V4 修订作者侧自审

状态：`HISTORICAL_V4_AUTHOR_SELF_REVIEW / SUPERSEDED_BY_V4_EXTERNAL_REVIEW_AND_V5_REMEDIATION`

> 本文件保存 V4 提审前作者侧自审。V4 独立复审已返回 `BLOCKED / CONTENT_CHANGES_REQUIRED`；当前裁决见文档 41，当前修订自审见文档 42。

## 1. 修订范围

本轮仅修复 V3 外审确认的 4 个 P1 和 2 个 P2，并同步 Current Authority。没有修改 Go、SQL、OpenAPI、Event/State、前端业务代码、Solidity、部署地址、已部署 PANGU2 或链上状态。

## 2. Finding 修订矩阵

| Finding | 作者侧结果 | 关键证据 |
|---|---|---|
| `P1-F0V3-STAGE-01` | `FIX_READY` | 文档 30、29、Context、Architecture、Glossary 对 F3～F6 使用同一映射 |
| `P1-F0V3-AUTO-02` | `FIX_READY` | 文档 24、30 和 Rules 冻结 F6→F7 强制暂停 |
| `P1-F0V3-ECON-03` | `FIX_READY` | 文档 28 冻结 `EXTERNAL_PREFUND_ONLY` 与绑定 Flap Token 奖励储备 |
| `P1-F0V3-AUTHORITY-04` | `FIX_READY` | Current Context 删除旧 G5/G6；README 把 v2 API/Schema 标为 Legacy |
| `P2-F0V3-FLAP-05` | `FIX_READY` | Flap 三模式统一标记 Candidate/Pending F1 |
| `P2-F0V3-ACCOUNTING-06` | `FIX_READY` | Internal Revenue Ledger、Surplus 对账、Outflow Identity 和 Retry 规则已冻结 |

## 3. 阶段不变量

```text
F3 = CHAIN_ACQUISITION_INDEXER_READ_MODEL
F4 = LAUNCH_WORKFLOW_AND_API_NO_SIGNING
F5 = SIGNER_AND_TRANSACTION_EXECUTION
F6 = ADMIN_LAUNCH_CONSOLE_AND_NATIVE_MVP

F6_TO_F7_AUTO_ADVANCE = FORBIDDEN
F7_ENTRY_AUTHORIZED = NO_BY_DEFAULT
```

F7～F10 仍是必做路线；暂停只表示首次进入新金融 Solidity 前需要 Extension Entry Review 和 Responsible Owner/Security Scope Authorization。

## 4. 会计和 Staking 不变量

```text
ACCOUNTING_SOURCE_OF_TRUTH = INTERNAL_REVENUE_LEDGER
ACTUAL_CHAIN_BALANCE = SOLVENCY_CHECK_ONLY
UNACCOUNTED_SURPLUS_BNB = NON_DISTRIBUTABLE_UNTIL_RECONCILED

STAKING_REWARD_FUNDING_MODEL = EXTERNAL_PREFUND_ONLY
REWARD_ASSET = BOUND_FLAP_TOKEN
REVENUE_VAULT_LIABILITY_USED_FOR_STAKING = NO
STAKING_PRINCIPAL_USED_FOR_REWARD = NEVER
```

每笔 Outflow 使用唯一 execution identity；成功后不得重复，失败重试复用原 identity。Tax Revenue 若未来需要进入 Staking，属于新的经济变更和 Owner Freeze，不是参数调整。

## 5. 证据限制

以下不能由作者自审关闭：

```text
V4_REMOTE_PUSH = USER_MANUAL_PENDING
V4_OUTER_ZIP_SHA256_UPLOAD = USER_MANUAL_PENDING
V4_INDEPENDENT_REVIEW = PENDING
F0_OWNER_FREEZE = PENDING_AFTER_APPROVED_REVIEW
```

## 6. 未执行

```text
Go build/test
Frontend build/test
Solidity build/test
Migration/PostgreSQL
Docker/RPC/Fork
Flap Portal call
Signature/Broadcast/Deployment
Dependency download
```

本轮只允许静态文档、链接、Diff、Manifest、Hash、敏感信息与跨文件一致性检查。作者不得自行输出 `APPROVED` 或授权 F1。

提交前静态检查：

```text
AUTHORITATIVE_FILES = 47
MISSING_FILES = 0
MARKDOWN_FILES = 41
RELATIVE_LINKS = 94
MISSING_LINKS = 0
UNBALANCED_FENCES = 0
RULE_ROWS = 61
OLD_CURRENT_G5_G6_HITS = 0
ACCIDENTAL_CHAT_REQUIREMENT_HITS = 0
CONTEXT_VERSION = 20
OUT_OF_SCOPE_CODE_FILES = 0
```

## 7. 作者侧结论

```text
V4_CONTENT_REMEDIATION = FIX_READY
INDEPENDENT_RETEST = PENDING
F0_OWNER_FREEZE_ALLOWED = NO
F1_ENTRY_AUTHORIZED = NO
FLAP_IMPLEMENTATION_ALLOWED = NO
BSC_MAINNET = NO-GO
```
