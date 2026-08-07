# Plan Review Verdict: CHANGES_REQUIRED

```text
Solidity Implementation Allowed: NO
Deployment Approval: NOT_GRANTED
Mainnet: NO-GO
```

本结论不是 `BLOCKED`：现有 S0–S9 文档足以审核方案架构和阶段逻辑，但**不足以签发完整的 S0 设计 Gate 批准**。主要原因是 S0 自己声明的前置材料 `README.md` 与 `00_AUDIT_FINDINGS_BASELINE.md` 未上传，同时审核治理闭环所依赖的 `01/02/03` 也缺失。另一方面，我在 GitHub `pandy123321/bnb-presale-minimal` 的 `contracts-v2` 当前源码中发现了几处需要在 S0 冻结前明确的架构问题。

---

## RECEIVED_DOCUMENTS

已收到并完整读取：

| 文档                                                | SHA-256                                                            |
| ------------------------------------------------- | ------------------------------------------------------------------ |
| S0_DESIGN_AND_INVARIANT_FREEZE.md                 | `093260dc0b78b85bd55ac872a7618940ce60dc68fce8c14a4eead5e350f4470a` |
| S1_COST_BASIS_DUAL_LEDGER.md                      | `5f8b67ce65f4ce2d7177564fc0f0e25cde1ecd172a8b1234e6d0ac14d65b5037` |
| S2_TOKEN_ROUTER_MIXED_SETTLEMENT_AND_WHITELIST.md | `c0e3344130d2967a52464823eaf27ebeee50d945d94c88594ab1d8a6caacfb86` |
| S3_STAKING_COST_BASIS_BRIDGE.md                   | `62983ea74b7e952b482edcba36180883c79247d3c5174237201d900d49214a70` |
| S4_STAKING_REWARD_EXIT_AND_PAUSE.md               | `97d41ac3df0fc3dc0d6118dfcc6009f539a232ac4ba914e75fe4193d57a9d939` |
| S5_SUPPORT_BUYBACK_PRICE_IMPACT.md                | `df1f8e33a9febc3a03b2cef3f04b7d812a863410e20fc493e3c106243a90c650` |
| S6_DIVIDEND_EPOCH_FINALITY.md                     | `2ed73052d82d84735328a1abff5ef8adda80ae9203d2a5027ddc84d1b8397283` |
| S7_ORACLE_UINT32_ROLLOVER.md                      | `1abb06aaed5320d78f86c4c13f56612e05db9cf225d4d8907c151637521cca3d` |
| S8_CONTRACT_ACCOUNT_BOUNDARY.md                   | `7766216a8d20ea4d54b6a1a8999459d2bd4849c168198b6b61eca2cfea012011` |
| S9_FINAL_CODE_EXIT_GATE.md                        | `8415855813150229183891fa1c1c779490d347c7533d13f409f4e991cdb60e16` |

对应阶段内容见 S0–S9。         

## MISSING_REQUIRED_DOCUMENTS

```text
README.md
00_AUDIT_FINDINGS_BASELINE.md
01_MASTER_EXECUTION_PROMPT.md
02_REVIEW_WORKFLOW_AND_PROMPTS.md
03_STAGE_EVIDENCE_TEMPLATE.md
```

因此以下内容目前只能是：

```text
FINDING_BASELINE = NOT_INDEPENDENTLY_VERIFIED
REVIEW_INDEPENDENCE_RULES = NOT_INDEPENDENTLY_VERIFIED
ADJUDICATION_RULES = NOT_INDEPENDENTLY_VERIFIED
EVIDENCE_TEMPLATE = NOT_INDEPENDENTLY_VERIFIED
FULL_SHA_ENFORCEMENT = NOT_INDEPENDENTLY_VERIFIED
```

未上传、因此没有进行正式基线交叉核对的附加文档：

```text
BSC_TESTNET_DEPLOYMENT_BASELINE.md
05_BUSINESS_AND_CONTRACT_INHERITANCE.md
08_RULES_COMPLIANCE_AND_DECISIONS.md
09_SELF_REVIEW.md
CONTRACT_SECURITY_AUDIT.md
```

## DOCUMENT_VERSION_OR_SHA_IF_AVAILABLE

阶段 ID 已由各文件给出 `PANGU2-V2-S0` 至 `PANGU2-V2-S9`；附件自身没有 Git Commit SHA，因此上表记录的是本次收到文件的 SHA-256。

GitHub 当前可访问仓库为 `pandy123321/bnb-presale-minimal`，`contracts-v2/` 被当前仓库文档标识为 authoritative。当前检索到的较新可见提交为：

