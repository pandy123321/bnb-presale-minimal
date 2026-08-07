# S8B — 合约账户与 Pair/Router/TransferContext 防绕过回归

```text
Stage ID: PANGU2-V2-S8B
Findings: P3-TKN-01 (part 2/2)
Prerequisite: S8A APPROVED_CODE_ONLY or USER-SIGNED ACCEPTED_DEVIATION
Macro Gate: M3 PRIORITY_FULL_AUDIT REQUIRED
```

## 1. 目标

独立验证 S8A 的 registry/lifecycle 没有削弱 Launch Protection、直接 Pair 禁令、Router settlement、TransferContext 或角色边界。若 S8A 采用偏差路径，本阶段验证保留的 EOA-only 防线没有因前序阶段回归。

## 2. Allowed Paths

```text
contracts-v2/src/Pangu2Token.sol（只修复本阶段确认的 bypass）
contracts-v2/src/Pangu2TradeRouter.sol（只修复本阶段确认的 bypass）
contracts-v2/src/libraries/TransferContext.sol（只修复本阶段确认的 bypass）
contracts-v2/src/interfaces/IPangu2Token.sol
contracts-v2/test/*ContractAccount*.t.sol
contracts-v2/test/*TransferContext*.t.sol
contracts-v2/test/*Launch*.t.sol
contracts-v2/test/*TradeRouter*.t.sol
contracts-v2/test/*Invariant*.t.sol
remediation/evidence/S8B_*.md
```

不得增加任意 target/path/call，不能把 approved user contract 变成 system address。

## 3. 必须验证的攻击路径

- approved/EXIT_ONLY 合约不能直接向 Pair 转账或直接调用 Pair swap 绕过 settle；
- 未登记 CREATE2 Pair、恶意 Router、伪 Safe、callback receiver 不能绕过税费；
- approved contract 不能调用 `systemTransfer`、`settleBuy/settleSell`、CostBasis hooks 或建立 TransferContext；
- approved contract 买卖使用自身真实 buyer/seller 参与 `trading gate → 独立 feeWhitelist → launch → normal` 判断；approved-user 身份本身不提供免税，只有 Governance 对 Token whitelist 的独立显式授权才提供既有 0% 税属性；
- Pair/System/approved 状态不能重叠；
- Registry revoke/grace 不得被用作临时免税或清除 CostBasis；
- 用户向 counterfactual address 转账、部署匹配/不匹配代码后的行为；
- `msg.sender`、from、to、context operator 不可混淆；
- Pause、Trading Gate 和 Launch 15 分钟窗口仍生效；
- S1/S2 mixed CostBasis 与合约账户行为一致。

## 4. 测试要求

- 真实 Token/Router/CostBasis 集成，不使用空 hook Mock 关闭 Finding；
- APPROVED、EXIT_ONLY、REVOKED 与 EOA 的差分测试；
- 直接 Pair、其他 Router、delegate/callback 组合攻击；
- whitelist、launch、paused、pre-open 组合矩阵；
- Fuzz：角色/状态、transfer direction、mixed lot、pair/system 地址；
- Invariant：只有 Settlement 路径能完成用户交易；approved user contract 永远没有协议权限。

## 5. M3 优先全量代码审核

S8B 复审批准后逐行审核全部 `contracts-v2/src/**`，覆盖：

- S5 Support curve preflight 与 FeeVault/Adapter/Locker；
- S6 Epoch finality 与 FeeVault funding/CostBasis claim；
- S7 Oracle rollover/long-gap 与 Router/FeeVault/Support consumers；
- S8A/S8B contract lifecycle 与 Token/Router/Pair 防绕过；
- M1/M2 已关闭 Finding 是否出现回归；
- 全部权限、Pause、事件、ABI 和冻结经济参数；
- mandatory Build、interface match 和代码层可部署性；
- 不审核实际部署流程、地址、RPC、广播或迁移执行。

## 6. 退出条件

```text
P3-TKN-01 = CLOSED_CODE_ONLY or USER-SIGNED ACCEPTED_DEVIATION
DIRECT_PAIR_BYPASS = NOT_FOUND
IMPLEMENTATION_COMMIT_SHA = full 40-char SHA
CORE_SOLIDITY_BUILD = PASS
INTERFACE_IMPLEMENTATION_MATCH = PASS
COMPILE_ERRORS = 0
STAGE_REVIEW = APPROVED_CODE_ONLY
M3_PRIORITY_FULL_AUDIT = APPROVED_CODE_ONLY
M3_CODE_DEPLOYABILITY = YES
M3_BASELINE_COMPLIANCE = PASS
S9_ALLOWED = YES
DEPLOYMENT_OR_RUNTIME_APPROVAL = NOT_GRANTED
```
