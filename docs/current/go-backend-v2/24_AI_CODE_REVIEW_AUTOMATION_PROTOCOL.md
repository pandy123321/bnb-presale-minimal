# BingGoPlus — 独立审核手动提交流程与阶段门禁协议

## 1. 适用范围

本协议适用于所有已批准阶段计划，包括历史 G0-G9 和当前 Flap F0-F11。执行 Agent 必须在每个阶段结束后准备完整提审上下文，并在获得审核结果前暂停。外部审核统一由用户手动提交；执行 Agent 只生成完整提审包、Hash 和提示词，不寻找、不调用、不轮询外部审核通道。

```text
阶段实施 -> 阶段自检 -> 生成提审包 -> 交付用户手动提交
    -> 用户回传完整报告 -> 执行方二次裁决 -> 通过才进入下一阶段
```

本协议不授权数据库迁移、合约重部署、主网操作、签名广播或生产发布。

## 2. 每阶段强制流程

每个阶段完成时，Agent 必须依次执行：

1. 锁定本阶段范围，停止继续开发下一阶段；
2. 记录本阶段修改文件、Commit、工作区状态和未执行项；
3. 生成单一完整提审包及 `PAYLOAD_MANIFEST.csv`；
4. 计算提审包 SHA-256；
5. 将冻结文档、阶段目标、上一轮审核结论、当前变更、Manifest 和自检结果作为同一上下文，交付责任人手动提交；
6. 在用户回传报告后保存审核标识（如有）、报告时间、Commit 和 Package SHA-256；
7. 等待用户回传完整独立审核报告，不得自行推断通过；
8. 仅在 Verdict 允许推进时登记阶段 Gate，并开始下一阶段。

同一执行轮次不得在审核和裁决完成前跨越多个阶段。

当前及后续阶段统一使用：

```text
EXTERNAL_REVIEW_SUBMISSION = USER_MANUAL
```

因此执行 Agent不得搜索审核工具、轮询任务或伪造 Review ID，只负责生成可复算的提审材料并接收用户回传的报告。

## 3. 手动独立审核提交上下文

提交必须包含：

```text
PROJECT = BingGoPlus Go Backend V2
STAGE = 当前已批准阶段（Gx 或 FLAP-Fx）
BASELINE_COMMIT = 当前基线 Commit
IMPLEMENTATION_COMMIT = 本阶段 Commit
PACKAGE_SHA256 = 完整提审包 Hash
PREVIOUS_REVIEW_VERDICT = 上一轮 Verdict
OPEN_FINDINGS = 当前未关闭问题
SCOPE = 本阶段允许修改范围
NON_GOALS = 禁止修改范围
```

必须要求独立审核 Agent 只审核本阶段范围，并输出带文件路径、行号、证据、具体修复方法和 Verdict 的 Markdown 报告。

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
    -> 生成新包并交付用户重新提交

BLOCKED
    -> STAGE_GATE = BLOCKED
    -> 停止所有开发
    -> 补齐材料后重新提交

REJECTED
    -> STAGE_GATE = REJECTED
    -> 停止并等待项目负责人重新授权
```

任何 `P0` 或 `P1` 未关闭时，不得推进。`P2` 是否阻断以独立审核报告和冻结规则为准，不得由执行 Agent 自行豁免。

## 5. 用户回传与上下文同步

用户回传审核结果后，执行 Agent 必须保存报告原文或附件标识并核验：

- 审核包 SHA-256 与本次提交一致；
- 审核 Commit 与提审 Commit 一致；
- 审核范围没有越界；
- 报告存在最终 Verdict；
- Findings 与状态记录一致。

下一阶段提交时，必须自动带入上一阶段：

```text
审核报告路径或 Artifact ID；手工审核没有任务号时使用 `N/A_USER_MANUAL`
上一阶段 Verdict
已关闭 Finding
仍开放 Finding
修复 Commit
提审包 SHA-256
```

若用户尚未回传完整审核结果，必须输出：

```text
EXTERNAL_REVIEW_SUBMISSION = USER_MANUAL
EXTERNAL_REVIEW_STATUS = AWAITING_USER_REPORT
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
EXTERNAL_REVIEW_SUBMISSION = USER_MANUAL
EXTERNAL_REVIEW_ID = <id> / N/A_USER_MANUAL
REVIEW_ARTIFACT_ID
REVIEW_REPORT_SHA256
REVIEW_TIMESTAMP
REVIEWER_IDENTITY
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