```text
cd7bde9b977674fa49d8527346e8a666cd9fe450
```

该提交同时再次说明 `contracts-v2/` 为 Testnet active contract directory，且 Mainnet 为 NO-GO。

但你提供的：

```text
3ef50b6d77a31c092e9353e255e672836f36ece8
4d33669b41568fa573e9c0e5865be8b1cea803c3
```

通过当前 GitHub 仓库接口无法解析。因此：

```text
DEPLOYED_SOURCE_COMMIT_3ef50... = NOT_INDEPENDENTLY_VERIFIED
PLAN_HEAD_4d336... = NOT_INDEPENDENTLY_VERIFIED
CURRENT_SOURCE_REVIEW_REFERENCE = current GitHub main/contracts-v2
```

不能把当前 `main` 源码自动等价为当时制定方案使用的 `4d336...`。

---

# 1. Project Understanding

本次审核对象是 **PANGU2 V2 Solidity 修复方案本身**，不是确认代码已经修好，也不是 Testnet runtime 审核。

现有 Testnet 地址不可升级，因此即使未来 `contracts-v2` 源码修复正确，也必须重新部署/迁移到新地址才能改变 runtime。S9 已明确：

```text
CODE_FIX_REQUIRES_REDEPLOYMENT = YES
BSC_TESTNET_RUNTIME_FIXED = NO
MAINNET = NO-GO
```

这一边界定义是正确的。

本轮我只使用：

* 上传的 S0–S9 文档作为计划证据；
* GitHub `contracts-v2` 当前源码作为实现可行性和依赖关系的辅助证据。

没有进行 RPC、Fork、广播、部署、签名或 Mainnet 判断。

---

# 2. Documents Received and Evidence Boundary

| 文档                   |  收到 | 完整读取 | 用途                    | 缺失影响                         |
| -------------------- | --: | ---: | --------------------- | ---------------------------- |
| S0                   | YES |  YES | 设计冻结                  | —                            |
| S1                   | YES |  YES | CostBasis             | —                            |
| S2                   | YES |  YES | Mixed Sell/Whitelist  | —                            |
| S3                   | YES |  YES | Staking Principal     | —                            |
| S4                   | YES |  YES | Reward/Pause          | —                            |
| S5                   | YES |  YES | Buyback               | —                            |
| S6                   | YES |  YES | Dividend              | —                            |
| S7                   | YES |  YES | Oracle                | —                            |
| S8                   | YES |  YES | Smart Account         | —                            |
| S9                   | YES |  YES | Final Gate            | —                            |
| README               |  NO |   NO | 总体规则/S0 前置            | **阻止本轮签发 S0 Gate**           |
| 00 Finding Baseline  |  NO |   NO | 9 Finding 权威定义        | **阻止 Finding baseline 独立确认** |
| 01 Master Prompt     |  NO |   NO | 执行治理                  | 流程完整性无法完全确认                  |
| 02 Review Workflow   |  NO |   NO | Review/M1/M2/M3/FINAL | 独立性和分类无法完全确认                 |
| 03 Evidence Template |  NO |   NO | Commit/测试/复审证据        | SHA、时间线、角色链无法完全确认            |

---

# 3. Plan Architecture Verdict

| 项目                             | Verdict                    | 结论                                              |
| ------------------------------ | -------------------------- | ----------------------------------------------- |
| Stage Size                     | CHANGES REQUIRED           | S0/S1/S2/S3/S5/S6/S7/S9合理；S4建议拆分；S8 FIX 路径建议拆分  |
| Stage Ordering                 | SAFE                       | S1→S2、S3→S4、M1/M2/M3位置总体正确                      |
| Dependencies                   | SAFE AFTER CLARIFICATION   | Staking position context、Whitelist 基线需先冻结       |
| Allowed/Forbidden Paths        | CHANGES REQUIRED           | 部署**执行**应禁止，但 compile-compatible script 修改需例外处理 |
| Economic Baseline Preservation | NOT_INDEPENDENTLY_VERIFIED | 阶段文档内部看起来保持固定参数，但权威基线文档缺失                       |
| Review Independence            | NOT_INDEPENDENTLY_VERIFIED | 02 缺失                                           |
| Evidence Chain                 | NOT_INDEPENDENTLY_VERIFIED | 03 缺失                                           |
| Code-Only Deployability Review | CHANGES REQUIRED           | 当前脚本属于 Forge 编译面                                |
| Redeployment Boundary          | SAFE AS WRITTEN            | 源码修复与已部署 runtime 明确分离                           |

---

# 4. P0 Plan Findings

```text
No confirmed PLAN-P0.
```

这不构成任何部署批准。

---

