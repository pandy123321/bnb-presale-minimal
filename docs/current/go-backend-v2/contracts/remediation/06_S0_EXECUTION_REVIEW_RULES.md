# PANGU2 V2 S0 执行结论独立审核规则

```text
Document ID: PANGU2-V2-S0-INDEPENDENT-REVIEW-RULES
Review Type: DESIGN_GATE_REVIEW
Review Mode: READ_ONLY
Target Stage: PANGU2-V2-S0
Solidity Changes: FORBIDDEN
Deployment Approval: NOT_GRANTED
Mainnet: NO-GO
```

## 1. 审核目的

本规则供独立审核 Agent 检查 S0 执行 Agent 产出的设计候选是否完整、唯一、可实现、可测试并符合 PANGU2 V2 权威经济基线。

本审核只能决定 S0 设计候选是否可以交给 Review Adjudication Agent 校对。独立审核 Agent不得修改文件，不得自行签发最终 `APPROVED_DESIGN_BASELINE`，不得授权 Solidity 实现、部署、迁移或 Mainnet。

## 2. 角色隔离

```text
S0 Design Agent != Independent Review Agent
Independent Review Agent != Review Adjudication Agent
S0 Design Agent != Review Adjudication Agent
```

审核报告必须记录 Agent/session identity、开始和完成时间以及目标 Commit 的完整 40 位 SHA。角色隔离无法证明时：

```text
REVIEW_STATUS = BLOCKED_ROLE_SEPARATION
S0_APPROVED_DESIGN_BASELINE = NO
S1_ALLOWED = NO
SOLIDITY_IMPLEMENTATION_ALLOWED = NO
```

## 3. 审核输入

审核前必须完整读取：

```text
docs/current/go-backend-v2/contracts/remediation/README.md
docs/current/go-backend-v2/contracts/remediation/00_AUDIT_FINDINGS_BASELINE.md
docs/current/go-backend-v2/contracts/remediation/01_MASTER_EXECUTION_PROMPT.md
docs/current/go-backend-v2/contracts/remediation/02_REVIEW_WORKFLOW_AND_PROMPTS.md
docs/current/go-backend-v2/contracts/remediation/03_STAGE_EVIDENCE_TEMPLATE.md
docs/current/go-backend-v2/contracts/remediation/05_EXTERNAL_PLAN_REVIEW_ADJUDICATION.md
docs/current/go-backend-v2/contracts/remediation/06_S0_EXECUTION_REVIEW_RULES.md
docs/current/go-backend-v2/contracts/remediation/stages/S0_DESIGN_AND_INVARIANT_FREEZE.md
```

必须读取 S0 输出：

```text
docs/current/go-backend-v2/contracts/remediation/evidence/S0_DESIGN_DECISION_REGISTER.md
docs/current/go-backend-v2/contracts/remediation/evidence/S0_INVARIANT_SPECIFICATION.md
docs/current/go-backend-v2/contracts/remediation/evidence/S0_ABI_AND_STATE_MACHINE_FREEZE.md
docs/current/go-backend-v2/contracts/remediation/evidence/S0_BASELINE_COMPLIANCE_MATRIX.md
docs/current/go-backend-v2/contracts/remediation/evidence/S0_STAGE_EVIDENCE.md
```

必须读取权威基线：

```text
docs/current/go-backend-v2/contracts/BSC_TESTNET_DEPLOYMENT_BASELINE.md
docs/current/go-backend-v2/05_BUSINESS_AND_CONTRACT_INHERITANCE.md
docs/current/go-backend-v2/08_RULES_COMPLIANCE_AND_DECISIONS.md
docs/current/go-backend-v2/09_SELF_REVIEW.md
docs/current/CONTRACT_SECURITY_AUDIT.md
通用智能合约安全开发风险控制与漏洞治理规范 V1.0.md
```

源码事实使用：

```text
Deployed Source Commit = 3ef50b6d77a31c092e9353e255e672836f36ece8
Planning Review Head = 4d33669b41568fa573e9c0e5865be8b1cea803c3
S0 Review Commit = <由提交方提供的完整 40 位 SHA>
```

