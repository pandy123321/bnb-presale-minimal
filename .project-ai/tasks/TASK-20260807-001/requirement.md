# TASK-20260807-001 — Contract Remediation S0-S9

## Source
`docs/current/go-backend-v2/contracts/remediation/`

## Summary
修复 BSC Testnet 已部署合约（提交 `3ef50b6`）的 9 个安全 Finding：3 P1、4 P2、2 P3。10 个阶段串行执行，3 个大审核（M1/M2/M3）。

## Phases

| 阶段 | 范围 | Finding | 大审核 |
|------|------|--------|:--:|
| S0 | 设计冻结（不改代码） | — | 设计审核 |
| S1 | CostBasis known/unknown 双账本 | P1-CB-01 | — |
| S2 | Token/Router Mixed Sell + Whitelist 修复 | P1-CB-01, P2-TAX-01 | M1 |
| S3 | Staking 成本引用与迁移 | P1-STK-01 | — |
| S4 | Staking 奖励/退出/暂停 | P1-STK-02, P2-STK-03 | M2 |
| S5 | Support 回购价格冲击预检 | P2-BBK-01 | — |
| S6 | Dividend Epoch 终态 | P2-DIV-01 | — |
| S7 | Oracle uint32 timestamp 回绕 | P3-ORC-01 | — |
| S8 | 合约账户边界策略 | P3-TKN-01 | M3 |
| S9 | 全量代码退出门 | 全部 | 最终 |

## Per-Stage Closure
Pre-Fix Review → Adjudication → Implementation (CONFIRMED only) → Validate → Commit → Post-Fix Review → Adjudication → Fix → Re-Review → APPROVED_CODE_ONLY

## Constraints
- 实现 Agent 不可自行签发批准
- P0/P1/P2 不得用"后续再处理"关闭
- 不得改变冻结经济参数
- 不得运行 forge script/cast send/RPC/部署命令

## Status: 待用户批准 S0 启动
