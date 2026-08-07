# S5 — SupportPool 固定回购价格冲击预检

```text
Stage ID: PANGU2-V2-S5
Findings: P2-BBK-01
Prerequisite: M2 APPROVED_CODE_ONLY
Macro Gate: none
```

## 1. 目标

保留固定 0.01 BNB 回购和 60 秒成功间隔，但让 `canExecuteBuyback()` 与 `buyback()` 同时检查真实 V2 储备下的 curve expected output。浅池时应明确返回 PRICE_IMPACT/不可执行，而不是先报告 allowed、再在 swap 中回滚。

## 2. Allowed Paths

```text
contracts-v2/src/SupportPool.sol
contracts-v2/src/adapters/PancakeV2Adapter.sol（仅需要共享可信 quote 时）
contracts-v2/src/interfaces/IPancakeV2Adapter.sol
contracts-v2/src/interfaces/ISupportPool.sol
contracts-v2/src/libraries/*V2Quote*.sol（如新增最小专用库）
contracts-v2/test/*SupportPool*.t.sol
contracts-v2/test/*PancakeV2Adapter*.t.sol
remediation/evidence/S5_*.md
```

Forbidden：改变 `BUYBACK_AMOUNT`、`MIN_BUYBACK_INTERVAL`、recipient、税率、FeeVault bucket，或修改部署脚本。

## 3. 实现要求

1. 固定读取已绑定 Pair 的 reserves，并正确处理 token0/token1 顺序。
2. 优先复用现有 `PancakeV2Adapter.quoteExactInput()`：它已经绑定 canonical Token/WBNB Pair，并通过固定 Router `getAmountsOut` 报价。只有独立审核证明该接口不满足安全要求时才允许新增专用库；不得扩展为任意 pair/path quote。
3. 继续获取经过验证的 TWAP quote。
4. 计算协议 TWAP minimumOut；如果 curve expectedOut 低于该 floor，状态为不可执行并给出明确 block reason。
5. `canExecuteBuyback()` 和 `buyback()` 必须调用同一内部判断逻辑或严格等价逻辑，避免 preview/execute 漂移。
6. 执行前重新读取储备和 Oracle；旧 view 结果不能作为可信执行授权。
7. deadline、allowance 清零、固定 Locker recipient、actual balance delta、nonReentrant 和 cooldown 规则保持不变。
8. 失败回购不得更新 `lastSuccessfulBuybackAt` 或 buybackCount。
9. 不得自动把 0.01 BNB 缩小成动态金额；这是经济模型变更，除非 S0 有明确用户批准。
10. 增加事件或 view 字段，提供 TWAP quote、curve quote、minimumOut 和拒绝原因，便于链下诊断。

## 4. 测试要求

- 部署基线浅池 `100 PANGU2 / 0.01 WBNB`：`canExecute` 明确不可执行，`buyback` 同原因 fail-closed；
- 足够深储备：view 与 execute 一致并成功进入固定 Locker；
- token0/token1 双方向；
- reserve=0、stale Oracle、deviation、insufficient BNB、cooldown；
- 储备在 view 后变化，execute 重新验证；
- swap revert 不消耗 cooldown、不残留 allowance；
- Fuzz：reserve ratio、amountOut、fee rounding；
- 回归：permissionless trigger 不能选择 recipient 或得到 Token/BNB。

## 5. 阶段审核重点

- curve formula 与 Pancake V2 实现是否一致；
- TWAP 和 curve quote 单位/方向；
- reserve 读取是否可被单块操纵，以及 spot/TWAP deviation 是否仍有效；
- 新 Adapter view 是否暴露任意 pair/path；
- `canExecute` 不得对实际无法执行状态返回 allowed；
- 不把增加流动性误报为代码修复。

## 6. 退出条件

```text
P2-BBK-01 = CLOSED_CODE_ONLY
BUYBACK_AMOUNT = 0.01 BNB
MIN_INTERVAL = 60 seconds
RECIPIENT = BUYBACK_LOCKER
IMPLEMENTATION_COMMIT_SHA = full 40-char SHA
CORE_SOLIDITY_BUILD = PASS
INTERFACE_IMPLEMENTATION_MATCH = PASS
COMPILE_ERRORS = 0
INDEPENDENT_REVIEW = APPROVED_CODE_ONLY
REVIEW_VERDICT_CONFIRMED = YES
S6_ALLOWED = YES only if CORE_SOLIDITY_BUILD = PASS
LIVE_RESERVE_STATUS = NOT_CHECKED_IN_THIS_STAGE
DEPLOYMENT_APPROVAL = NOT_GRANTED
```
