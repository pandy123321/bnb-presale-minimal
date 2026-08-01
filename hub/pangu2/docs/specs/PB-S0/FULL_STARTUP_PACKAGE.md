# PANGU2最终开发启动文件全集

===== BEGIN FILE: README_START_HERE.md =====
# PANGU2最终开发启动执行包 V1.0

## 当前固定仓库

```text
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Current Base Branch Tip SHA: c8eaedbc47205194c518f2ff6a1415e3ff5abe16
Project Root: hub/pangu2/
Archived Project: hub/pixiu1/ (READ_ONLY / FORBIDDEN)
Observed Workflow Runs At Base SHA: NONE
```

## 正确启动顺序

```text
P2-G03V31 提交V3.1治理与V1.1拆分基线
→ GitHub固定SHA审核
→ Closeout
→ 人工决定合并
→ 合并后PB-S0继续
→ P2-G04精确工具链和锁文件
→ LOCAL/CI/Required Checks
→ Parameter Freeze与Schema
→ PB-S0 Closeout
→ PB-S1合约
```

## 当前Gate

```text
Document Readiness: READY
Project Start Gate: GO
PB-S0 Stage Start Gate: GO
P2-G03V31 Task Start Gate: GO
P2-G04 Task Start Gate: BLOCKED
PB-S1 Stage Start Gate: BLOCKED
PB-S2 Stage Start Gate: BLOCKED
BSC Testnet Integration Gate: BLOCKED
BSC Mainnet Release Gate: NO-GO
```

`Project Start Gate: GO`仅授权PB-S0治理基线落库任务，不授权产品代码、测试网写链或主网操作。

## 使用方法

1. 将本包 `repository_payload/` 作为P2-G03V31候选Diff。
2. 在Cursor粘贴 `startup_records/07_CURSOR_EXECUTION_PROMPT_P2-G03V31.md`。
3. Cursor必须先核对Base SHA，创建独立任务分支和Draft PR。
4. 执行本地Markdown/结构/链接/Secret/Forbidden Path检查。
5. 使用 `08_REVIEW_AGENT_PROMPT_P2-G03V31.md` 审核固定Head SHA。
6. 审核APPROVED后执行Closeout，交人工项目负责人决定合并。
7. 合并后再启动P2-G04。

## 候选哈希

```text
Candidate Ruleset Manifest SHA-256: 91f2e06e36f122869a6720aab655bad1e1bcbda6cc8d64b8104036b1746d758e
Candidate Baseline Manifest SHA-256: f6536f2ab38052a63090edff7e234f11c97d0d69689692de288829aa2d9e4d4e
```
===== END FILE: README_START_HERE.md =====

===== BEGIN FILE: CURRENT_REPOSITORY_SHA_MANIFEST.md =====
# 当前仓库SHA证据

```text
Repository: pandy123321/bnb-presale-minimal
Branch: pgbnb
Current Head SHA: c8eaedbc47205194c518f2ff6a1415e3ff5abe16
Observed At: 2026-08-01
```

| Path | Git Blob SHA |
|---|---|
| `AGENTS.md` | `54fe0102e492dc364243b10de90debfb657d59da` |
| `hub/pangu2/docs/baseline/PANGU2_DEVELOPMENT_BASELINE_V1.1_RC.md` | `9a7cc459aa75db4c0bda93c8dc127ddc0e514e3f` |
| `hub/pangu2/docs/current/盘古2项目详细开发文档_V2.1_PGBNB.md` | `5ae6e838b14cb51836bd9fb9c6e539687b4706ec` |
| `.cursor/rules/github-review-only-governance.mdc` | `897d06fc7a3907dc1ff142d43fb79a36e23a7ea7` |
| `.cursor/rules/project-coordinator.mdc` | `0feea093b9d03445361a5ab945927c04ba033571` |
| `.cursor/rules/execution-agent.mdc` | `b0d8f81675279e0f46cf06ad5fa8daa03506221a` |
| `.cursor/rules/review-agent.mdc` | `e16e6a054d24dfdf153d40e9e210a42d37b9db55` |
| `.cursor/rules/human-project-owner.mdc` | `9770f38b11027a3e45048ad5fe8c2729ee436f3a` |
| `.cursor/rules/pangu2-baseline-core.mdc` | `bb4e6c013cf4376abb0aacd398990ee6a3dd311d` |
| `.cursor/rules/pangu2-baseline-protocol.mdc` | `5d3f1de5d55be2974fb397f7339cc5ec89476841` |
| `.cursor/rules/pangu2-baseline-architecture.mdc` | `6e0708aadc9f2a4dffde9282e0d7a9f6d1f8f214` |

