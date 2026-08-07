# S4A — Staking Per-Position 奖励与退出会计

```text
Stage ID: PANGU2-V2-S4A
Findings: P1-STK-01B (reward zero-cost typed credit), P1-STK-02, P2-STK-03
Prerequisite: S3 APPROVED_CODE_ONLY
Macro Gate: none; M2 occurs after S4B
```

## 1. 目标

将奖励归属到具体 position，阻止锁定期内先领取再提前退出；把没收奖励和本金 penalty 正确记入 available reserve；冻结 normal exit、no-staker 和 reward dust 的完整会计。暂停控制不在本阶段实现，由 S4B 单独处理。

## 2. Allowed Paths

```text
contracts-v2/src/Pangu2Staking.sol
contracts-v2/src/interfaces/IPangu2Staking.sol
contracts-v2/src/Pangu2Token.sol（仅 reward typed context 适配确有必要时）
contracts-v2/src/CostBasisManager.sol（仅 zero-cost reward hook 适配确有必要时）
contracts-v2/test/*Staking*.t.sol
contracts-v2/test/*Invariant*.t.sol
remediation/evidence/S4A_*.md
```

不得在本阶段新增 Pausable/角色，不得重新修改 S2 税费或 S3 principal lot 规则。需要扩大范围时标记 `SCOPE_EXPANSION_REQUIRED`。

## 3. Per-Position Reward 要求

1. 本阶段负责把旧 account-level reward 路径迁移为 per-position accounting，并激活 S3 预定义的 typed reward context；奖励必须可归因到具体 position，不得继续使用可在锁定期提前领取的 account-level bucket 混合不同锁期。
2. 每个 position 至少记录 reward index、accrued reward、`principalClosed`、`rewardClaimedOrForfeited`。
3. stake、claim、normal exit、early exit 前先更新 global index 和目标 position reward。
4. 锁定期内不可领取该 position 奖励。
5. 到期后允许 position-level claim；重复 claim 不得重复付款。
6. Normal Unstake 只关闭 principal；已经成熟的奖励保持独立可领取，不能因为本金退出而丢失，也不能再次累积本金奖励。
7. Early Unstake：
   - 计算该 position 全部未成熟/未领取奖励；
   - `ownedAccruedRewardLiability -= forfeitedReward`；
   - `availableRewardReserve += forfeitedReward`；
   - 不向用户支付该奖励；
   - 不影响其他 position。
8. 10% principal penalty 固定加入 `availableRewardReserve`；其历史 CostBasis 按 S3 规则作为经济损失移除。
9. `totalStaked == 0` 时停止产生无人归属的新 emission；已经绑定 position 的成熟 liability 仍可领取。
10. global index 除法 dust 必须进入显式 rounding liability/surplus，并按 S0 规则确定性返回 reserve，不能形成永久账外 Token。
11. `fundRewards()` 继续使用实际到账余额差；reward-rate cap 数值不变。
12. 所有 reward payment 使用 S3 的 typed zero-cost hook，不得直接污染用户 CostBasis。

## 4. 资金恒等式

每次状态改变后必须满足：

```text
stakingTokenBalance
= activePrincipal
+ availableRewardReserve
+ ownedAccruedRewardLiability
+ explicitRoundingOrSurplus
```

所有右侧 bucket 都必须可追溯；禁止使用“实际余额更多所以仍然 solvency”掩盖账外余额。

## 5. 测试要求

- `accrue→claim before unlock` 必须 revert；
- `accrue→earlyUnstake`：reward 和 penalty 都进入 reserve；
- 多 position 不同锁期：到期 position 可领取，未到期 position 不可领取；
- normal principal exit 后成熟 reward 仍能且只能领取一次；
- claim 后重复 claim、exit 后 claim、重复 exit；
- no staker、periodFinish、rate=0、reserve 恰好覆盖、极小 reward；
- global index rounding dust 和 period close；
- Reward typed context 与真实 CostBasisManager 集成；
- 恶意 receiver/reentrant attempt；
- Fuzz：多个 position、时间、rate、funding、claim/exit 顺序；
- Invariant：实际余额恒等式、paid + reserve + owned liability 守恒。

## 6. 阶段审核重点

- position-level reward 是否真正替代旧 account-level claim 路径；
- principalClosed/rewardClosed 两个终态是否独立且不可重复；
- no-staker emission 和 rounding dust；
- S3 typed context、CostBasis 和 Token 时序；
- 旧公开 API 是否留下可绕过的新旧双入口；
- 不得以 Pause 逻辑掩盖奖励状态机问题。

## 7. 退出条件

```text
P1-STK-02 = CLOSED_CODE_ONLY
P2-STK-03 = CLOSED_CODE_ONLY
P1-STK-01A_REGRESSION = PASS
P1-STK-01B = CLOSED_CODE_ONLY
IMPLEMENTATION_COMMIT_SHA = full 40-char SHA
CORE_SOLIDITY_BUILD = PASS
INTERFACE_IMPLEMENTATION_MATCH = PASS
COMPILE_ERRORS = 0
INDEPENDENT_REVIEW = APPROVED_CODE_ONLY
REVIEW_VERDICT_CONFIRMED = YES
S4B_ALLOWED = YES only if CORE_SOLIDITY_BUILD = PASS
DEPLOYMENT_APPROVAL = NOT_GRANTED
```
