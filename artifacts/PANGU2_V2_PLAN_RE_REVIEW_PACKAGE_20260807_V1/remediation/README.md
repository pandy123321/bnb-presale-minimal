# PANGU2 V2 合约安全修复执行包

```text
Document ID: PANGU2-V2-SECURITY-REMEDIATION-PLAN
Status: PLANNING_READY
Planning Observed HEAD: 4d33669b41568fa573e9c0e5865be8b1cea803c3
Deployed Source Commit: 3ef50b6d77a31c092e9353e255e672836f36ece8
Chain ID: 97
Mainnet: NO-GO
Automatic Merge: FORBIDDEN
Automatic Push: FORBIDDEN
Automatic Deployment: FORBIDDEN
```

本目录把 PANGU2 V2 合约安全修复拆成短阶段，供另一个 Agent 逐阶段执行。它不授权部署、迁移、RPC、广播、签名、推送或合并。

## 1. 权威输入

执行 Agent 必须按以下顺序读取：

1. `../BSC_TESTNET_DEPLOYMENT_BASELINE.md`
2. `../../05_BUSINESS_AND_CONTRACT_INHERITANCE.md`
3. `../../08_RULES_COMPLIANCE_AND_DECISIONS.md`
4. `../../09_SELF_REVIEW.md`
5. `../../../CONTRACT_SECURITY_AUDIT.md`
6. `00_AUDIT_FINDINGS_BASELINE.md`
7. `01_MASTER_EXECUTION_PROMPT.md`
8. `02_REVIEW_WORKFLOW_AND_PROMPTS.md`
9. `03_STAGE_EVIDENCE_TEMPLATE.md`
10. `05_EXTERNAL_PLAN_REVIEW_ADJUDICATION.md`
11. 当前阶段文件

若执行时 HEAD 不再是上面的 Planning Observed HEAD，必须先记录新 HEAD，并比较 `3ef50b6..HEAD` 的 `contracts-v2/src/**` 差异。不得假设本计划生成后的新代码已经安全。

## 2. 修复阶段

| 顺序 | 阶段 | 主要范围 | 关闭目标 | 大阶段审核 |
|---|---|---|---|---|
| 0 | `S0` 设计冻结 | 经济规则、ABI、状态机、不变量 | 所有实现前决策 | 设计审核 |
| 1 | `S1` CostBasis 双账本 | CostBasis、接口、数学库 | P1-CB-01 核心账本 | 阶段审核 |
| 2 | `S2` Token/Router 结算 | Token、Router、CostBasis 接口 | P1-CB-01、P2-TAX-01 | **M1 优先全量代码审核** |
| 3 | `S3` Staking 成本迁移 | Token、CostBasis、Staking | P1-STK-01 | 阶段审核 |
| 4A | `S4A` Staking 奖励/退出 | Staking、接口、测试 | P1-STK-02、P2-STK-03 | 阶段审核 |
| 4B | `S4B` Staking 暂停 | Staking、角色、测试 | 暂停加固 | **M2 优先全量代码审核** |
| 5 | `S5` Support 回购 | SupportPool、Adapter/接口 | P2-BBK-01 | 阶段审核 |
| 6 | `S6` Dividend 终态 | DividendDistributor | P2-DIV-01 | 阶段审核 |
| 7 | `S7` Oracle 回绕 | PancakeV2TwapOracle | P3-ORC-01 | 阶段审核 |
| 8A | `S8A` 合约账户生命周期 | Pangu2Token | Registry、revoke、exit 或偏差决策 | 阶段审核 |
| 8B | `S8B` Pair/Router 防绕过 | Token、Router、Context 测试 | P3-TKN-01 | **M3 优先全量代码审核** |
| 9 | `S9` 最终代码退出门 | 全部 `contracts-v2/src/**` | 所有代码 Finding | **最终全量代码审核** |

阶段文件位于 `stages/`。必须按顺序执行；不得因为某阶段修改较小而跳过审核闭环。

## 3. 每个阶段的强制闭环

```text
Stage Start Snapshot
→ Pre-Fix Read-Only Review
→ Pre-Fix Review Adjudication
→ 仅对 CONFIRMED Finding 执行 Implementation
→ Local Code Validation
→ Commit（完整 40-char SHA）
→ Post-Fix Independent Read-Only Review
→ Post-Fix Review Adjudication
→ 仅修复 CONFIRMED Findings
→ Fix Commit
→ Independent Re-Review
→ APPROVED_CODE_ONLY
→ Stage Closeout
```

规则：