Candidate Ruleset Manifest SHA-256: `91f2e06e36f122869a6720aab655bad1e1bcbda6cc8d64b8104036b1746d758e`
Candidate Baseline Manifest SHA-256: `f6536f2ab38052a63090edff7e234f11c97d0d69689692de288829aa2d9e4d4e`

候选SHA是本执行包本地内容哈希；提交后必须记录新的Git Blob SHA和Current Head SHA。
===== END FILE: CURRENT_REPOSITORY_SHA_MANIFEST.md =====

===== BEGIN FILE: startup_records/00_PROJECT_EXECUTION_PROFILE_ACTIVE.md =====
# PANGU2 Project Execution Profile — ACTIVE INPUT

```text
Profile ID: PANGU2-PEP-1.1-START
Version: V1.1
Status: ACTIVE_FOR_PB-S0_GOVERNANCE_ONLY
Owner: Human Project Owner
Effective From: 2026-08-01
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Project Root: hub/pangu2/
Archived Project: hub/pixiu1/
Governance Architecture: GITHUB_REVIEW_ONLY
Project Strategy: PANGU2_FIRST_PLATFORM_READY
Target Environment: BSC_TESTNET
BSC_MAINNET: NO-GO
Automatic Merge: FORBIDDEN
Automatic Deployment: FORBIDDEN
Task Start Base SHA: c8eaedbc47205194c518f2ff6a1415e3ff5abe16
Current Base Branch Tip SHA: c8eaedbc47205194c518f2ff6a1415e3ff5abe16
```

## Effective Scope

只允许V3.1治理、V1.1拆分基线、Cursor规则和对应文档记录落库。产品代码不在本Profile当前授权范围内。

## Normative Paths

```text
AGENTS.md
docs/governance/**
hub/pangu2/docs/baseline/**
hub/pangu2/docs/specs/**
hub/pangu2/docs/decisions/**
hub/pangu2/docs/evidence/**
.cursor/rules/**
.agent-rules/**
```

## Hard Boundaries

- `hub/pixiu1/**`禁止修改；
- 禁止合约、DApp、API、Worker、Admin、数据库、Infra和Workflow改动；
- 禁止Secret、资金、签名和写链；
- 用户资产必须由用户钱包签名；
- PB-S1业务参数必须来自已签Parameter Freeze Record。
===== END FILE: startup_records/00_PROJECT_EXECUTION_PROFILE_ACTIVE.md =====

===== BEGIN FILE: startup_records/01_PROJECT_START_GATE_RECORD.md =====
# Project Start Gate Record

```text
Gate Record ID: PANGU2-PSG-20260801-01
Project ID: PANGU2
Gate Type: Project Start Gate
Gate Result: GO
Decision Owner: Project Coordinator Agent
Effective Scope: PB-S0 governance and baseline adoption only
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Current Base Branch Tip SHA: c8eaedbc47205194c518f2ff6a1415e3ff5abe16
Candidate Ruleset Manifest SHA-256: 91f2e06e36f122869a6720aab655bad1e1bcbda6cc8d64b8104036b1746d758e
Candidate Baseline Manifest SHA-256: f6536f2ab38052a63090edff7e234f11c97d0d69689692de288829aa2d9e4d4e
```

## Inputs

- DR-P2-0001 ACTIVE：`pgbnb + hub/pangu2/`；
- 当前仓库已存在Pangu2 RC基线和Cursor规则；
- 本包提供V3.1/V1.1替代候选；
- BSC_MAINNET保持NO-GO。

## GO Conditions Met

