# 运营Admin开发计划

```text
Document ID: PANGU2-ADMIN-PLAN-1.0
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

## 1. 页面

```text
登录
仪表盘
合约注册表
链上同步状态
交易监控
Dividend Epoch
Buyback/Locker
Jobs与重试
审计日志
系统状态
```

## 2. Admin任务

```text
A01 工程骨架和布局
A02 Session/RBAC
A03 Dashboard/Registry/Transactions
A04 Epoch/Jobs/Audit
A05 危险操作保护与E2E
```

## 3. 硬规则

- 不改用户资产、成本和分配；
- 不提供SupportPool普通提现；
- 不原位修改已发布Root；
- 不直接持有生产签名权限；
- 写操作必须二次确认并显示环境、链、合约、金额和calldata摘要；
- 测试网危险操作优先生成提案或受限任务，不隐藏权限边界；
- 所有操作有审计记录。

## 4. 并行

A01可与B01/F01并行；A02等待B02的Admin Auth Schema；A03与B03/B05并行；A04与B06/B07并行。