如果指定 Commit 或必要 S0 输出无法读取，只对相应项目输出 `BLOCKED_EVIDENCE`，不得用当前工作区或 public main 静默替代。

## 4. 禁止操作

审核 Agent不得：

- 修改任何文件；
- 修复或补写 S0 文档；
- 修改 Solidity、接口、测试或部署脚本；
- 执行 Build、测试、Fuzz、Invariant、Fork、RPC、Anvil、广播、签名或部署；
- 审核 Backend、DApp、数据库、Docker、服务器或本地部署环境；
- 根据测试源码存在或旧报告存在声称验证通过；
- 将设计批准描述为已修复 BSC Testnet runtime；
- 将 `APPROVED_FOR_ADJUDICATION` 描述为 `APPROVED_DESIGN_BASELINE`；
- 代替用户签署 `ACCEPTED_DEVIATION`；
- 在关键决策仍有两个选项时替执行 Agent作出选择。

本轮必须记录：

```text
Tests Executed This Review = NO
Build Executed This Review = NO
RPC Used This Review = NO
Files Modified This Review = NONE
```

## 5. Verdict 规则

独立审核 Verdict 只能是：

```text
APPROVED_FOR_ADJUDICATION
CHANGES_REQUIRED
BLOCKED
```

### 5.1 APPROVED_FOR_ADJUDICATION

仅当以下条件全部满足时允许：

```text
Required S0 Documents Present = YES
Correct Review Commit Verified = YES
Decision Register Complete = YES
All Mandatory Decisions Unique = YES
Unresolved P0/P1/P2 Design Issues = 0
Economic Baseline Changed = NO
Invariant Specification Complete = YES
ABI/State Machine Freeze Complete = YES
Cross-Document Consistency = PASS
Solidity Files Modified During S0 = NONE
```

该结论只允许进入 Review Adjudication，不直接允许 S1。

### 5.2 CHANGES_REQUIRED

适用于：

- 决策仍使用“推荐、任选、后续再定”等非唯一表述；
- 设计遗漏攻击路径、状态转换、权限边界、舍入或回滚语义；
- 文档之间互相矛盾；
- ABI 或状态机不足以指导唯一实现；
- 不变量不可验证；
- 未经用户批准改变经济基线；
- 存在尚未关闭的 PLAN-P1/P2；
- S0 Agent错误声称可以修改 Solidity或进入 S1。

### 5.3 BLOCKED

只适用于无法完成实质审核的证据阻断，例如：

- S0 Review Commit 无法读取且没有绑定快照；
- 必要 S0 输出缺失；
- 权威基线缺失；
- 无法确认审核对象；
- 角色隔离无法证明；
- 提交包完整性或哈希无法验证且可能导致审核错版本。

不得仅因本轮没有运行测试或 Build 输出 BLOCKED；S0 本来就是文档设计阶段。

## 6. Finding 标准

每条正式 Finding 必须包含：

```text
Finding ID
Severity: PLAN-P0 / PLAN-P1 / PLAN-P2 / PLAN-P3
Status: NEW / KNOWN / DUPLICATE / NOT_APPLICABLE
Document
Section / Line
Commit Evidence
Baseline Evidence
Problem
Failure Scenario
Cross-Contract Impact
Affected Stages
Why Current Design Is Insufficient
Required Correction
Economic Baseline Impact
Whether Solidity Evidence Is Required
Whether Finding Blocks S0 Approval
```

严重级别：

- `PLAN-P0`：设计允许直接资产盗取、无限 Mint、任意接管或不可恢复的核心资产锁死；
- `PLAN-P1`：设计会导致重大资金/税费/会计/权限/Oracle 错误，或无法形成安全实现；
- `PLAN-P2`：关键边界歧义、不变量缺失、阶段关闭错误或证据 Gate 不完整；
- `PLAN-P3`：命名、链接、轻微证据字段或维护性问题，不影响当前设计安全结论。

没有具体文档、失败场景和影响的意见不得列为正式 Finding。

## 7. 强制审核矩阵

### 7.1 基线与范围

审核：

