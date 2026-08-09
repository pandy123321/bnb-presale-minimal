# BingGoPlus Flap F0 V3 外部审核二次裁决

状态：`V3_REVIEW_BLOCKED / CONTENT_CHANGES_REQUIRED / V4_FIX_READY / INDEPENDENT_RETEST_PENDING`

外部报告来源：用户在当前任务中粘贴的完整 V3 审核报告。原报告机器结论：

```text
F0_V3_REVIEW_VERDICT = BLOCKED
CONTENT_REVIEW_RESULT = CHANGES_REQUIRED
P0 = 0
P1 = 4
P2 = 2
F0_OWNER_FREEZE_ALLOWED = NO
F1_ENTRY_AUTHORIZED = NO
BSC_MAINNET = NO-GO
```

本文件只记录执行方逐项裁决。不能以作者裁决自行关闭 Finding，所有修订均为 `FIX_READY / INDEPENDENT_RETEST_PENDING`。

## 1. 证据层裁决

| Finding | 裁决 | 证据与处置 |
|---|---|---|
| 外层 `.zip.sha256` 未随附件上传 | `CONFIRMED_SUBMISSION_GAP` | V3 sidecar 已在本地生成且 Hash 与审核方实算一致，但用户当次只上传 ZIP。V4 必须同时交付 ZIP 和 sidecar；该动作由用户手动完成 |
| V3 Commit 远程不可解析 | `CONFIRMED_MANUAL_ACTION_PENDING` | 本地 Commit/完整 Diff 可核验，但规则要求远程可解析。执行 Agent 不得自动 Push；V4 Push 仍由用户完成 |

上述两项不是文档内容修复，不能通过改写状态伪装关闭。

## 2. 内容 Finding 裁决

| Finding | 裁决 | 根因 | V4 修订 |
|---|---|---|---|
| `P1-F0V3-STAGE-01` F3～F6 职责不一致 | `CONFIRMED` | V3 执行计划与提审契约使用了两套 Stage Owner | 统一为 F3 Chain/Indexer/Read Model、F4 Workflow/API、F5 Signer/Execution、F6 Admin Console/Native MVP |
| `P1-F0V3-AUTO-02` F6 可能自动进入 F7 | `CONFIRMED` | 全局默认自动推进没有新 Solidity 域例外 | 冻结 `F6_TO_F7_AUTO_ADVANCE=FORBIDDEN` 与显式 Extension Entry/Owner/Security Gate |
| `P1-F0V3-ECON-03` Staking Reward 资金源缺失 | `CONFIRMED` | 只写“预充值”，未冻结资产、Actor、RevenueVault 关系 | 冻结 `EXTERNAL_PREFUND_ONLY`、绑定 Flap Token、不得使用 RevenueVault BNB 或本金 |
| `P1-F0V3-AUTHORITY-04` Current Authority 残留旧 G5/G6 与 v2 新基线 | `CONFIRMED` | Context/README 未完成 Legacy 标注 | 删除现行 G5/G6 语义；将 `/api/v2`、`binggoplus_v2` 明确标为 Legacy，将 v3/Flap Schema 标为 F2 Candidate |
| `P2-F0V3-FLAP-05` Flap 能力表述 Fail Open | `CONFIRMED` | Context 使用“支持”而 F1 尚未授权 | 统一为 `CANDIDATE_PENDING_F1_BASELINE` 等 Evidence 状态 |
| `P2-F0V3-ACCOUNTING-06` 内部账本事实源与幂等缺失 | `CONFIRMED` | 只定义偿付不等式，没有定义未登记 surplus 和 outflow identity | 冻结 Internal Ledger、Balance 仅作 Solvency、Surplus 对账前不可分配、流出 identity 一次性规则 |

## 3. 保持关闭/不重开的结论

V3 审核支持执行方对 V2 两项错误建议的拒绝，继续保持：

```text
IN_PLACE_FLAP_PIVOT = OWNER_DECISION / PASS
ADMIN_WALLET = OWNER_DECISION / PASS
NEW_SEPARATE_PROJECT_REQUIRED = REJECTED_WITH_EVIDENCE
USER_SELF_SERVICE_WALLET_REQUIRED = REJECTED_WITH_EVIDENCE
```

F1 仍必须核对 Admin Wallet 的 `creator/payer/msg.sender/initial buyer` 真实语义。拒绝改成 User Wallet 不等于放宽身份核验。

## 4. 修订边界

本轮只允许修改文档、规则和 Current Context；不得修改 Go、SQL、OpenAPI、Event/State、前端业务代码、Solidity、部署地址或链上状态。未执行测试、构建、Migration、RPC、签名、广播或部署。

## 5. 当前状态

```text
V3_EXTERNAL_FINDINGS_ADJUDICATED = YES
V4_CONTENT_FIX = FIX_READY
INDEPENDENT_RETEST = PENDING
F0_OWNER_FREEZE_ALLOWED = NO
F1_ENTRY_AUTHORIZED = NO
FLAP_IMPLEMENTATION_ALLOWED = NO
BSC_MAINNET = NO-GO
```
