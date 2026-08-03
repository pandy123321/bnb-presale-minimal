# 后端与Chain Worker开发计划

```text
Document ID: PANGU2-BACKEND-PLAN-1.0
Version: V1.0
Status: PLANNING_BASELINE
Project ID: PANGU2
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Observed Base SHA: c8eaedbc47205194c518f2ff6a1415e3ff5abe16
Project Root: hub/pangu2/
Target Environment: LOCAL / CI / BSC_TESTNET / STAGING
BSC_MAINNET: NO-GO
Automatic Merge: FORBIDDEN
Automatic Deployment: FORBIDDEN
Prepared At: 2026-08-01
```

> `Observed Base SHA` 是本文件生成时观察值。每个Task开始前必须重新读取Base Branch Tip并固定 `Task Start Base SHA`。

## 1. 技术边界

```text
services/api/          Laravel模块化单体、Horizon业务Job
services/chain-worker/ TypeScript链上原始事实Worker
```

Chain Worker唯一负责：

- Blocks、Transactions、Receipts、Logs；
- canonical/finality/reorg；
- chain cursor；
- raw fact outbox。

Laravel/Horizon唯一负责：

- 钱包认证、RBAC和审计；
- Contract Registry读模型；
- 用户和Admin API；
- 业务投影；
- Snapshot、排名、Merkle和Proof；
- 业务重试和补偿。

两个系统不得处理同一事实任务。

## 2. 后端任务顺序

```text
B01 API工程骨架
→ B02 Wallet Auth与Session
→ B03 Registry/System Status
→ B04 Quote/Transaction API
→ B05 Chain Raw Facts与投影
→ B06 Dividend/Buyback/Locker
→ B07 Admin/RBAC/Audit
```

B01-B03可以在合约未完成时基于Schema和Mock进行。B04正式LIVE受PB-S1 preview ABI阻塞。B06正式LIVE受Epoch、Merkle和Locker规则阻塞。

## 3. 模块建议

```text
app/Modules/Core/
├─ Auth
├─ Wallet
├─ Chain
├─ ContractRegistry
├─ Transaction
├─ RBAC
├─ Audit
└─ Support

app/Modules/Pangu2/
├─ Trade
├─ CostBasis
├─ Dividend
├─ Buyback
├─ Locker
├─ Projection
├─ Api
└─ Admin
```

## 4. 后端Definition of Done

- OpenAPI实现或明确501/503；
- 输入验证和稳定错误码；
- Amount/Chain/Address单位一致；
- 幂等键；
- 分页；
- 新鲜度和区块信息；
- 审计；
- 单元/Feature/Contract测试；
- Migration前向兼容；
- 不存在后台代签；
- 不复制链上判税。