- S0 是否只修改 `remediation/evidence/S0_*.md` 或经规则允许的 S0 文档；
- 是否修改 Solidity、测试、接口、脚本或应用；
- deployed commit、planning head、review commit 是否明确区分；
- 是否把后续源码修复误写成已部署 runtime 修复；
- Initial Supply、税率、Launch 15 分钟、回购 0.01 BNB、60 秒间隔等参数是否保持不变；
- 任何经济变化是否明确标记 `USER_APPROVAL_REQUIRED` 并阻止 S0 关闭。

### 7.2 CostBasis 双账本

必须确认设计唯一规定：

```text
knownBalance
knownCostWbnbWei
unknownBalance
actualBalance = knownBalance + unknownBalance
knownBalance == 0 => knownCostWbnbWei == 0
```

检查：

- eligible liquid user 范围明确；
- Pair/System/协议 custody 被排除；
- UNKNOWN 输入不能删除或使用 KNOWN 成本；
- KNOWN/UNKNOWN/mixed transfer 和 sell 消费顺序唯一；
- full exit、partial exit、zero balance/nonzero cost 边界明确；
- legacy NONE/KNOWN/UNKNOWN view 派生规则明确；
- Dividend/Reward 零成本输入不覆盖已有成本；
- 实际余额失配 fail-closed；
- aggregate known cost 不会因转账增加。

### 7.3 Mixed Sell、舍入与 Preview

必须确认：

- UNKNOWN 固定 9% Support + 1% Burn；
- KNOWN 按精确利润比较进入 4% 或 10%；
- 利润分类不依赖已向下取整的 proportional cost；
- 给出 overflow-safe 精确比较；
- remainder/carry 和完整退出规则明确；
- 同一 quote 下拆分操作不能降低 aggregate tax；
- support + burn + swapTokens = sellAmount；
- wei 级容差不会跨越 4%/10% 边界产生套利；
- Preview Option A/B 已唯一选择；
- Option A 有用户 maximum deduction 约束，或 Option B 有明确 revision lock；
- Preview/Execute 失败时全局原子回滚。

如果 Option A/B 仍同时保留，必须输出至少 `PLAN-P1`，S0 不得批准。

### 7.4 Canonical 税费控制面

确认：

```text
Trading Gate
→ Fee Whitelist
→ Launch Protection
→ Normal Cost-Basis Tax
```

以及：

- whitelist 存储和管理员唯一来源为 Pangu2Token/GOVERNANCE_ROLE；
- whitelist 只免税，不绕过 Trading/Pause/Pair/余额安全；
- zero-tax settlement 跳过 FeeVault 零额 credit；
- Preview 和 Execute 使用真实 buyer/seller；
- 实现阶段源代码 SHA 不匹配时必须 fail-closed。

### 7.5 Staking 阶段边界与 typed context

必须确认：

```text
P1-STK-01A principal CostBasis migration → S3
P1-STK-01B reward zero-cost typed credit → S4A
```

检查：

- S3 不激活、不关闭 reward credit；
- S4A 才迁移 account-level→per-position reward；
- mutation path 唯一为 Staking→typed Token→onlyToken CostBasis；
- context 绑定 stakingContract/account/positionId/operationKind；
- positionId 不跨用户、不复用；
- 禁止 Staking 和 Token 双写 CostBasis；
- context 的建立、使用、清除和 revert 原子性明确。

### 7.6 Staking 资金状态机

确认：

```text
stakingTokenBalance
= activePrincipal
+ availableRewardReserve
+ ownedAccruedRewardLiability
+ explicitRoundingOrSurplus
```

检查：

- normal exit 只关闭 principal，成熟 reward 可独立领取；
- early exit reward 被没收并返回 reserve；
- 10% penalty 进入 reserve；
- claim/forfeit 终态不可重复；
- totalStaked=0 不产生无人归属 emission；
- rounding dust 有显式归属；
- reward-rate liability coverage 明确；
- Pause、setRewardRate(0)、principal exit 的语义唯一；
- PAUSER/UNPAUSER 分离。

### 7.7 Oracle

必须确认：