即使独立审核报告返回 `APPROVED`，仍不得自动执行以下动作：

- 修改或重部署已部署 Solidity 合约；
- BSC 主网部署或广播；
- 生产数据库迁移；
- 私钥签名、链上交易或生产发布；
- 修改冻结的 API、State、Event 或权限模型；
- 下载未获批准的依赖。

这些动作必须分别通过对应 Environment、Security、Deployment 和 Runtime Gate。

## 8. 阶段完成输出

```text
STAGE = Gx / FLAP-Fx
IMPLEMENTATION_STATUS = COMPLETE / INCOMPLETE
SELF_CHECK = PASS / FAIL
PACKAGE_SHA256 = <hash>
EXTERNAL_REVIEW_SUBMISSION = USER_MANUAL
EXTERNAL_REVIEW_ID = <id> / N/A_USER_MANUAL
REVIEW_ARTIFACT_ID = <attachment/path/hash identity>
REVIEW_REPORT_SHA256 = <hash>
REVIEW_TIMESTAMP = <actual timestamp>
REVIEWER_IDENTITY = <agent/session identity if available, otherwise UNKNOWN_NOT_CLAIMED>
EXTERNAL_REVIEW_VERDICT = PENDING / APPROVED / CHANGES_REQUIRED / BLOCKED
STAGE_GATE = PASSED / OPEN / BLOCKED / REJECTED
NEXT_STAGE = 已冻结的下一阶段 / NONE
NEXT_STAGE_AUTHORIZATION = YES / NO
WAITING_FOR_EXTERNAL_REVIEW = YES / NO
```

## 9. 范围内自动执行与范围外人工确认

### 9.1 默认授权原则

只要任务属于当前已批准的 BingGoPlus Go Backend V2 冻结范围，并且不改变既有业务规则、经济模型、控制逻辑、API 契约、数据库结构、State/Event 规范、权限边界或已部署合约，执行 Agent 可以直接执行，不需要逐项人工确认。

范围内默认包括：

- 按当前已批准阶段计划实施当前阶段任务；
- 修改当前阶段明确允许修改的 Go Backend 代码；
- 使用当前冻结方案要求的开发环境；
- 安装、配置和使用已批准的环境依赖；
- 执行当前阶段所需的本地构建、静态检查、文档检查和已批准验证；
- 生成提审包、Manifest、Hash 和阶段状态；
- 生成审核包、Hash 和提示词，交付用户手动提交，并在用户回传报告后同步审核上下文；
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
8. 改变当前阶段计划边界、审核门禁或 Freeze 状态；
9. 修改其他阶段代码或文档，且不是当前阶段必要的引用同步；
10. 执行当前冻结规则没有覆盖的业务操作；
11. 绕过独立审核，或在用户回传并完成二次裁决前推进下一阶段；
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

执行 Agent 可以直接更新当前阶段执行记录、阶段状态、手动提审交付记录、审核结果记录，以及实现所需的引用、路径、Hash 和状态字段。

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

范围内任务可以自动执行，但每个阶段完成后仍必须生成提审材料并暂停，由用户手动提交。外部审核通过只代表当前阶段在审核范围内通过，不代表获得范围外任务授权。

即使范围内自动执行，也不得自动执行生产部署、主网操作、私钥签名、链上广播或已部署合约重部署；这些动作必须单独通过对应 Environment、Security、Deployment 和 Runtime Gate。

## 10. 外部审核结论二次判定

### 10.1 不得盲从外部审核结果

执行 Agent 收到用户回传的独立审核报告后，不得直接把报告中的 Finding、修复建议或阶段 Verdict 当作事实执行。必须先进行一次独立的结果判定：

```text
读取审核报告
    -> 逐项核对文件、行号、规则和证据
    -> 对每条结论进行正确性判定
    -> 只执行确认正确的结论
```

外部审核机器人的结论不是自动授权。执行 Agent 必须根据当前冻结文档、实际代码、SQL、API、State/Event 规范、权限边界和既有独立审核记录判断其是否成立。

### 10.2 结论分类

