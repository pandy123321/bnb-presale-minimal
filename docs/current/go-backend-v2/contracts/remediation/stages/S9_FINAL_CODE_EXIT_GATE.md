# S9 — PANGU2 V2 最终代码退出门

```text
Stage ID: PANGU2-V2-S9
Type: FINAL_CODE_GATE
Prerequisite: M1 + M2 + M3 APPROVED_CODE_ONLY
New Features: FORBIDDEN
Deployment/RPC/Fork: OUT_OF_SCOPE
Mainnet: NO-GO
```

## 1. 目标

对修复后的完整 `contracts-v2/src/**` 做最终代码级闭环：确认所有原 Finding 已关闭、没有跨阶段回归、经济基线未变化，并判断未来候选代码是否具备进入“独立部署/迁移规划阶段”的资格。

本阶段不能授予实际部署批准。

## 2. Allowed Paths

默认只允许：

```text
contracts-v2/src/**（仅修复最终审核 CONFIRMED Finding）
contracts-v2/test/**
docs/current/go-backend-v2/contracts/remediation/evidence/S9_*.md
```

禁止修改广播、应用、Backend、数据库、V3 `contracts/src/**` 或经济基线文档。部署脚本默认只读；若 approved ABI/constructor 改动导致完整 Build 仅因脚本签名不兼容失败，只能按 README 的 `COMPILE_COMPATIBILITY_EXCEPTION` 单独申请、单独 Commit 和单独审核。不得把该例外扩展为部署执行审核。

## 3. 最终静态审核范围

必须逐行阅读：

```text
contracts-v2/src/Pangu2Token.sol
contracts-v2/src/Pangu2TradeRouter.sol
contracts-v2/src/CostBasisManager.sol
contracts-v2/src/FeeVault.sol
contracts-v2/src/SupportPool.sol
contracts-v2/src/BuybackLocker.sol
contracts-v2/src/DividendDistributor.sol
contracts-v2/src/Pangu2Staking.sol
contracts-v2/src/GovernanceAdapter.sol
contracts-v2/src/adapters/PancakeV2Adapter.sol
contracts-v2/src/oracle/PancakeV2TwapOracle.sol
contracts-v2/src/interfaces/**
contracts-v2/src/libraries/**
```

必须重新扫描：

- `tx.origin`、`delegatecall`、`selfdestruct`、Proxy/upgrade、硬编码秘密；
- 所有 external/public 权限；
- Reentrancy、CEI 和低级调用；
- SafeERC20、FullMath、downcast、舍入；
- TransferContext、Epoch、Staking position、Oracle 状态机；
- Pause/Unpause 分离；
- 构造、零地址、code check、immutable 和一次性配置；
- 事件和链上溯源字段；
- Rescue/withdraw/任意 target/selector；
- ABI 和 interface 实现一致性。

## 4. 原 Finding 重放

逐条重放并输出证据：

```text
P1-CB-01 UNKNOWN dust
P1-STK-01 staking cost return/reward
P1-STK-02 claim-before-early-exit
P2-TAX-01 whitelist zero credit
P2-STK-03 forfeited reward reserve
P2-BBK-01 buyback price impact
P2-DIV-01 pre-start cancel
P3-ORC-01 uint32 rollover
P3-TKN-01 smart wallet/counterfactual boundary
```

每项只能是：

```text
CLOSED_CODE_ONLY
STILL_OPEN
REGRESSION_FOUND
ACCEPTED_DEVIATION（仅 P3 且有用户证据）
```

## 5. 跨合约资金流

最终审核必须对以下资金流做数量和状态守恒检查：

### Buy

```text
User BNB → Router → Adapter/Pair → gross Token
→ Token settlement → Dividend fee → FeeVault → net Token → CostBasis lots
```

### Sell

```text
User known/unknown lots → CostBasis consume
→ support/burn/swapTokens → Adapter/Pair → BNB payout
```

### Support

```text
Support tax → FeeVault support bucket → conversion
→ SupportPool → fixed buyback preflight → Adapter → Locker
```

### Dividend

```text
Dividend bucket → fund → commitment → publish
→ claim → zero-cost lot → close/cancel-after-end → carry
```

### Staking

```text
Liquid lots → position lots → reward accrual
→ normal exit / early penalty+forfeiture → liquid lots
```

## 6. 最终代码验证建议

如果环境可用，应运行并记录绑定最终 Commit 的：

- `forge fmt --check`；
- `forge build`；
- 全部 Unit/Regression；
- Fuzz，安全关键目标建议至少 10,000 runs；
- Invariant，按合理深度和 runs 记录配置；
- 合约大小、ABI/interface 一致性和静态分析。

本阶段仍禁止 Fork、RPC、Anvil、部署和广播。没有运行的项目必须为 `NOT_RUN`。

最终 `CORE_SOLIDITY_BUILD` 不允许为 `NOT_RUN`。完整 Build 必须覆盖 Foundry compile surface，并把 src/interface 实现不匹配和 script compile compatibility 与实际部署逻辑明确分开。

## 7. 代码层可部署性

`CODE_DEPLOYABILITY=YES` 只在以下条件全部满足时给出：

- 全部实现满足接口；
- 构造参数、immutable 和一次配置关系无循环锁死；
- 新旧 ABI 变化完整记录；
- 合约大小和编译器目标没有代码级 blocker；
- 新地址图和必须重部署范围已列出；
- 没有未关闭 P0/P1/P2；
- P3 要么关闭，要么有用户接受证据；
- Build/Test 证据真实绑定最终 Commit，或未运行项明确导致 `UNKNOWN`。

它不代表部署脚本、链上角色、RPC、测试网或 Mainnet 已验证。

## 8. 最终审核和校对

1. Implementation Agent只整理必要代码和证据，不新增功能。
2. Priority Full Audit Agent执行 FINAL 全量审核。
3. Review Adjudication Agent校对每条 Finding 和最终 Verdict。
4. 只修复校对为 CONFIRMED 的最终问题。
5. Fix Commit 后重新执行 FINAL 全量审核和校对。

## 9. 退出条件

```text
FINAL_VERDICT = APPROVED_CODE_ONLY
ORIGINAL_P0_OPEN = 0
ORIGINAL_P1_OPEN = 0
ORIGINAL_P2_OPEN = 0
NEW_P0_P1_P2_OPEN = 0
BASELINE_COMPLIANCE = PASS
CODE_DEPLOYABILITY = YES
CORE_SOLIDITY_BUILD = PASS
INTERFACE_IMPLEMENTATION_MATCH = PASS
COMPILE_ERRORS = 0
INDEPENDENT_REVIEW = APPROVED_CODE_ONLY
REVIEW_VERDICT_CONFIRMED = YES
CODE_FIX_REQUIRES_REDEPLOYMENT = YES
READY_FOR_SEPARATE_MIGRATION_AND_DEPLOYMENT_PLANNING = YES
BSC_TESTNET_RUNTIME_FIXED = NO
MAINNET = NO-GO
```

任何一项不满足时，输出 `CHANGES_REQUIRED` 或 `BLOCKED`，不得降低 Gate。
