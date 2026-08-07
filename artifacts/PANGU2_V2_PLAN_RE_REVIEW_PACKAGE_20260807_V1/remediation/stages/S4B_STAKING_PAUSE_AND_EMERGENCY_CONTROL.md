# S4B — Staking 暂停与紧急止损控制

```text
Stage ID: PANGU2-V2-S4B
Findings: Staking Pausable hardening
Prerequisite: S4A APPROVED_CODE_ONLY
Macro Gate: M2 PRIORITY_FULL_AUDIT REQUIRED
```

## 1. 目标

在不重写 S4A reward accounting 的前提下，为 Staking 增加独立 PAUSER/UNPAUSER 控制和可恢复的事故响应语义。本阶段保持本金安全退出，不把 Pause 变成资产锁死机制。

## 2. Allowed Paths

```text
contracts-v2/src/Pangu2Staking.sol
contracts-v2/src/interfaces/IPangu2Staking.sol
contracts-v2/test/*StakingPause*.t.sol
contracts-v2/test/*Staking*.t.sol（仅暂停回归）
remediation/evidence/S4B_*.md
```

禁止修改 CostBasis、Token、Reward 计算、税率和部署脚本。若 constructor 变化造成完整 Build 的 script 签名错误，按 `COMPILE_COMPATIBILITY_EXCEPTION` 处理。

## 3. Pause 语义

默认冻结为：

- 新增独立 `PAUSER_ROLE` 和 `UNPAUSER_ROLE`；
- Pause 阻止新 Stake、Reward Claim、fundRewards 和非零 reward-rate 更新；
- Pause 时允许 `setRewardRate(0)`，用于立即停止未来 emission；
- Staking 单独 Pause 时，normal/early principal exit 继续可用；
- principal exit 必须继续执行 S3 CostBasis typed context 和 S4A reward/forfeiture 会计；
- Token 全局 Pause 可以作为更强措施并阻止 system transfer，但不由本阶段改变；
- Pause、Unpause、Emergency Rate Stop 都发出事件；
- role admin 关系明确，普通 REWARD_MANAGER 不自动获得 Unpause。

若 constructor 参数不足以把角色授予预期地址，保持角色类型和 admin 分离并记录未来部署接线；不得自行修改地址或部署策略。

## 4. 测试要求

- Pause 下 stake/claim/fund/nonzero rate 被阻止；
- Pause 下 `setRewardRate(0)` 成功；
- Pause 下 normal/early principal exit 按设计可用；
- exit 仍正确执行 CostBasis、penalty 和 forfeited reward；
- 只有 PAUSER 能 pause，只有 UNPAUSER 能 unpause；
- 重复 pause/unpause、角色撤销、零地址构造/role 配置；
- Token 全局 Pause 与 Staking Pause 的组合行为；
- Pause 不能绕过 claim maturity 或 position ownership。

## 5. M2 优先全量代码审核

S4B 复审批准后对全部 `contracts-v2/src/**` 执行 M2，重点检查：

- S1/S2 双账本与 S3 position lot、S4A reward 的完整一致性；
- S4B Pause 是否造成永久本金 DoS 或新权限绕过；
- Reward payment 是否污染成本或绕过税率；
- 多 position、舍入、liability 和实际余额；
- Token Context、CostBasis caller 权限和重入；
- Buy/Sell/Dividend/Support 是否受到新接口回归影响；
- 构造、接口和 compile-surface 的代码层可部署性；
- 不审核本地部署执行、RPC、广播或地址接线结果。

## 6. 退出条件

```text
STAKING_PAUSE_POLICY = BASELINE_APPROVED
P1-STK-01/02_REGRESSION = PASS
P2-STK-03_REGRESSION = PASS
IMPLEMENTATION_COMMIT_SHA = full 40-char SHA
CORE_SOLIDITY_BUILD = PASS
INTERFACE_IMPLEMENTATION_MATCH = PASS
COMPILE_ERRORS = 0
STAGE_REVIEW = APPROVED_CODE_ONLY
M2_PRIORITY_FULL_AUDIT = APPROVED_CODE_ONLY
M2_CODE_DEPLOYABILITY = YES
M2_BASELINE_COMPLIANCE = PASS
S5_ALLOWED = YES
DEPLOYMENT_OR_RUNTIME_APPROVAL = NOT_GRANTED
```

