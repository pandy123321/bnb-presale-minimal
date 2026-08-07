# S8A — 合约账户 Registry、撤销和安全退出生命周期

```text
Stage ID: PANGU2-V2-S8A
Findings: P3-TKN-01 (part 1/2)
Prerequisite: S7 APPROVED_CODE_ONLY
Decision: FIX or USER-SIGNED ACCEPTED_DEVIATION
Macro Gate: none; M3 occurs after S8B
```

## 1. 目标

如果 S0 批准智能钱包兼容修复，本阶段实现 approved user contract 的独立 registry 和不锁资产的撤销生命周期。若用户选择保留 EOA-only，则本阶段只记录签署的 `ACCEPTED_DEVIATION`，Agent不能代签。

本阶段不完成 Direct Pair/Router/Context 的全量攻击回归；该工作由 S8B 隔离执行。

## 2. Allowed Paths

FIX 路径：

```text
contracts-v2/src/Pangu2Token.sol
contracts-v2/src/interfaces/IPangu2Token.sol
contracts-v2/test/*ContractAccount*.t.sol
contracts-v2/test/*Launch*.t.sol（仅 registry 生命周期必要回归）
remediation/evidence/S8A_*.md
```

偏差路径：

```text
remediation/evidence/S8A_ACCEPTED_DEVIATION.md
```

## 3. 生命周期

FIX 路径必须实现 S0 冻结的独立状态机：

```text
NONE → APPROVED → EXIT_ONLY/GRACE → REVOKED
```

规则：

1. `APPROVED` 合约按普通用户参与 transfer/buy/sell、税费和 CostBasis；不获得协议权限。
2. Governance 撤销时先进入 `EXIT_ONLY/GRACE`，不得直接锁死已有 Token。
3. EXIT_ONLY 允许转出和通过官方 Router 卖出现有余额；禁止普通接收和买入新增余额。
4. 余额归零且宽限条件满足后才进入 REVOKED。
5. 状态转换不可跳过、重复或回退；每次转换发出包含 account、old/new state、operator 的事件。
6. approved-user registry 与 `feeWhitelist` 是独立治理属性：approved-user 不自动免税，fee whitelist 也不自动取得 approved-user 身份；只有 `GOVERNANCE_ROLE` 的独立显式 whitelist 操作才允许二者重叠。
7. approved user contract mapping 与以下协议身份必须互斥：
   - System Address；
   - Pair；
   - Settlement Role；
   - Liquidity Manager；
   - TransferContext allowlist；
8. 已经属于上述协议身份的地址不能登记为普通 user contract；普通 user contract 也不能因此调用 settle/systemTransfer/hook。

## 4. Counterfactual 授权

必须按 S0 冻结结果实现：

- 明确只有哪个 Governance/Registry Role 可预登记；
- 绑定 trusted factory、initCodeHash、expected runtime codehash 或 S0 批准的等价身份；
- 部署后验证实际 code identity，不匹配时不得进入 APPROVED；
- 未部署地址不能利用预登记身份成为未来 Pair/Router 绕过入口；
- 不得提供 permissionless 任意地址自注册。

如果这些条件无法在当前范围内安全实现，停止并输出 `BLOCKED_DECISION`，不得用一个只按 address 的永久 allowlist 代替。

## 5. 测试要求

- NONE→APPROVED→EXIT_ONLY→REVOKED 完整状态机；
- APPROVED 可收、转、买、卖，按普通用户计税和记 CostBasis；
- EXIT_ONLY 不能接收/买入，但能转出/官方卖出直到余额归零；
- Governance 不能让有余额合约直接 REVOKED；
- Pair/System/Settlement/LiquidityManager/TransferContext 地址不能登记；feeWhitelist 仅能通过独立 Governance 操作显式重叠，且不改变 approved-user 生命周期或协议权限；
- counterfactual identity 匹配和不匹配；
- 未授权调用、重复转换、零地址；
- 事件完整性；
- Fuzz：状态、余额、code deployment 时序。

## 6. 退出条件

FIX 路径：

```text
P3-TKN-01_LIFECYCLE = CLOSED_CODE_ONLY
IMPLEMENTATION_COMMIT_SHA = full 40-char SHA
CORE_SOLIDITY_BUILD = PASS
INTERFACE_IMPLEMENTATION_MATCH = PASS
COMPILE_ERRORS = 0
INDEPENDENT_REVIEW = APPROVED_CODE_ONLY
REVIEW_VERDICT_CONFIRMED = YES
S8B_ALLOWED = YES
```

偏差路径：

```text
P3-TKN-01 = ACCEPTED_DEVIATION
USER_APPROVAL_EVIDENCE = PRESENT
SMART_WALLET_SUPPORT = NO
COUNTERFACTUAL_LOCK_WARNING = DOCUMENTED
CODE_COMMIT_SHA = full 40-char SHA of last approved code commit
CORE_SOLIDITY_BUILD = PASS
INTERFACE_IMPLEMENTATION_MATCH = PASS
COMPILE_ERRORS = 0
INDEPENDENT_REVIEW = APPROVED_CODE_ONLY or ACCEPTED_DEVIATION_VERIFIED
REVIEW_VERDICT_CONFIRMED = YES
S8B_ALLOWED = YES
```

无用户批准时不得使用偏差路径。
