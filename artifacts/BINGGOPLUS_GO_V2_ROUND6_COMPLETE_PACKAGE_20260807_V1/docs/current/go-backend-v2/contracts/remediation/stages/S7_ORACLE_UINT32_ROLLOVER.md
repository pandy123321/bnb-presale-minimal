# S7 — Pancake V2 Oracle uint32 时间回绕

```text
Stage ID: PANGU2-V2-S7
Findings: P3-ORC-01
Prerequisite: S6 APPROVED_CODE_ONLY
Macro Gate: none
```

## 1. 目标

按照 Pancake V2 累计价格模型的模运算语义处理 uint32 timestamp 回绕，同时保持窗口、最低储备、stale 和 spot/TWAP deviation 全部 fail-closed。

## 2. Allowed Paths

```text
contracts-v2/src/oracle/PancakeV2TwapOracle.sol
contracts-v2/src/interfaces/IPangu2TwapOracle.sol
contracts-v2/src/libraries/*Oracle*.sol（仅必要时）
contracts-v2/test/*Oracle*.t.sol
remediation/evidence/S7_*.md
```

Forbidden：改变 1800 秒 window、300 bps deviation、最低储备、Pair、Token/WBNB 方向或管理权限。

## 3. 实现要求

1. 使用明确的 unchecked uint32 modular subtraction 计算 elapsed；
2. 证明普通时间、刚好回绕和跨回绕后的 elapsed 正确；
3. 与 V2 Pair counterfactual cumulative 的 uint32 语义一致；
4. 不把任意 Pair timestamp ahead 都默认为合法回绕；需要用窗口/stale/状态机约束异常值；
5. cumulative price uint256 overflow 也按 V2 预期语义处理，不能引入 Solidity 0.8 意外 revert；
6. update 仍为 permissionless，频繁调用不能重置未完成窗口；
7. 储备为零、低流动性、quote 为零、spot/TWAP 偏差和超过 5×window stale 继续 fail-closed；
8. token0/token1 双方向 quote 不变。
9. long-gap/re-anchor 采用唯一规则：`MAX_TWAP_AGE = 5 × twapWindow`。当 `elapsed > MAX_TWAP_AGE` 时，必须丢弃旧 anchor 对应的完成候选，以当前 counterfactual cumulative 重新 anchor，状态进入 `ACCUMULATING`，且该次 update 不得产生 `READY` quote。`elapsed == MAX_TWAP_AGE` 仍按正常窗口完成逻辑处理，但所有最低储备、quote 非零和 deviation 检查继续 fail-closed。Implementation Agent不得自行选择用超长区间直接生成 READY。

## 4. 测试要求

- timestamp=`2^32-1` 前后回绕；
- anchor 在回绕前、current 在回绕后；
- elapsed 小于、等于、大于 window；
- stale 5×window 边界跨回绕；
- 超过 5×window 的 long-gap update/re-anchor；
- cumulative uint256 接近 overflow；
- 无 swap、储备变化、低储备、恢复流动性；
- 高频 permissionless update 不阻止 READY；
- bidirectional quote differential；
- Fuzz：uint32 timestamps、reserves、cumulatives。

## 5. 阶段审核重点

- unchecked 范围是否最小且有证明；
- 攻击者是否能伪造“回绕”绕过窗口；
- READY/ACCUMULATING/LIQUIDITY_LOW 恢复路径；
- Math 精度和 quote zero；
- 不得因远期问题削弱当前 Oracle 安全阈值。

## 6. 退出条件

```text
P3-ORC-01 = CLOSED_CODE_ONLY
WINDOW = 1800 seconds
MAX_DEVIATION = 300 bps
MIN_RESERVES_CHANGED = NO
IMPLEMENTATION_COMMIT_SHA = full 40-char SHA
CORE_SOLIDITY_BUILD = PASS
INTERFACE_IMPLEMENTATION_MATCH = PASS
COMPILE_ERRORS = 0
INDEPENDENT_REVIEW = APPROVED_CODE_ONLY
REVIEW_VERDICT_CONFIRMED = YES
S8A_ALLOWED = YES only if CORE_SOLIDITY_BUILD = PASS
DEPLOYMENT_APPROVAL = NOT_GRANTED
```
