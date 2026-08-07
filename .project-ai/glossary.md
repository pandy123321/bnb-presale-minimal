# PANGU2 — Glossary

## 品牌
BingGoPlus / BGP: 产品品牌。Pangu2: 链上合约/ABI/事件/Token 名称（已部署不可改）。

## 代币
PANGU2 / BGP: BEP-20 代币, 精度 18, 总供应量 1,000,000,000
BNB: BSC 链原生币。WBNB: Wrapped BNB。
BPS: Basis Points, 10000 BPS = 100%

## 合约

| 术语 | 说明 |
|------|------|
| TradeRouter | 买/卖入口 + 预览报价 |
| CostBasis | 成本追踪 KNOWN/UNKNOWN/NONE + 双账本 (S1 修复目标) |
| FeeVault | 税费归集 DIVIDEND/SUPPORT 双 Bucket |
| SupportPool | permissionless 触发 + 固定 0.01 BNB + 距上次成功至少 60s（不是定时器频率承诺） |
| BuybackLocker | FIXED_DURATION 365 天锁仓 |
| DividendDistributor | 前 100 名分红 + Merkle Proof |
| Pangu2Staking | 1-730 天锁仓 + 10% 罚金 + O(1) 奖励 |

## 税收优先级

```text
Trading Gate → Fee Whitelist → Launch Protection (15min 30%) → Normal Cost-Basis (4%/10%)
```

| 场景 | 税率 | 资金流向 |
|------|:--:|------|
| Whitelist | 0% | 全额 swap |
| Launch Buy | 30% | DividendDistributor |
| Launch Sell | 30% | 29% Support + 1% Burn + 70% swap |
| Normal Buy | 4% | DividendDistributor |
| Normal Sell UNKNOWN/盈利 | 10% | 9% Support + 1% Burn |
| Normal Sell 未盈利 | 4% | SupportPool |

## 部署与修复阶段

| 术语 | 说明 |
|------|------|
| Deploy Source Commit `3ef50b6` | 当前 BSC Testnet 实际部署的合约源码提交 |
| S0-S9 | 合约安全修复 10 阶段（S0 设计→S1-S8 实现→S9 退出） |
| APPROVED_CODE_ONLY | 代码层通过，不表示可部署 |
| M1/M2/M3 | S2/S4/S8 后的大阶段全量代码审核 |
| Go V2 | 新后端语言/框架（Go 替代 Laravel+TypeScript Worker） |
| `backend-go/` | Go V2 目标代码目录 |
| projection_receipts | 投影完成权威证据；Raw Event 无单一 PROJECTED 状态 |
| Dividend 历史视图 | finalized blocks / projection coverage / token ledger / staking history 四个 security_barrier 视图 |
| OUT_OF_SCOPE / ROADMAP_NOT_APPROVED | 团队/推荐/佣金等未批准能力；当前 V2 不实现 |

## 后端

| 术语 | 说明 |
|------|------|
| ApiEnvelope | { data, meta, error } 统一响应 |
| CSRF Token | GET /csrf-token → X-CSRF-TOKEN + 419 自动重试 |
| RBAC | SUPER_ADMIN/OPERATOR/AUDITOR/VIEWER |
| GE-A01~A04 | Admin 治理面板 4 批次开发 |
| ChainOperatorService | 纯 PHP ECDSA 离线签名 + EIP-155 + eth_sendRawTransaction |

## Chain Worker

| 术语 | 说明 |
|------|------|
| 6 Streams | TRADE/DIVIDEND/STAKING/LOCKER/SUPPORT/FEE_VAULT |
| Fencing Token | 分布式租约 + generation 检测 |
| Reorg Recovery | BlockHash 验证 + 回退 + 重新扫描 |

## DApp V7.1

| 术语 | 说明 |
|------|------|
| 3 Pages | Home / Trade / Portfolio |
| trading-disabled | 交易未开启时图表占位 + 按钮禁用 + 无倒计时 |
| `—` (em-dash) | 动态数据占位符，等 API 接入真实数据 |
| packages/ui/ | 7 共享组件 + tokens.css + global.css |

## Phase 0-9 执行计划

| 术语 | 说明 |
|------|------|
| Phase 0 | 基线固化（只读，已完成） |
| Phase 1-3 | 工作区收口 / 统一地址 / Worker 迁移 |
| Phase 4-6 | Backend 报价 + Admin 前端 + DApp 数据接入 |
| Phase 7-9 | 安全收口 / 全量验证 / 测试网部署 |

## 信息来源
- contracts-v2/src/*.sol, contracts-v2/broadcast/*/97/run-latest.json
- docs/current/go-backend-v2/
- docs/current/BSC_TESTNET_DEPLOYMENT_BASELINE.md
- apps/dapp/src/features/wallet/deployed.ts
- backend/app/Modules/, packages/ui/