每条外部 Finding 或建议必须标记为以下之一：

```text
CORRECT_ACTIONABLE
INCORRECT_DO_NOT_EXECUTE
PARTIALLY_CORRECT_LIMITED_ACTION
UNVERIFIABLE_PAUSE
OUT_OF_SCOPE_HUMAN_CONFIRMATION_REQUIRED
```

处理规则：

- `CORRECT_ACTIONABLE`：可以在当前阶段范围内执行修复或推进动作；
- `INCORRECT_DO_NOT_EXECUTE`：不得执行该结论，并记录反证；
- `PARTIALLY_CORRECT_LIMITED_ACTION`：只执行被证据支持的部分，禁止扩大范围；
- `UNVERIFIABLE_PAUSE`：证据不足，暂停相关动作，不得猜测执行；
- `OUT_OF_SCOPE_HUMAN_CONFIRMATION_REQUIRED`：超出冻结范围，暂停并请求人工确认。

### 10.3 阶段 Verdict 的接受条件

只有当以下条件全部满足，才能接受外部审核的阶段通过结论：

```text
REVIEW_PACKAGE_MATCH = YES
REVIEW_SCOPE_MATCH = YES
ALL_P0_P1_FINDINGS_VERIFIED = YES
NO_UNVERIFIABLE_BLOCKING_FINDING = YES
NO_OUT_OF_SCOPE_ACTION_REQUIRED = YES
VERDICT_EVIDENCE_CONSISTENT = YES
```

如果审核报告包含错误的阻断结论，执行 Agent 不得执行错误修复，但必须在判定记录中说明理由；如果错误结论导致整体 Verdict 无法直接接受，则状态应为：

```text
EXTERNAL_VERDICT_ADJUDICATION = DISPUTED
NEXT_STAGE_AUTHORIZATION = NO
```

如果报告同时包含正确和错误结论，只执行确认正确且属于当前范围的部分；错误部分不执行；无法确认部分保持暂停。

### 10.4 必须写入的二次判定记录

每次接收独立审核报告后，必须在阶段状态或审核记录中写入：

```text
EXTERNAL_REVIEW_ID = <id> / N/A_USER_MANUAL
REVIEW_ARTIFACT_ID
REVIEW_REPORT_SHA256
REVIEW_TIMESTAMP
REVIEWER_IDENTITY
EXTERNAL_REVIEW_VERDICT
REVIEW_PACKAGE_SHA256
ADJUDICATION_STATUS = ACCEPTED / PARTIAL / DISPUTED / PAUSED
FINDING_ID
EXTERNAL_CONCLUSION
INDEPENDENT_ASSESSMENT = CORRECT / INCORRECT / PARTIAL / UNVERIFIABLE
EVIDENCE_CHECK
ACTION_TAKEN = <实际执行动作或 NONE>
ACTION_REASON
SCOPE_DECISION
NEXT_STAGE_AUTHORIZATION
```

### 10.5 下一次提审必须同步该过程

下一次交付用户手动提审时，必须将上一轮审核的二次判定过程作为上下文一并提交，包括：

- 外部审核任务 ID（没有时为 `N/A_USER_MANUAL`）、Artifact ID、报告 SHA-256、时间、Reviewer Identity 和原始 Verdict；
- 每条 Finding 的正确性判定；
- 被执行的正确结论及对应修改；
- 被拒绝执行的错误结论及反证；
- 仅部分执行的结论及范围限制；
- 无法确认或超出范围的结论；
- 当前仍开放的 Finding；
- 当前阶段是否允许推进；
- 上一轮审核包 SHA-256 与本轮新包 SHA-256。

提交报告必须增加以下区块：

```text
## External Review Adjudication

REVIEW_ID = <id> / N/A_USER_MANUAL
REVIEW_ARTIFACT_ID = <attachment/path/hash identity>
REVIEW_REPORT_SHA256 = <hash>
REVIEW_TIMESTAMP = <actual timestamp>
REVIEWER_IDENTITY = <identity or UNKNOWN_NOT_CLAIMED>
ORIGINAL_VERDICT = <verdict>
ADJUDICATION_STATUS = <status>

| Finding | External conclusion | Independent assessment | Action | Evidence |
|---|---|---|---|---|
| ... | ... | CORRECT / INCORRECT / PARTIAL / UNVERIFIABLE | ... | ... |

NEXT_STAGE_AUTHORIZATION = YES / NO
```