- 项目身份、仓库、分支和项目根明确；
- 只读归档边界明确；
- 本次任务无产品代码、Secret、资金或写链；
- Allowed/Forbidden Paths完整；
- Candidate SHA Manifest已生成。

## Restrictions

该GO不传递给PB-S1/PB-S2，也不构成Baseline已人工批准、PR可自动合并或环境可部署。
===== END FILE: startup_records/01_PROJECT_START_GATE_RECORD.md =====

===== BEGIN FILE: startup_records/02_PB-S0_STAGE_START_RECORD.md =====
# PB-S0 Stage Start Gate Record

```text
Stage ID: PB-S0
Stage Status: READY
Stage Start Gate: GO
Task Authorized: P2-G03V31
Task Start Base SHA: c8eaedbc47205194c518f2ff6a1415e3ff5abe16
Required Next Stage: PB-S0 governance adoption
```

## Stage Goal

将V3.1治理、V1.1拆分基线和配套Cursor规则提交到仓库，清除现有V3.0与单体RC基线冲突，形成后续Task Spec的正式输入。

## Entry Conditions

- Repository/branch/project root已固定；
- Current Head可读取；
- Candidate payload只含治理和文档；
- No active CI workflow run at current Head；
- PB-S1开放Decision不影响文档迁移任务。

## Exit Conditions

- P2-G03V31 PR完成Delta与Closeout Review；
- 必需检查绑定Final Reviewed Head；
- 人工项目负责人决定合并；
- Merged Commit SHA记录；
- 协调Agent执行PB-S0阶段进度更新；
- P2-G04重新执行Task Start Gate。
===== END FILE: startup_records/02_PB-S0_STAGE_START_RECORD.md =====

===== BEGIN FILE: startup_records/03_P2-G03V31_TASK_START_GATE.md =====
# P2-G03V31 Task Start Gate Record

```text
Project ID: PANGU2
Stage ID: PB-S0
Task ID: P2-G03V31
Task Title: 采用V3.1治理与V1.1拆分开发基线
Task Start Gate: GO
Block Reason: NONE
Task Start Base SHA: c8eaedbc47205194c518f2ff6a1415e3ff5abe16
Current Base Branch Tip SHA: c8eaedbc47205194c518f2ff6a1415e3ff5abe16
Previous Reviewed Head SHA: NONE
Candidate Ruleset Manifest SHA-256: 91f2e06e36f122869a6720aab655bad1e1bcbda6cc8d64b8104036b1746d758e
Candidate Baseline Manifest SHA-256: f6536f2ab38052a63090edff7e234f11c97d0d69689692de288829aa2d9e4d4e
```

## Preconditions

- 工作区必须干净；
- 当前分支必须从`pgbnb`的固定Base SHA创建；
- 必须搜索重复Task、PR和Finding；
- Base Tip变化时停止并重新Gate；
- 第一次正式审核前允许整理Commit，送审后禁止重写历史。
===== END FILE: startup_records/03_P2-G03V31_TASK_START_GATE.md =====

===== BEGIN FILE: startup_records/04_P2-G03V31_TASK_SPEC.md =====
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
===== END FILE: startup_records/04_P2-G03V31_TASK_SPEC.md =====

===== BEGIN FILE: startup_records/05_REQUIRED_CHECK_MANIFEST_P2-G03V31.md =====
# Required Check Manifest — P2-G03V31

```text
Manifest ID: P2-G03V31-CHECKS-1.0
Task Start Base SHA: c8eaedbc47205194c518f2ff6a1415e3ff5abe16
Candidate Spec SHA: f6536f2ab38052a63090edff7e234f11c97d0d69689692de288829aa2d9e4d4e
Candidate Ruleset SHA: 91f2e06e36f122869a6720aab655bad1e1bcbda6cc8d64b8104036b1746d758e
```

