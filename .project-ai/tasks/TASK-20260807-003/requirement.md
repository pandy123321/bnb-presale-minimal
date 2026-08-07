# TASK-20260807-003 — Go V2 Round5 提审包归一

## Source
第五轮独立云端审核报告（`ROUND5_VERDICT = BLOCKED`）  
权威目录：`docs/current/go-backend-v2/`

## Summary
第五轮因机器规范（SQL/OpenAPI/Event/State/规则原文）未随 Markdown 一并上传而 `BLOCKED`。本任务生成单一完整 Round6 提审包，确保 Markdown 与机器规范同 revision；不修改业务逻辑、Solidity 或已部署合约。

## Deliverables
- `16_INDEPENDENT_CLOUD_ROUND5_REMEDIATION.md`
- `17_ROUND6_CLOUD_REVIEW_PROMPT.md`
- `artifacts/BINGGOPLUS_GO_V2_ROUND6_COMPLETE_PACKAGE_20260807_V1/`
- `SUBMISSION_MANIFEST`（path / size / sha256）

## Constraints
- 不得自行将 Finding 标为 CLOSED
- 状态仅可写 `FIX_READY / INDEPENDENT_RETEST_PENDING`
- 禁止用历史 ZIP 替代当前 SQL/YAML
- Mainnet NO-GO；Testnet redeploy FORBIDDEN

## Status: FIX_READY / INDEPENDENT_RETEST_PENDING
