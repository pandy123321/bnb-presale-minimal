# PANGU2 V2 安全 Finding 修复基线

```text
Audit Target: contracts-v2/src/**
Deployed Source Commit: 3ef50b6d77a31c092e9353e255e672836f36ece8
Planning Observed HEAD: 4d33669b41568fa573e9c0e5865be8b1cea803c3
Code Audit Verdict: CHANGES_REQUIRED
P0: 0
P1: 3
P2: 4
P3: 2
Mainnet: NO-GO
```

本文件是修复任务的 Finding 输入，不是关闭证明。每项只有在对应阶段完成实现、独立审核、审核结论校对和复审后才能改为 `CLOSED_CODE_ONLY`。

## 1. Finding 矩阵

| ID | 级别 | 问题 | 部署测试网源码影响 | 目标阶段 |
|---|---|---|---|---|
| P1-CB-01 | P1 | UNKNOWN 灰尘把接收方全部 KNOWN 仓位污染为 UNKNOWN | YES | S1 + S2 |
| P1-STK-01 | P1 | Staking 本金返还和奖励没有恢复/更新 CostBasis | YES | S3 |
| P1-STK-02 | P1 | 先 Claim 再 Early Unstake 绕过奖励没收 | YES | S4A |
| P2-TAX-01 | P2 | Whitelist 零税结算调用 `FeeVault.credit(0)` 导致回滚 | YES | S2 |
| P2-STK-03 | P2 | 没收奖励从 liability 删除但未返回 reserve | YES | S4A |
| P2-BBK-01 | P2 | 固定回购未检查自身价格冲击，初始浅池可能持续回滚 | YES；实时储备需回读 | S5 |
| P2-DIV-01 | P2 | Published Epoch 可在 claimStart 前被 Governance 取消 | YES | S6 |
| P3-ORC-01 | P3 | Oracle 未正确处理 uint32 timestamp 回绕 | YES；当前不可利用 | S7 |
| P3-TKN-01 | P3 | `code.length` 全局限制导致智能钱包不兼容/反事实地址锁定 | YES | S8A + S8B |

## 2. 不得破坏的经济基线

```text
Initial Supply = 1,000,000,000 PANGU2
Decimals = 18
No post-constructor mint

Priority:
Trading Gate → Fee Whitelist → Launch Protection → Normal Cost-Basis Tax

Whitelist Buy/Sell = 0%
Launch Buy/Sell = 30%
Launch Sell = 29% Support + 1% Burn
Normal Buy = 4% Dividend
Normal Sell KNOWN at/below proportional cost = 4% Support
Normal Sell KNOWN above proportional cost = 9% Support + 1% Burn
Normal Sell UNKNOWN = 9% Support + 1% Burn
Launch Protection = 15 minutes

Staking minimum = 1 Token
Maximum lock = 730 days
Early principal penalty = 10%

Buyback amount = 0.01 BNB
Minimum successful-buyback interval = 60 seconds
Buyback recipient = BuybackLocker

Dividend claim window = exactly 30 days
Oracle window = 1800 seconds
Oracle max deviation = 300 bps
```

任何改变以上参数或税率优先级的方案都属于经济模型变更，必须暂停阶段并请求用户批准；不得以“修复漏洞”为名顺带改变。

## 3. Finding 关闭证据

每项关闭必须同时具备：

1. Fix Commit 完整 SHA；
2. 部署 Commit 与 Fix Commit 的代码证据；
3. 原攻击路径已不可执行的逐步说明；
4. 正向功能测试；
5. 原攻击路径回归测试；
6. 相关 Fuzz/Invariant；
7. 独立审核 `APPROVED_CODE_ONLY`；
8. 校对 Agent 确认审核结论正确；
9. 未改变经济基线；
10. 明确 `CODE_FIX_REQUIRES_REDEPLOYMENT = YES`。

## 4. 历史事项处理

- 旧 `CONTRACT_SECURITY_AUDIT.md` 绑定 `e2c09c5`，不能批准部署 Commit 或本修复分支。
- 部署后的脚本/interface 修复不能反向修复测试网 runtime。
- V2 MVP 保留 V3 tokenId LP 模型是已知偏差；除非发现新的攻击路径，不在本计划中重构。
- 本计划只修合约代码；部署、迁移、链上 readback 和测试网切换必须另开任务。