### 10.6 安全默认值

以下任一情况成立时，必须暂停相关动作：

```text
无法读取原始审核报告
审核包 Hash 不匹配
审核范围与当前阶段不一致
Finding 证据无法复核
外部结论与冻结规则冲突且无法裁决
正确结论与错误结论混杂，无法隔离执行范围
```

暂停状态：

```text
EXTERNAL_VERDICT_ADJUDICATION = PAUSED
HUMAN_CONFIRMATION = REQUIRED
NEXT_STAGE_AUTHORIZATION = NO
```

## 10.7 审核通过后的自动推进规则

在当前已批准执行计划内，阶段审核通过后默认自动进入下一阶段，不需要再次请求人工确认。执行 Agent 必须先完成外部审核结论二次判定，再按以下条件决定是否推进：

```text
EXTERNAL_REVIEW_VERDICT = APPROVED
EXTERNAL_REVIEW_ADJUDICATION = ACCEPTED
REVIEW_COMPLETENESS = COMPLETE
UNVERIFIABLE_BLOCKING_FINDING = 0
OUT_OF_SCOPE_TASK = 0
ACCEPTANCE_CRITERIA = PASS
NEXT_STAGE_DEFINED = YES
PACKAGE_HASH_MATCH = YES
```

全部满足时：

```text
AUTO_ADVANCE_DECISION = APPROVED
STAGE_GATE = PASSED
NEXT_STAGE_AUTHORIZATION = YES
```

执行 Agent 应自动完成以下动作：

1. 记录当前阶段完成状态；
2. 保存审核 ID（没有时为 `N/A_USER_MANUAL`）、Artifact ID、报告 SHA-256、时间、Reviewer Identity、Verdict、二次判定记录、Commit 和 Package SHA-256；
3. 将上一阶段上下文同步到阶段状态记录；
4. 读取既定执行计划中的下一阶段；
5. 自动开始下一阶段的范围内任务；
6. 在下一阶段完成后再次生成提审材料并交付用户手动提交。

只有以下情况才必须暂停并请求人工确认：

- 外部结论无法判断或证据不足；
- 审核包、Commit 或审核范围不匹配；
- 存在未关闭的 P0/P1 或审核指定的阻断项；
- 发现范围外任务或需要修改冻结规则；
- 需要改变业务逻辑、API、数据库、权限、State/Event 或合约；
- 需要修改已关闭 Finding；
- 当前阶段验收条件未满足；
- 下一阶段没有在冻结执行计划中定义。

暂停状态必须写为：

```text
AUTO_ADVANCE_DECISION = PAUSED
NEXT_STAGE_AUTHORIZATION = NO
HUMAN_CONFIRMATION = REQUIRED
```

自动推进仅适用于当前已批准阶段计划内任务，不代表获得以下操作授权：

- 生产部署；
- BSC 主网操作；
- 私钥签名或链上广播；
- 已部署合约重部署；
- 修改冻结规则、API、数据库或权限模型；
- 下载未批准依赖。

### 10.7.1 Flap F6 到 F7 的强制暂停例外

默认自动推进规则不适用于 `F6 -> F7`。F6 结束的是 Flap Native MVP；F7 首次进入 BGPlus 自建金融 Solidity、RevenueVault 资金会计和新的安全边界。F7～F10 仍是责任人批准的必做路线，但 F6 审核通过本身不授予 F7 开发权限。

```text
F6_REVIEW = APPROVED
F6_ADJUDICATION = ACCEPTED
NEXT_STAGE = F7
AUTO_ADVANCE_DECISION = PAUSED
F7_ENTRY_AUTHORIZED = NO
```

只有同时取得以下证据后才能开始 F7：

```text
F7_EXTENSION_ENTRY_REVIEW = APPROVED
RESPONSIBLE_OWNER_SECURITY_SCOPE_AUTHORIZATION = SIGNED
F7_SCOPE_AND_PROHIBITED_ACTIONS = FROZEN
F7_ENTRY_AUTHORIZED = YES
```