# 5. P1 Plan Findings

## PLAN-P1-01 — 阶段 Gate 允许在缺少编译成功证据时继续

**Severity:** PLAN-P1
**Type:** PLAN_DEFECT / SCOPE_ERROR
**Document:** S1、S3–S8、S9
**Section:** Stage Exit / Code Deployability

**Problem**

S1 明确允许：

```text
BUILD = PASS or NOT_RUN_WITH_BLOCKER
```

仍然进入 S2。S3 也允许关键集成测试 `NOT_RUN_WITH_BLOCKER` 后进入 S4，而后续多个阶段没有独立的 mandatory build Gate。 

**Evidence**

S1 会修改 `ICostBasisManager`，S2 直接依赖它；S3 会同时修改 Token、CostBasis、Staking 和 interface。

**Failure Scenario**

S1 修改 interface/struct 后没有真正编译，仍获 `S2_ALLOWED=YES`。S2 基于未编译的接口继续修改 Token/Router，导致问题跨阶段积累，到 M1 才发现整个分支无法编译。

**Impact**

破坏短阶段隔离，阶段 Commit 失去可审计性。

**Why Existing Plan Is Insufficient**

`NOT_RUN` 可以合理用于 fuzz/invariant，但不应该等价于“核心源码可不编译仍推进下一阶段”。

**Required Plan Correction**

每个 S1–S8 Implementation/Fix Commit 至少要求：

```text
CORE_SOLIDITY_BUILD = PASS
INTERFACE_IMPLEMENTATION_MATCH = PASS
NEXT_STAGE_ALLOWED = NO if compile fails
```

测试可因工具不可用记录 `NOT_RUN_WITH_BLOCKER`，但**编译 blocker 不能关闭阶段**。

**Affected Stages:** S1–S9、M1–M3
**Whether S0 Can Start Before Correction:** YES，但 S0 退出前应修正总体 Gate
**Whether Solidity Source Required To Confirm:** NO

---

## PLAN-P1-02 — Staking position CostBasis 没有冻结唯一权威 mutation path

**Severity:** PLAN-P1
**Type:** PLAN_AMBIGUITY
**Document:** S0、S3
**Section:** S0 §3.3 / S3 §3

S3 要求 `account + staking + positionId`，这是正确方向，但没有冻结 **positionId 如何安全穿过 Staking → Token → CostBasis**。

当前源码的 `systemTransfer()` 只携带：

```solidity
to
amount
TransferContext.Kind
```

没有 `positionId`。当前 `TransferContext` 虽然已有 `STAKING_DEPOSIT / PRINCIPAL_RETURN / REWARD`，也没有 position payload。

同时当前 CostBasis 用户 mutation 主要是 Token/Router 权限模型。

**Failure/Attack Scenario**

实现 Agent 可能选择：

1. Staking 直接修改 CostBasis；
2. Token hook 也同时修改；
3. positionId 通过可伪造 reason bytes 传入；
4. return 时只知道 account，错误消费另一个 position。

结果可能是 double accounting、跨 position 取成本或 CostBasis 伪造。

**Impact**

P1-STK-01 可能表面修复，实际引入新的本金 CostBasis 漏洞。

**Required Plan Correction**

S0 必须冻结**唯一权威 mutation path**。推荐：

```text
Staking determines positionId before transfer
→ authenticated typed Token staking context carries staking/account/positionId/kind
→ Token performs transfer
→ CostBasis mutation only through one authenticated path
→ no duplicate direct Staking + Token mutation
```

并明确 `PRINCIPAL_RETURN` 如何携带 positionId。

**Affected Stages:** S0、S3、S4、M2
**Whether S0 Can Start Before Correction:** YES；但不能 APPROVE S0 前遗留
**Whether Solidity Source Required To Confirm:** 部分；当前源码已证明现有 context 不携带 positionId

---

## PLAN-P1-03 — Staking 资金守恒规则仍缺少几个必须冻结的经济状态

**Severity:** PLAN-P1
**Type:** PLAN_AMBIGUITY
**Document:** S0、S3、S4
**Section:** Reward / Early Unstake / Invariants

S4 正确要求 forfeited reward：

```text
liability -= forfeitedReward
availableRewardReserve += forfeitedReward
```



但 S0 尚未完整冻结：

* Normal Unstake 是 auto-claim 还是保留 claim credit；
* Early Unstake 的 10% penalty Token 最终属于 `availableRewardReserve`、surplus 还是其他 bucket；
* `totalStaked == 0` 时允许存在的“已归属 liability”和禁止的“无人归属 liability”区别；
* reward index 舍入 dust 的确定归属。