| Check Name | Applicability | Reason | Workflow File | Expected Job | Observed Status at Base | Head SHA | Evidence |
|---|---|---|---|---|---|---|---|
| markdown-lint | REQUIRED | 全部为Markdown/MDX规则 | `<TO_BE_IMPLEMENTED>` | markdown-lint | NOT_IMPLEMENTED | `<CURRENT_HEAD>` | log |
| baseline-structure-check | REQUIRED | 文件、章节、模板完整 | `<TO_BE_IMPLEMENTED>` | baseline-structure | NOT_IMPLEMENTED | `<CURRENT_HEAD>` | report |
| decision-reference-check | REQUIRED | Decision/PFR不可伪造 | `<TO_BE_IMPLEMENTED>` | decision-reference | NOT_IMPLEMENTED | `<CURRENT_HEAD>` | report |
| internal-link-check | REQUIRED | 文档跨链路 | `<TO_BE_IMPLEMENTED>` | link-check | NOT_IMPLEMENTED | `<CURRENT_HEAD>` | report |
| secret-scan | REQUIRED | 禁止凭证 | `<TO_BE_IMPLEMENTED>` | secret-scan | NOT_IMPLEMENTED | `<CURRENT_HEAD>` | report |
| forbidden-path-check | REQUIRED | 纯文档任务 | `<TO_BE_IMPLEMENTED>` | forbidden-path | NOT_IMPLEMENTED | `<CURRENT_HEAD>` | diff |
| duplicate-normative-source | REQUIRED | 参数唯一来源 | `<TO_BE_IMPLEMENTED>` | duplicate-source | NOT_IMPLEMENTED | `<CURRENT_HEAD>` | report |
| old-tier-active-use | REQUIRED | 禁止恢复35/25/25/15 | `<TO_BE_IMPLEMENTED>` | tier-check | NOT_IMPLEMENTED | `<CURRENT_HEAD>` | report |
| product-code-tests | NOT_APPLICABLE | 本Task禁止产品代码 | NONE | NONE | NOT_APPLICABLE | `<CURRENT_HEAD>` | Forbidden Path证明 |

## Rules

- `skipped`不是PASS；
- Path filter必须覆盖全部Allowed Paths；
- 报告为空或检查数为0时不得PASS；
- CI未实现时执行Agent必须提供本地等价证据，Closeout记录仍标CI `NOT_IMPLEMENTED`。
===== END FILE: startup_records/05_REQUIRED_CHECK_MANIFEST_P2-G03V31.md =====

===== BEGIN FILE: startup_records/06_EVIDENCE_MANIFEST_P2-G03V31.md =====
# Evidence Manifest — P2-G03V31

```text
Manifest ID: P2-G03V31-EVIDENCE-1.0
Status: TEMPLATE_READY
Task Start Base SHA: c8eaedbc47205194c518f2ff6a1415e3ff5abe16
Current Head SHA: <TO_BE_FIXED_AFTER_COMMIT>
Spec SHA: f6536f2ab38052a63090edff7e234f11c97d0d69689692de288829aa2d9e4d4e
Ruleset SHA: 91f2e06e36f122869a6720aab655bad1e1bcbda6cc8d64b8104036b1746d758e
```

每项必须填写：

```text
Evidence ID:
Type:
Command:
Working Directory:
Start Time:
End Time:
Exit Code:
Head SHA:
Log Path:
Report Path:
SHA-256:
Observed Count:
Failure Count:
Notes:
```

## Required Evidence

1. Workspace/branch/Base SHA preflight；
2. Duplicate Task/PR/Finding search；
3. File manifest；
4. UTF-8和单H1；
5. Internal links；
6. Parameter source uniqueness；
7. Forbidden Paths Diff；
8. Secret scan；
9. Old tier active-use scan；
10. Candidate SHA与提交后Git Blob/Head映射；
11. Draft PR信息；
12. Required Check Manifest结果。
===== END FILE: startup_records/06_EVIDENCE_MANIFEST_P2-G03V31.md =====

===== BEGIN FILE: startup_records/07_CURSOR_EXECUTION_PROMPT_P2-G03V31.md =====
# Cursor执行提示词 — P2-G03V31

你是PANGU2项目执行Agent。只执行纯文档与规则迁移，不开发产品代码。

固定输入：

