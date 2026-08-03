# 前后端同步点记录模板

```text
Document ID: PANGU2-FB-SYNC-RECORD-1.0
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

```text
Sync Point ID:
Slice:
OpenAPI SHA:
API Types Package Version:
State Machine SHA:
Error Catalog SHA:
ABI/Event SHA:
Backend Head SHA:
DApp Head SHA:
Admin Head SHA:
Mock Server Head SHA:
Compatibility Result:
Breaking Change:
Affected Tasks:
Change Request:
Approved By:
Effective From:
```

## Verification

- Backend实现满足OpenAPI；
- DApp/Admin仅使用生成Client；
- Mock Example满足Schema；
- 数据状态和错误码一致；
- 金额单位一致；
- Breaking Change已升级版本；
- 旧Review是否SUPERSEDED已明确。