当前源码实际把 early penalty 加入 `availableRewardReserve`，但该行为是否是权威业务基线，因为基线文件缺失，不能独立确认。

**Failure Scenario**

两个实现 Agent 对 penalty/reward credit 作不同理解，资金虽然没有直接丢失，却导致：

```text
actual balance != principal + reserve + liability + explicit surplus
```

或 normal exit 后 reward 永久无法领取。

**Required Plan Correction**

S0 增加明确状态恒等式，例如：

```text
stakingTokenBalance
= activePrincipal
+ availableRewardReserve
+ ownedAccruedRewardLiability
+ explicitSurplus
```

并逐项冻结 normal exit、early penalty、forfeiture 和 rounding dust 的状态迁移。

**Affected Stages:** S0、S3、S4、M2、S9
**Whether S0 Can Start Before Correction:** YES
**Whether Solidity Source Required To Confirm:** NO；但 penalty 基线需要基线文档确认

---

## PLAN-P1-04 — S8 FIX 路径的 registry/revoke/counterfactual 状态机不足以直接编码

**Severity:** PLAN-P1
**Type:** PLAN_AMBIGUITY
**Document:** S0、S8
**Section:** Contract Account Boundary

S8 已经正确意识到“不能简单删除 `code.length`”，也意识到 revoke 不能锁资产。

但还没有冻结一个可直接实现的状态机。

当前 Token 对未登记 contract sender/receiver 是全局拒绝。

**Failure Scenario A — Asset Lock**

Smart wallet 已有余额：

```text
APPROVED → Governance revoke
```

如果直接回到全局 `code.length` 禁止，wallet 将无法把已有 Token 转出或通过官方 Router 卖出。

**Failure Scenario B — Counterfactual Misregistration**

只按 address 预登记 counterfactual wallet，却没有绑定受信 factory/initCodeHash/codeHash，未来该地址的代码身份没有足够的链上约束。

**Failure Scenario C — Permission Escalation**

把 approved user contract 与 `systemAddress`/settlement/context allowlist 混用，会让智能钱包获得协议权限。

**Required Plan Correction**

S0 至少冻结：

```text
NONE
→ APPROVED
→ EXIT_ONLY / GRACE
→ REVOKED
```

并冻结：

* approvedUserContract 与 System/Pair/Settlement/Whitelist 完全正交；
* counterfactual registration 的授权主体；
* 是否绑定 trusted factory / initCodeHash / expected code identity；
* revoked wallet 的唯一安全退出路径；
* Direct Pair 仍永远 fail-closed。

如果不能冻结，S8 应选择：

```text
BLOCKED_DECISION
```

或由用户本人签署 `ACCEPTED_DEVIATION`。

**Affected Stages:** S0、S8、M3、S9
**Whether S0 Can Start Before Correction:** YES
**Whether Solidity Source Required To Confirm:** NO

---

# 6. P2 Plan Findings

## PLAN-P2-01 — proportional floor 与“拆分卖出不可降低税”之间缺少形式化规则

**Severity:** PLAN-P2
**Type:** PLAN_AMBIGUITY
**Document:** S0、S1、S2
**Section:** CostBasis rounding / split sell

S0/S1 指定 partial known consumption 使用 proportional floor，同时要求拆分不能降低税。 

问题是 repeated floor 会将舍入余数集中在剩余 position。

靠一句：

```text
允许明确的向上取整差但不得可盈利
```

不足以成为实现规范。

**Failure Scenario**

在接近 `TWAP == proportionalCost` 的税率边界，重复部分消费可能把若干 wei 成本留到最后一段 position，使同一经济仓位的分拆执行与一次执行在 4%/10% 分类上产生差异。

**Impact**

通常属于 rounding-level 风险，但分类跳跃是 6 个百分点，必须证明无法产生可盈利策略。

**Required Plan Correction**

S0 冻结一个可测试性质：

```text
For any equivalent sequence of transfers/sells:
aggregate known cost never increases;
rounding cannot make aggregate tax lower than the canonical unsplit result
beyond an explicitly bounded, non-profitable tolerance.
```

若单纯 proportional floor 无法证明，则引入 carry/remainder 或其他确定性方法。

**Affected Stages:** S0、S1、S2、M1
**Whether S0 Can Start Before Correction:** YES
**Whether Solidity Source Required To Confirm:** NO

---

## PLAN-P2-02 — `actualBalance = knownBalance + unknownBalance` 的适用账户范围不够精确

**Severity:** PLAN-P2
**Type:** PLAN_AMBIGUITY
**Document:** S0
**Section:** CB-INV-01

如果按字面套用所有账户，它不适用于：

