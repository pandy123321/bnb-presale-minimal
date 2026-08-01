# 角色规则索引

本目录说明角色规则部署位置。可执行规则以仓库根为准：

- `AGENTS.md`：总执行说明与交接顺序
- `.cursor/rules/*.mdc`：Cursor 可加载规则（含 frontmatter）
- `.agent-rules/*.md`：与 README 推荐布局一致的规范副本

业务与 Web3 项目代码统一放在 `hub/`；本治理目录属于仓库根，不随具体项目归档。

| 角色 | Cursor Rule | 规范副本 |
|---|---|---|
| 项目协调 Agent | `.cursor/rules/project-coordinator.mdc` | `.agent-rules/project-coordinator.md` |
| 执行 Agent | `.cursor/rules/execution-agent.mdc` | `.agent-rules/execution-agent.md` |
| 审核 Agent | `.cursor/rules/review-agent.mdc` | `.agent-rules/review-agent.md` |
| 人工项目负责人 | `.cursor/rules/human-project-owner.mdc` | `.agent-rules/human-project-owner.md` |
| 治理总规则 | `.cursor/rules/github-review-only-governance.mdc` | （见 `AGENTS.md`） |
| 盘古2 当前任务基线 | `.cursor/rules/pangu2-p2-g03v31-task-baseline.mdc` | `hub/pangu2/docs/specs/PB-S0/P2-G03V31*` + `startup_records/` |
| 盘古2 核心 | `.cursor/rules/pangu2-baseline-core.mdc` | `hub/pangu2/docs/baseline/` + `docs/current/` |
| 盘古2 协议 | `.cursor/rules/pangu2-baseline-protocol.mdc` | 同上 §9–14 / V2.1 §5 |
| 盘古2 架构交付 | `.cursor/rules/pangu2-baseline-architecture.mdc` | 同上 §15–27 / V2.1 §6–12 |
| pixiu1 基线（归档） | `.cursor/rules/pixiu1-baseline-*.mdc` | `hub/pixiu1/docs/baseline/` |
