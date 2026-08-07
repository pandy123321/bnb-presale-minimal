# S0 — 修复架构、经济规则与不变量冻结

```text
Stage ID: PANGU2-V2-S0
Type: DESIGN_GATE
Code Changes: FORBIDDEN
Prerequisite: README and Finding Baseline read completely
Exit: APPROVED_DESIGN_BASELINE
```

## 1. 目标

在改 Solidity 前冻结跨合约设计，避免 CostBasis、Staking、Token 和 Router 分别修复后互相冲突。本阶段只生成设计候选文档，不修改合约、接口、测试或部署脚本。

## 2. Allowed Paths

```text
docs/current/go-backend-v2/contracts/remediation/evidence/S0_*.md
```

## 3. 必须形成的设计决策

### 3.1 CostBasis 双账本

推荐模型：每个账户内部同时保存：

```text
knownBalance
knownCostWbnbWei
unknownBalance

actual ERC20 balance == knownBalance + unknownBalance
knownBalance == 0 => knownCostWbnbWei == 0
```

该等式只适用于 `CostBasis-eligible liquid user account`。Pair、System、Router、FeeVault、Staking custody、Locker 和其他协议托管地址不使用普通用户账本，由各自资金守恒不变量覆盖。Staking position lot 不计入用户 liquid ERC20 balance。

必须冻结：

- UNKNOWN 输入不能删除既有 KNOWN 成本；
- UNKNOWN Token 不能使用 KNOWN 成本逃税；
- 推荐 transfer/sell 都优先消费 UNKNOWN，再按比例消费 KNOWN；
- KNOWN 的成本使用 proportional floor，完整消费时迁移全部剩余成本；
- Dividend 和 Staking Reward 作为零成本 KNOWN 输入，不能污染已有成本；
- legacy `NONE/KNOWN/UNKNOWN` view 如何从双账本派生；
- mixed position 的 Preview/Execute 如何公开分项数据；
- 拆分转账和拆分卖出不能增加总成本或降低应缴税。

必须冻结可验证的舍入规范：

- 利润分类不得直接依赖已经向下取整的 proportional cost；推荐使用 overflow-safe 的精确有理数比较：`knownQuote * knownBalance` 与 `knownCost * knownSold`；
- 成本消费的 remainder 留在剩余 known position，完整退出消费全部剩余成本；
- 在相同起始账本和相同 Oracle 价格快照下，等价拆分不能比 canonical unsplit execution 获得更低 aggregate tax；
- 必须给出明确的 wei 级容差。默认不允许因为分类跨越 4%/10% 边界产生可盈利容差；
- 如果 proportional floor 无法满足，设计必须引入 carry/remainder 或其他确定性方法，而不是把差异留给测试解释。

若不采用该模型，必须证明替代方案同时阻止：灰尘污染、UNKNOWN 成本屏蔽、拆分舍入套利和实际余额失配。

### 3.2 Mixed Sell 税费

冻结以下分项：

```text
unknownSold → 9% Support + 1% Burn
knownSold and TWAP <= proportional known cost → 4% Support
knownSold and TWAP > proportional known cost → 9% Support + 1% Burn
```

同一笔 mixed sell 必须允许不同部分采用不同税率，再汇总 support、burn 和 swapTokens。禁止把 1 wei UNKNOWN 扩大成全仓 10%，也禁止把 UNKNOWN 合并进 KNOWN 成本。

必须冻结 Preview revision/quoteBlock 的唯一语义，S0 未选择前不得进入 S2：

```text
Option A — diagnostic only:
execute 始终重算 live CostBasis/Oracle，用户通过 deadline、minimumOut 和明确的 maximum protocol deduction 约束经济结果。

Option B — optimistic lock:
用户提交 expected CostBasis revision/quote constraint，任何不匹配都回滚。
```

不得同时把 revision 当展示字段和隐式执行锁。若选择 Option A，必须冻结 `maximumTax/maxSupport/maxBurn/minSwapTokens` 中至少一种足以限制协议扣减的用户保护；若选择 Option B，必须评估灰尘导致 revision 变化的 griefing 风险。

当前目标源码的 canonical 控制面必须在 S0 证据中重新确认并固定：

