# PANGU2 V2 云端方案复审提交清单

```text
Purpose: prevent incomplete review packages
Review Type: remediation plan re-review
Solidity Implementation: FORBIDDEN UNTIL S0 APPROVAL
Deployment Approval: NOT_GRANTED
Mainnet: NO-GO
```

## 1. 必传修复方案文档

提交前逐项确认，不能只上传 `stages/`：

```text
remediation/README.md
remediation/00_AUDIT_FINDINGS_BASELINE.md
remediation/01_MASTER_EXECUTION_PROMPT.md
remediation/02_REVIEW_WORKFLOW_AND_PROMPTS.md
remediation/03_STAGE_EVIDENCE_TEMPLATE.md
remediation/04_CLOUD_REVIEW_SUBMISSION_CHECKLIST.md
remediation/05_EXTERNAL_PLAN_REVIEW_ADJUDICATION.md

remediation/stages/S0_DESIGN_AND_INVARIANT_FREEZE.md
remediation/stages/S1_COST_BASIS_DUAL_LEDGER.md
remediation/stages/S2_TOKEN_ROUTER_MIXED_SETTLEMENT_AND_WHITELIST.md
remediation/stages/S3_STAKING_COST_BASIS_BRIDGE.md
remediation/stages/S4A_STAKING_REWARD_EXIT.md
remediation/stages/S4B_STAKING_PAUSE_AND_EMERGENCY_CONTROL.md
remediation/stages/S5_SUPPORT_BUYBACK_PRICE_IMPACT.md
remediation/stages/S6_DIVIDEND_EPOCH_FINALITY.md
remediation/stages/S7_ORACLE_UINT32_ROLLOVER.md
remediation/stages/S8A_CONTRACT_ACCOUNT_LIFECYCLE.md
remediation/stages/S8B_CONTRACT_ACCOUNT_BYPASS_REGRESSION.md
remediation/stages/S9_FINAL_CODE_EXIT_GATE.md
```

旧文件 `S4_STAKING_REWARD_EXIT_AND_PAUSE.md` 和 `S8_CONTRACT_ACCOUNT_BOUNDARY.md` 已被拆分，不能与新文件同时提交，避免审核方使用过期阶段。

## 2. 必传权威基线

```text
contracts/BSC_TESTNET_DEPLOYMENT_BASELINE.md
go-backend-v2/05_BUSINESS_AND_CONTRACT_INHERITANCE.md
go-backend-v2/08_RULES_COMPLIANCE_AND_DECISIONS.md
go-backend-v2/09_SELF_REVIEW.md
docs/current/CONTRACT_SECURITY_AUDIT.md
通用智能合约安全开发风险控制与漏洞治理规范 V1.0.md
```

如果云端无法访问 Git commit，至少同时上传目标 Solidity 源码快照或归档，并在 manifest 中记录：

```text
Deployed Source Commit = 3ef50b6d77a31c092e9353e255e672836f36ece8
Planning/Review Head = <full 40-char SHA>
Source Archive SHA-256 = <hash>
```

## 3. 提交 Manifest

上传前为每个文件计算 SHA-256，随审核请求附上：

| Relative Path | SHA-256 | Git Blob/Commit（如有） | Required |
|---|---|---|---|
| | | | YES |

不得只用附件文件名证明版本；相同名称的修订文件必须用 hash 区分。

## 4. 云端审核边界

要求云端审核者明确：

- 本轮只审核修复方案和 S0 Gate；
- 未收到的源码不得猜测；
- GitHub public main 不得自动替代本地 `3ef50b6/Review HEAD`；
- `SOURCE_CODE_VERIFICATION_REQUIRED` 与 `PLAN_DEFECT` 必须分开；
- 不运行 RPC、Fork、部署或链上写入；
- 不授予 Solidity implementation、部署或 Mainnet 批准。

## 5. 复审期望输出

```text
Plan Review Verdict = APPROVED_FOR_S0_DESIGN_GATE / CHANGES_REQUIRED / BLOCKED
S0_GATE_APPROVAL = GRANTED / NOT_GRANTED
SOLIDITY_IMPLEMENTATION_ALLOWED = NO
MISSING_REQUIRED_DOCUMENTS = []
DOCUMENT_HASHES_VERIFIED = YES / NO
PLAN_P0/P1/P2/P3
BASELINE_COMPLIANCE
ROLE_SEPARATION_WORKFLOW
MANDATORY_BUILD_GATE
STAGE_SPLIT_VERDICT
DEPLOYMENT_APPROVAL = NOT_GRANTED
MAINNET = NO-GO
```

只有云端方案复审通过、且其结论再次由本地校对确认后，才能开始执行 S0。S0 本身批准前仍不得修改 Solidity。

