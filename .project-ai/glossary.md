# BingGoPlus — Glossary

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
| PancakeV2Adapter | PancakeSwap V2 swap/quote |
| PancakeV2TwapOracle | 累积价格 TWAP + 低流动性保护 |
| Pair | PancakeSwap V2 PANGU2/WBNB 交易对 |

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
| `backend-go/` | Go V2 目标代码目录（当前不存在） |
| projection_receipts | 投影完成权威证据；Raw Event 无单一 PROJECTED 状态 |
| Dividend 历史视图 | finalized blocks / projection coverage / token ledger / staking history 四个 security_barrier 视图 |
| OUT_OF_SCOPE / ROADMAP_NOT_APPROVED | 团队/推荐/佣金等未批准能力；当前 V2 不实现 |

## Go V2 Freeze Gate 术语

| 术语 | 说明 |
|------|------|
| FREEZE_CANDIDATE | 设计冻结候选状态，未获所有责任人签署 |
| FROZEN_FOR_DEVELOPMENT | 所有 Gate 通过后的开发冻结状态（当前 = NO） |
| Round9 Verdict | `APPROVED_FOR_RESPONSIBLE_OWNER_FREEZE` — 第九轮独立复验通过 |
| Round10 Verdict | `APPROVED_FOR_RESPONSIBLE_OWNER_FREEZE` — 第十轮关闭 P2-R9-01 |
| Responsible Owner Freeze | `pd123` 代表全部责任域签署 GATE-01~05（2026-08-08） |
| GATE-01~05 | Product/Business, API/Contract, Database/Dependency, Event/State, Security/RBAC/Signer |
| P1-R8-01, P1-R8-02, P2-R9-01 | Round8/9/10 中已关闭的 P1/P2 Finding |
| UNRESOLVED-BIZ-01 | Dividend 有效持币量定义（待产品签署） |

## Runtime Gate 术语（2026-08-08 执行）

| 术语 | 说明 |
|------|------|
| RT-GATE-01 | PostgreSQL Migration + Role Runtime 验证（当前 `BLOCKED_POSTGRESQL_NOT_AVAILABLE`） |
| RT-GATE-02 | BSC Testnet Fixed-Block Readback（当前 `BLOCKED_APPROVED_RPC_REQUIRED`） |
| RT-GATE-03 | Go Build 阶段定义（当前 `DECISION_READY`，G0→G1→G2 方案已定义） |
| G0 | Pre-development Freeze（RT-GATE-01 + 02 + 依赖下载批准） |
| G1 | Go Skeleton / Bootstrap（仅 cmd/internal skeleton，禁止业务实现） |
| G2 | 业务实现（G1 go build + go vet 通过后） |
| `current_user` exact role model | 运行进程直接以 `bgp_*` LOGIN Role 连接，不依赖 INHERIT Group Role |
| bind_current_dividend_publish_command | 受控 bind function：仅 bgp_api 在 Epoch=`APPROVED` 时绑定不可替换的 Publish Command |

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

## PostgreSQL 角色

| 术语 | 说明 |
|------|------|
| bgp_migrator | 唯一 Schema/DDL 所有者；仅 Migration 时使用；运行进程不持有 |
| bgp_api | Public/Admin HTTP；Session/Command/Approval/Dividend DRAFT intake；Audit append-only |
| bgp_indexer | Block/Raw Event/Cursor/Lease；不写业务投影 |
| bgp_projector | Raw Event 只读；投影器；Dividend 链上事件派生 Epoch 字段列级写 |
| bgp_dividend | 只读窄化历史 View 构建 Artifact；不读 current 表，不写 merkle_root |
| bgp_reconciler | 读 approved Command → Signer → 广播；列级更新 Command state |
| bgp_auditor | 治理/部署/Audit/Job/Anomaly 只读；不读认证或 signer 状态 |
| bgp_readonly | 产品投影/状态/排障只读 |

## Phase 0-9 执行计划

| 术语 | 说明 |
|------|------|
| Phase 0 | 基线固化（只读，已完成） |
| Phase 1-3 | 工作区收口 / 统一地址 / Worker 迁移 |
| Phase 4-6 | Backend 报价 + Admin 前端 + DApp 数据接入 |
| Phase 7-9 | 安全收口 / 全量验证 / 测试网部署 |

## 信息来源
- contracts-v2/src/*.sol, contracts-v2/broadcast/*/97/run-latest.json
- docs/current/go-backend-v2/（README, 01-09, 22, 23, runtime-gate/, contracts/, sql/）
- docs/current/go-backend-v2/contracts/BSC_TESTNET_DEPLOYMENT_BASELINE.md
- apps/dapp/src/features/wallet/deployed.ts
- backend/app/Modules/, packages/ui/
- docs/current/go-backend-v2/sql/0001_binggoplus_v2_schema.sql
- docs/current/go-backend-v2/sql/0002_binggoplus_v2_runtime_privileges.sql