* FeeVault；
* Router；
* Staking contract；
* Locker；
* Pair；
* 其他 System address。

这些地址并不应该拥有普通 user CostBasis ledger。

**Required Plan Correction**

改成类似：

```text
For every CostBasis-eligible liquid user account:
ERC20.balanceOf(account) == knownBalance(account) + unknownBalance(account)

Pair/System/Protocol custody accounts are excluded from user-ledger equality
and governed by their own conservation invariants.
```

Staking position lot 也不得计入账户 liquid ERC20 balance。

**Affected Stages:** S0、S1、S3、M1/M2
**Whether S0 Can Start Before Correction:** YES
**Whether Solidity Source Required To Confirm:** NO

---

## PLAN-P2-03 — Preview revision/quoteBlock 到底是“信息”还是“执行锁”没有冻结

**Severity:** PLAN-P2
**Type:** PLAN_AMBIGUITY
**Document:** S2
**Section:** Mixed Sell §3

当前 Router 的 execute 会在交易内重新执行 `_previewSell(msg.sender, tokenAmount)`，然后再 consume 和 settlement，因此“链下 preview”本身并不是执行权限。

S2 又要求：

```text
CostBasis revision/quote block 等执行约束
```

但没有定义 seller 是否必须提交 expectedRevision。

**Failure Scenario**

如果 revision 不校验，UI preview 到 execute 之间用户状态变化后可能得到不同税率；如果严格校验每个 revision，又可能制造大量无必要 stale-preview DoS。

**Required Plan Correction**

S0/S2 明确二选一：

```text
A. revision/quoteBlock only diagnostic;
   execute recomputes live state and caller limits economic outcome via
   deadline + minimumOut + maximumTax/maxSupport/maxBurn.

B. expectedRevision is explicit user-consent optimistic lock;
   mismatch reverts.
```

不要同时模糊使用两种语义。

**Affected Stages:** S0、S2、M1
**Whether S0 Can Start Before Correction:** YES
**Whether Solidity Source Required To Confirm:** NO

---

## PLAN-P2-04 — Whitelist 修复缺少 canonical source ownership

**Severity:** PLAN-P2
**Type:** SOURCE_CODE_VERIFICATION_REQUIRED
**Document:** S2
**Section:** Whitelist Fix

S2 要求：

```text
Trading Gate → Whitelist → Launch → Normal
```

并要求 whitelist buy/sell 0%。

但在我本轮读取的当前 `Pangu2Token`、`Pangu2TradeRouter` 中，没有看到与上述完整 whitelist/launch state machine 对应的实现；当前 FeeVault 确实会对 `credit(0)` revert。

由于你的 `4d336...` baseline 无法在当前 GitHub 历史中解析，我不能由此判定 Finding 错误。

**Required Plan Correction**

在 S0 明确记录：

```text
WHITELIST_CANONICAL_CONTRACT =
WHITELIST_STORAGE =
WHITELIST_ADMIN_ROLE =
TRADING_GATE_SOURCE =
LAUNCH_STATE_SOURCE =
ZERO_TAX_CALL_CHAIN =
```

如果目标 Commit 实际没有该逻辑，则先执行：

```text
SOURCE_CODE_VERIFICATION_REQUIRED
```

不得让 Implementation Agent自行发明 whitelist 架构。

**Affected Stages:** S0、S2、M1
**Whether S0 Can Start Before Correction:** YES
**Whether Solidity Source Required To Confirm:** YES

---

# 7. P3 Plan Findings

本轮没有需要提升为正式 `PLAN-P3` 的独立问题。

---

# 8. Stage-by-Stage Review

