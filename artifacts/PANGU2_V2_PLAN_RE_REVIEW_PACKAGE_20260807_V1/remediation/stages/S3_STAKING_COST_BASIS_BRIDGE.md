# S3 — Staking 本金 CostBasis 迁移闭环

```text
Stage ID: PANGU2-V2-S3
Findings: P1-STK-01
Prerequisite: M1 APPROVED_CODE_ONLY
Macro Gate: none; M2 occurs after S4B
```

## 1. 目标

为每个 Staking position 建立不可混淆的成本引用，使 Stake、正常退出、提前退出和 Reward credit 都能保持 CostBasis 一致。该阶段只修本金/成本桥；奖励成熟与没收规则在 S4A 完成，暂停策略在 S4B 完成。

## 2. Allowed Paths

```text
contracts-v2/src/Pangu2Token.sol
contracts-v2/src/CostBasisManager.sol
contracts-v2/src/Pangu2Staking.sol
contracts-v2/src/interfaces/IPangu2Token.sol
contracts-v2/src/interfaces/ICostBasisManager.sol
contracts-v2/src/interfaces/IPangu2Staking.sol
contracts-v2/src/libraries/TransferContext.sol
contracts-v2/test/*Staking*.t.sol
contracts-v2/test/*CostBasis*.t.sol
contracts-v2/test/*Invariant*.t.sol
remediation/evidence/S3_*.md
```

Forbidden：Router 税率逻辑、Support、Dividend、Oracle、部署脚本和应用代码。

## 3. 实现要求

### 3.1 Position 引用

- 在发生 Token transfer 前确定唯一 `positionId` 或 position key；
- key 至少绑定 chain-local Staking address、account、positionId；
- positionId 不得重复绑定、跨用户迁移或在关闭后重用；
- Token hook 不能仅凭可伪造的 reason bytes 修改任意 position。

唯一 mutation authority 必须严格实现为：

```text
Staking creates/reserves positionId before transfer
→ typed Token entrypoint authenticates msg.sender as configured Staking
→ Token context binds stakingContract + account + positionId + operationKind
→ Token changes ERC20 balances
→ CostBasisManager mutates only through an onlyToken hook
→ Token clears every typed context field before returning
```

Staking 不得直接调用 CostBasis mutation；Token hook 与显式调用不得双重记账。`STAKING_PRINCIPAL_RETURN` 和 Reward 也必须走 typed entrypoint，不得退化为只有 `to/amount/kind` 的无 position reference 路径。

### 3.2 Stake

- `stakingDeposit` 只允许已配置 Staking 调用；
- 从用户液态双账本按 S0 规则迁出 known/unknown lot；
- 将迁出的 known balance/cost、unknown balance 绑定到 position；
- Staking 实际收到数量必须与 CostBasis 记录一致；
- 任一检查失败，Token transfer、Staking position 和 CostBasis 全部回滚。

### 3.3 Normal Unstake

- 只能返回调用者自己的、未关闭、已到期 position；
- 将 position 剩余 principal lot 和 known cost 全部迁回用户；
- 迁回后 position 成本账本归零并永久关闭；
- 不得把本金返还标成 UNKNOWN 或零成本。

### 3.4 Early Unstake

- 10% penalty 基于 position principal 计算；
- net principal 对应的 known/unknown lot 和 known cost 按比例迁回；
- penalty 对应成本从用户经济成本中移除，不得转成未来领取人的历史成本；
- 完整退出时 position 所有 lot 清零；
- 舍入剩余必须有确定归属，不能留下 `balance=0, cost>0`。

### 3.5 Reward

- 为 S4A 预留或实现明确的 `STAKING_REWARD` zero-cost hook；
- Reward 增加用户零成本 known balance，不覆盖原 known/unknown lot；
- 普通 Staking 合约不能调用该 hook 给任意账户伪造本金成本。

### 3.6 事件和权限

事件至少绑定 account、staking contract、positionId、token amount、known cost、unknown amount、操作类型。所有新 external hook 必须有 caller、零地址、amount 和 position state 校验。

## 4. 测试要求

- KNOWN Stake→normal exit→sell，成本恢复且税率正确；
- UNKNOWN、mixed Stake→normal exit；
- KNOWN/mixed Early Unstake，net lot 与 penalty cost 正确；
- Reward credit 不改变既有成本；
- 多 position 不串位；跨用户 positionId 攻击失败；重复退出失败；
- transfer/CostBasis/Staking 任一步 revert 时全局回滚；
- Fuzz：amount、lock、known/unknown 组合和舍入；
- Invariant：liquid lots + active staking lots 守恒，关闭 position 无残余成本。

测试必须使用真实 CostBasisManager，不得用空 hook Mock 作为关闭证据。

## 5. 阶段审核重点

- Token `_update` 和显式 staking function 是否双重记账；
- hook 在 transfer 前后读取实际余额的时序；
- Staking 重入保护和 Token external hook 回调；
- position 状态是否先 effects 后 interaction，并在 revert 时原子回滚；
- reward zero-cost 是否可能成为低权限伪造 KNOWN 的入口；
- 旧 V3 LP tokenId 代码没有被误改。

## 6. 退出条件

```text
P1-STK-01 = CLOSED_CODE_ONLY
IMPLEMENTATION_COMMIT_SHA = full 40-char SHA
CORE_SOLIDITY_BUILD = PASS
INTERFACE_IMPLEMENTATION_MATCH = PASS
COMPILE_ERRORS = 0
REAL_COST_BASIS_INTEGRATION_TEST = PASS or NOT_RUN_WITH_BLOCKER
INDEPENDENT_REVIEW = APPROVED_CODE_ONLY
REVIEW_VERDICT_CONFIRMED = YES
S4A_ALLOWED = YES only if CORE_SOLIDITY_BUILD = PASS
DEPLOYMENT_APPROVAL = NOT_GRANTED
```