```text
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Expected Task Start Base SHA: c8eaedbc47205194c518f2ff6a1415e3ff5abe16
Project Root: hub/pangu2/
Task ID: P2-G03V31
Candidate Ruleset SHA-256: 91f2e06e36f122869a6720aab655bad1e1bcbda6cc8d64b8104036b1746d758e
Candidate Baseline SHA-256: f6536f2ab38052a63090edff7e234f11c97d0d69689692de288829aa2d9e4d4e
```

先执行：

```bash
git status --short
git branch --show-current
git rev-parse HEAD
git rev-parse origin/pgbnb
git merge-base HEAD origin/pgbnb
git log --all --oneline --grep='P2-G03V31'
```

并搜索已有Open PR、Finding和同名分支。工作区不干净、Base Tip不等于 `c8eaedbc47205194c518f2ff6a1415e3ff5abe16`、已有重复任务或无法读取规则时，停止并输出BLOCKED。

读取：

```text
AGENTS.md
docs/governance/**
hub/pangu2/docs/baseline/**
startup_records/03_P2-G03V31_TASK_START_GATE.md
startup_records/04_P2-G03V31_TASK_SPEC.md
startup_records/05_REQUIRED_CHECK_MANIFEST_P2-G03V31.md
```

创建分支：

```text
task/pangu2/pb-s0/p2-g03v31-governance-baseline
```

将 `repository_payload/` 对应文件复制到仓库相同路径。不得修改Forbidden Paths。不得修改Workflow、脚本或锁文件。

完成所有Required Tests，记录命令、退出码、日志和报告。创建Draft PR，PR描述绑定Task Spec、风险、测试、证据、Merge Base和Current Head。

首次审核：

```text
Previous Reviewed Head SHA: NONE
Review Range: Merge Base SHA → Current Head SHA
```

输出执行结果和审核提示词。不得merge或deploy。
===== END FILE: startup_records/07_CURSOR_EXECUTION_PROMPT_P2-G03V31.md =====

===== BEGIN FILE: startup_records/08_REVIEW_AGENT_PROMPT_P2-G03V31.md =====
# 审核Agent提示词 — P2-G03V31

你是PANGU2审核Agent，只读审核固定GitHub Draft PR。

```text
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Task ID: P2-G03V31
Task Start Base SHA: c8eaedbc47205194c518f2ff6a1415e3ff5abe16
Candidate Spec SHA-256: f6536f2ab38052a63090edff7e234f11c97d0d69689692de288829aa2d9e4d4e
Candidate Ruleset SHA-256: 91f2e06e36f122869a6720aab655bad1e1bcbda6cc8d64b8104036b1746d758e
Previous Reviewed Head SHA: NONE
Current Head SHA: <TO_BE_FILLED>
Merge Base SHA: <TO_BE_FILLED>
Evidence Manifest SHA: <TO_BE_FILLED>
Required Check Manifest SHA: <TO_BE_FILLED>
```

审核：

1. Current Head、Merge Base、Spec、Ruleset和Evidence一致；
2. Diff仅包含Task Allowed Paths；
3. `hub/pixiu1/**`和产品代码无变化；
4. 六层Gate、独立生命周期、完整SHA、Finding和Required Checks完整；
5. Stage Acceptance必须发生在人工合并后；
6. Pangu2基线位于 `hub/pangu2/docs/baseline/**`；
7. 参数只在Parameter Freeze文件维护；
8. 未签参数没有被标ACTIVE/FROZEN；
9. 旧35/25/25/15未作为有效规则；
10. `skipped`和NOT_IMPLEMENTED未被伪报PASS；
11. 不存在Secret、自动merge/deploy或主网授权；
12. 报告不为空，测试数没有异常归零。

Verdict只能：

```text
APPROVED
CHANGES_REQUIRED
BLOCKED
```

Closeout通过时输出 `Lifecycle Recommendation: MERGE_READY`，下一角色为Human Project Owner，不得描述为已合并。
===== END FILE: startup_records/08_REVIEW_AGENT_PROMPT_P2-G03V31.md =====

===== BEGIN FILE: startup_records/09_NEXT_TASK_P2-G04_PREPARED.md =====
# P2-G04 Prepared Task — 精确工具链与锁文件冻结