```text
twapWindow = 1800 seconds
MAX_TWAP_AGE = 5 × twapWindow
maxDeviation = 300 bps
```

唯一 long-gap 规则必须是：

```text
elapsed > MAX_TWAP_AGE
→ discard old completion candidate
→ re-anchor current counterfactual cumulative
→ ACCUMULATING
→ no READY quote in the same update
```

同时检查 `elapsed == MAX_TWAP_AGE`、uint32 回绕、cumulative overflow、低储备、零报价、deviation、permissionless 高频 update 和状态恢复。

### 7.8 Approved-user 与 Fee Whitelist

确认：

```text
approved-user does not automatically grant feeWhitelist
feeWhitelist does not automatically grant approved-user
```

只有 Governance 独立显式操作可允许二者重叠。Pair、System、Settlement、LiquidityManager 和 TransferContext 身份必须与 approved-user 互斥。

检查 approved-user 不获得 systemTransfer、settlement、CostBasis hook、context 或 Pair/Router 绕过权限。

### 7.9 Contract Account 生命周期

若选择 FIX，必须冻结：

```text
NONE → APPROVED → EXIT_ONLY/GRACE → REVOKED
```

检查：

- 授权主体和 code identity；
- counterfactual registration；
- APPROVED 权限；
- EXIT_ONLY 可转出/官方卖出但不可接收/买入；
- 有余额不能直接 REVOKED；
- 终态不可回退；
- Direct Pair 永远 fail-closed；
- 事件完整。

若选择 EOA-only deviation，必须有用户本人签署的证据；Agent不得代签。没有签署时必须输出 `BLOCKED_DECISION`。

### 7.10 Support 与 Dividend

确认：

- 回购金额仍为 0.01 BNB；
- 成功 cooldown 仍为 60 秒；
- recipient 固定 Locker；
- 使用 canonical PancakeV2Adapter quote，不开放任意 pair/path；
- view/execute 共用判断；
- 浅池 fail-closed，不动态缩小金额；
- Dividend 只能在 `block.timestamp > claimEnd` 后取消；
- 已有 claim 不可取消；
- pre-start emergency cancel 未经用户批准不得加入。

### 7.11 ABI、状态机和可实现性

必须确认 S0 输出列出：

- structs、enums、functions、interfaces；
- events/errors/context kinds；
- legacy compatibility；
- constructor/interface 编译影响；
- DApp/Backend 后续适配影响但不在本阶段实现；
- 每个状态机的允许转换、终态、失败和重试行为。

设计必须足以让 S1–S8B Agent按唯一语义实现。若关键 ABI 只写原则而没有字段或调用权威路径，不能批准。

## 8. 不变量审核规则

每条不变量必须包含：

```text
Invariant ID
Applicable Contracts
Preconditions
Allowed State Transition
Success Postconditions
Revert Zero-Change Requirement
Unit Verification
Fuzz Verification
Invariant Verification
```

至少覆盖：

```text
CB-INV-01..05
SELL-INV-01..02
STK-INV-01..06
ORC-INV-01
REG-INV-01..02
FEE-INV-01
DIV-INV-01
```

只写口号、没有可观测状态和失败条件的不变量视为未完成。

## 9. 跨文档一致性

逐项比较：

```text
S0 Design Decision Register
S0 Invariant Specification
S0 ABI and State Machine Freeze
S0 Baseline Compliance Matrix
S0 Stage Evidence
S1–S8B stage plans
```

检查：

- 同一 Decision ID 是否只有一个结果；
- 同一 Finding 是否只在规定阶段关闭；
- ABI 字段与状态机语义一致；
- 不变量与经济规则一致；
- stage Allowed Paths 足以实现冻结方案；
- stage exit 不会提前关闭后续工作；
- 不存在 `S0_ALLOWED`、`S1_ALLOWED`、`SOLIDITY_IMPLEMENTATION_ALLOWED` 相互矛盾的状态。

## 10. 审核输出格式

首先输出：

```text
S0 Independent Review Verdict:
APPROVED_FOR_ADJUDICATION / CHANGES_REQUIRED / BLOCKED
```