| 阶段    | 目标 | 范围       | 是否过大     | 依赖 | 测试/不变量     | 建议                                                                      |
| ----- | -- | -------- | -------- | -- | ---------- | ----------------------------------------------------------------------- |
| S0    | 正确 | 需补充      | 否        | 正确 | 需补充        | 增加 rounding、staking context、S8 state machine、whitelist canonical source |
| S1    | 正确 | 合理       | 否        | 正确 | 较强         | **Build 必须 PASS**，不能以 NOT_RUN 关闭                                        |
| S2    | 正确 | 基本合理     | 中等       | 正确 | 强          | whitelist source + revision semantics 先冻结                               |
| M1    | 正确 | 应全量      | —        | 正确 | 未验证        | 02 缺失，无法确认真实 Full Audit Prompt                                          |
| S3    | 正确 | 需细化      | 中等       | 正确 | 较强         | 冻结唯一 Staking→Token→CB mutation path                                     |
| S4    | 正确 | 过宽       | **是**    | 正确 | 强          | 建议拆 S4A Reward、S4B Pause                                                |
| M2    | 正确 | 应全量      | —        | 正确 | 未验证        | 放在 S4A/B 后正确                                                            |
| S5    | 正确 | 合理       | 否        | 正确 | 强          | 优先复用固定 Pair 的 Adapter quote                                             |
| S6    | 正确 | 合理       | 否        | 正确 | 强          | 保持 `> claimEnd`                                                         |
| S7    | 正确 | 合理       | 否        | 正确 | 较强         | 增加 long-gap/re-anchor 语义                                                |
| S8    | 正确 | FIX 路径偏大 | **条件性是** | 正确 | 强          | FIX 时拆 registry lifecycle / bypass regression                           |
| M3    | 正确 | 应全量      | —        | 正确 | 未验证        | S8 后做全量回归位置正确                                                           |
| S9    | 正确 | 合理       | 否        | 正确 | 强          | 加强 compile-surface 规则                                                   |
| FINAL | 正确 | 必须全量     | —        | 正确 | 必须绑定最终 SHA | FINAL fix 后必须重新全量审核，不能只看 diff                                           |

整体阶段顺序：

```text
S0
→ S1 → S2 → M1
→ S3 → S4A → S4B → M2
→ S5 → S6 → S7 → S8 → M3
→ S9 / FINAL
```

比当前版本更安全。

---

# 9. Technical Design Review

| 模块                        | Verdict                          | 核心判断                                                     |
| ------------------------- | -------------------------------- | -------------------------------------------------------- |
| CostBasis Dual Ledger     | **SAFE AFTER CLARIFICATION**     | 双账本方向正确；需解决 rounding + invariant scope                   |
| Mixed Sell Settlement     | **SAFE AFTER CLARIFICATION**     | 分 unknown/known 是正确修复；revision 语义需冻结                     |
| Whitelist Zero Tax        | **SOURCE VERIFICATION REQUIRED** | FeeVault `credit(0)`问题存在，但 canonical whitelist 路径未独立确认   |
| Staking Cost Migration    | **CHANGES REQUIRED**             | 缺 positionId authenticated context/mutation authority    |
| Staking Reward/Vesting    | **CHANGES REQUIRED**             | per-position 正确，但 conservation/normal-exit outcome 未完全冻结 |
| Staking Pause             | **SAFE AFTER CLARIFICATION**     | principal exit + `rate=0`策略正确；角色接线需解决                    |
| Support Buyback Preflight | **SAFE AFTER CLARIFICATION**     | 固定 0.01 + curve/TWAP 组合正确                                |
| Dividend Finality         | **SAFE AS WRITTEN**              | `> claimEnd` + no claims + terminal 状态方向正确               |
| Oracle Rollover           | **SAFE AFTER CLARIFICATION**     | modular arithmetic 正确；异常/长间隔恢复规则应明确                      |
| Contract Account Boundary | **CHANGES REQUIRED**             | Registry方向可行，但 revoke/counterfactual 需状态机                |

### SupportPool 特别结论

当前 `PancakeV2Adapter` 已有固定 canonical pair 的：

```solidity
quoteExactInput(tokenIn, tokenOut, amountIn)
```

并且 `_validatePair()` 限定只能 Token/WBNB 双向，内部使用 Router `getAmountsOut`。因此 S5 **优先复用这个固定 Pair quote** 比增加任意 pair/path quote API 更安全。

当前 SupportPool 的 `canExecuteBuyback()` 只验证 TWAP，没有把真实 curve output 纳入 preflight，而且 `canExecuteBuyback()` 和 `buyback()` 各自重复逻辑，所以 S5 修复目标本身成立。

### Oracle 特别结论

当前 GitHub `main` 中的 Oracle 已经使用：

```solidity
unchecked { elapsed32 = ts - anchor.timestamp; }
```

累计价格 delta 同样处于 unchecked modular arithmetic。

所以：

```text
P3-ORC-01 against current main
= appears already partially/fully addressed
```

但**不能据此关闭原 Finding**，因为计划指定的 `4d336...` 和 deployed `3ef50...` 无法重建。本项仍应在目标 Implementation Commit 上重新审核。

---

# 10. Review and Adjudication Workflow Verdict

```text
Architecture: SOUND
Independent Closure Evidence: NOT_INDEPENDENTLY_VERIFIED
Overall: CHANGES_REQUIRED
```

正确之处：

```text
Pre-Fix Review
→ Adjudication
→ only CONFIRMED fixes
→ Post-Fix Independent Review
→ Adjudication
→ Fix only confirmed new findings
→ Re-Review
```

这个结构可以有效阻止“错误 Finding 被实现 Agent 直接实施”。

