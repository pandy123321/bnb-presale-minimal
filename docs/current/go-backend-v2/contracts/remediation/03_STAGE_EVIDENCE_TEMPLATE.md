# PANGU2 V2 阶段证据模板

复制本模板到 `remediation/evidence/<STAGE_ID>_CLOSEOUT.md`。不得覆盖其他阶段证据。

## 1. Stage Identity

```text
Stage ID:
Stage Title:
Stage Start Base SHA:
Implementation Commit SHA:
Fix Commit SHA(s):
Final Review Commit SHA:
Branch:
Prepared At:
Prepared By:
```

### Chronology

| Event | Agent/Role | Full Commit SHA | Started At | Completed At | Verdict |
|---|---|---|---|---|---|
| Pre-Fix Review | | | | | |
| Pre-Fix Adjudication | | | | | |
| Implementation | | | | | |
| Post-Fix Review | | | | | |
| Post-Fix Adjudication | | | | | |
| Fix | | | | | |
| Re-Review | | | | | |

Implementation、Review、Adjudication 必须记录不同 Agent/session identity；缺少角色隔离时不得关闭阶段。

## 2. Scope

```text
Findings Targeted:
Allowed Paths:
Files Changed:
Forbidden Paths Touched = NO
Economic Baseline Changed = NO
```

## 3. Implementation Evidence

### 3.1 Pre-Fix Review Gate

```text
Pre-Fix Review Agent:
Pre-Fix Commit:
Pre-Fix Review Verdict:
Pre-Fix Report Path/ID:
Pre-Fix Adjudication Agent:
Pre-Fix Adjudication Verdict:
IMPLEMENTATION_ALLOWED:
```

### 3.2 Code Changes

| Finding/Requirement | Before | After | File/Function | Attack Path Closed By |
|---|---|---|---|---|
| | | | | |

## 4. Validation Evidence

| Check | Exact Command | Commit | Exit Code | Result | Evidence File |
|---|---|---|---|---|---|
| Format | | | | PASS/FAIL/NOT_RUN | |
| Build | | | | PASS/FAIL/NOT_RUN | |
| Core Solidity Build | | | | PASS/FAIL | |
| Interface Implementation Match | | | | PASS/FAIL | |
| Unit | | | | PASS/FAIL/NOT_RUN | |
| Regression | | | | PASS/FAIL/NOT_RUN | |
| Fuzz | | | | PASS/FAIL/NOT_RUN | |
| Invariant | | | | PASS/FAIL/NOT_RUN | |

测试源码存在、`out/` 存在或旧报告存在不能填写 PASS。

S1–S8B 的 `Core Solidity Build` 和 `Interface Implementation Match` 不允许填写 `NOT_RUN` 后继续下一阶段。若 Forge 完整编译仅被 approved ABI/constructor 导致的 script 签名不兼容阻止，记录编译错误并启动 `COMPILE_COMPATIBILITY_EXCEPTION`，不得自行扩大范围。

## 5. Independent Review

```text
Review Agent:
Review Commit:
Review Verdict:
Review Report Path/ID:
Findings Raised:
```

## 6. Review Adjudication

| Review Finding | Classification | Evidence | Fix Allowed |
|---|---|---|---|
| | CONFIRMED/REJECTED_WITH_EVIDENCE/DUPLICATE/NEEDS_MORE_EVIDENCE/SCOPE_EXPANSION_REQUIRED | | YES/NO |

```text
REVIEW_VERDICT_CONFIRMED:
FIX_ALLOWED:
```

## 7. Re-Review

```text
Fix Commit:
Re-Review Verdict:
Review Adjudication Verdict:
New Findings:
```

## 8. Stage Exit

```text
Original Findings Closed:
Residual Risks:
CODE_DEPLOYABILITY:
CORE_SOLIDITY_BUILD:
INTERFACE_IMPLEMENTATION_MATCH:
BASELINE_COMPLIANCE:
Stage Verdict:
Next Stage Allowed:
ROLE_SEPARATION_VERIFIED:
Deployment Approval = NOT_GRANTED
BSC Testnet Runtime Fixed = NO
Mainnet = NO-GO
```