- 实现 Agent 不得给自己的阶段签发独立批准。
- 阶段开始时，必须先独立确认原 Finding、根因和拟定修复边界；未确认前禁止改代码。
- 审核 Agent 只读，不修改代码。
- 校对 Agent 必须逐条检查审核 Finding 是否有文件、行号、攻击路径和基线冲突证据。
- `CHANGES_REQUIRED` 不等于所有审核意见都正确；只有校对为 `CONFIRMED` 的 Finding 才能进入修复。
- `APPROVED_CODE_ONLY` 只表示代码阶段通过，不表示可部署、已部署、可扩大测试网或 Mainnet GO。
- P0/P1/P2 不得用“后续再处理”关闭。P3 只有用户书面批准 `ACCEPTED_DEVIATION` 才能不改代码。

## 4. 开发期审核边界

审核必须覆盖：

- Solidity 实现、接口、库和与修改直接相关的测试；
- 跨合约调用和资金流；
- 权限、暂停、重入、CEI、算术、状态机和事件；
- 构造函数、immutable、一次性配置和接口兼容性；
- 是否符合部署基线中的经济参数和控制逻辑；
- 代码层可部署性：能否编译、接口是否完整、构造参数和连接关系是否自洽。

开发期审核不覆盖：

- 本地部署流程、私钥、`.env`、Docker、数据库、Backend、DApp；
- RPC、Fork、广播回执、链上角色和真实 runtime；
- 实际部署脚本执行、签名、交易或迁移执行；
- 把测试文件存在、Build 产物存在或旧广播 `status=1` 当作本阶段通过。

实现 Agent可以运行本地 `forge fmt/build/test`、Fuzz 和 Invariant 作为代码验证；不得运行 `forge script`、Fork、RPC、`cast send/call`、Anvil 或任何部署命令。本目录不授权修改部署脚本，除非用户以后单独建立部署/迁移阶段。

## 5. Git 和证据规则

- 推荐分支：`codex/pangu2-v2-security-remediation`。
- 每阶段开始记录 Base SHA、HEAD、状态和允许路径。
- 保留用户原有未跟踪文件；不得清理或覆盖无关改动。
- 每阶段至少一个实现 Commit；审核修复使用独立 follow-up Commit。
- 报告必须记录完整 40 字符 SHA，不能只写短 SHA。
- 不自动 push、merge、tag 或部署。

## 6. 大阶段全量审核定义

M1、M2、M3 和 S9 的 `PRIORITY_FULL_AUDIT` 必须：

1. 阅读全部 `contracts-v2/src/**`，而不只看 diff；
2. 复核本大阶段代码对 Buy、Sell、Support、Dividend、Staking 的影响；
3. 复核其他未修改合约是否因接口、状态或权限变化被破坏；
4. 搜索新增绕过、重入、错误税率、会计漂移、角色接管和永久 DoS；
5. 检查基线参数未被未经批准地改变；
6. 判断 `CODE_DEPLOYABILITY = YES / NO`，但不得宣称实际部署通过；
7. 输出 `APPROVED_CODE_ONLY / CHANGES_REQUIRED / BLOCKED`。

## 7. 强制编译 Gate

S1–S8B 的每个 Implementation/Fix Commit 都必须满足：

```text
IMPLEMENTATION_COMMIT_SHA = full 40-char SHA
CORE_SOLIDITY_BUILD = PASS
INTERFACE_IMPLEMENTATION_MATCH = PASS
COMPILE_ERRORS = 0
NEXT_STAGE_ALLOWED = NO if CORE_SOLIDITY_BUILD != PASS
```

Unit/Fuzz/Invariant 因工具或环境缺失可以记录 `NOT_RUN_WITH_BLOCKER`，但核心 Solidity 编译失败或未执行不能关闭阶段。没有可用编译器时，阶段保持 `BLOCKED_BUILD_EVIDENCE`。

Foundry 会把 `contracts-v2/script/**` 纳入完整编译面。部署执行始终不在本计划范围内，但允许只读检查脚本的类型和 constructor 调用。如果已经批准的 Solidity ABI/constructor 变化导致完整 Build 仅因脚本签名不匹配而失败，可以申请 `COMPILE_COMPATIBILITY_EXCEPTION`：

- 必须先提供编译错误和最小影响文件证据；
- 必须由 Review Adjudication 标记 `SCOPE_EXPANSION_REQUIRED` 并取得用户批准；
- 只允许更新 Solidity 类型、接口或 constructor 参数位置；
- 使用独立 Commit 和独立代码审核；
- 禁止修改地址、私钥、环境变量、角色策略、部署顺序、迁移逻辑、广播或链上操作；
- 该补丁只证明编译兼容，不构成部署脚本审核或部署批准。