```text
Task ID: P2-G04
Task Status: DRAFT
Task Start Gate: BLOCKED
Block Reason: DEPENDENCY
Dependency: P2-G03V31 must be MERGED and Stage record updated
Base SHA: <TO_BE_FIXED_AFTER_P2-G03V31_MERGE>
```

## Goal

在 `hub/pangu2/` 初始化并精确固定Solidity、Foundry、OpenZeppelin、Node、PHP/Laravel、Composer、pnpm/npm、PostgreSQL和Redis版本与锁文件策略。

## Why Blocked

当前V3.1/V1.1候选尚未进入仓库和合并，P2-G04不能使用未生效的Spec/Ruleset SHA。合并后由协调Agent重新执行Task Start Gate。

## Future Allowed Paths

```text
hub/pangu2/.tool-versions
hub/pangu2/contracts/foundry.toml
hub/pangu2/contracts/remappings.txt
hub/pangu2/contracts/lib/**
hub/pangu2/package.json
hub/pangu2/pnpm-lock.yaml
hub/pangu2/composer.json
hub/pangu2/composer.lock
hub/pangu2/docs/specs/PB-S0/P2-G04.md
```

精确范围必须在新Base SHA下重新审核。
===== END FILE: startup_records/09_NEXT_TASK_P2-G04_PREPARED.md =====

===== BEGIN FILE: startup_records/10_PB-S1_PB-S2_BLOCKER_RECORD.md =====
# PB-S1 / PB-S2 Stage Blocker Record

```text
PB-S1 Stage Start Gate: BLOCKED
PB-S2 Stage Start Gate: BLOCKED
BSC Testnet Integration Gate: BLOCKED
BSC Mainnet Release Gate: NO-GO
```

## PB-S1 Blockers

- V3.1/V1.1治理包尚未合并；
- 精确工具链和锁文件未冻结；
- LOCAL/CI与Required Checks未实现；
- Parameter Freeze Record未签；
- 盈利Quote Profile未冻结；
- Locker期限/到期、销毁、Epoch、UNKNOWN、成本迁移、分红资产/余数/未领取处理未决；
- ABI/Event Schema未固定。

## PB-S2 Blockers

- DB/API/Event Schema和Worker职责未形成固定Task Spec；
- Laravel/Node精确版本和Lockfile未固定；
- Chain Worker与Job Worker本地/CI环境未建立。

## Unblock Owner

阶段级阻塞由Project Coordinator Agent路由；业务和参数Decision由Human Project Owner批准。
===== END FILE: startup_records/10_PB-S1_PB-S2_BLOCKER_RECORD.md =====

===== BEGIN FILE: startup_records/11_HUMAN_APPROVAL_RECORD.md =====
# 人工项目负责人批准记录 — V3.1/V1.1治理基线采用

```text
Decision ID: DR-P2-GOV-001
Decision Title: Adopt Governance V3.1 and PANGU2 Baseline V1.1
Version: V1.0
Status: PENDING_HUMAN_DECISION
Project ID: PANGU2
Stage ID: PB-S0
Task ID: P2-G03V31
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Task Start Base SHA: c8eaedbc47205194c518f2ff6a1415e3ff5abe16
Candidate Ruleset Manifest SHA-256: 91f2e06e36f122869a6720aab655bad1e1bcbda6cc8d64b8104036b1746d758e
Candidate Baseline Manifest SHA-256: f6536f2ab38052a63090edff7e234f11c97d0d69689692de288829aa2d9e4d4e
```

## Decision

```text
Human Decision Status:
APPROVED / REJECTED / NEEDS_REVISION / PAUSED / CANCELLED

Selected Scope:
- AGENTS.md V3.1
- docs/governance/** V3.1/V1.1
- Cursor/Agent rules V3.1
- hub/pangu2/docs/baseline/** V1.1

Approved By:
Approval Date:
Reason:
Conditions:
Expires At:
```

## Effect

APPROVED只允许执行P2-G03V31文档落库和审核。它不批准PB-S1参数、合约开发、测试网部署、生产Secret、资金或主网写链。
===== END FILE: startup_records/11_HUMAN_APPROVAL_RECORD.md =====