但目前无法确认：

* Implementation/Reviewer/Adjudicator 是否强制不同 Agent/session；
* `CONFIRMED / REJECTED_WITH_EVIDENCE / DUPLICATE / NEEDS_MORE_EVIDENCE / SCOPE_EXPANSION_REQUIRED` 是否在 02 中有严格定义；
* 是否要求完整 40 字符 SHA；
* 是否记录 reviewer input commit、fix commit、复审 commit；
* 是否明确 `test source exists != test PASS`；
* M1/M2/M3/FINAL 是否真的强制重新逐行读 `contracts-v2/src/**`。

因为对应的 `02`、`03` 没有上传。

---

# 11. Required Plan Amendments

优先修改顺序：

### A. `S0_DESIGN_AND_INVARIANT_FREEZE.md`

增加以下冻结项：

```text
1. CostBasis invariant只适用于 CostBasis-eligible liquid user accounts。

2. Freeze exact split-rounding safety property.
   Repeated partial consumption MUST NOT produce economically lower aggregate tax
   than canonical equivalent execution beyond an explicitly proved bound.

3. Freeze exactly one Staking CostBasis mutation authority.
   Position context MUST authenticate:
   stakingContract + account + positionId + operationKind.

4. Freeze Staking accounting:
   normal-exit reward disposition;
   early penalty destination;
   forfeited reward destination;
   owned liability at totalStaked==0;
   rounding dust/surplus.

5. Freeze approved-user-contract lifecycle and counterfactual authorization.

6. Identify canonical Trading Gate / Whitelist / Launch storage and roles.

7. Freeze Preview revision semantics:
   advisory live-recompute OR explicit optimistic lock.
```

### B. `S1...S8 Stage Exit`

统一加入：

```text
IMPLEMENTATION_COMMIT_SHA = full 40-char SHA
CORE_BUILD = PASS
INTERFACE_MATCH = PASS
COMPILE_ERRORS = 0
NEXT_STAGE_ALLOWED = NO if CORE_BUILD != PASS
```

### C. `S4`

建议正式拆成：

```text
S4A — Per-position Reward / Liability / Forfeiture
S4B — Staking Pause / PAUSER / UNPAUSER / emergency rate=0
M2 — after S4B
```

### D. `S8`

FIX 路径建议：

```text
S8A — Approved User Contract Registry + revoke/exit lifecycle
S8B — Direct Pair / Router / Context bypass regression
M3 — after S8B
```

### E. 代码阶段与部署脚本边界

这里需要修改当前“绝对禁止修改 deployment script”的表述。

`contracts-v2/foundry.toml` 将：

```text
script = "script"
```

纳入 Foundry 工程。

而当前 `DeployPangu2.s.sol` 直接实例化：

```solidity
new Pangu2Token(...)
new Pangu2Staking(...)
new Pangu2TradeRouter(...)
...
```

因此如果 S0 批准 constructor/interface 变化，不同步脚本签名，完整 `forge build` 很可能无法通过。

推荐规则：

```text
Deployment execution remains OUT_OF_SCOPE.

Read-only inspection of deployment scripts is ALLOWED for compile compatibility.

If an approved Solidity ABI/constructor change necessarily breaks compilation,
a narrowly scoped COMPILE_COMPATIBILITY patch to deployment scripts is allowed,
ONLY to update Solidity types/signatures/constructor arguments.

Forbidden in that patch:
- RPC
- env value decisions
- addresses
- keys
- broadcasting
- chain execution
- role-policy changes
- migration logic
- deployment approval
```

这是“代码编译兼容”，不是“部署审核”。

---

# 12. Verified Strengths

以下设计是正确的，不建议无理由重做：

* S0 在 Solidity 前进行设计冻结。
* S1 与 S2 分离是正确的：ledger 和 settlement 是不同风险层。
* S1 明确不是 deployable candidate。
* `UNKNOWN` 不再污染全部 KNOWN 的双账本方向正确。
* Mixed sell 不允许 1 wei unknown 把全仓升级成 10%。
* CostBasis consume 与 settlement/swap 应事务原子化。
* Staking 使用 per-position reward 方向正确。
* Early exit forfeited reward 返回 reserve 的方向正确。
* Staking Pause 仍允许本金退出、同时允许 `setRewardRate(0)`，方向正确。
* SupportPool 固定 `0.01 BNB`，不通过动态缩量“假修复”。
* Dividend published epoch 默认禁止 pre-start cancel。
* Oracle 不削弱 1800s/300bps/min reserves。
* S8 不允许 Agent 自己签署 `ACCEPTED_DEVIATION`。
* M1/M2/M3 分别位于高风险簇之后，位置合理。
* S9 重新播放全部 9 个原 Finding，而不是只看最终 diff。
* `APPROVED_CODE_ONLY` 与实际部署批准明确隔离。
* Testnet runtime 不会被源码 Commit“自动修复”。

