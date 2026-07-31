# AI 开发项目三 Agent 云端治理：角色执行说明

> 架构：GITHUB_REVIEW_ONLY  
> 版本：V3.0

本仓库为 PGBNB Web3 hub：业务项目位于 `hub/`（已归档项目见 `hub/pixiu1/`）。治理规则位于仓库根，适用于整个 hub。

本仓库 Agent 必须按角色规则执行。可执行规则位于：

| 文件 | 使用角色 | 用途 |
|---|---|---|
| `.cursor/rules/project-coordinator.mdc` / `.agent-rules/project-coordinator.md` | 项目协调 Agent | 项目启动、阶段启动、阶段阻塞和阶段衔接 |
| `.cursor/rules/execution-agent.mdc` / `.agent-rules/execution-agent.md` | 执行 Agent | 代码实施、测试、Push、PR 和直接提交审核 |
| `.cursor/rules/review-agent.mdc` / `.agent-rules/review-agent.md` | 审核 Agent | 只读审核 PR、Finding、返修和 Closeout |
| `.cursor/rules/human-project-owner.mdc` / `.agent-rules/human-project-owner.md` | 人工项目负责人 | 重大决策、合并、发布、权限和豁免 |
| `.cursor/rules/github-review-only-governance.mdc` | 全体 | 架构边界与交接顺序（默认生效） |

## 整体执行顺序

```text
人工项目负责人提出目标
        ↓
项目协调 Agent 执行 Project Start Gate
        ↓
项目协调 Agent 生成阶段首次执行提示词
        ↓
执行 Agent 开发、本地测试、Push、创建或更新 PR
        ↓
执行 Agent 直接生成审核提示词
        ↓
审核 Agent 审核固定 Head SHA
        ├─ CHANGES_REQUIRED
        │    ↓
        │  审核 Agent 直接生成返修提示词
        │    ↓
        │  执行 Agent 返修并 Push 新 SHA
        │    ↓
        │  再次直接提交审核
        │
        ├─ BLOCKED
        │    ↓
        │  代码级阻塞：执行/审核直接处理
        │  阶段级阻塞：交回项目协调 Agent
        │
        └─ APPROVED
             ↓
           Closeout Review
             ↓
           项目协调 Agent 确认阶段衔接
             ↓
           人工项目负责人决定是否合并
```

## 各角色如何执行

### 项目协调 Agent

**什么时候执行：** 项目首次启动；新阶段启动；阶段级阻塞；Closeout 通过后；项目暂停、恢复、取消或关闭。

**怎么执行：** 加载项目协调规则 → 执行 Project Start Gate → `GO` 时生成阶段首次执行提示词给执行 Agent → 开发审核循环期间暂不介入 → Closeout 后判断下一阶段。

### 执行 Agent

**什么时候执行：** 收到阶段首次执行提示词；收到审核 Agent 的返修提示词。

**怎么执行：** 加载执行规则 → 开发与本地测试 → Push 任务分支 → 创建/更新 Draft PR → 等待 CI → 输出 PR Number / Merge Base SHA / Head SHA → 直接把审核提示词交给审核 Agent。返修时继续原 Task ID、原 PR、原任务分支。

### 审核 Agent

**什么时候执行：** 执行 Agent 已提供固定 Head SHA；返修后有新 Head SHA；需要 Closeout。

**怎么执行：** 加载审核规则 → 只读审核固定 PR Head SHA → 输出 `APPROVED / CHANGES_REQUIRED / BLOCKED` → 不通过时直接生成返修提示词 → Closeout 通过后把阶段结果交给项目协调 Agent。

### 人工项目负责人

**什么时候执行：** 业务目标/范围重大不确定；权限或生产边界变化；阶段暂停/取消/替代；`MERGE_READY`；部署、回滚或豁免。

**怎么执行：** 阅读确认事项 → 使用明确结论批准或拒绝 → 保存 Decision Record → 不介入普通代码返修 → Closeout 后决定是否合并 → 合并后独立决定是否部署。

## 最关键的边界

1. 正式代码审核只使用 GitHub PR 和固定 Head SHA。
2. 执行 Agent 与审核 Agent 直接完成开发、审核、返修和复审。
3. 项目协调 Agent 不介入每一轮代码交接。
4. 项目协调 Agent 只负责项目和阶段级协调。
5. 审核 Agent 才能给出正式 Review Verdict。
6. 只有人工项目负责人可以决定合并和发布。
7. 审核通过不等于已合并。
8. 已合并不等于已验收。
9. 已验收不等于生产已上线。
