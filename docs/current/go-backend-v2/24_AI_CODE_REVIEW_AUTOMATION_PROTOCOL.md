# BingGoPlus Go Backend V2 — Ai-Code-Review 自动阶段门禁协议

## 1. 适用范围

本协议适用于 G0-G9 的所有开发阶段。执行 Agent 必须在每个阶段结束后自动通过已配置的 `Ai-Code-Review` 外部审核工具提交完整上下文，并在获得审核结果前暂停。

```text
阶段实施 -> 阶段自检 -> 生成提审包 -> Ai-Code-Review 提交
    -> 等待结果 -> 解析 Verdict -> 通过才进入下一阶段
```

本协议不授权数据库迁移、合约重部署、主网操作、签名广播或生产发布。

## 2. 每阶段强制流程

每个阶段完成时，Agent 必须依次执行：

1. 锁定本阶段范围，停止继续开发下一阶段；
2. 记录本阶段修改文件、Commit、工作区状态和未执行项；
3. 生成单一完整提审包及 `PAYLOAD_MANIFEST.csv`；
4. 计算提审包 SHA-256；
5. 将冻结文档、阶段目标、上一轮审核结论、当前变更、Manifest 和自检结果作为同一上下文，通过 `Ai-Code-Review` 提交；
6. 保存外部审核任务 ID、提交时间、Commit 和 Package SHA-256；
7. 等待 Ai-Code-Review 最终 Verdict，不得自行推断通过；
8. 仅在 Verdict 允许推进时登记阶段 Gate，并开始下一阶段。

同一执行轮次不得自动跨越多个阶段。

## 3. Ai-Code-Review 提交上下文

提交必须包含：

```text
PROJECT = BingGoPlus Go Backend V2
STAGE = G0..G9 当前阶段
BASELINE_COMMIT = 当前基线 Commit
IMPLEMENTATION_COMMIT = 本阶段 Commit
PACKAGE_SHA256 = 完整提审包 Hash
PREVIOUS_REVIEW_VERDICT = 上一轮 Verdict
OPEN_FINDINGS = 当前未关闭问题
SCOPE = 本阶段允许修改范围
NON_GOALS = 禁止修改范围
```

必须要求 Ai-Code-Review 只审核本阶段范围，并输出带文件路径、行号、证据和 Verdict 的 Markdown 报告。

## 4. Verdict 门禁

```text
APPROVED / APPROVED_FOR_NEXT_STAGE
    -> STAGE_GATE = PASSED
    -> NEXT_STAGE_AUTHORIZATION = YES
    -> 允许进入下一阶段

CHANGES_REQUIRED
    -> STAGE_GATE = OPEN
    -> 停止推进
    -> 仅修复本阶段 Finding
    -> 生成新包并重新提交 Ai-Code-Review

BLOCKED
    -> STAGE_GATE = BLOCKED
    -> 停止所有开发
    -> 补齐材料后重新提交

REJECTED
    -> STAGE_GATE = REJECTED
    -> 停止并等待项目负责人重新授权
```

任何 `P0` 或 `P1` 未关闭时，不得推进。`P2` 是否阻断以独立审核报告和冻结规则为准，不得由执行 Agent 自行豁免。

## 5. 自动获取与上下文同步

如果 `Ai-Code-Review` 工具支持任务查询，Agent 必须保存任务 ID并轮询至最终结果；结果返回后必须核验：

- 审核包 SHA-256 与本次提交一致；
- 审核 Commit 与提审 Commit 一致；
- 审核范围没有越界；
- 报告存在最终 Verdict；
- Findings 与状态记录一致。

下一阶段提交时，必须自动带入上一阶段：

```text
审核报告路径或任务 ID
上一阶段 Verdict
已关闭 Finding
仍开放 Finding
修复 Commit
提审包 SHA-256
```

若工具暂时不可用，必须输出：

```text
EXTERNAL_REVIEW_TOOL = Ai-Code-Review
EXTERNAL_REVIEW_STATUS = UNAVAILABLE
WAITING_FOR_EXTERNAL_REVIEW = YES
NEXT_STAGE_AUTHORIZATION = NO
```

不得把“已生成提审包”当成审核通过。

## 6. 阶段状态记录

每次提交后更新 `STAGE_GATE_STATUS.md` 或等价状态记录，至少包含：

```text
CURRENT_STAGE
STAGE_STATUS
IMPLEMENTATION_COMMIT
PACKAGE_SHA256
EXTERNAL_REVIEW_TOOL = Ai-Code-Review
EXTERNAL_REVIEW_ID
EXTERNAL_REVIEW_VERDICT
OPEN_FINDINGS
CLOSED_FINDINGS
NEXT_STAGE_AUTHORIZATION
WAITING_FOR_EXTERNAL_REVIEW
```

只有同时满足以下条件，阶段才可标记 `PASSED`：

```text
IMPLEMENTATION_COMPLETE = YES
STATIC_SELF_CHECK = PASS
PACKAGE_MANIFEST = VALID
EXTERNAL_REVIEW_VERDICT = APPROVED
P0_OPEN = 0
P1_OPEN = 0
NEXT_STAGE_AUTHORIZATION = YES
```

## 7. 高风险动作独立授权

即使 Ai-Code-Review 返回 `APPROVED`，仍不得自动执行以下动作：

