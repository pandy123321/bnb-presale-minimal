# BingGoPlus — Glossary

## 品牌
BingGoPlus / BGP: 产品品牌和 Flap Launch 平台。Pangu2: Legacy 链上合约/ABI/事件/Token 名称（已部署不可改，不再是新产品主线）。

## 代币
Flap Token: 必须通过已冻结的 Flap Portal/VaultPortal 创建的新产品 Token。
PANGU2: Legacy BEP-20，精度 18，总供应量 1,000,000,000，只读保留。
BNB: BSC 链原生币。WBNB: Wrapped BNB。
BPS: Basis Points, 10000 BPS = 100%

## 合约

| 术语 | 说明 |
|------|------|
| TradeRouter | 买/卖入口 + 预览报价 |
| CostBasis | KNOWN/UNKNOWN 成本追踪 |
| FeeVault | DIVIDEND/SUPPORT 双 Bucket |
| SupportPool | 0.01 BNB/60s 回购，permissionless |
| BuybackLocker | FIXED_DURATION 365 天 |
| DividendDistributor | 前 100 名分红 + Merkle Proof |
| Pangu2Staking | 1-730 天锁仓 + 10% 罚金 |
| PancakeV2Adapter/Oracle | V2 swap/quote/TWAP |
| Pair | PANGU2/WBNB 交易对 |
| Admin Renounce | 8 合约 DEFAULT_ADMIN_ROLE → 0x0（Finalize 预期） |

## Legacy PANGU2 税收优先级（历史）

```text
Trading Gate → Fee Whitelist → Launch Protection (15min 30%) → Normal Cost-Basis (4%/10%)
```

## Go（唯一后端，当前 Flap F0）

| 术语 | 说明 |
|------|------|
| `backend-go/` | Go V2 代码目录；G1 审核基线 28 文件，当前工作区候选变更不等于阶段完成 |
| F0-F11 | 当前 Flap 产品主线阶段；F0 文档冻结候选，F1 尚未授权 |
| Legacy RT-GATE-01/02/03 | PANGU2 历史 Gate：RT01 PASS、RT02 BLOCKED_EVIDENCE、RT03 FIX_READY；不授权当前 Flap 实现 |
| FROZEN_FOR_DEVELOPMENT | PANGU2 历史字段，不代表 Flap 可开发；当前 Flap `F1_ENTRY_AUTHORIZED = NO` |
| F3 | Flap Chain Acquisition、Indexer 与确定性 Read Model；只读、不签名 |
| F4 | Launch Workflow、Admin/Public API、RBAC、幂等与审计；只生成 Transaction Intent |
| F5 | Signer、Transaction Execution、Nonce、Receipt/Event 精确绑定；实际链写另需人工授权 |
| F6 | Admin Launch Console、最小公开读面与 Flap Native MVP；不含 BGPlus 自建合约 |
| F7-F10 | 自建 BGPlus Vault、回购、锁仓、分红、后端集成与通用 Staking |
| F11 | Legacy PANGU2 Cutover/Retirement 独立 Gate，不与新合约开发合并 |

## 外部生态

| 术语 | 说明 |
|------|------|
| Flap.sh | 通过 Portal/VaultPortal 提供 Token Launch、Bonding Curve 与 DEX Migration 的外部平台 |
| FLAP-F0 | 当前产品转向、范围、经济继承、参数和退役冻结阶段 |
| FLAP_STANDARD | Portal 普通 Token 候选；`CANDIDATE_PENDING_F1_BASELINE` |
| FLAP_TAX_SPLIT | VaultPortal + 官方 Split Vault 候选；`MVP_CANDIDATE_PENDING_F1_BASELINE` |
| FLAP_TAX_BGPLUS | VaultPortal + 自建 BGPlus Factory/Vault；`REQUIRED_EXTENSION_PENDING_F1_AND_SOLIDITY_GATES` |
| BGPlusRevenueVault | 接收 Flap Tax BNB，并按 Launch 前确定的五桶 BPS 分配；候选默认 Dividend/Buyback-Burn/Staking/Marketing/Operations = 30/25/20/15/10 |
| Top100 Bonus Pool | Dividend 桶内的额外奖励池；候选默认占 Dividend 桶 20%，按固定快照的榜内有效持币量同比例分配；不是旧 35/25/25/15 四档 |
| Staking Reward Funding | `TAX_BNB_SWAP_TO_BOUND_TOKEN + OPTIONAL_EXTERNAL_PREFUND`；只用 Staking Bucket，迁移后受控兑换；不使用其他 Bucket 或质押本金 |
| BGPlusTokenVesting | 团队、投资人、项目储备的独立预充值锁仓；不铸币、不复用回购 Locker |
| Launch Protection Candidate | 旧模型真实基线为开盘后 15 分钟/30% 税，不是 15% 税；仅在 F1/独立 Solidity Gate 证明兼容时启用 |
| EarlyUnstake Penalty | 默认 principal 的 10%；完整 principal liability 一次减少，净额返还用户，罚金和被没收奖励只回同 Pool available Reward Reserve |
| Custody Exclusion | Staking/Vesting/Locker/Vault 等合约地址余额不直接参加分红；Staking principal 按 staker 计一次，Vesting 未释放量不参加 |
| Factory Commission V1 | creation fee = 0、revenue commission = 0、recipient = zero；Factory 不接收 RevenueVault outflow |
| Legacy PANGU2 | 现有合约和数据只读保留，不重部署、不新增功能 |
| TokenCreated | Flap 创建交易核心事件；必须结合 Version/Curve/Tax/Migrator/DEX/Extension/Vault 等同交易事件 |

## Laravel（代码冻结）

| 术语 | 说明 |
|------|------|
| ApiEnvelope | { data, meta, error } |
| GE-A01~A04 | 旧治理面板 4 批次；不再新增功能，G9 前运行时状态按迁移阶段单独记录 |

## DApp V7.1

| 术语 | 说明 |
|------|------|
| 3 Pages | Home / Trade / Portfolio |
| trading-disabled | 无图表、无倒计时、按钮 disabled |

## 合约修复

| 术语 | 说明 |
|------|------|
| Deploy Commit `3ef50b6` | BSC Testnet 实际部署源码 |
| F-1~F-4 | 4 个待修复 Finding（F-2/F-3 已提交，F-1/F-4 待执行） |

## 信息来源
- contracts-v2/src/*.sol, contracts-v2/broadcast/*/97/run-latest.json
- backend-go/（G1 审核基线 28 文件；当前工作区候选变更未审核）
- docs/current/go-backend-v2/
- docs/current/RULES_MASTER.md
