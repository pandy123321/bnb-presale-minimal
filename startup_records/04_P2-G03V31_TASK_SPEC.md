# P2-G03V31 Task Spec

```text
Project ID: PANGU2
Stage ID: PB-S0
Task ID: P2-G03V31
Task Title: 采用V3.1治理与V1.1拆分开发基线
Prompt Version: P2-G03V31-V1.0
Task Status: READY
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Task Start Base SHA: c8eaedbc47205194c518f2ff6a1415e3ff5abe16
Current Base Branch Tip SHA: c8eaedbc47205194c518f2ff6a1415e3ff5abe16
Spec SHA: f6536f2ab38052a63090edff7e234f11c97d0d69689692de288829aa2d9e4d4e
Ruleset SHA: 91f2e06e36f122869a6720aab655bad1e1bcbda6cc8d64b8104036b1746d758e
Previous Reviewed Head SHA: NONE
Automatic Merge: FORBIDDEN
Automatic Deployment: FORBIDDEN
```

## Goal

将 `repository_payload/` 的治理、基线和Cursor规则作为一个纯文档Draft PR提交，使仓库从V3.0/单体RC口径迁移到V3.1/V1.1，并为P2-G04及后续Task提供统一规范。

## Allowed Paths

```text
AGENTS.md
docs/governance/**
.agent-rules/project-coordinator.md
.agent-rules/execution-agent.md
.agent-rules/review-agent.md
.agent-rules/human-project-owner.md
.cursor/rules/github-review-only-governance.mdc
.cursor/rules/project-coordinator.mdc
.cursor/rules/execution-agent.mdc
.cursor/rules/review-agent.mdc
.cursor/rules/human-project-owner.mdc
.cursor/rules/pangu2-baseline-core.mdc
.cursor/rules/pangu2-baseline-protocol.mdc
.cursor/rules/pangu2-baseline-architecture.mdc
hub/pangu2/docs/baseline/**
hub/pangu2/docs/specs/PB-S0/P2-G03V31.md
hub/pangu2/docs/evidence/PB-S0/P2-G03V31/**
```

## Forbidden Paths

```text
hub/pixiu1/**
hub/pangu2/contracts/**
hub/pangu2/apps/**
hub/pangu2/services/**
hub/pangu2/packages/**
hub/pangu2/database/**
hub/pangu2/infra/**
hub/pangu2/config/**
.github/workflows/**
dependency lockfiles
Secret or environment credentials
```

## Requirements

1. 使用 `repository_payload/` 作为候选正文，不自行重写业务参数。
2. 根 `docs/governance/**` 仅保存Hub共享治理。
3. Pangu2基线只能在 `hub/pangu2/docs/baseline/**`。
4. 当前单体 `PANGU2_DEVELOPMENT_BASELINE_V1.1_RC.md`替换为SUPERSEDED NOTICE。
5. V3.1规则必须明确六层Gate、独立生命周期、完整SHA模型、Required Check Manifest和Finding状态。
6. 不得将PENDING_SIGNATURE/TBC改为ACTIVE或FROZEN。
7. 不得输出PB-S1 GO。
8. 创建或更新Draft PR；不得合并。
9. 输出Current Head、Merge Base、Spec/Ruleset候选哈希和检查证据。

## Required Tests

```text
UTF-8 read check
single-H1 check for each Markdown file
required-file manifest check
internal-link check
duplicate normative source check
parameter-source uniqueness check
decision-reference check
forbidden-path diff check
secret scan
old 35/25/25/15 active-use check
Project/Stage/Task Gate enum check
SHA field presence check
```

## Required Checks

使用 `05_REQUIRED_CHECK_MANIFEST_P2-G03V31.md`。不存在的CI Job必须记录 `NOT_IMPLEMENTED`，不得伪报PASS。

## Outputs

- Draft PR；
- Merge Base SHA；
- Current Head SHA；
- 文件Diff清单；
- Candidate/Committed Spec和Ruleset SHA；
- Evidence Manifest；
- 审核Agent可复制提示词。

## Closure Conditions

- 仅Allowed Paths变化；
- V3.1/V1.1文件全部存在；
- Pangu2物理路径符合DR-P2-0001；
- 参数唯一来源无重复；
- 所有Blocking Finding VERIFIED_CLOSED或WONT_FIX_APPROVED；
- Closeout Review绑定Final Head；
- Task进入MERGE_READY，而不是MERGED；
- 下一角色唯一为Human Project Owner。

## Rollback Boundary

只回滚本Task文档和规则文件。禁止触碰 `hub/pixiu1/**` 或产品代码。