```text
WHITELIST_CANONICAL_CONTRACT = Pangu2Token
WHITELIST_STORAGE = Pangu2Token.feeWhitelist
WHITELIST_ADMIN_ROLE = GOVERNANCE_ROLE
TRADING_GATE_SOURCE = Pangu2Token.tradingOpenAt
LAUNCH_STATE_SOURCE = Pangu2Token.isInLaunchProtection
BUY_RATE_SOURCE = Pangu2Token.resolveBuyTaxBps
SELL_RATE_SOURCE = Pangu2Token.resolveSellTaxBps
ZERO_TAX_EXECUTION = TradeRouter → Pangu2Token.settleBuy/settleSell
```

如果执行阶段目标 SHA 与上述 mapping 不一致，标记 `SOURCE_CODE_VERIFICATION_REQUIRED` 并停止，Implementation Agent不得自行发明另一套 whitelist/launch 架构。

### 3.3 Staking 成本引用

冻结 `account + staking contract + positionId` 唯一引用及以下迁移：

- Stake：液态 known/unknown lot 迁入对应 position；
- Normal Unstake：原比例本金和成本完整迁回；
- Early Unstake：只迁回 net principal 对应 lot；penalty 对应成本作为真实损失移除；
- Reward：零成本 KNOWN；
- positionId 不得重用或迁到其他用户；
- Token hook 必须携带不可混淆的 position reference；
- Staking 不能直接任意修改其他账户 CostBasis。

阶段关闭边界必须唯一化：

```text
P1-STK-01A — principal CostBasis migration → S3
P1-STK-01B — reward zero-cost typed position credit → S4A
```

S3 只实现和关闭本金 lot/成本迁移，可以预定义 S4A 所需的 typed reward ABI/context，但不得激活 reward credit，也不得在 S4A 前声称 `P1-STK-01B` 已关闭。S4A 负责把 account-level reward 迁移到 per-position accounting，并激活、验证 zero-cost typed reward credit。

唯一权威 mutation path 必须冻结为：

```text
Staking 在 transfer 前确定 positionId
→ 调用 typed Token staking entrypoint
→ Token 建立带 stakingContract + account + positionId + operationKind 的认证 context
→ Token 执行余额变化
→ CostBasis 只接受 Token 的单一路径 mutation
→ Token 清除完整 typed context
```

禁止同时由 Staking 直接写 CostBasis、又由 Token hook 重复写；禁止用未类型化或可伪造的 reason bytes 携带 positionId。`STAKING_PRINCIPAL_RETURN` 必须使用相同 typed reference，不能只携带 account/amount。

### 3.4 Staking 奖励

推荐 per-position reward accounting：

- position 记录 reward index、accrued、claimed/closed；
- 锁定期内奖励不可领取；
- normal maturity 后领取；
- early exit 没收该 position 未成熟奖励并返回 available reserve；
- 多个不同锁期 position 不共享可绕过的 account-level claim；
- totalStaked 为 0 时不能产生无人归属 liability；
- actual balance、principal、available reserve、liability 和显式 surplus 守恒。

必须冻结完整状态迁移：

- Normal Unstake 只关闭 principal；已成熟 reward 可以独立领取，不能因本金退出而丢失，也不能重复领取；
- Early principal penalty 固定进入 `availableRewardReserve`，不得进入未记账 surplus；
- Early forfeited reward 执行 `ownedLiability -= forfeited` 且 `availableRewardReserve += forfeited`；
- `totalStaked == 0` 时，已经绑定到具体 position 的 matured liability 仍可存在；不得继续产生无人归属的新 emission；
- global reward index 的除法 dust 必须进入显式 `roundingLiability/surplus`，并在 period close/no-staker 路径确定性返回 reserve；
- position 至少区分 `principalClosed` 与 `rewardClaimedOrForfeited`，避免 normal exit 后奖励丢失。

冻结恒等式：

```text
stakingTokenBalance
= activePrincipal
+ availableRewardReserve
+ ownedAccruedRewardLiability
+ explicitRoundingOrSurplus
```

若保留 account-level reward，必须给出能阻止 `claim→earlyUnstake` 和多 position 混淆的完整证明。

### 3.5 Pause 策略

冻结 Staking 专用暂停语义：

