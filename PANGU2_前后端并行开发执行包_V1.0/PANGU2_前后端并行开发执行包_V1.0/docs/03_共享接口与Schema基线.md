# 共享接口与Schema基线

```text
Document ID: PANGU2-SHARED-SCHEMA-1.0
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

## 1. 文件位置

```text
hub/pangu2/docs/schemas/openapi/pangu2-api-v1.yaml
hub/pangu2/docs/schemas/events/pangu2-events-v1.json
hub/pangu2/docs/schemas/state-machines/pangu2-state-machines-v1.json
hub/pangu2/docs/schemas/errors/pangu2-errors-v1.json
hub/pangu2/docs/schemas/mock/pangu2-mock-v1.json
hub/pangu2/packages/api-types/**
hub/pangu2/packages/domain/**
```

## 2. 通用响应Envelope

成功：

```json
{
  "data": {},
  "meta": {
    "project": "PANGU2",
    "environment": "LOCAL",
    "chain_id": 31337,
    "data_status": "MOCK_DATA",
    "block_number": null,
    "generated_at": "2026-08-01T00:00:00Z",
    "schema_version": "1.0.0"
  },
  "error": null
}
```

失败：

```json
{
  "data": null,
  "meta": {
    "project": "PANGU2",
    "environment": "LOCAL",
    "chain_id": 31337,
    "data_status": "UNAVAILABLE",
    "block_number": null,
    "generated_at": "2026-08-01T00:00:00Z",
    "schema_version": "1.0.0"
  },
  "error": {
    "code": "QUOTE_UNAVAILABLE",
    "message": "Quote is unavailable.",
    "retryable": true,
    "details": {}
  }
}
```

## 3. 金额与地址

- 金额全部使用十进制整数字符串；
- 不在JSON使用浮点金额；
- EVM地址使用校验或规范化小写策略，Schema必须固定；
- Chain ID使用整数；
- block number可用十进制字符串避免跨语言精度问题；
- 时间使用RFC3339 UTC。

## 4. Data Status

```text
MOCK_DATA
SYNCING
LIVE
STALE
DEGRADED
UNAVAILABLE
```

前端必须显示非LIVE状态，不能隐藏。

## 5. 状态机

### Wallet

```text
DISCONNECTED → CONNECTING → CONNECTED
CONNECTED → DISCONNECTED
任何状态 → ERROR
```

### Network

```text
UNKNOWN → SUPPORTED / UNSUPPORTED / SWITCHING / ERROR
```

### Quote

```text
IDLE → LOADING → READY → EXPIRED
LOADING → FAILED
READY → LOADING
```

### Approval

```text
NOT_REQUIRED / REQUIRED
REQUIRED → SIGNATURE_PENDING → SUBMITTED
SUBMITTED → CONFIRMED / FAILED
SIGNATURE_PENDING → REJECTED
```

### Chain Transaction

```text
CREATED → SUBMITTED → PENDING
PENDING → CONFIRMED / FAILED / REPLACED / DROPPED
CONFIRMED → REORGED
REORGED → PENDING / CONFIRMED / FAILED
```

### Claim

```text
NOT_AVAILABLE → AVAILABLE
AVAILABLE → SIGNATURE_PENDING → SUBMITTED
SUBMITTED → CLAIMED / FAILED / REORG_RECHECK
```

## 6. 首批API

### Public/System

```text
GET /api/v1/projects/pangu2/config
GET /api/v1/projects/pangu2/system-status
GET /api/v1/projects/pangu2/contracts
```

### Auth

```text
POST /api/v1/projects/pangu2/auth/nonce
POST /api/v1/projects/pangu2/auth/verify
POST /api/v1/projects/pangu2/auth/logout
```

### Wallet

```text
GET /api/v1/projects/pangu2/wallets/{address}/summary
GET /api/v1/projects/pangu2/wallets/{address}/transactions
```

### Quote

```text
POST /api/v1/projects/pangu2/quotes/buy
POST /api/v1/projects/pangu2/quotes/sell
```

Quote API只能代理/格式化合约preview或返回Mock/Unavailable，不得在后端复制判税公式。

### Dividend/Support

```text
GET /api/v1/projects/pangu2/dividend/epochs/current
GET /api/v1/projects/pangu2/dividend/epochs/{epochId}
GET /api/v1/projects/pangu2/dividend/epochs/{epochId}/proof/{address}
GET /api/v1/projects/pangu2/buybacks
GET /api/v1/projects/pangu2/locker/batches
```

### Admin

```text
POST /admin-api/v1/projects/pangu2/auth/login
GET  /admin-api/v1/projects/pangu2/dashboard
GET  /admin-api/v1/projects/pangu2/contracts
GET  /admin-api/v1/projects/pangu2/jobs
GET  /admin-api/v1/projects/pangu2/audit-logs
```

危险写操作必须在独立Schema和权限Decision后增加。

## 7. 兼容性

- 同一Major版本允许新增可选字段；
- 删除字段、改变类型、单位或语义属于Breaking Change；
- Breaking Change升级Major并创建Change Request；
- 前端不得依赖未进入Schema的临时字段；
- 生成文件不得手工编辑。