- 修改或重部署已部署 Solidity 合约；
- BSC 主网部署或广播；
- 生产数据库迁移；
- 私钥签名、链上交易或生产发布；
- 修改冻结的 API、State、Event 或权限模型；
- 下载未获批准的依赖。

这些动作必须分别通过对应 Environment、Security、Deployment 和 Runtime Gate。

## 8. 阶段完成输出

```text
STAGE = Gx
IMPLEMENTATION_STATUS = COMPLETE / INCOMPLETE
SELF_CHECK = PASS / FAIL
PACKAGE_SHA256 = <hash>
EXTERNAL_REVIEW_TOOL = Ai-Code-Review
EXTERNAL_REVIEW_ID = <id>
EXTERNAL_REVIEW_VERDICT = PENDING / APPROVED / CHANGES_REQUIRED / BLOCKED
STAGE_GATE = PASSED / OPEN / BLOCKED / REJECTED
NEXT_STAGE = Gx+1 / NONE
NEXT_STAGE_AUTHORIZATION = YES / NO
WAITING_FOR_EXTERNAL_REVIEW = YES / NO
```

## 9. 范围内自动执行与范围外人工确认

### 9.1 默认授权原则

只要任务属于当前已批准的 BingGoPlus Go Backend V2 冻结范围，并且不改变既有业务规则、经济模型、控制逻辑、API 契约、数据库结构、State/Event 规范、权限边界或已部署合约，执行 Agent 可以直接执行，不需要逐项人工确认。

范围内默认包括：

- 按 G0-G9 已批准阶段实施当前阶段任务；
- 修改当前阶段明确允许修改的 Go Backend 代码；
- 使用当前冻结方案要求的开发环境；
- 安装、配置和使用已批准的环境依赖；
- 执行当前阶段所需的本地构建、静态检查、文档检查和已批准验证；
- 生成提审包、Manifest、Hash 和阶段状态；
- 通过 `Ai-Code-Review` 提交审核并同步审核上下文；
- 在外部审核明确 `APPROVED` 后进入下一阶段；
- 根据审核报告修复当前阶段范围内的问题并重新提审。

执行 Agent 不得因为范围内的正常开发动作反复请求人工确认。

### 9.2 必须人工确认的范围外任务

出现以下任一情况时，必须立即暂停并请求人工确认：

1. 修改当前冻结文档之外的新规则；
2. 新增、删除或改变业务逻辑；
3. 改变合约经济模型或控制逻辑；
4. 修改 Solidity、已部署合约、部署地址或链 ID；
5. 改变已冻结的 API、数据库结构、State/Event、权限或角色模型；
6. 新增当前文档未定义的服务、模块、外部系统或数据源；
7. 引入当前依赖准入规则未批准的依赖；
8. 改变 G0-G9 阶段边界、审核门禁或 Freeze 状态；
9. 修改其他阶段代码或文档，且不是当前阶段必要的引用同步；
10. 执行当前冻结规则没有覆盖的业务操作；
11. 绕过 `Ai-Code-Review` 或在审核结果返回前推进下一阶段；
12. 修改已经关闭的 Finding 结论；
13. 进行生产部署、主网操作、私钥签名、链上广播或已部署合约重部署。

### 9.3 依赖与环境边界

当前阶段所需环境依赖不需要逐项人工确认，但必须同时满足：

```text
依赖属于当前冻结方案；
依赖符合开源项目准入规则；
依赖不改变业务逻辑；
依赖不修改生产环境；
依赖不会绕过安全、权限和审核 Gate。
```

如果依赖属于新的技术路线，或需要改变冻结架构、数据库、API 或部署模型，则属于范围外任务，必须人工确认。

### 9.4 文档修改边界

执行 Agent 可以直接更新当前阶段执行记录、阶段状态、Ai-Code-Review 提交记录、审核结果记录，以及实现所需的引用、路径、Hash 和状态字段。

不得直接修改冻结业务规则、经济模型、API 契约、数据库结构、Event/State 规范、权限模型、责任人签署结论或已关闭 Finding。确需修改时，必须先请求人工确认并重新触发相应设计审核和 Freeze 流程。

### 9.5 自动判定协议

每个新任务开始前，按以下顺序判断：

```text
1. 是否属于当前阶段？
2. 是否已在冻结文档或阶段任务中定义？
3. 是否只修改当前允许的代码、文档记录或批准依赖？
4. 是否保持业务逻辑、合约、API、数据库、权限和部署边界不变？
```

四项均为“是”时：

```text
SCOPE_DECISION = IN_SCOPE
HUMAN_CONFIRMATION = NOT_REQUIRED
ACTION = CONTINUE
```

任一项为“否”或无法确定时：

```text
SCOPE_DECISION = OUT_OF_SCOPE_OR_UNCLEAR
HUMAN_CONFIRMATION = REQUIRED
ACTION = PAUSE
```

暂停输出必须说明具体越界内容及其对规则、代码、数据、权限或部署的影响。

### 9.6 与外部审核的关系

范围内任务可以自动执行，但每个阶段仍必须自动提交 `Ai-Code-Review`。外部审核通过只代表当前阶段在审核范围内通过，不代表获得范围外任务授权。

即使范围内自动执行，也不得自动执行生产部署、主网操作、私钥签名、链上广播或已部署合约重部署；这些动作必须单独通过对应 Environment、Security、Deployment 和 Runtime Gate。