这项暂停只控制新 Solidity 域的进入时点，不允许执行 Agent 把 F7～F10 删除、永久延期或降为 Optional。未经授权不得创建或修改 `contracts-flap` 业务合约，也不得把 F6 的 Admin Wallet 权限扩展为任意合约调用。

## 11. 审核结论必须包含可执行修复方案

### 11.1 禁止只报问题不提供解决路径

独立审核报告不得只列出“存在问题”或“建议修复”，而必须对每条确认成立的 Finding 给出可执行的修复说明。审核 Agent 仍保持只读，不得直接修改代码；但必须让实施 Agent 能够依据报告准确完成修复。

### 11.2 每条 Finding 的必填字段

每条 P0/P1/P2/P3 Finding 至少必须包含：

```text
FINDING_ID
SEVERITY
FILE_PATH
LINE_RANGE_OR_FUNCTION
CURRENT_BEHAVIOR
EXPECTED_BEHAVIOR
EVIDENCE
ROOT_CAUSE
IMPACT
REMEDIATION_REQUIRED = YES / NO
REMEDIATION_SCOPE
REMEDIATION_STEPS
CONSTRAINTS_AND_NON_GOALS
ACCEPTANCE_CRITERIA
REGRESSION_CHECKS
```

其中：

- `FILE_PATH` 必须是仓库内可定位的相对路径；
- `LINE_RANGE_OR_FUNCTION` 必须给出行号、函数名、SQL 对象或明确代码符号；
- `EVIDENCE` 必须引用实际代码、配置、文档或可复核的状态路径；
- `REMEDIATION_STEPS` 必须说明具体修改哪个文件、哪个函数/对象、增加或删除什么逻辑；
- `CONSTRAINTS_AND_NON_GOALS` 必须说明不得修改哪些冻结边界；
- `ACCEPTANCE_CRITERIA` 必须定义修复完成后的可验证结果；
- `REGRESSION_CHECKS` 必须列出需要重新检查的旧路径和禁止回归的 Finding。

### 11.3 修复方案的最低详细程度

修复建议至少要达到以下粒度：

```text
错误：不能只写“修复取消逻辑”。

合格：
1. 修改 sql/0001_binggoplus_v2_schema.sql；
2. 在 enforce_governance_command_cancellation_request_boundary() 中限制状态边；
3. 仅允许 Command=REJECTED 时 REQUESTED->REJECTED；
4. 保持 CANCELLED->CONSUMED 不变；
5. 禁止 API 获得整表 UPDATE；
6. 验收 APPROVED/QUEUED 不能拒绝请求，REJECTED 可以收敛请求；
7. 回归检查 P1-R8-01/P1-R8-02。
```

审核报告可以提供 SQL 伪代码、函数签名、状态转移表或补丁级别的修改建议，但不得在未授权时直接写入工作区。

### 11.4 不同结论类别的输出要求

```text
CORRECT_ACTIONABLE
    -> 必须提供完整修复方案和验收标准

PARTIALLY_CORRECT_LIMITED_ACTION
    -> 必须明确可修复部分、不可修复部分和边界

INCORRECT_DO_NOT_EXECUTE
    -> 必须提供反证和“不执行”的理由；无需提供错误修复方案

UNVERIFIABLE_PAUSE
    -> 必须列出缺失材料、需要补充的证据和恢复审核条件

OUT_OF_SCOPE_HUMAN_CONFIRMATION_REQUIRED
    -> 必须说明越界对象、影响和需要人工决定的选项
```

### 11.5 下一轮提审必须携带修复闭环

实施 Agent 重新提交审核时，必须为上一轮每条可执行 Finding 提供闭环映射：

```text
FINDING_ID
ORIGINAL_LOCATION
ORIGINAL_REMEDIATION
IMPLEMENTED_FILES
IMPLEMENTED_LINES_OR_FUNCTIONS
IMPLEMENTATION_COMMIT
ACCEPTANCE_EVIDENCE
REGRESSION_RESULT
REMAINING_LIMITATIONS
```

外部审核 Agent 必须检查“问题—修复—验收”三者是否一致；如果只看到问题已报告但没有可执行修复方案，报告不得标记为完整审核报告，阶段状态保持：

```text
REVIEW_COMPLETENESS = INCOMPLETE
NEXT_STAGE_AUTHORIZATION = NO
```