---

# 13. Missing Source-Level Verification

以下必须继续标记：

```text
SOURCE_CODE_VERIFICATION_REQUIRED
```

1. `3ef50b6...` 的实际 deployed source 与当前 GitHub repo 的精确关系。
2. `4d33669...` 的完整源码快照。
3. P2-TAX-01 对应的 whitelist/trading-gate canonical 实现。
4. 双账本改造后所有 legacy `positionOf/NONE/KNOWN/UNKNOWN` 消费方。
5. Staking position context 最终 ABI。
6. S8 smart wallet 最终 registry/state machine。
7. S1–S9 每个未来 Implementation/Fix Commit 的真实 Build/Test 结果。
8. M1/M2/M3/FINAL 对所有 `contracts-v2/src/**` 的逐行审核。
9. 所有 constructor/interface 变化后的完整代码编译。
10. 实际 Testnet runtime、角色、RPC 和迁移结果——这些仍属于后续阶段，本轮不审核。

需要特别强调：本轮我读取了 CostBasis、Token、Router、Staking、SupportPool、Dividend、Oracle、Adapter、FeeVault、TransferContext、Foundry 配置和部署脚本等关键源码来判断方案可执行性，但**没有把这次工作伪装成 FINAL 全量 Solidity 安全审核**。

---

# 14. Final Answers

| 问题                               | 最终回答                                                                                                    |
| -------------------------------- | ------------------------------------------------------------------------------------------------------- |
| 1. 这套方案能否安全开始 S0？                | **NO — 当前审核包尚不能签发 S0 Gate。** README 和 00 Finding Baseline 是 S0 自身前置条件且未提供。补齐后，S0 是正确的下一步。               |
| 2. S0 设计目标是否充分？                  | **方向充分，但交付项需补充。** 重点补 position context、rounding、staking conservation、S8 state machine、whitelist source。 |
| 3. S1–S9 顺序是否合理？                 | **YES，总体合理。**                                                                                           |
| 4. 是否有阶段应继续拆分？                   | **YES。S4 建议必须拆 S4A/S4B；S8 若选择 FIX，建议拆 S8A/S8B。**                                                        |
| 5. CostBasis 双账本方向是否安全？          | **YES AFTER CLARIFICATION。** 比全仓 UNKNOWN 污染模型明显更安全。                                                     |
| 6. Staking per-position 方向是否安全？  | **YES AFTER ARCHITECTURE FREEZE。** positionId context 和唯一 mutation authority 必须先解决。                     |
| 7. Pre-Fix/Post-Fix 审核与校对闭环是否充分？ | **概念上充分，但证据上 NOT_INDEPENDENTLY_VERIFIED。** 需读取 02/03 后才能批准。                                             |
| 8. M1/M2/M3/FINAL 全量审核是否放置正确？    | **YES。** M1 after S2、M2 after S4、M3 after S8、FINAL after all fixes 的位置正确。                               |
| 9. 是否存在违反已部署经济基线的计划？             | **本轮没有确认到。** 但由于基线文档缺失，只能标 `NOT_INDEPENDENTLY_VERIFIED`。                                                |
| 10. 是否错误把代码修复描述为测试网已修复？          | **NO。** S9 明确 `BSC_TESTNET_RUNTIME_FIXED = NO`。                                                         |
| 11. 是否可以开始修改 Solidity？           | **NO。** 必须先完成并独立批准 S0，再完成 Review Adjudication。                                                          |
| 12. 是否授予部署或 Mainnet 批准？          | **NO。**                                                                                                 |

最终状态：

```text
Plan Review Verdict: CHANGES_REQUIRED

S0_DESIGN_STAGE_DIRECTION: CORRECT
S0_GATE_APPROVAL: NOT_GRANTED_YET

Solidity Implementation Allowed: NO

Required Before S0 Approval:
1. Provide README.md
2. Provide 00_AUDIT_FINDINGS_BASELINE.md
3. Provide 01_MASTER_EXECUTION_PROMPT.md
4. Provide 02_REVIEW_WORKFLOW_AND_PROMPTS.md
5. Provide 03_STAGE_EVIDENCE_TEMPLATE.md
6. Incorporate PLAN-P1/P2 amendments above
7. Independently re-review the amended S0 input package

Deployment Approval = NOT_GRANTED
Mainnet = NO-GO
```
