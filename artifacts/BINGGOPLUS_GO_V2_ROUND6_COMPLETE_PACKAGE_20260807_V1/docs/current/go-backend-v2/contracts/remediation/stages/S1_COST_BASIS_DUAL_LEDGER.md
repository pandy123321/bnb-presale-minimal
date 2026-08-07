# S1 — CostBasis 双账本与安全转账

```text
Stage ID: PANGU2-V2-S1
Findings: P1-CB-01 (part 1/2)
Prerequisite: S0 APPROVED_DESIGN_BASELINE
Macro Gate: none; M1 occurs after S2
```

## 1. 目标

实现 S0 冻结的 known/unknown 双账本和安全转账规则，使 UNKNOWN 灰尘只影响其自身数量，不能覆盖接收方已有 KNOWN 成本，也不能使用 KNOWN 成本逃税。

本阶段不修改 Token/Router 的混合卖出结算；S1 Commit 是中间开发候选，不得标记为可部署版本。

## 2. Allowed Paths

```text
contracts-v2/src/CostBasisManager.sol
contracts-v2/src/interfaces/ICostBasisManager.sol
contracts-v2/src/libraries/CostMath.sol（仅在确有必要时）
contracts-v2/test/*CostBasis*.t.sol
contracts-v2/test/*Invariant*.t.sol
remediation/evidence/S1_*.md
```

Forbidden：Token、Router、Staking、FeeVault、部署脚本、V3 `contracts/src/**` 及应用代码。

## 3. 实现步骤

1. 在不改变冻结税率的前提下引入 account lot 数据：known balance/cost、unknown balance。
2. 为 legacy `positionOf` 等 view 定义兼容派生语义；不得让旧调用方静默得到虚假 KNOWN。
3. 重写 `onUserTransfer()`：
   - 基于 transfer 后实际余额验证 source/recipient；
   - 按 S0 冻结顺序拆分 unknown/known transfer；
   - recipient 分别增加 unknown 和 known lot；
   - 完整 known transfer 迁移全部剩余成本；部分 transfer 使用 proportional floor；
   - source 余额归零时清零所有成本；
   - 不把接收方已有 KNOWN 改写为 UNKNOWN。
4. 更新 `recordBuy()`：只增加 known lot 和真实 WBNB cost。
5. 更新 `recordZeroCost()`：增加零成本 known lot，不删除原成本。
6. 更新 `onSystemCreditUnknown()`：只增加 unknown lot。
7. 保持遗留 LP tokenId 逻辑不变，除非接口编译必须适配；禁止趁机重写 LP 模型。
8. 为 lot 变化增加足够事件：旧值、新值、known cost、unknown amount、reason；不得泄漏成只有聚合 status 的不可追溯事件。
9. 所有 external hook 保持严格调用者校验、零地址和零金额规则。

## 4. 必须验证的攻击路径

- UNKNOWN 地址向已有 KNOWN 余额地址发送 1 wei；接收方 known cost 不变，只有 1 wei unknown。
- UNKNOWN 大额转入 KNOWN，不得获得 KNOWN 成本。
- KNOWN→KNOWN 完整/部分迁移。
- KNOWN→UNKNOWN/mixed 接收方的 lot 分离。
- 拆成 N 次转账和一次转账不能增加 aggregate known cost。
- 在相同 Oracle/账本快照下，拆分行为不能因 proportional floor 把 4%/10% 分类变成更低 aggregate tax；利润分类使用 S0 冻结的精确比较。
- source 实际余额和账本不一致时 fail-closed，但不能无条件删除无关接收方成本。
- zero-cost Token 转入已有 known/mixed 地址。

## 5. 测试要求

至少新增：

- Unit：所有 lot 转换矩阵；
- Fuzz：随机 known/unknown 数量、部分转账、多个接收方；
- Invariant：实际余额守恒、成本不增加、unknown 不消耗 known cost；
- 回归：原 KNOWN→KNOWN 成本比例迁移；
- AccessControl：普通用户不能直接 record/consume/hook。

若 Forge 不可用，记录 `NOT_RUN`，但阶段不能因测试源码存在而称 PASS。

## 6. 阶段审核重点

- 舍入是否可通过拆分增加成本；
- actual balance 的 before/after 推导是否在 Token hook 时序下正确；
- 双方为同一地址、零数量、全部余额、余额不一致等边界；
- 存储升级无意义：这是新地址候选，不得设计成对旧地址原地升级；
- 接口改变是否为 S2 留出 mixed sell 分项。

## 7. 退出条件

```text
P1-CB-01_LEDGER = CLOSED_CODE_ONLY
P1-CB-01_SETTLEMENT = OPEN_UNTIL_S2
IMPLEMENTATION_COMMIT_SHA = full 40-char SHA
CORE_SOLIDITY_BUILD = PASS
INTERFACE_IMPLEMENTATION_MATCH = PASS
COMPILE_ERRORS = 0
UNIT/FUZZ/INVARIANT = PASS or explicitly NOT_RUN
INDEPENDENT_REVIEW = APPROVED_CODE_ONLY
REVIEW_VERDICT_CONFIRMED = YES
S2_ALLOWED = YES only if CORE_SOLIDITY_BUILD = PASS
DEPLOYMENT_APPROVAL = NOT_GRANTED
```