- Pause 阻止新增 Stake、Reward Claim、Funding 和非零 rate 更新；
- `setRewardRate(0)` 必须能用于事故止损；
- 是否允许 normal/early principal exit 必须明确，推荐 Staking 单独暂停时仍允许本金退出；
- Token 全局 pause 仍可作为更强事故措施；
- PAUSER_ROLE 和 UNPAUSER_ROLE 必须是独立角色。

### 3.6 Support/Dividend/Oracle/合约账户

- 固定回购仍为 0.01 BNB；修复目标是准确预检价格冲击，不是自动缩小金额；
- Dividend 默认只能在 claimEnd 后取消；若要 emergency pre-start cancel，必须用户单独批准；
- Oracle 采用 uint32 modular elapsed，不削弱 1800 秒窗口、300 bps 偏差或最低储备；当 `elapsed > MAX_TWAP_AGE`（冻结为 `5 × twapWindow`）时，必须丢弃该长区间完成候选，以当前 counterfactual cumulative 重新 anchor，状态进入 `ACCUMULATING`，且该次 update 不得产生 `READY` quote；
- 合约账户策略必须保持直接 Pair/未授权 Router 防绕过。推荐治理预登记 approved user contract；如果选择保留现状，必须由用户签署 `ACCEPTED_DEVIATION`。

若选择 approved user contract，S0 必须冻结生命周期：

```text
NONE → APPROVED → EXIT_ONLY/GRACE → REVOKED
```

- approved-user 身份不自动授予 `feeWhitelist`，`feeWhitelist` 也不自动授予 approved-user 身份；二者是独立治理属性。只有 `GOVERNANCE_ROLE` 的独立显式 whitelist 操作才允许二者重叠；
- Pair、System、Settlement、Liquidity Manager、TransferContext 身份不得与 approved-user 身份重叠；
- `APPROVED → REVOKED` 不得立即锁死已有余额；先进入 EXIT_ONLY，只允许转出/官方卖出，禁止新增接收/买入；
- 余额归零并满足宽限条件后才能完成 REVOKED；
- counterfactual registration 必须冻结授权主体以及 trusted factory、initCodeHash 或 expected code identity 约束；
- Direct Pair 永远 fail-closed；approved user contract 不获得任何 context 或协议调用权限。

如果无法冻结该状态机，S8A 必须为 `BLOCKED_DECISION`，或由用户本人签署 `ACCEPTED_DEVIATION`。

### 3.7 ABI 和版本

列出所有拟新增/变更：

- structs；
- external/public functions；
- interfaces；
- events/errors；
- context kinds；
- legacy view compatibility；
- DApp/Backend 将来需要适配的 ABI，但本阶段不修改应用。

## 4. 必须定义的不变量

至少包括：

```text
CB-INV-01 for each eligible liquid user: actualBalance = knownBalance + unknownBalance
CB-INV-02 transfer cannot increase aggregate known cost
CB-INV-03 unknown input cannot reduce recipient known cost
CB-INV-04 unknown tokens cannot consume known cost
CB-INV-05 equivalent split actions cannot lower canonical aggregate tax under the same quote snapshot
SELL-INV-01 preview components sum to execute settlement
SELL-INV-02 support + burn + swapTokens = sellAmount
STK-INV-01 liquid lots + staked lots conserve principal lots
STK-INV-02 actual staking balance covers principal + reward liabilities
STK-INV-03 locked reward cannot be claimed before maturity
STK-INV-04 forfeited reward returns to available reserve
STK-INV-05 only Token may mutate CostBasis under an authenticated typed position context
STK-INV-06 no new unowned reward liability accrues while totalStaked = 0
FEE-INV-01 actual FeeVault balance covers both buckets
DIV-INV-01 reserved + claimed + carry conservation
```

## 5. 审核与退出

1. 实现 Agent提交设计文档 Commit。
2. 独立审核 Agent检查经济基线、攻击路径和可实现性。
3. 校对 Agent逐条确认审核结论。
4. 修订所有 CONFIRMED 问题并复审。

退出条件：

```text
DESIGN_VERDICT = APPROVED_DESIGN_BASELINE
ECONOMIC_BASELINE_CHANGED = NO
UNRESOLVED_P0_P1_P2_DECISIONS = 0
S1_ALLOWED = YES
```
