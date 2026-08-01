# pangu2

盘古2（PANGU2）项目根目录。唯一业务项目路径：`hub/pangu2/`。

## 当前开发基线（P2-G03V31）

| 路径 | 说明 |
|---|---|
| `docs/specs/PB-S0/P2-G03V31.md` | 当前任务基线索引 |
| `docs/specs/PB-S0/03_P2-G03V31_TASK_START_GATE.md` | Task Start Gate（GO） |
| `docs/specs/PB-S0/04_P2-G03V31_TASK_SPEC.md` | Task Spec |
| `docs/specs/PB-S0/05_REQUIRED_CHECK_MANIFEST_P2-G03V31.md` | 审核基线：Required Checks |
| `docs/specs/PB-S0/06_EVIDENCE_MANIFEST_P2-G03V31.md` | 审核基线：Evidence Manifest |
| `docs/specs/PB-S0/07_CURSOR_EXECUTION_PROMPT_P2-G03V31.md` | 执行提示词 |
| `docs/specs/PB-S0/08_REVIEW_AGENT_PROMPT_P2-G03V31.md` | 审核基线：审核提示词 |
| `../../startup_records/`（仓库根） | 上述同步副本 |
| `docs/evidence/PB-S0/P2-G03V31/` | 证据与审核基线副本 |

## 其他文档

| 路径 | 说明 |
|---|---|
| `docs/baseline/PANGU2_DEVELOPMENT_BASELINE_V1.1_RC.md` | 单体 RC（已 SUPERSEDED，仅归档） |
| `docs/current/盘古2项目详细开发文档_V2.1_PGBNB.md` | 详细开发文档 V2.1（Markdown 副本） |
| `docs/current/盘古2项目详细开发文档_V2.1_PGBNB.docx` | 详细开发文档 V2.1（原文） |

## Cursor Rules

默认生效：

- `.cursor/rules/pangu2-p2-g03v31-task-baseline.mdc`（当前任务基线）
- `.cursor/rules/pangu2-baseline-core.mdc`
- `.cursor/rules/pangu2-baseline-protocol.mdc`
- `.cursor/rules/pangu2-baseline-architecture.mdc`

## 当前状态

- Base Branch：`pgbnb`
- Active Task：`P2-G03V31`（Task Start Gate GO）
- Decision：`DR-P2-0001` ACTIVE（本目录为唯一项目根）
- `hub/pixiu1/`：归档只读
- 产品开发 Gate：BLOCKED；BSC_MAINNET：NO-GO
- Automatic Merge / Deployment：FORBIDDEN