然后按以下结构输出。

### 1. Review Identity

```text
Review Agent / Session:
Review Started At:
Review Completed At:
S0 Base Commit:
S0 Review Commit:
Deployed Source Commit:
Planning Review Head:
Files Modified = NONE
Tests Executed = NO
Build Executed = NO
RPC Used = NO
```

### 2. Evidence Completeness

| Required Input | Present | Commit/Hash Bound | Read Completely | Impact |
|---|---|---|---|---|

### 3. Mandatory Decision Matrix

| Decision ID | Requirement | S0 Decision | Unique | Baseline Compliant | Implementable | Verdict |
|---|---|---|---|---|---|---|

### 4. Invariant Review

| Invariant ID | Complete | Observable | Revert Atomicity | Testable | Verdict |
|---|---|---|---|---|---|

### 5. ABI and State Machine Review

| ID | Design | Authority | Transition/Failure Semantics | Compatibility | Verdict |
|---|---|---|---|---|---|

### 6. Baseline Compliance

| Baseline Item | Expected | S0 Result | Changed | Evidence | Verdict |
|---|---|---|---|---|---|

### 7. Findings

按 PLAN-P0、PLAN-P1、PLAN-P2、PLAN-P3 分组。无问题时必须明确写 `None`。

### 8. Verified Non-Issues

列出已经静态确认的重要安全设计，不得只写“整体合理”。

### 9. Cross-Document Consistency

```text
DECISION_REGISTER_CONSISTENT = PASS / FAIL
INVARIANT_SPEC_CONSISTENT = PASS / FAIL
ABI_STATE_MACHINE_CONSISTENT = PASS / FAIL
STAGE_BOUNDARIES_CONSISTENT = PASS / FAIL
BASELINE_MATRIX_CONSISTENT = PASS / FAIL
```

### 10. Final Gate Answer

必须逐项回答：

1. S0 是否包含全部必需设计决定？
2. 每个关键决定是否唯一，不再留给 Implementation Agent自选？
3. 是否存在未解决的 PLAN-P0/P1/P2？
4. 是否改变经济基线？
5. ABI 和状态机是否足以指导唯一实现？
6. 不变量是否可以被后续测试验证？
7. 是否发现 Solidity、测试或脚本被越权修改？
8. 是否建议提交 Review Adjudication？

最后必须输出：

```text
INDEPENDENT_REVIEW_VERDICT = APPROVED_FOR_ADJUDICATION / CHANGES_REQUIRED / BLOCKED
REVIEW_ADJUDICATION_REQUIRED = YES
S0_APPROVED_DESIGN_BASELINE = NO
S1_ALLOWED = NO
SOLIDITY_IMPLEMENTATION_ALLOWED = NO
DEPLOYMENT_APPROVAL = NOT_GRANTED
BSC_TESTNET_RUNTIME_FIXED = NO
MAINNET = NO-GO
```

注意：即使独立审核没有 Finding，也必须由另一个 Review Adjudication Agent 校对本报告。只有裁决闭环完成，并由后续 Gate 明确产生 `APPROVED_DESIGN_BASELINE` 后，才可能允许进入 S1。

## 11. 可直接交给审核 Agent 的启动提示词

```text
你是 PANGU2 V2 S0 独立设计审核 Agent。请严格按照：

docs/current/go-backend-v2/contracts/remediation/06_S0_EXECUTION_REVIEW_RULES.md

只读审核 S0 执行 Agent 在指定完整 40 位 Review Commit 上产生的全部 S0 文档。

项目根目录：
E:\github\bnb\bnb-presale-minimal

S0 Review Commit：
<填写完整 40 位 SHA>

禁止修改文件、Solidity、测试或部署脚本；禁止 Build、测试、RPC、Fork、部署和链上操作。

你的权限仅限输出：
APPROVED_FOR_ADJUDICATION / CHANGES_REQUIRED / BLOCKED

不得直接签发 APPROVED_DESIGN_BASELINE，不得授权 S1，不得授权 Solidity 实现或部署。完成后把审核报告全文交给独立 Review Adjudication Agent 校对。
```
