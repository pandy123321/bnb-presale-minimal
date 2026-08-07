# S2 — Token/Router Mixed Sell 结算与 Whitelist 零税修复

```text
Stage ID: PANGU2-V2-S2
Findings: P1-CB-01 (part 2/2), P2-TAX-01
Prerequisite: S1 APPROVED_CODE_ONLY
Macro Gate: M1 PRIORITY_FULL_AUDIT REQUIRED
```

## 1. 目标

把 S1 双账本接入 Preview、Consume 和实际 Token settlement；同一笔 mixed sell 对 unknown、known-profit、known-nonprofit 分项计税。同时修复 whitelist 零税仍调用 `FeeVault.credit(0)` 的执行回滚。

## 2. Allowed Paths

```text
contracts-v2/src/Pangu2Token.sol
contracts-v2/src/Pangu2TradeRouter.sol
contracts-v2/src/CostBasisManager.sol
contracts-v2/src/interfaces/IPangu2Token.sol
contracts-v2/src/interfaces/IPangu2TradeRouter.sol
contracts-v2/src/interfaces/ICostBasisManager.sol
contracts-v2/src/libraries/CostMath.sol（仅必要时）
contracts-v2/test/*TradeRouter*.t.sol
contracts-v2/test/*Tax*.t.sol
contracts-v2/test/*CostBasis*.t.sol
contracts-v2/test/*Invariant*.t.sol
remediation/evidence/S2_*.md
```

Forbidden：Staking、SupportPool、Dividend、Oracle、部署脚本、应用代码。

## 3. Mixed Sell 实现要求

1. Preview 必须返回至少：
   - unknown sold；
   - known sold；
   - proportional known cost；
   - known TWAP quote；
   - support amount；
   - burn amount；
   - swapTokens；
   - S0 已冻结语义的 CostBasis revision/quote constraint 或 diagnostic 字段。
2. UNKNOWN 部分固定 10% 路径；KNOWN 部分只用其自身 quote 与 proportional cost 比较。
3. 不允许 1 wei unknown 把全部卖出量变成 10%。
4. 不允许 mixed position 把 unknown quote 与 known cost 比较从而降低税率。
5. `support + burn + swapTokens == sellAmount`，每个组成部分由 `FullMath.mulDiv` 或明确舍入规则计算。
6. Preview 和 Execute 使用同一 seller，而不是 `msg.sender`/recipient 混淆。
7. Execute 必须在当前交易中重新验证 CostBasis 和 Oracle；前端 preview 不能作为可信税额输入。
8. quote block、deadline、minimumOut 和 maximum 5 分钟窗口继续有效。
9. CostBasis consume 与 Token transfer/settlement 必须原子化；任何 Adapter/FeeVault/BNB payout 失败都回滚成本消费。
10. 10% 路径只 swap 90%，1% burn 和 9% support 各扣一次。
11. 必须严格实现 S0 选择的 Preview 语义：diagnostic live-recompute 路径必须有显式 maximum protocol deduction；optimistic-lock 路径必须校验 expected revision/quote constraint。

## 4. Whitelist 修复要求

1. 继续保持优先级：Trading Gate → Whitelist → Launch → Normal。
2. Whitelist buy/sell 税费为 0，但仍必须通过 Trading Gate、Pause、deadline、minimumOut、Pair/System 和 Adapter 安全检查。
3. 当 tax/support/burn 为 0 时，Token 跳过对应零额 transfer 和 `FeeVault.credit()` 调用。
4. FeeVault 不需要为了该修复接受任意异常零额记账；优先在 Token 调用点跳过。
5. Preview 与真实 buy/sell 都必须覆盖 whitelist。
6. 重新核验并记录 canonical source：whitelist/trading/launch 存储和 rate resolver 均来自目标 Commit 的 Pangu2Token；若不一致停止并标记 `SOURCE_CODE_VERIFICATION_REQUIRED`。

## 5. 测试要求

- 1 wei unknown + 大额 known 的 mixed sell；只对 1 wei 部分使用 UNKNOWN 税率。
- mixed known profit/nonprofit 边界：TWAP 等于、低于、高于 proportional cost。
- 拆分 sell 与一次 sell 的成本/税费一致性，允许明确的向上取整差但不得可盈利。
- whitelist buy/sell 真实经过 Router、Token、FeeVault，不允许只测 preview。
- whitelist 在 pre-open、paused、launch、deadline 过期、minOut 不足时仍 fail-closed。
- 4%、10%、30%、0% 的完整 Tax Matrix。
- Fuzz：mixed balances、Oracle quote、部分 sell。
- Invariant：settlement 守恒、CostBasis consume 不增加成本、Preview/Execute 组件一致。

## 6. M1 优先全量代码审核

阶段复审批准后，立即使用 `02_REVIEW_WORKFLOW_AND_PROMPTS.md` 的 PRIORITY_FULL_AUDIT 提示词执行 M1。

M1 必须逐行阅读全部 `contracts-v2/src/**`，重点检查：

- 新 CostBasis 接口对 Dividend、Staking、Locker、LP 遗留路径的影响；
- Token `_update` Context 和 direct Pair 防绕过；
- Router buy/sell、refund、approval、BNB payout 和重入；
- FeeVault bucket credit 是否仍守恒；
- 税率优先级和全部冻结参数；
- ABI/接口/构造关系的代码层可部署性。

M1 不审核本地部署脚本执行、RPC 或广播。

## 7. 退出条件

```text
P1-CB-01 = CLOSED_CODE_ONLY
P2-TAX-01 = CLOSED_CODE_ONLY
STAGE_REVIEW = APPROVED_CODE_ONLY
M1_PRIORITY_FULL_AUDIT = APPROVED_CODE_ONLY
M1_BASELINE_COMPLIANCE = PASS
M1_CODE_DEPLOYABILITY = YES
IMPLEMENTATION_COMMIT_SHA = full 40-char SHA
CORE_SOLIDITY_BUILD = PASS
INTERFACE_IMPLEMENTATION_MATCH = PASS
COMPILE_ERRORS = 0
S3_ALLOWED = YES
DEPLOYMENT_OR_RUNTIME_APPROVAL = NOT_GRANTED
MAINNET = NO-GO
```
