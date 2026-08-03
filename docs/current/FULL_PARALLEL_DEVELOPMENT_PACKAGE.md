# PANGU2前后端并行开发完整文档

===== BEGIN FILE: README_START_HERE.md =====
# PANGU2前后端并行开发执行包

```text
Document ID: PANGU2-FB-SYNC-PACK-1.0
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

## 1. 目标

在不破坏盘古2治理和参数边界的前提下，同步开发：

- Laravel API与业务Job；
- TypeScript Chain Worker；
- 用户DApp；
- 运营Admin；
- 共享OpenAPI、类型、状态机和Mock Server；
- LOCAL、CI、BSC_TESTNET和STAGING联调。

## 2. 核心方法

```text
治理与工具链
→ 共享Schema和Mock
→ 前端/后端骨架并行
→ 业务纵切片并行
→ 合约ABI/Event接入
→ BSC_TESTNET端到端
```

前端不自行实现税率、盈利判定、排名或可领取金额公式。后端不代替用户签名，不把未批准合约规则写成正式业务逻辑。

## 3. 开发流

| Track | 范围 | 主要目录 |
|---|---|---|
| Shared | OpenAPI、API Types、状态机、Mock、错误码 | `packages/**`, `docs/schemas/**` |
| Backend | Laravel API、Horizon业务Job | `services/api/**` |
| Chain | 原始链上事实、Reorg、Cursor | `services/chain-worker/**` |
| DApp | 用户钱包、交易、分红、托底、我的 | `apps/dapp/**` |
| Admin | RBAC、仪表盘、Epoch、任务、审计 | `apps/admin/**` |
| Integration | Contract/API/UI/Testnet E2E | `docs/evidence/**`, 各模块测试 |

## 4. 立即执行顺序

1. 完成并合并V3.1/V1.1治理基线任务；
2. P2-X01固定共享接口候选；
3. P2-X02建立Mock Server与生成类型；
4. 后端P2-B01和前端P2-F01、P2-A01并行；
5. 按纵切片逐项联调；
6. PB-S1合约ABI/Event可用后替换Mock链上源；
7. P2-I04完成BSC_TESTNET闭环。

## 5. 当前门控

```text
Document Readiness: READY
Parallel Development Plan Readiness: READY
Product Task Start Gate: NEEDS_CONFIRMATION
Reason:
- V3.1/V1.1基线需先进入仓库并固定SHA；
- 工具链、Lockfile和LOCAL/CI未关闭；
- Parameter Freeze与Quote Profile尚未完整签署。
```

因此本包是可执行Task Spec集合，但每个Task仍需项目协调Agent在实际Base SHA下单独输出 `Task Start Gate: GO`。

## 6. 使用入口

- 总计划：`docs/01_前后端并行开发总计划.md`
- 依赖图：`docs/02_阶段依赖与并行矩阵.md`
- 共享契约：`docs/03_共享接口与Schema基线.md`
- 后端计划：`docs/04_后端与ChainWorker开发计划.md`
- DApp计划：`docs/05_DApp开发计划.md`
- Admin计划：`docs/06_Admin开发计划.md`
- 联调验收：`docs/07_联调测试与验收计划.md`
- Task索引：`docs/08_Task索引与Gate.md`
- Cursor提示词：`prompts/`
===== END FILE: README_START_HERE.md =====

===== BEGIN FILE: docs/01_前后端并行开发总计划.md =====
# 前后端并行开发总计划

```text
Document ID: PANGU2-FB-MASTER-1.0
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

## 1. 并行原则

### 1.1 Contract First，不是 Backend First

前后端共同依赖以下共享契约：

```text
OpenAPI Schema
API Error Catalog
State Machine Schema
Contract Registry Schema
ABI/Event Schema
Mock Dataset Schema
Data Freshness Schema
```

共享契约由Shared Track维护，前端和后端都不得在各自代码中建立第二套定义。

### 1.2 Mock先行但必须显式

合约或后端尚未完成时允许：

```text
data_status = MOCK_DATA
source = mock
```

不得将模拟数据描述为链上实时结果。正式联调后依次切换：

```text
MOCK_DATA → SYNCING → LIVE
```

### 1.3 前端不复制业务公式

- 不计算用户应适用4%还是10%；
- 不计算成本基础；
- 不计算最终分红排名；
- 不生成Merkle Root或Proof；
- 不计算SupportPool可提现金额；
- 所有正式结果来自合约preview、API投影或Proof。

## 2. 开发波次

### Wave 0：治理与工程基础

目标：

- V3.1/V1.1进入仓库；
- 精确版本和Lockfile固定；
- 目录、LOCAL、CI和Required Checks建立；
- Schema文件位置和Owner固定。

输出：

```text
Repository Base SHA
Ruleset SHA
Spec SHA
Toolchain/Lockfile SHA
LOCAL启动命令
CI Required Check Manifest
```

### Wave 1：共享契约

并行前必须先完成：

- P2-X01共享OpenAPI和状态机；
- P2-X02生成类型、Mock Server和示例；
- P2-X03Schema Contract Test。

此后允许Backend、DApp和Admin骨架并行。

### Wave 2：应用骨架并行

同步执行：

```text
Backend P2-B01
DApp P2-F01
Admin P2-A01
```

关闭条件：

- 都能在LOCAL启动；
- 都显示版本、环境和数据状态；
- 前端只使用生成API Client；
- Backend返回统一Envelope；
- CI可独立构建各模块。

### Wave 3：身份与基础数据纵切片

同步执行：

```text
P2-B02 Wallet Auth
P2-B03 Contract Registry/System Status
P2-F02 Wallet/Network
P2-F03 API Client/Global State
P2-A02 Admin Auth/RBAC
```

联调输出：

- 钱包签名登录；
- 错误网络；
- Session和RBAC；
- Contract Registry；
- 系统状态和新鲜度。

### Wave 4：交易纵切片

同步执行：

```text
P2-B04 Quote/Transaction API
P2-B05 Chain Transaction Projection
P2-F04 Trade UI
P2-F05 Transaction State Machine
P2-A03 Transaction/Contract Monitoring
```

合约未解锁时：

- Buy/Sell Quote只返回Mock或 `UNAVAILABLE`；
- 不实现后端判税公式；
- UI状态和错误流可以先完成。

### Wave 5：分红、回购与Locker纵切片

同步执行：

```text
P2-B06 Dividend/Buyback/Locker API
P2-F06 Dividend/Support/My Pages
P2-A04 Epoch/Job/Audit
```

需要PB-S1 ABI/Event和Signed Parameter Freeze后才能切换LIVE。

### Wave 6：真实合约与测试网

同步执行：

- ABI/Event生成和版本绑定；
- Chain Worker真实索引；
- Backend投影重建；
- DApp钱包真实交易；
- Admin真实只读和受控操作；
- Testnet E2E、故障和恢复。

## 3. 每个纵切片完成顺序

```text
Schema Candidate
→ Mock Example
→ Backend Implementation
→ Generated Client
→ Frontend UI
→ Contract Test
→ Integration Test
→ Review
```

## 4. 同步点

| Sync Point | 必须一致 |
|---|---|
| SP-01 | OpenAPI SHA、API Types版本 |
| SP-02 | 状态枚举和错误码 |
| SP-03 | Contract Registry和Chain ID |
| SP-04 | Quote字段和金额单位 |
| SP-05 | Transaction状态机 |
| SP-06 | Dividend Epoch/Proof字段 |
| SP-07 | ABI/Event Schema版本 |
| SP-08 | Testnet deployment manifest |

任一同步点变化必须创建Change Request，并标记受影响任务和旧审核是否失效。

## 5. 合并策略

推荐：

- Shared Schema独立PR优先合并；
- Backend、DApp、Admin使用独立Draft PR；
- 纵切片完成后由Integration PR验证；
- 禁止将前后端大量无关功能放在同一PR；
- Schema变更先合并，消费者PR再rebase或merge Base更新后重新审核。
===== END FILE: docs/01_前后端并行开发总计划.md =====

===== BEGIN FILE: docs/02_阶段依赖与并行矩阵.md =====
# 阶段依赖与并行矩阵

```text
Document ID: PANGU2-FB-DEPS-1.0
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

## 1. 总依赖图

```text
PB-S0 Governance/Toolchain/LOCAL-CI
              ↓
      Shared Schema X01-X03
       ↙        ↓        ↘
 Backend B01   DApp F01   Admin A01
       ↘        ↓        ↙
       Identity & Config Slice
                 ↓
          Trade Slice (Mock)
                 ↓
     PB-S1 ABI/Event/Deployment
                 ↓
          Trade Slice (LIVE)
                 ↓
      Dividend/Buyback/Locker
                 ↓
      BSC_TESTNET Integration
```

## 2. 并行矩阵

| Task组 | 可否并行 | 条件 |
|---|---|---|
| B01 / F01 / A01 | 可以 | X01、X02完成 |
| B02 / B03 / F02 / F03 / A02 | 可以 | Auth和Envelope Schema固定 |
| B04 / B05 / F04 / F05 / A03 | 条件并行 | Quote和Tx Schema固定；可先Mock |
| B06 / F06 / A04 | 条件并行 | Epoch/Proof/Buyback Schema固定 |
| Chain Worker真实索引 / UI真实交易 | 不可无ABI并行 | ABI/Event Schema和Deployment Manifest固定 |
| BSC_TESTNET E2E | 不可提前 | 必要任务MERGED、Integration Gate GO |

## 3. 并行冲突规则

以下情况不能并行修改：

- 同一OpenAPI文件；
- 同一状态枚举；
- 同一生成Client输出；
- 同一数据库Migration序列；
- 同一Contract Registry配置；
- 同一CI Workflow。

必须指定唯一Owner，其余任务只消费生成结果。

## 4. 任务Owner

| 事实来源 | 唯一Owner |
|---|---|
| OpenAPI | Shared/Backend Schema Task |
| API Types | Generator |
| Contract ABI/Event | PB-S1 Schema Task |
| Chain Raw Facts | Chain Worker |
| Business Projection | Laravel/Horizon |
| UI State | DApp/Admin各自，但枚举来自Shared |
| Economic Parameters | Signed Parameter Freeze |
| Merkle Root/Proof | Dividend Job |
| Review Verdict | Review Agent |
| Merge/Release | Human Project Owner |
===== END FILE: docs/02_阶段依赖与并行矩阵.md =====

===== BEGIN FILE: docs/03_共享接口与Schema基线.md =====
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
===== END FILE: docs/03_共享接口与Schema基线.md =====

===== BEGIN FILE: docs/04_后端与ChainWorker开发计划.md =====
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
===== END FILE: docs/04_后端与ChainWorker开发计划.md =====

===== BEGIN FILE: docs/05_DApp开发计划.md =====
# 用户DApp开发计划

```text
Document ID: PANGU2-DAPP-PLAN-1.0
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
/
├─ 首页
├─ 交易
├─ 分红
├─ 托底
└─ 我的
```

## 2. DApp任务

```text
F01 Vue工程、路由、设计系统
F02 Wallet与Network
F03 API Client与全局状态
F04 Trade页面与Quote
F05 Approval/Signature/Transaction状态机
F06 Dividend/Support/My
F07 Error/Recovery/Accessibility/E2E
```

## 3. 并行规则

F01可与B01并行；F02/F03可与B02/B03并行；F04/F05可先用Mock与B04/B05并行；F06正式LIVE等待B06和PB-S1事件。

## 4. 硬规则

- 不提供4%/10%选择；
- 不在前端判定盈利；
- `previewSell`结果来自合约或API代理；
- 授权和卖出显示为两笔独立交易；
- 报价显示引用区块、过期时间、数据状态；
- 买入MAX预留Gas；
- 估算排名、结算排名和可领取结果分开；
- 非LIVE数据显式显示；
- 不显示未批准的固定锁仓期限；
- 用户资产操作必须由钱包签名。

## 5. DApp Definition of Done

- Mobile-first；
- Wallet/Network/Quote/Approval/Signature/Tx/Claim状态覆盖；
- 用户拒签、交易替换、丢弃、重组和数据STALE有明确UI；
- API Client来自生成包；
- Mock与LIVE切换不改变页面业务逻辑；
- 单元、组件、构建和E2E通过。
===== END FILE: docs/05_DApp开发计划.md =====

===== BEGIN FILE: docs/06_Admin开发计划.md =====
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
===== END FILE: docs/06_Admin开发计划.md =====

===== BEGIN FILE: docs/07_联调测试与验收计划.md =====
# 联调测试与验收计划

```text
Document ID: PANGU2-INTEGRATION-PLAN-1.0
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

## 1. 联调层级

### L1 Schema Contract

- OpenAPI校验；
- 生成类型无Diff；
- Mock Example满足Schema；
- 状态枚举一致；
- 错误码完整。

### L2 Module Integration

- DApp对Mock API；
- Admin对Mock Admin API；
- Backend对Mock Chain Adapter；
- Worker对Anvil测试合约。

### L3 Local Full Stack

```text
Anvil
+ PostgreSQL
+ Redis
+ API
+ Chain Worker
+ Horizon
+ DApp
+ Admin
```

### L4 BSC_TESTNET

真实钱包、真实交易、真实索引、真实投影和真实Proof。

## 2. 纵切片验收

| Slice | Backend | Frontend | Evidence |
|---|---|---|---|
| Config | config/status/contracts | 环境与网络显示 | API/截图/测试 |
| Auth | nonce/verify/session | 钱包登录 | 签名与重放测试 |
| Wallet | summary/history | 我的页面 | 数据一致性 |
| Trade | quote/tx projection | 交易与状态机 | preview/receipt |
| Dividend | epoch/proof | 分红页面/claim | root/proof/tx |
| Support | buyback/locker | 托底页面 | event/projection |
| Admin | dashboard/jobs/audit | Admin页面 | RBAC/audit |

## 3. Integration Gate GO条件

- 必要Task MERGED；
- OpenAPI/ABI/Event SHA固定；
- Required Checks绑定Merged Commit；
- Deployment Manifest完整；
- Mock关键路径已替换为LIVE；
- Blocking Finding关闭；
- 用户钱包签名路径验证；
- Reorg/RPC故障/Worker重启测试；
- Rollback与停用Runbook；
- Evidence Manifest完整。

## 4. 失败恢复

- RPC失败：指数退避、DEGRADED状态；
- Reorg：raw facts标记removed/canonical并重建投影；
- API不可用：前端显示UNAVAILABLE而不是旧数据冒充LIVE；
- Quote过期：强制重新获取；
- Tx dropped/replaced：状态恢复；
- Worker重启：从持久Cursor继续；
- Merkle错误：按批准流程取消或Correction Epoch。
===== END FILE: docs/07_联调测试与验收计划.md =====

===== BEGIN FILE: docs/08_Task索引与Gate.md =====
# Task索引与Gate

```text
Document ID: PANGU2-FB-TASK-INDEX-1.0
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

## 1. 任务清单

| Task ID | Title | Stream | Planning Status | File |
|---|---|---|---|---|
| P2-A01 | Admin工程骨架与布局 | admin | READY_AFTER_X02 | `tasks/admin/P2-A01.md` |
| P2-A02 | Admin认证与RBAC UI | admin | BLOCKED_BY_A01_B02 | `tasks/admin/P2-A02.md` |
| P2-A03 | Dashboard、Registry与交易监控 | admin | BLOCKED_BY_A01_B03_B05 | `tasks/admin/P2-A03.md` |
| P2-A04 | Epoch、Jobs与审计页面 | admin | BLOCKED_BY_A02_B06_B07 | `tasks/admin/P2-A04.md` |
| P2-A05 | Admin Closeout与E2E | admin | BLOCKED_PREVIOUS | `tasks/admin/P2-A05.md` |
| P2-B01 | Laravel API与Horizon工程骨架 | backend | READY_AFTER_X02 | `tasks/backend/P2-B01.md` |
| P2-B02 | 钱包签名认证与Session | backend | BLOCKED_BY_B01 | `tasks/backend/P2-B02.md` |
| P2-B03 | Contract Registry与System Status | backend | BLOCKED_BY_B01 | `tasks/backend/P2-B03.md` |
| P2-B04 | Quote与用户交易API | backend | BLOCKED_REQUIREMENT | `tasks/backend/P2-B04.md` |
| P2-B05 | Chain Worker与交易投影 | backend | BLOCKED_SCHEMA | `tasks/backend/P2-B05.md` |
| P2-B06 | Dividend、Buyback与Locker读模型 | backend | BLOCKED_REQUIREMENT | `tasks/backend/P2-B06.md` |
| P2-B07 | Admin RBAC、Jobs与审计 | backend | BLOCKED_BY_B02_B06 | `tasks/backend/P2-B07.md` |
| P2-F01 | DApp工程骨架与设计系统 | dapp | READY_AFTER_X02 | `tasks/dapp/P2-F01.md` |
| P2-F02 | 钱包连接与Network状态 | dapp | BLOCKED_BY_F01 | `tasks/dapp/P2-F02.md` |
| P2-F03 | 生成API Client与全局数据状态 | dapp | BLOCKED_BY_F01_X02 | `tasks/dapp/P2-F03.md` |
| P2-F04 | 交易页面与Quote展示 | dapp | BLOCKED_BY_F02_F03 | `tasks/dapp/P2-F04.md` |
| P2-F05 | Approval、Signature与交易状态机 | dapp | BLOCKED_ABI | `tasks/dapp/P2-F05.md` |
| P2-F06 | 分红、托底与我的页面 | dapp | BLOCKED_API | `tasks/dapp/P2-F06.md` |
| P2-F07 | DApp Closeout与E2E | dapp | BLOCKED_PREVIOUS | `tasks/dapp/P2-F07.md` |
| P2-I01 | Local Full Stack编排 | integration | BLOCKED_FOUNDATION | `tasks/integration/P2-I01.md` |
| P2-I02 | Mock纵切片端到端 | integration | BLOCKED_X_B_F_A | `tasks/integration/P2-I02.md` |
| P2-I03 | Anvil合约与应用集成 | integration | BLOCKED_PB_S1 | `tasks/integration/P2-I03.md` |
| P2-I04 | BSC_TESTNET完整闭环 | integration | BLOCKED_INTEGRATION_GATE | `tasks/integration/P2-I04.md` |
| P2-I05 | STAGING发布与PB-S6 Closeout | integration | BLOCKED_I04 | `tasks/integration/P2-I05.md` |
| P2-X01 | 共享OpenAPI、错误码和状态机候选 | shared | READY_AFTER_PB-S0 | `tasks/shared/P2-X01.md` |
| P2-X02 | 生成API Types、Client与Mock Server | shared | BLOCKED_BY_X01 | `tasks/shared/P2-X02.md` |
| P2-X03 | 共享契约测试与变更控制 | shared | BLOCKED_BY_X02 | `tasks/shared/P2-X03.md` |

## 2. 当前可启动分类

```text
当前GO:
- 仅文档审阅、治理基线采用和本并行开发包落库准备。

治理和工具链关闭后可GO:
- P2-X01
- P2-X02
- P2-B01
- P2-F01
- P2-A01

可Mock并行、LIVE受阻:
- P2-B04
- P2-F04
- P2-F05部分UI状态
- P2-B06
- P2-F06
- P2-A04

BLOCKED:
- 依赖PB-S1 ABI/Event或Signed Parameter Freeze的LIVE任务；
- BSC_TESTNET Integration；
- BSC_MAINNET全部任务。
```

## 3. Task Start Gate规则

每个任务必须单独固定：

- Task Start Base SHA；
- Current Base Branch Tip SHA；
- Spec/Ruleset/Workflow/Lockfile SHA；
- Allowed/Forbidden Paths；
- Active Decision与Parameter Freeze；
- Dependencies；
- Required Checks；
- Duplicate Task/PR/Finding；
- Closure Conditions。

本索引不是Task Start Gate。
===== END FILE: docs/08_Task索引与Gate.md =====

===== BEGIN FILE: tasks/admin/P2-A01.md =====
# P2-A01 — Admin工程骨架与布局

```text
Project ID: PANGU2
Stream: ADMIN
Task ID: P2-A01
Task Status: READY_AFTER_X02
Task Start Gate: <TO_BE_SET_BY_COORDINATOR>
Block Reason: NONE
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Task Start Base SHA: <TO_BE_FIXED_AT_TASK_START>
Current Base Branch Tip SHA: <TO_BE_FIXED_AT_TASK_START>
Merge Base SHA: <TO_BE_FIXED_AFTER_BRANCH>
Previous Reviewed Head SHA: NONE
Current Head SHA: <TO_BE_FIXED_AFTER_COMMIT>
Spec SHA: <TO_BE_FIXED_AT_TASK_START>
Ruleset SHA: <TO_BE_FIXED_AT_TASK_START>
CI Workflow SHA: <TO_BE_FIXED_AT_TASK_START>
Dependency Lockfile SHA: <TO_BE_FIXED_AT_TASK_START>
Evidence Manifest SHA: <TO_BE_FIXED_AT_CLOSEOUT>
```

## Goal

建立Vue/TS/Vite/Ant Design Vue Admin工程、路由、布局和构建。

## Dependencies

`P2-X02`

## Allowed Paths

```text
hub/pangu2/apps/admin/**
```

## Forbidden Paths

```text
hub/pixiu1/**
未在Allowed Paths列出的其他Stream目录
生产Secret和环境凭证
主网配置或写链脚本
```

## Requirements

- 环境与项目明显显示。
- Generated Admin Client。
- 无危险操作。
- 统一错误和Data Status。

## Required Tests

lint；typecheck；unit；build；router smoke。

## Outputs

Admin骨架。

## Closure Conditions

- Requirements全部完成；
- Required Tests绑定Current Head SHA；
- 只修改Allowed Paths；
- 无Blocking Finding；
- Evidence Manifest完整；
- Review APPROVED后进入MERGE_READY；
- 人工决定合并后才能标MERGED。

## Next Role

Review Agent。
===== END FILE: tasks/admin/P2-A01.md =====

===== BEGIN FILE: tasks/admin/P2-A02.md =====
# P2-A02 — Admin认证与RBAC UI

```text
Project ID: PANGU2
Stream: ADMIN
Task ID: P2-A02
Task Status: BLOCKED_BY_A01_B02
Task Start Gate: <TO_BE_SET_BY_COORDINATOR>
Block Reason: NONE
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Task Start Base SHA: <TO_BE_FIXED_AT_TASK_START>
Current Base Branch Tip SHA: <TO_BE_FIXED_AT_TASK_START>
Merge Base SHA: <TO_BE_FIXED_AFTER_BRANCH>
Previous Reviewed Head SHA: NONE
Current Head SHA: <TO_BE_FIXED_AFTER_COMMIT>
Spec SHA: <TO_BE_FIXED_AT_TASK_START>
Ruleset SHA: <TO_BE_FIXED_AT_TASK_START>
CI Workflow SHA: <TO_BE_FIXED_AT_TASK_START>
Dependency Lockfile SHA: <TO_BE_FIXED_AT_TASK_START>
Evidence Manifest SHA: <TO_BE_FIXED_AT_CLOSEOUT>
```

## Goal

实现登录、Session、角色、无权限状态和路由保护。

## Dependencies

`P2-A01`, Admin Auth API

## Allowed Paths

```text
hub/pangu2/apps/admin/src/features/auth/**
hub/pangu2/apps/admin/src/router/**
hub/pangu2/apps/admin/tests/**
```

## Forbidden Paths

```text
hub/pixiu1/**
未在Allowed Paths列出的其他Stream目录
生产Secret和环境凭证
主网配置或写链脚本
```

## Requirements

- 权限来自API。
- 前端隐藏不等于后端授权。
- Session过期安全退出。
- 不保存高敏凭证。

## Required Tests

login/logout；expired；roles；forbidden routes；API 401/403。

## Outputs

Admin认证和权限UI。

## Closure Conditions

- Requirements全部完成；
- Required Tests绑定Current Head SHA；
- 只修改Allowed Paths；
- 无Blocking Finding；
- Evidence Manifest完整；
- Review APPROVED后进入MERGE_READY；
- 人工决定合并后才能标MERGED。

## Next Role

Review Agent。
===== END FILE: tasks/admin/P2-A02.md =====

===== BEGIN FILE: tasks/admin/P2-A03.md =====
# P2-A03 — Dashboard、Registry与交易监控

```text
Project ID: PANGU2
Stream: ADMIN
Task ID: P2-A03
Task Status: BLOCKED_BY_A01_B03_B05
Task Start Gate: <TO_BE_SET_BY_COORDINATOR>
Block Reason: NONE
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Task Start Base SHA: <TO_BE_FIXED_AT_TASK_START>
Current Base Branch Tip SHA: <TO_BE_FIXED_AT_TASK_START>
Merge Base SHA: <TO_BE_FIXED_AFTER_BRANCH>
Previous Reviewed Head SHA: NONE
Current Head SHA: <TO_BE_FIXED_AFTER_COMMIT>
Spec SHA: <TO_BE_FIXED_AT_TASK_START>
Ruleset SHA: <TO_BE_FIXED_AT_TASK_START>
CI Workflow SHA: <TO_BE_FIXED_AT_TASK_START>
Dependency Lockfile SHA: <TO_BE_FIXED_AT_TASK_START>
Evidence Manifest SHA: <TO_BE_FIXED_AT_CLOSEOUT>
```

## Goal

实现系统状态、合约注册表、同步状态、交易监控和新鲜度。

## Dependencies

`P2-A01`, B03/B05 API

## Allowed Paths

```text
hub/pangu2/apps/admin/src/features/dashboard/**
hub/pangu2/apps/admin/src/features/contracts/**
hub/pangu2/apps/admin/src/features/transactions/**
hub/pangu2/apps/admin/tests/**
```

## Forbidden Paths

```text
hub/pixiu1/**
未在Allowed Paths列出的其他Stream目录
生产Secret和环境凭证
主网配置或写链脚本
```

## Requirements

- 只读优先。
- 地址、chain、ABI版本、部署区块显示。
- Reorg/STALE/DEGRADED可见。
- 不提供任意合约调用。

## Required Tests

mock/live；empty；stale；reorg；pagination；role visibility。

## Outputs

监控页面。

## Closure Conditions

- Requirements全部完成；
- Required Tests绑定Current Head SHA；
- 只修改Allowed Paths；
- 无Blocking Finding；
- Evidence Manifest完整；
- Review APPROVED后进入MERGE_READY；
- 人工决定合并后才能标MERGED。

## Next Role

Review Agent。
===== END FILE: tasks/admin/P2-A03.md =====

===== BEGIN FILE: tasks/admin/P2-A04.md =====
# P2-A04 — Epoch、Jobs与审计页面

```text
Project ID: PANGU2
Stream: ADMIN
Task ID: P2-A04
Task Status: BLOCKED_BY_A02_B06_B07
Task Start Gate: <TO_BE_SET_BY_COORDINATOR>
Block Reason: DEPENDENCY: Signed governance/epoch permissions
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Task Start Base SHA: <TO_BE_FIXED_AT_TASK_START>
Current Base Branch Tip SHA: <TO_BE_FIXED_AT_TASK_START>
Merge Base SHA: <TO_BE_FIXED_AFTER_BRANCH>
Previous Reviewed Head SHA: NONE
Current Head SHA: <TO_BE_FIXED_AFTER_COMMIT>
Spec SHA: <TO_BE_FIXED_AT_TASK_START>
Ruleset SHA: <TO_BE_FIXED_AT_TASK_START>
CI Workflow SHA: <TO_BE_FIXED_AT_TASK_START>
Dependency Lockfile SHA: <TO_BE_FIXED_AT_TASK_START>
Evidence Manifest SHA: <TO_BE_FIXED_AT_CLOSEOUT>
```

## Goal

实现Epoch状态、Root提案状态、Jobs、重试和审计日志。

## Dependencies

`P2-A02`, B06/B07 API

## Allowed Paths

```text
hub/pangu2/apps/admin/src/features/epochs/**
hub/pangu2/apps/admin/src/features/jobs/**
hub/pangu2/apps/admin/src/features/audit/**
hub/pangu2/apps/admin/tests/**
```

## Forbidden Paths

```text
hub/pixiu1/**
未在Allowed Paths列出的其他Stream目录
生产Secret和环境凭证
主网配置或写链脚本
```

## Requirements

- 不直接改Root分配。
- 重试需二次确认和Idempotency。
- 显示environment/contract/amount/calldata摘要。
- 所有动作展示审计ID。

## Required Tests

RBAC；retry confirm；duplicate retry；audit；danger summary；forbidden operations。

## Outputs

运营工作流页面。

## Closure Conditions

- Requirements全部完成；
- Required Tests绑定Current Head SHA；
- 只修改Allowed Paths；
- 无Blocking Finding；
- Evidence Manifest完整；
- Review APPROVED后进入MERGE_READY；
- 人工决定合并后才能标MERGED。

## Next Role

Review Agent。
===== END FILE: tasks/admin/P2-A04.md =====

===== BEGIN FILE: tasks/admin/P2-A05.md =====
# P2-A05 — Admin Closeout与E2E

```text
Project ID: PANGU2
Stream: ADMIN
Task ID: P2-A05
Task Status: BLOCKED_PREVIOUS
Task Start Gate: <TO_BE_SET_BY_COORDINATOR>
Block Reason: NONE
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Task Start Base SHA: <TO_BE_FIXED_AT_TASK_START>
Current Base Branch Tip SHA: <TO_BE_FIXED_AT_TASK_START>
Merge Base SHA: <TO_BE_FIXED_AFTER_BRANCH>
Previous Reviewed Head SHA: NONE
Current Head SHA: <TO_BE_FIXED_AFTER_COMMIT>
Spec SHA: <TO_BE_FIXED_AT_TASK_START>
Ruleset SHA: <TO_BE_FIXED_AT_TASK_START>
CI Workflow SHA: <TO_BE_FIXED_AT_TASK_START>
Dependency Lockfile SHA: <TO_BE_FIXED_AT_TASK_START>
Evidence Manifest SHA: <TO_BE_FIXED_AT_CLOSEOUT>
```

## Goal

完成Admin安全、错误、无障碍和测试网E2E。

## Dependencies

`P2-A01..A04`

## Allowed Paths

```text
hub/pangu2/apps/admin/**
hub/pangu2/docs/evidence/PB-S5/**
```

## Forbidden Paths

```text
hub/pixiu1/**
未在Allowed Paths列出的其他Stream目录
生产Secret和环境凭证
主网配置或写链脚本
```

## Requirements

- 无未授权入口。
- 无SupportPool提现。
- 无用户资产修改。
- 生产构建无Secret。
- 所有危险操作审计。

## Required Tests

lint；typecheck；unit；build；e2e；RBAC matrix；secret scan。

## Outputs

PB-S5 Closeout证据。

## Closure Conditions

- Requirements全部完成；
- Required Tests绑定Current Head SHA；
- 只修改Allowed Paths；
- 无Blocking Finding；
- Evidence Manifest完整；
- Review APPROVED后进入MERGE_READY；
- 人工决定合并后才能标MERGED。

## Next Role

Review Agent。
===== END FILE: tasks/admin/P2-A05.md =====

===== BEGIN FILE: tasks/backend/P2-B01.md =====
# P2-B01 — Laravel API与Horizon工程骨架

```text
Project ID: PANGU2
Stream: BACKEND
Task ID: P2-B01
Task Status: READY_AFTER_X02
Task Start Gate: <TO_BE_SET_BY_COORDINATOR>
Block Reason: NONE
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Task Start Base SHA: <TO_BE_FIXED_AT_TASK_START>
Current Base Branch Tip SHA: <TO_BE_FIXED_AT_TASK_START>
Merge Base SHA: <TO_BE_FIXED_AFTER_BRANCH>
Previous Reviewed Head SHA: NONE
Current Head SHA: <TO_BE_FIXED_AFTER_COMMIT>
Spec SHA: <TO_BE_FIXED_AT_TASK_START>
Ruleset SHA: <TO_BE_FIXED_AT_TASK_START>
CI Workflow SHA: <TO_BE_FIXED_AT_TASK_START>
Dependency Lockfile SHA: <TO_BE_FIXED_AT_TASK_START>
Evidence Manifest SHA: <TO_BE_FIXED_AT_CLOSEOUT>
```

## Goal

初始化Laravel API、模块边界、PostgreSQL、Redis/Horizon、统一Envelope、健康检查和测试结构。

## Dependencies

`P2-X02`; 精确PHP/Composer/Laravel版本和Lockfile固定

## Allowed Paths

```text
hub/pangu2/services/api/**
hub/pangu2/docs/evidence/PB-S2/P2-B01/**
```

## Forbidden Paths

```text
hub/pixiu1/**
未在Allowed Paths列出的其他Stream目录
生产Secret和环境凭证
主网配置或写链脚本
```

## Requirements

- 模块化单体。
- config/status使用共享Envelope。
- 环境标识和日志脱敏。
- Migration唯一来源。
- 不实现业务公式或写链。

## Required Tests

composer install locked；lint；unit；feature；migration fresh；health endpoint；secret scan。

## Outputs

可启动API、Horizon、健康检查、基础CI证据。

## Closure Conditions

- Requirements全部完成；
- Required Tests绑定Current Head SHA；
- 只修改Allowed Paths；
- 无Blocking Finding；
- Evidence Manifest完整；
- Review APPROVED后进入MERGE_READY；
- 人工决定合并后才能标MERGED。

## Next Role

Review Agent。
===== END FILE: tasks/backend/P2-B01.md =====

===== BEGIN FILE: tasks/backend/P2-B02.md =====
# P2-B02 — 钱包签名认证与Session

```text
Project ID: PANGU2
Stream: BACKEND
Task ID: P2-B02
Task Status: BLOCKED_BY_B01
Task Start Gate: <TO_BE_SET_BY_COORDINATOR>
Block Reason: NONE
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Task Start Base SHA: <TO_BE_FIXED_AT_TASK_START>
Current Base Branch Tip SHA: <TO_BE_FIXED_AT_TASK_START>
Merge Base SHA: <TO_BE_FIXED_AFTER_BRANCH>
Previous Reviewed Head SHA: NONE
Current Head SHA: <TO_BE_FIXED_AFTER_COMMIT>
Spec SHA: <TO_BE_FIXED_AT_TASK_START>
Ruleset SHA: <TO_BE_FIXED_AT_TASK_START>
CI Workflow SHA: <TO_BE_FIXED_AT_TASK_START>
Dependency Lockfile SHA: <TO_BE_FIXED_AT_TASK_START>
Evidence Manifest SHA: <TO_BE_FIXED_AT_CLOSEOUT>
```

## Goal

实现Nonce、EVM签名验证、Session、登出、重放保护和Admin认证基础。

## Dependencies

`P2-B01`, Auth OpenAPI

## Allowed Paths

```text
hub/pangu2/services/api/app/Modules/Core/Auth/**
hub/pangu2/services/api/app/Modules/Core/Wallet/**
hub/pangu2/services/api/routes/**
hub/pangu2/services/api/tests/**
hub/pangu2/services/api/database/migrations/**
```

## Forbidden Paths

```text
hub/pixiu1/**
未在Allowed Paths列出的其他Stream目录
生产Secret和环境凭证
主网配置或写链脚本
```

## Requirements

- Nonce一次性、过期、Domain/Chain绑定。
- 不托管私钥、不代签。
- Session安全和限流。
- 地址规范化策略与Schema一致。
- 审计登录结果。

## Required Tests

valid/invalid/replay/expired/wrong-domain/wrong-chain signatures；rate limit；session tests。

## Outputs

Auth API、Migration、审计事件和测试证据。

## Closure Conditions

- Requirements全部完成；
- Required Tests绑定Current Head SHA；
- 只修改Allowed Paths；
- 无Blocking Finding；
- Evidence Manifest完整；
- Review APPROVED后进入MERGE_READY；
- 人工决定合并后才能标MERGED。

## Next Role

Review Agent。
===== END FILE: tasks/backend/P2-B02.md =====

===== BEGIN FILE: tasks/backend/P2-B03.md =====
# P2-B03 — Contract Registry与System Status

```text
Project ID: PANGU2
Stream: BACKEND
Task ID: P2-B03
Task Status: BLOCKED_BY_B01
Task Start Gate: <TO_BE_SET_BY_COORDINATOR>
Block Reason: NONE
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Task Start Base SHA: <TO_BE_FIXED_AT_TASK_START>
Current Base Branch Tip SHA: <TO_BE_FIXED_AT_TASK_START>
Merge Base SHA: <TO_BE_FIXED_AFTER_BRANCH>
Previous Reviewed Head SHA: NONE
Current Head SHA: <TO_BE_FIXED_AFTER_COMMIT>
Spec SHA: <TO_BE_FIXED_AT_TASK_START>
Ruleset SHA: <TO_BE_FIXED_AT_TASK_START>
CI Workflow SHA: <TO_BE_FIXED_AT_TASK_START>
Dependency Lockfile SHA: <TO_BE_FIXED_AT_TASK_START>
Evidence Manifest SHA: <TO_BE_FIXED_AT_CLOSEOUT>
```

## Goal

实现环境、Chain、Contract Registry、系统状态和数据新鲜度API。

## Dependencies

`P2-B01`, Registry Schema

## Allowed Paths

```text
hub/pangu2/services/api/app/Modules/Core/Chain/**
hub/pangu2/services/api/app/Modules/Core/ContractRegistry/**
hub/pangu2/services/api/tests/**
hub/pangu2/services/api/database/migrations/**
```

## Forbidden Paths

```text
hub/pixiu1/**
未在Allowed Paths列出的其他Stream目录
生产Secret和环境凭证
主网配置或写链脚本
```

## Requirements

- 地址按environment/chain/version管理。
- 未配置合约返回UNAVAILABLE。
- 不硬编码生产地址。
- 返回部署区块、ABI版本和数据状态。
- 变更有审计。

## Required Tests

registry CRUD domain tests；public read API；wrong chain；missing contract；freshness tests。

## Outputs

Contract Registry和System Status API。

## Closure Conditions

- Requirements全部完成；
- Required Tests绑定Current Head SHA；
- 只修改Allowed Paths；
- 无Blocking Finding；
- Evidence Manifest完整；
- Review APPROVED后进入MERGE_READY；
- 人工决定合并后才能标MERGED。

## Next Role

Review Agent。
===== END FILE: tasks/backend/P2-B03.md =====

===== BEGIN FILE: tasks/backend/P2-B04.md =====
# P2-B04 — Quote与用户交易API

```text
Project ID: PANGU2
Stream: BACKEND
Task ID: P2-B04
Task Status: BLOCKED_REQUIREMENT
Task Start Gate: <TO_BE_SET_BY_COORDINATOR>
Block Reason: REQUIREMENT: PB-S1 preview ABI and Quote Profile
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Task Start Base SHA: <TO_BE_FIXED_AT_TASK_START>
Current Base Branch Tip SHA: <TO_BE_FIXED_AT_TASK_START>
Merge Base SHA: <TO_BE_FIXED_AFTER_BRANCH>
Previous Reviewed Head SHA: NONE
Current Head SHA: <TO_BE_FIXED_AFTER_COMMIT>
Spec SHA: <TO_BE_FIXED_AT_TASK_START>
Ruleset SHA: <TO_BE_FIXED_AT_TASK_START>
CI Workflow SHA: <TO_BE_FIXED_AT_TASK_START>
Dependency Lockfile SHA: <TO_BE_FIXED_AT_TASK_START>
Evidence Manifest SHA: <TO_BE_FIXED_AT_CLOSEOUT>
```

## Goal

实现Buy/Sell Quote代理、交易准备数据和稳定错误码；正式LIVE必须调用合约preview，不复制判税。

## Dependencies

`P2-B01`, `P2-B03`, Quote Schema, PB-S1 preview ABI

## Allowed Paths

```text
hub/pangu2/services/api/app/Modules/Pangu2/Trade/**
hub/pangu2/services/api/tests/**
hub/pangu2/services/api/routes/**
```

## Forbidden Paths

```text
hub/pixiu1/**
未在Allowed Paths列出的其他Stream目录
生产Secret和环境凭证
主网配置或写链脚本
```

## Requirements

- Mock阶段返回MOCK_DATA。
- ABI不可用返回QUOTE_UNAVAILABLE。
- 不接收客户端税率。
- 返回deadline、minOut建议、quote block、expiry和data status。
- API不代签或广播用户交易。

## Required Tests

mock/live adapter contract tests；expiry；unavailable；wrong network；integer amounts；no formula duplication scan。

## Outputs

Quote API和Contract Adapter。

## Closure Conditions

- Requirements全部完成；
- Required Tests绑定Current Head SHA；
- 只修改Allowed Paths；
- 无Blocking Finding；
- Evidence Manifest完整；
- Review APPROVED后进入MERGE_READY；
- 人工决定合并后才能标MERGED。

## Next Role

Review Agent。
===== END FILE: tasks/backend/P2-B04.md =====

===== BEGIN FILE: tasks/backend/P2-B05.md =====
# P2-B05 — Chain Worker与交易投影

```text
Project ID: PANGU2
Stream: BACKEND
Task ID: P2-B05
Task Status: BLOCKED_SCHEMA
Task Start Gate: <TO_BE_SET_BY_COORDINATOR>
Block Reason: DEPENDENCY: ABI/Event/DB Schema
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Task Start Base SHA: <TO_BE_FIXED_AT_TASK_START>
Current Base Branch Tip SHA: <TO_BE_FIXED_AT_TASK_START>
Merge Base SHA: <TO_BE_FIXED_AFTER_BRANCH>
Previous Reviewed Head SHA: NONE
Current Head SHA: <TO_BE_FIXED_AFTER_COMMIT>
Spec SHA: <TO_BE_FIXED_AT_TASK_START>
Ruleset SHA: <TO_BE_FIXED_AT_TASK_START>
CI Workflow SHA: <TO_BE_FIXED_AT_TASK_START>
Dependency Lockfile SHA: <TO_BE_FIXED_AT_TASK_START>
Evidence Manifest SHA: <TO_BE_FIXED_AT_CLOSEOUT>
```

## Goal

实现Block/Tx/Receipt/Log索引、Finality、Reorg、Cursor、raw outbox和用户交易投影。

## Dependencies

Event Schema、DB Schema、P2-B01

## Allowed Paths

```text
hub/pangu2/services/chain-worker/**
hub/pangu2/services/api/app/Modules/Core/Transaction/**
hub/pangu2/services/api/database/migrations/**
hub/pangu2/services/api/tests/**
```

## Forbidden Paths

```text
hub/pixiu1/**
未在Allowed Paths列出的其他Stream目录
生产Secret和环境凭证
主网配置或写链脚本
```

## Requirements

- Chain Worker唯一拥有raw facts和cursor。
- 事件唯一键含block_hash。
- canonical/reorg可逆。
- Laravel只消费outbox。
- 多实例lease和幂等。
- 用户交易状态支持replaced/dropped/reorg。

## Required Tests

unit；Anvil integration；reorg simulation；restart/cursor；duplicate log；lease concurrency；projection rebuild。

## Outputs

Raw事实、Outbox、交易投影和恢复证据。

## Closure Conditions

- Requirements全部完成；
- Required Tests绑定Current Head SHA；
- 只修改Allowed Paths；
- 无Blocking Finding；
- Evidence Manifest完整；
- Review APPROVED后进入MERGE_READY；
- 人工决定合并后才能标MERGED。

## Next Role

Review Agent。
===== END FILE: tasks/backend/P2-B05.md =====

===== BEGIN FILE: tasks/backend/P2-B06.md =====
# P2-B06 — Dividend、Buyback与Locker读模型

```text
Project ID: PANGU2
Stream: BACKEND
Task ID: P2-B06
Task Status: BLOCKED_REQUIREMENT
Task Start Gate: <TO_BE_SET_BY_COORDINATOR>
Block Reason: REQUIREMENT: Signed Dividend/Locker Parameter Freeze
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Task Start Base SHA: <TO_BE_FIXED_AT_TASK_START>
Current Base Branch Tip SHA: <TO_BE_FIXED_AT_TASK_START>
Merge Base SHA: <TO_BE_FIXED_AFTER_BRANCH>
Previous Reviewed Head SHA: NONE
Current Head SHA: <TO_BE_FIXED_AFTER_COMMIT>
Spec SHA: <TO_BE_FIXED_AT_TASK_START>
Ruleset SHA: <TO_BE_FIXED_AT_TASK_START>
CI Workflow SHA: <TO_BE_FIXED_AT_TASK_START>
Dependency Lockfile SHA: <TO_BE_FIXED_AT_TASK_START>
Evidence Manifest SHA: <TO_BE_FIXED_AT_CLOSEOUT>
```

## Goal

实现Epoch、排名、Allocation、Proof、Buyback和Locker投影与用户API。

## Dependencies

`P2-B05`, Dividend/Merkle Schema, PB-S1 Events

## Allowed Paths

```text
hub/pangu2/services/api/app/Modules/Pangu2/Dividend/**
hub/pangu2/services/api/app/Modules/Pangu2/Buyback/**
hub/pangu2/services/api/app/Modules/Pangu2/Locker/**
hub/pangu2/services/api/tests/**
hub/pangu2/services/api/database/migrations/**
```

## Forbidden Paths

```text
hub/pixiu1/**
未在Allowed Paths列出的其他Stream目录
生产Secret和环境凭证
主网配置或写链脚本
```

## Requirements

- 相同输入生成相同排名/Allocation/Root/Proof。
- 排名余额降序，同余额地址升序。
- Proof文件和DB记录互相保存Hash。
- UI只读Proof，不由前端计算。
- 余数/空档/未领取按Signed PFR。

## Required Tests

determinism；tie-break；less-than-100；dust；proof verify；reorg invalidation；rebuild。

## Outputs

Dividend/Buyback/Locker API和确定性证据。

## Closure Conditions

- Requirements全部完成；
- Required Tests绑定Current Head SHA；
- 只修改Allowed Paths；
- 无Blocking Finding；
- Evidence Manifest完整；
- Review APPROVED后进入MERGE_READY；
- 人工决定合并后才能标MERGED。

## Next Role

Review Agent。
===== END FILE: tasks/backend/P2-B06.md =====

===== BEGIN FILE: tasks/backend/P2-B07.md =====
# P2-B07 — Admin RBAC、Jobs与审计

```text
Project ID: PANGU2
Stream: BACKEND
Task ID: P2-B07
Task Status: BLOCKED_BY_B02_B06
Task Start Gate: <TO_BE_SET_BY_COORDINATOR>
Block Reason: NONE
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Task Start Base SHA: <TO_BE_FIXED_AT_TASK_START>
Current Base Branch Tip SHA: <TO_BE_FIXED_AT_TASK_START>
Merge Base SHA: <TO_BE_FIXED_AFTER_BRANCH>
Previous Reviewed Head SHA: NONE
Current Head SHA: <TO_BE_FIXED_AFTER_COMMIT>
Spec SHA: <TO_BE_FIXED_AT_TASK_START>
Ruleset SHA: <TO_BE_FIXED_AT_TASK_START>
CI Workflow SHA: <TO_BE_FIXED_AT_TASK_START>
Dependency Lockfile SHA: <TO_BE_FIXED_AT_TASK_START>
Evidence Manifest SHA: <TO_BE_FIXED_AT_CLOSEOUT>
```

## Goal

实现Admin Session、RBAC、Dashboard、Jobs、重试、审计和受控操作API。

## Dependencies

`P2-B02`, `P2-B03`, `P2-B05`, `P2-B06`

## Allowed Paths

```text
hub/pangu2/services/api/app/Modules/Core/RBAC/**
hub/pangu2/services/api/app/Modules/Core/Audit/**
hub/pangu2/services/api/app/Modules/Pangu2/Admin/**
hub/pangu2/services/api/tests/**
hub/pangu2/services/api/database/migrations/**
```

## Forbidden Paths

```text
hub/pixiu1/**
未在Allowed Paths列出的其他Stream目录
生产Secret和环境凭证
主网配置或写链脚本
```

## Requirements

- 权限最小化。
- 重试有Idempotency-Key。
- 禁止改用户资产/成本/分配。
- 禁止SupportPool普通提现。
- 危险操作只生成受控任务/提案并审计。

## Required Tests

RBAC matrix；audit append-only；job retry；idempotency；forbidden operations。

## Outputs

Admin API、角色矩阵和审计证据。

## Closure Conditions

- Requirements全部完成；
- Required Tests绑定Current Head SHA；
- 只修改Allowed Paths；
- 无Blocking Finding；
- Evidence Manifest完整；
- Review APPROVED后进入MERGE_READY；
- 人工决定合并后才能标MERGED。

## Next Role

Review Agent。
===== END FILE: tasks/backend/P2-B07.md =====

===== BEGIN FILE: tasks/dapp/P2-F01.md =====
# P2-F01 — DApp工程骨架与设计系统

```text
Project ID: PANGU2
Stream: DAPP
Task ID: P2-F01
Task Status: READY_AFTER_X02
Task Start Gate: <TO_BE_SET_BY_COORDINATOR>
Block Reason: NONE
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Task Start Base SHA: <TO_BE_FIXED_AT_TASK_START>
Current Base Branch Tip SHA: <TO_BE_FIXED_AT_TASK_START>
Merge Base SHA: <TO_BE_FIXED_AFTER_BRANCH>
Previous Reviewed Head SHA: NONE
Current Head SHA: <TO_BE_FIXED_AFTER_COMMIT>
Spec SHA: <TO_BE_FIXED_AT_TASK_START>
Ruleset SHA: <TO_BE_FIXED_AT_TASK_START>
CI Workflow SHA: <TO_BE_FIXED_AT_TASK_START>
Dependency Lockfile SHA: <TO_BE_FIXED_AT_TASK_START>
Evidence Manifest SHA: <TO_BE_FIXED_AT_CLOSEOUT>
```

## Goal

建立Vue 3/TypeScript/Vite工程、路由、布局、设计Token、测试和构建。

## Dependencies

`P2-X02`; 精确Node/包管理器版本

## Allowed Paths

```text
hub/pangu2/apps/dapp/**
```

## Forbidden Paths

```text
hub/pixiu1/**
未在Allowed Paths列出的其他Stream目录
生产Secret和环境凭证
主网配置或写链脚本
```

## Requirements

- Mobile-first。
- 页面：首页/交易/分红/托底/我的。
- 环境和data status全局可见。
- API Client只来自生成包。
- 不包含正式业务计算。

## Required Tests

lint；typecheck；unit；build；router smoke；mobile viewport。

## Outputs

可运行DApp骨架和组件基线。

## Closure Conditions

- Requirements全部完成；
- Required Tests绑定Current Head SHA；
- 只修改Allowed Paths；
- 无Blocking Finding；
- Evidence Manifest完整；
- Review APPROVED后进入MERGE_READY；
- 人工决定合并后才能标MERGED。

## Next Role

Review Agent。
===== END FILE: tasks/dapp/P2-F01.md =====

===== BEGIN FILE: tasks/dapp/P2-F02.md =====
# P2-F02 — 钱包连接与Network状态

```text
Project ID: PANGU2
Stream: DAPP
Task ID: P2-F02
Task Status: BLOCKED_BY_F01
Task Start Gate: <TO_BE_SET_BY_COORDINATOR>
Block Reason: NONE
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Task Start Base SHA: <TO_BE_FIXED_AT_TASK_START>
Current Base Branch Tip SHA: <TO_BE_FIXED_AT_TASK_START>
Merge Base SHA: <TO_BE_FIXED_AFTER_BRANCH>
Previous Reviewed Head SHA: NONE
Current Head SHA: <TO_BE_FIXED_AFTER_COMMIT>
Spec SHA: <TO_BE_FIXED_AT_TASK_START>
Ruleset SHA: <TO_BE_FIXED_AT_TASK_START>
CI Workflow SHA: <TO_BE_FIXED_AT_TASK_START>
Dependency Lockfile SHA: <TO_BE_FIXED_AT_TASK_START>
Evidence Manifest SHA: <TO_BE_FIXED_AT_CLOSEOUT>
```

## Goal

实现钱包连接、地址显示、Network检测/切换、断开、错误恢复。

## Dependencies

`P2-F01`, Contract Config Schema

## Allowed Paths

```text
hub/pangu2/apps/dapp/src/features/wallet/**
hub/pangu2/apps/dapp/src/stores/**
hub/pangu2/apps/dapp/src/components/**
hub/pangu2/apps/dapp/tests/**
```

## Forbidden Paths

```text
hub/pixiu1/**
未在Allowed Paths列出的其他Stream目录
生产Secret和环境凭证
主网配置或写链脚本
```

## Requirements

- 用户钱包签名。
- Wrong network不允许交易。
- 支持拒绝连接/切网。
- 不保存私钥。
- 显示chain/environment。

## Required Tests

wallet mock；connect/reject/disconnect；wrong network；switch error；reload restore。

## Outputs

Wallet/Network状态机和UI。

## Closure Conditions

- Requirements全部完成；
- Required Tests绑定Current Head SHA；
- 只修改Allowed Paths；
- 无Blocking Finding；
- Evidence Manifest完整；
- Review APPROVED后进入MERGE_READY；
- 人工决定合并后才能标MERGED。

## Next Role

Review Agent。
===== END FILE: tasks/dapp/P2-F02.md =====

===== BEGIN FILE: tasks/dapp/P2-F03.md =====
# P2-F03 — 生成API Client与全局数据状态

```text
Project ID: PANGU2
Stream: DAPP
Task ID: P2-F03
Task Status: BLOCKED_BY_F01_X02
Task Start Gate: <TO_BE_SET_BY_COORDINATOR>
Block Reason: NONE
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Task Start Base SHA: <TO_BE_FIXED_AT_TASK_START>
Current Base Branch Tip SHA: <TO_BE_FIXED_AT_TASK_START>
Merge Base SHA: <TO_BE_FIXED_AFTER_BRANCH>
Previous Reviewed Head SHA: NONE
Current Head SHA: <TO_BE_FIXED_AFTER_COMMIT>
Spec SHA: <TO_BE_FIXED_AT_TASK_START>
Ruleset SHA: <TO_BE_FIXED_AT_TASK_START>
CI Workflow SHA: <TO_BE_FIXED_AT_TASK_START>
Dependency Lockfile SHA: <TO_BE_FIXED_AT_TASK_START>
Evidence Manifest SHA: <TO_BE_FIXED_AT_CLOSEOUT>
```

## Goal

接入生成Client、Query缓存、统一错误、Data Status和新鲜度展示。

## Dependencies

`P2-F01`, `P2-X02`

## Allowed Paths

```text
hub/pangu2/apps/dapp/src/api/**
hub/pangu2/apps/dapp/src/stores/**
hub/pangu2/apps/dapp/src/components/**
hub/pangu2/apps/dapp/tests/**
```

## Forbidden Paths

```text
hub/pixiu1/**
未在Allowed Paths列出的其他Stream目录
生产Secret和环境凭证
主网配置或写链脚本
```

## Requirements

- 禁止手写第二套DTO。
- MOCK/STALE/DEGRADED/UNAVAILABLE可见。
- 请求取消、重试和错误恢复。
- Schema版本不兼容时fail visibly。

## Required Tests

mock API；network error；stale；retry；schema mismatch；typecheck。

## Outputs

API层、数据状态组件和测试。

## Closure Conditions

- Requirements全部完成；
- Required Tests绑定Current Head SHA；
- 只修改Allowed Paths；
- 无Blocking Finding；
- Evidence Manifest完整；
- Review APPROVED后进入MERGE_READY；
- 人工决定合并后才能标MERGED。

## Next Role

Review Agent。
===== END FILE: tasks/dapp/P2-F03.md =====

===== BEGIN FILE: tasks/dapp/P2-F04.md =====
# P2-F04 — 交易页面与Quote展示

```text
Project ID: PANGU2
Stream: DAPP
Task ID: P2-F04
Task Status: BLOCKED_BY_F02_F03
Task Start Gate: <TO_BE_SET_BY_COORDINATOR>
Block Reason: NONE
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Task Start Base SHA: <TO_BE_FIXED_AT_TASK_START>
Current Base Branch Tip SHA: <TO_BE_FIXED_AT_TASK_START>
Merge Base SHA: <TO_BE_FIXED_AFTER_BRANCH>
Previous Reviewed Head SHA: NONE
Current Head SHA: <TO_BE_FIXED_AFTER_COMMIT>
Spec SHA: <TO_BE_FIXED_AT_TASK_START>
Ruleset SHA: <TO_BE_FIXED_AT_TASK_START>
CI Workflow SHA: <TO_BE_FIXED_AT_TASK_START>
Dependency Lockfile SHA: <TO_BE_FIXED_AT_TASK_START>
Evidence Manifest SHA: <TO_BE_FIXED_AT_CLOSEOUT>
```

## Goal

实现Buy/Sell输入、余额、Quote、税费摘要、expiry、minOut和风险提示。

## Dependencies

`P2-F02`, `P2-F03`, Quote Schema

## Allowed Paths

```text
hub/pangu2/apps/dapp/src/features/trade/**
hub/pangu2/apps/dapp/tests/**
```

## Forbidden Paths

```text
hub/pixiu1/**
未在Allowed Paths列出的其他Stream目录
生产Secret和环境凭证
主网配置或写链脚本
```

## Requirements

- 不允许选择4%/10%。
- 不在前端判税。
- Quote显示source、block、expiry、data status。
- MAX预留Gas。
- Mock数据显式标识。
- Quote expired后禁用提交。

## Required Tests

buy/sell；invalid amount；max；quote expiry；unavailable；mock/live rendering。

## Outputs

Trade UI，不含真实写链提交。

## Closure Conditions

- Requirements全部完成；
- Required Tests绑定Current Head SHA；
- 只修改Allowed Paths；
- 无Blocking Finding；
- Evidence Manifest完整；
- Review APPROVED后进入MERGE_READY；
- 人工决定合并后才能标MERGED。

## Next Role

Review Agent。
===== END FILE: tasks/dapp/P2-F04.md =====

===== BEGIN FILE: tasks/dapp/P2-F05.md =====
# P2-F05 — Approval、Signature与交易状态机

```text
Project ID: PANGU2
Stream: DAPP
Task ID: P2-F05
Task Status: BLOCKED_ABI
Task Start Gate: <TO_BE_SET_BY_COORDINATOR>
Block Reason: DEPENDENCY: PB-S1 ABI and live wallet integration
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Task Start Base SHA: <TO_BE_FIXED_AT_TASK_START>
Current Base Branch Tip SHA: <TO_BE_FIXED_AT_TASK_START>
Merge Base SHA: <TO_BE_FIXED_AFTER_BRANCH>
Previous Reviewed Head SHA: NONE
Current Head SHA: <TO_BE_FIXED_AFTER_COMMIT>
Spec SHA: <TO_BE_FIXED_AT_TASK_START>
Ruleset SHA: <TO_BE_FIXED_AT_TASK_START>
CI Workflow SHA: <TO_BE_FIXED_AT_TASK_START>
Dependency Lockfile SHA: <TO_BE_FIXED_AT_TASK_START>
Evidence Manifest SHA: <TO_BE_FIXED_AT_CLOSEOUT>
```

## Goal

实现授权、买卖签名、提交、pending、confirmed、failed、replaced、dropped和reorg状态。

## Dependencies

`P2-F04`, PB-S1 ABI, Transaction API

## Allowed Paths

```text
hub/pangu2/apps/dapp/src/features/transactions/**
hub/pangu2/apps/dapp/src/features/trade/**
hub/pangu2/apps/dapp/tests/**
```

## Forbidden Paths

```text
hub/pixiu1/**
未在Allowed Paths列出的其他Stream目录
生产Secret和环境凭证
主网配置或写链脚本
```

## Requirements

- Approval和Sell两笔交易。
- 执行前重新获取Quote。
- 前端不传税率。
- 用户拒签可恢复。
- Tx hash与API投影关联。
- Reorg后重新检查。

## Required Tests

approve required/not required；reject；pending；replace；drop；reorg；receipt mismatch。

## Outputs

真实交易交互状态机。

## Closure Conditions

- Requirements全部完成；
- Required Tests绑定Current Head SHA；
- 只修改Allowed Paths；
- 无Blocking Finding；
- Evidence Manifest完整；
- Review APPROVED后进入MERGE_READY；
- 人工决定合并后才能标MERGED。

## Next Role

Review Agent。
===== END FILE: tasks/dapp/P2-F05.md =====

===== BEGIN FILE: tasks/dapp/P2-F06.md =====
# P2-F06 — 分红、托底与我的页面

```text
Project ID: PANGU2
Stream: DAPP
Task ID: P2-F06
Task Status: BLOCKED_API
Task Start Gate: <TO_BE_SET_BY_COORDINATOR>
Block Reason: DEPENDENCY: B06 API and PB-S1 Distributor/Locker
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Task Start Base SHA: <TO_BE_FIXED_AT_TASK_START>
Current Base Branch Tip SHA: <TO_BE_FIXED_AT_TASK_START>
Merge Base SHA: <TO_BE_FIXED_AFTER_BRANCH>
Previous Reviewed Head SHA: NONE
Current Head SHA: <TO_BE_FIXED_AFTER_COMMIT>
Spec SHA: <TO_BE_FIXED_AT_TASK_START>
Ruleset SHA: <TO_BE_FIXED_AT_TASK_START>
CI Workflow SHA: <TO_BE_FIXED_AT_TASK_START>
Dependency Lockfile SHA: <TO_BE_FIXED_AT_TASK_START>
Evidence Manifest SHA: <TO_BE_FIXED_AT_CLOSEOUT>
```

## Goal

实现当前估算排名、Epoch排名、Proof/Claim、Buyback、Locker和用户历史。

## Dependencies

`P2-F03`, B06 API

## Allowed Paths

```text
hub/pangu2/apps/dapp/src/features/dividend/**
hub/pangu2/apps/dapp/src/features/support/**
hub/pangu2/apps/dapp/src/features/profile/**
hub/pangu2/apps/dapp/tests/**
```

## Forbidden Paths

```text
hub/pixiu1/**
未在Allowed Paths列出的其他Stream目录
生产Secret和环境凭证
主网配置或写链脚本
```

## Requirements

- 估算、结算、可领取分开。
- Proof来自API。
- Claim由钱包签名。
- Locker不显示未批准固定期限。
- SupportPool只读展示，无提现入口。

## Required Tests

empty states；mock/live；proof unavailable；claimed；claim rejected；locker modes；pagination。

## Outputs

三类用户页面和Claim状态。

## Closure Conditions

- Requirements全部完成；
- Required Tests绑定Current Head SHA；
- 只修改Allowed Paths；
- 无Blocking Finding；
- Evidence Manifest完整；
- Review APPROVED后进入MERGE_READY；
- 人工决定合并后才能标MERGED。

## Next Role

Review Agent。
===== END FILE: tasks/dapp/P2-F06.md =====

===== BEGIN FILE: tasks/dapp/P2-F07.md =====
# P2-F07 — DApp Closeout与E2E

```text
Project ID: PANGU2
Stream: DAPP
Task ID: P2-F07
Task Status: BLOCKED_PREVIOUS
Task Start Gate: <TO_BE_SET_BY_COORDINATOR>
Block Reason: NONE
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Task Start Base SHA: <TO_BE_FIXED_AT_TASK_START>
Current Base Branch Tip SHA: <TO_BE_FIXED_AT_TASK_START>
Merge Base SHA: <TO_BE_FIXED_AFTER_BRANCH>
Previous Reviewed Head SHA: NONE
Current Head SHA: <TO_BE_FIXED_AFTER_COMMIT>
Spec SHA: <TO_BE_FIXED_AT_TASK_START>
Ruleset SHA: <TO_BE_FIXED_AT_TASK_START>
CI Workflow SHA: <TO_BE_FIXED_AT_TASK_START>
Dependency Lockfile SHA: <TO_BE_FIXED_AT_TASK_START>
Evidence Manifest SHA: <TO_BE_FIXED_AT_CLOSEOUT>
```

## Goal

完成错误恢复、无障碍、性能、移动端和关键E2E。

## Dependencies

`P2-F01..F06`

## Allowed Paths

```text
hub/pangu2/apps/dapp/**
hub/pangu2/docs/evidence/PB-S4/**
```

## Forbidden Paths

```text
hub/pixiu1/**
未在Allowed Paths列出的其他Stream目录
生产Secret和环境凭证
主网配置或写链脚本
```

## Requirements

- 不新增业务公式。
- 关键状态有可访问文本。
- Error boundary和恢复。
- 生产构建无Secret。
- Testnet E2E证据。

## Required Tests

lint；typecheck；unit；build；e2e；mobile；accessibility；bundle check。

## Outputs

PB-S4 Closeout证据。

## Closure Conditions

- Requirements全部完成；
- Required Tests绑定Current Head SHA；
- 只修改Allowed Paths；
- 无Blocking Finding；
- Evidence Manifest完整；
- Review APPROVED后进入MERGE_READY；
- 人工决定合并后才能标MERGED。

## Next Role

Review Agent。
===== END FILE: tasks/dapp/P2-F07.md =====

===== BEGIN FILE: tasks/integration/P2-I01.md =====
# P2-I01 — Local Full Stack编排

```text
Project ID: PANGU2
Stream: INTEGRATION
Task ID: P2-I01
Task Status: BLOCKED_FOUNDATION
Task Start Gate: <TO_BE_SET_BY_COORDINATOR>
Block Reason: NONE
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Task Start Base SHA: <TO_BE_FIXED_AT_TASK_START>
Current Base Branch Tip SHA: <TO_BE_FIXED_AT_TASK_START>
Merge Base SHA: <TO_BE_FIXED_AFTER_BRANCH>
Previous Reviewed Head SHA: NONE
Current Head SHA: <TO_BE_FIXED_AFTER_COMMIT>
Spec SHA: <TO_BE_FIXED_AT_TASK_START>
Ruleset SHA: <TO_BE_FIXED_AT_TASK_START>
CI Workflow SHA: <TO_BE_FIXED_AT_TASK_START>
Dependency Lockfile SHA: <TO_BE_FIXED_AT_TASK_START>
Evidence Manifest SHA: <TO_BE_FIXED_AT_CLOSEOUT>
```

## Goal

编排Anvil/PostgreSQL/Redis/API/Worker/DApp/Admin的本地一键启动与清理。

## Dependencies

工具链、B01、F01、A01

## Allowed Paths

```text
hub/pangu2/infra/local/**
hub/pangu2/docs/evidence/PB-S6/P2-I01/**
```

## Forbidden Paths

```text
hub/pixiu1/**
未在Allowed Paths列出的其他Stream目录
生产Secret和环境凭证
主网配置或写链脚本
```

## Requirements

- 可重复启动。
- 数据可重置。
- 不含生产Secret。
- 服务健康检查和日志路径明确。

## Required Tests

cold start；restart；clean reset；health；secret scan。

## Outputs

LOCAL运行环境。

## Closure Conditions

- Requirements全部完成；
- Required Tests绑定Current Head SHA；
- 只修改Allowed Paths；
- 无Blocking Finding；
- Evidence Manifest完整；
- Review APPROVED后进入MERGE_READY；
- 人工决定合并后才能标MERGED。

## Next Role

Review Agent。
===== END FILE: tasks/integration/P2-I01.md =====

===== BEGIN FILE: tasks/integration/P2-I02.md =====
# P2-I02 — Mock纵切片端到端

```text
Project ID: PANGU2
Stream: INTEGRATION
Task ID: P2-I02
Task Status: BLOCKED_X_B_F_A
Task Start Gate: <TO_BE_SET_BY_COORDINATOR>
Block Reason: NONE
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Task Start Base SHA: <TO_BE_FIXED_AT_TASK_START>
Current Base Branch Tip SHA: <TO_BE_FIXED_AT_TASK_START>
Merge Base SHA: <TO_BE_FIXED_AFTER_BRANCH>
Previous Reviewed Head SHA: NONE
Current Head SHA: <TO_BE_FIXED_AFTER_COMMIT>
Spec SHA: <TO_BE_FIXED_AT_TASK_START>
Ruleset SHA: <TO_BE_FIXED_AT_TASK_START>
CI Workflow SHA: <TO_BE_FIXED_AT_TASK_START>
Dependency Lockfile SHA: <TO_BE_FIXED_AT_TASK_START>
Evidence Manifest SHA: <TO_BE_FIXED_AT_CLOSEOUT>
```

## Goal

在Mock Server下完成Config、Auth、Wallet、Trade、Dividend、Support和Admin纵切片。

## Dependencies

X01-X03、对应Backend/Frontend Mock任务

## Allowed Paths

```text
hub/pangu2/docs/evidence/PB-S6/P2-I02/**
hub/pangu2/tests/e2e/**
```

## Forbidden Paths

```text
hub/pixiu1/**
未在Allowed Paths列出的其他Stream目录
生产Secret和环境凭证
主网配置或写链脚本
```

## Requirements

- Mock全部标识。
- Schema和状态一致。
- 不声称链上通过。
- Error/empty/retry覆盖。

## Required Tests

browser e2e；API contract；mock schema；test count baseline。

## Outputs

Mock E2E证据。

## Closure Conditions

- Requirements全部完成；
- Required Tests绑定Current Head SHA；
- 只修改Allowed Paths；
- 无Blocking Finding；
- Evidence Manifest完整；
- Review APPROVED后进入MERGE_READY；
- 人工决定合并后才能标MERGED。

## Next Role

Review Agent。
===== END FILE: tasks/integration/P2-I02.md =====

===== BEGIN FILE: tasks/integration/P2-I03.md =====
# P2-I03 — Anvil合约与应用集成

```text
Project ID: PANGU2
Stream: INTEGRATION
Task ID: P2-I03
Task Status: BLOCKED_PB_S1
Task Start Gate: <TO_BE_SET_BY_COORDINATOR>
Block Reason: NONE
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Task Start Base SHA: <TO_BE_FIXED_AT_TASK_START>
Current Base Branch Tip SHA: <TO_BE_FIXED_AT_TASK_START>
Merge Base SHA: <TO_BE_FIXED_AFTER_BRANCH>
Previous Reviewed Head SHA: NONE
Current Head SHA: <TO_BE_FIXED_AFTER_COMMIT>
Spec SHA: <TO_BE_FIXED_AT_TASK_START>
Ruleset SHA: <TO_BE_FIXED_AT_TASK_START>
CI Workflow SHA: <TO_BE_FIXED_AT_TASK_START>
Dependency Lockfile SHA: <TO_BE_FIXED_AT_TASK_START>
Evidence Manifest SHA: <TO_BE_FIXED_AT_CLOSEOUT>
```

## Goal

连接真实本地合约ABI/Event、Chain Worker、API、DApp和Admin。

## Dependencies

PB-S1 MERGED、B05、F05、A03

## Allowed Paths

```text
hub/pangu2/tests/e2e/**
hub/pangu2/docs/evidence/PB-S6/P2-I03/**
```

## Forbidden Paths

```text
hub/pixiu1/**
未在Allowed Paths列出的其他Stream目录
生产Secret和环境凭证
主网配置或写链脚本
```

## Requirements

- 真实公开入口。
- 无Mock绕过交易。
- 交易、Receipt、Log、投影和UI一致。
- Reorg与重启。

## Required Tests

buy/sell；approval；tx lifecycle；event indexing；reorg；restart。

## Outputs

Anvil full-stack evidence。

## Closure Conditions

- Requirements全部完成；
- Required Tests绑定Current Head SHA；
- 只修改Allowed Paths；
- 无Blocking Finding；
- Evidence Manifest完整；
- Review APPROVED后进入MERGE_READY；
- 人工决定合并后才能标MERGED。

## Next Role

Review Agent。
===== END FILE: tasks/integration/P2-I03.md =====

===== BEGIN FILE: tasks/integration/P2-I04.md =====
# P2-I04 — BSC_TESTNET完整闭环

```text
Project ID: PANGU2
Stream: INTEGRATION
Task ID: P2-I04
Task Status: BLOCKED_INTEGRATION_GATE
Task Start Gate: <TO_BE_SET_BY_COORDINATOR>
Block Reason: ENVIRONMENT/DEPENDENCY
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Task Start Base SHA: <TO_BE_FIXED_AT_TASK_START>
Current Base Branch Tip SHA: <TO_BE_FIXED_AT_TASK_START>
Merge Base SHA: <TO_BE_FIXED_AFTER_BRANCH>
Previous Reviewed Head SHA: NONE
Current Head SHA: <TO_BE_FIXED_AFTER_COMMIT>
Spec SHA: <TO_BE_FIXED_AT_TASK_START>
Ruleset SHA: <TO_BE_FIXED_AT_TASK_START>
CI Workflow SHA: <TO_BE_FIXED_AT_TASK_START>
Dependency Lockfile SHA: <TO_BE_FIXED_AT_TASK_START>
Evidence Manifest SHA: <TO_BE_FIXED_AT_CLOSEOUT>
```

## Goal

在BSC_TESTNET完成部署注册、买卖、税费、回购、Locker、分红、Claim和Admin监控。

## Dependencies

PB-S1-S5必要PR MERGED；Integration Gate GO

## Allowed Paths

```text
hub/pangu2/docs/evidence/PB-S6/P2-I04/**
hub/pangu2/config/testnet/**
```

## Forbidden Paths

```text
hub/pixiu1/**
未在Allowed Paths列出的其他Stream目录
生产Secret和环境凭证
主网配置或写链脚本
```

## Requirements

- 不提交Secret。
- Deployment Manifest。
- 真实钱包签名。
- 数据库/API/UI/链上一致。
- 故障和恢复。
- 不扩展到主网。

## Required Tests

testnet smoke/e2e；RPC failure；worker restart；reorg/finality；claim；audit。

## Outputs

BSC_TESTNET Closeout Evidence。

## Closure Conditions

- Requirements全部完成；
- Required Tests绑定Current Head SHA；
- 只修改Allowed Paths；
- 无Blocking Finding；
- Evidence Manifest完整；
- Review APPROVED后进入MERGE_READY；
- 人工决定合并后才能标MERGED。

## Next Role

Review Agent。
===== END FILE: tasks/integration/P2-I04.md =====

===== BEGIN FILE: tasks/integration/P2-I05.md =====
# P2-I05 — STAGING发布与PB-S6 Closeout

```text
Project ID: PANGU2
Stream: INTEGRATION
Task ID: P2-I05
Task Status: BLOCKED_I04
Task Start Gate: <TO_BE_SET_BY_COORDINATOR>
Block Reason: NONE
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Task Start Base SHA: <TO_BE_FIXED_AT_TASK_START>
Current Base Branch Tip SHA: <TO_BE_FIXED_AT_TASK_START>
Merge Base SHA: <TO_BE_FIXED_AFTER_BRANCH>
Previous Reviewed Head SHA: NONE
Current Head SHA: <TO_BE_FIXED_AFTER_COMMIT>
Spec SHA: <TO_BE_FIXED_AT_TASK_START>
Ruleset SHA: <TO_BE_FIXED_AT_TASK_START>
CI Workflow SHA: <TO_BE_FIXED_AT_TASK_START>
Dependency Lockfile SHA: <TO_BE_FIXED_AT_TASK_START>
Evidence Manifest SHA: <TO_BE_FIXED_AT_CLOSEOUT>
```

## Goal

将固定Artifact部署到STAGING，完成监控、回滚和阶段验收输入。

## Dependencies

`P2-I04 APPROVED/MERGED`

## Allowed Paths

```text
hub/pangu2/infra/staging/**
hub/pangu2/docs/evidence/PB-S6/P2-I05/**
```

## Forbidden Paths

```text
hub/pixiu1/**
未在Allowed Paths列出的其他Stream目录
生产Secret和环境凭证
主网配置或写链脚本
```

## Requirements

- 固定Artifact Digest。
- TLS、日志、告警。
- 数据重置策略。
- 发布审批和回滚。
- 无生产Secret和主网写链。

## Required Tests

staging smoke；rollback；monitoring alert；artifact digest；security scan。

## Outputs

PB-S6 Closeout Record。

## Closure Conditions

- Requirements全部完成；
- Required Tests绑定Current Head SHA；
- 只修改Allowed Paths；
- 无Blocking Finding；
- Evidence Manifest完整；
- Review APPROVED后进入MERGE_READY；
- 人工决定合并后才能标MERGED。

## Next Role

Review Agent。
===== END FILE: tasks/integration/P2-I05.md =====

===== BEGIN FILE: tasks/shared/P2-X01.md =====
# P2-X01 — 共享OpenAPI、错误码和状态机候选

```text
Project ID: PANGU2
Stream: SHARED
Task ID: P2-X01
Task Status: READY_AFTER_PB-S0
Task Start Gate: <TO_BE_SET_BY_COORDINATOR>
Block Reason: NONE
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Task Start Base SHA: <TO_BE_FIXED_AT_TASK_START>
Current Base Branch Tip SHA: <TO_BE_FIXED_AT_TASK_START>
Merge Base SHA: <TO_BE_FIXED_AFTER_BRANCH>
Previous Reviewed Head SHA: NONE
Current Head SHA: <TO_BE_FIXED_AFTER_COMMIT>
Spec SHA: <TO_BE_FIXED_AT_TASK_START>
Ruleset SHA: <TO_BE_FIXED_AT_TASK_START>
CI Workflow SHA: <TO_BE_FIXED_AT_TASK_START>
Dependency Lockfile SHA: <TO_BE_FIXED_AT_TASK_START>
Evidence Manifest SHA: <TO_BE_FIXED_AT_CLOSEOUT>
```

## Goal

建立前后端共同依赖的OpenAPI、响应Envelope、错误码、状态机和金额单位，不包含未批准的链上判税公式。

## Dependencies

V3.1/V1.1已合并；工具链和文档目录可用。

## Allowed Paths

```text
hub/pangu2/docs/schemas/**
hub/pangu2/packages/domain/**
hub/pangu2/docs/specs/PB-S0/P2-X01.md
```

## Forbidden Paths

```text
hub/pixiu1/**
未在Allowed Paths列出的其他Stream目录
生产Secret和环境凭证
主网配置或写链脚本
```

## Requirements

- 建立首批API Schema和Example。
- 固定Data Status与状态机。
- Quote字段保留contract preview来源和UNAVAILABLE状态。
- 定义Schema版本与兼容规则。
- 不填造合约地址、TWAP或未批准参数。

## Required Tests

Schema lint；Example validation；duplicate enum check；breaking-change check；secret scan。

## Outputs

OpenAPI候选、错误码、状态机、Schema Manifest和SHA。

## Closure Conditions

- Requirements全部完成；
- Required Tests绑定Current Head SHA；
- 只修改Allowed Paths；
- 无Blocking Finding；
- Evidence Manifest完整；
- Review APPROVED后进入MERGE_READY；
- 人工决定合并后才能标MERGED。

## Next Role

Review Agent。
===== END FILE: tasks/shared/P2-X01.md =====

===== BEGIN FILE: tasks/shared/P2-X02.md =====
# P2-X02 — 生成API Types、Client与Mock Server

```text
Project ID: PANGU2
Stream: SHARED
Task ID: P2-X02
Task Status: BLOCKED_BY_X01
Task Start Gate: <TO_BE_SET_BY_COORDINATOR>
Block Reason: NONE
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Task Start Base SHA: <TO_BE_FIXED_AT_TASK_START>
Current Base Branch Tip SHA: <TO_BE_FIXED_AT_TASK_START>
Merge Base SHA: <TO_BE_FIXED_AFTER_BRANCH>
Previous Reviewed Head SHA: NONE
Current Head SHA: <TO_BE_FIXED_AFTER_COMMIT>
Spec SHA: <TO_BE_FIXED_AT_TASK_START>
Ruleset SHA: <TO_BE_FIXED_AT_TASK_START>
CI Workflow SHA: <TO_BE_FIXED_AT_TASK_START>
Dependency Lockfile SHA: <TO_BE_FIXED_AT_TASK_START>
Evidence Manifest SHA: <TO_BE_FIXED_AT_CLOSEOUT>
```

## Goal

从X01生成TypeScript类型、DApp/Admin Client和Mock Server，禁止手工维护第二套类型。

## Dependencies

`P2-X01 REVIEW_APPROVED/MERGED`

## Allowed Paths

```text
hub/pangu2/packages/api-types/**
hub/pangu2/packages/mock-api/**
hub/pangu2/docs/evidence/PB-S0/P2-X02/**
```

## Forbidden Paths

```text
hub/pixiu1/**
未在Allowed Paths列出的其他Stream目录
生产Secret和环境凭证
主网配置或写链脚本
```

## Requirements

- 生成过程可重复。
- Mock Example全部满足OpenAPI。
- Mock响应显式MOCK_DATA。
- 生成文件标识来源Schema SHA。
- 禁止在Mock中实现正式判税。

## Required Tests

generation clean-diff；typecheck；mock contract tests；schema examples；build。

## Outputs

生成Client、Mock Server、生成清单和Evidence。

## Closure Conditions

- Requirements全部完成；
- Required Tests绑定Current Head SHA；
- 只修改Allowed Paths；
- 无Blocking Finding；
- Evidence Manifest完整；
- Review APPROVED后进入MERGE_READY；
- 人工决定合并后才能标MERGED。

## Next Role

Review Agent。
===== END FILE: tasks/shared/P2-X02.md =====

===== BEGIN FILE: tasks/shared/P2-X03.md =====
# P2-X03 — 共享契约测试与变更控制

```text
Project ID: PANGU2
Stream: SHARED
Task ID: P2-X03
Task Status: BLOCKED_BY_X02
Task Start Gate: <TO_BE_SET_BY_COORDINATOR>
Block Reason: NONE
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Task Start Base SHA: <TO_BE_FIXED_AT_TASK_START>
Current Base Branch Tip SHA: <TO_BE_FIXED_AT_TASK_START>
Merge Base SHA: <TO_BE_FIXED_AFTER_BRANCH>
Previous Reviewed Head SHA: NONE
Current Head SHA: <TO_BE_FIXED_AFTER_COMMIT>
Spec SHA: <TO_BE_FIXED_AT_TASK_START>
Ruleset SHA: <TO_BE_FIXED_AT_TASK_START>
CI Workflow SHA: <TO_BE_FIXED_AT_TASK_START>
Dependency Lockfile SHA: <TO_BE_FIXED_AT_TASK_START>
Evidence Manifest SHA: <TO_BE_FIXED_AT_CLOSEOUT>
```

## Goal

建立Backend、DApp、Admin消费共享Schema的Contract Test和Breaking Change Gate。

## Dependencies

`P2-X01`, `P2-X02`

## Allowed Paths

```text
hub/pangu2/packages/api-types/**
hub/pangu2/packages/mock-api/**
hub/pangu2/docs/schemas/**
hub/pangu2/docs/evidence/PB-S0/P2-X03/**
```

## Forbidden Paths

```text
hub/pixiu1/**
未在Allowed Paths列出的其他Stream目录
生产Secret和环境凭证
主网配置或写链脚本
```

## Requirements

- Backend实现必须满足Schema。
- Frontend不得使用Schema外字段。
- Breaking change必须失败。
- Example、Mock、Generated Types版本一致。

## Required Tests

OpenAPI diff；consumer typecheck；contract tests；empty-report check。

## Outputs

Contract Test报告和Shared Sync Point SP-01/SP-02关闭证据。

## Closure Conditions

- Requirements全部完成；
- Required Tests绑定Current Head SHA；
- 只修改Allowed Paths；
- 无Blocking Finding；
- Evidence Manifest完整；
- Review APPROVED后进入MERGE_READY；
- 人工决定合并后才能标MERGED。

## Next Role

Review Agent。
===== END FILE: tasks/shared/P2-X03.md =====

===== BEGIN FILE: templates/SYNC_POINT_RECORD_TEMPLATE.md =====
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
===== END FILE: templates/SYNC_POINT_RECORD_TEMPLATE.md =====

===== BEGIN FILE: templates/TASK_SPEC_TEMPLATE.md =====
# 前后端并行Task Spec模板

```text
Document ID: PANGU2-FB-TASK-TEMPLATE-1.0
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
Project ID:
Stage ID:
Stream:
Task ID:
Task Title:
Prompt Version:
Task Status:
Task Start Gate:
Block Reason:
Repository:
Base Branch:
Task Start Base SHA:
Current Base Branch Tip SHA:
Merge Base SHA:
Previous Reviewed Head SHA: NONE
Current Head SHA:
Final Reviewed Head SHA:
Merged Commit SHA:
Spec SHA:
Ruleset SHA:
CI Workflow SHA:
Dependency Lockfile SHA:
Evidence Manifest SHA:
```

## Goal
## Non-Goals
## Dependencies
## Active Decisions
## Signed Parameter Freeze
## Allowed Paths
## Forbidden Paths
## Requirements
## API/ABI/Schema Inputs
## Required Tests
## Required Checks
## Outputs
## Closure Conditions
## Rollback Boundary
## Known Risks
## Next Role
## Next Action
===== END FILE: templates/TASK_SPEC_TEMPLATE.md =====

===== BEGIN FILE: prompts/CURSOR_ADMIN_TRACK_PROMPT.md =====
# Cursor提示词 — Admin Track启动

你是PANGU2 Admin执行Agent。一次只执行一个已GO的Admin Task。

硬规则：

- 不提供用户资产/成本/分配修改；
- 不提供SupportPool普通提现；
- 不提供任意合约调用；
- 权限以Backend为准；
- 危险操作二次确认并显示环境、链、合约、金额和calldata摘要；
- 所有动作可审计；
- 不保存生产Secret；
- 不修改Backend/DApp/Contracts；
- 创建Draft PR并绑定固定SHA。
===== END FILE: prompts/CURSOR_ADMIN_TRACK_PROMPT.md =====

===== BEGIN FILE: prompts/CURSOR_BACKEND_TRACK_PROMPT.md =====
# Cursor提示词 — Backend Track启动

你是PANGU2 Backend执行Agent。一次只执行一个已GO的Backend Task。

固定仓库：

```text
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Project Root: hub/pangu2/
Forbidden: hub/pixiu1/**
```

先读取：

- 根AGENTS.md；
- V3.1执行Agent规则；
- `docs/01_前后端并行开发总计划.md`；
- `docs/03_共享接口与Schema基线.md`；
- `docs/04_后端与ChainWorker开发计划.md`；
- 当前Task Spec；
- Active Decision和Signed Parameter Freeze。

执行前核对工作区、分支、Base Tip、Spec/Ruleset/Workflow/Lockfile SHA、重复Task/PR/Finding。

硬规则：

1. 不复制判税公式；
2. 不代替用户签名；
3. Chain Worker与Horizon事实Owner不可重叠；
4. 未有ABI时Quote返回MOCK_DATA或UNAVAILABLE；
5. 不修改DApp/Admin/Contracts；
6. 范围不足时提交Change Request；
7. 创建Draft PR；
8. 首次审核Previous Reviewed Head SHA为NONE；
9. 禁止自动merge/deploy。
===== END FILE: prompts/CURSOR_BACKEND_TRACK_PROMPT.md =====

===== BEGIN FILE: prompts/CURSOR_DAPP_TRACK_PROMPT.md =====
# Cursor提示词 — DApp Track启动

你是PANGU2 DApp执行Agent。一次只执行一个已GO的DApp Task。

读取共享Schema、生成API Client和当前Task Spec。

硬规则：

- 不计算4%/10%选择；
- 不判定盈利；
- 不生成排名、Root或Proof；
- 不保存私钥；
- 用户资产操作由钱包签名；
- Mock必须显示MOCK_DATA；
- Wrong Network、Quote Expired、拒签、Pending、Replaced、Dropped、Reorg必须有状态；
- 不修改Backend、Admin或Contracts；
- 只使用生成DTO；
- 创建Draft PR并绑定固定SHA。
===== END FILE: prompts/CURSOR_DAPP_TRACK_PROMPT.md =====

===== BEGIN FILE: prompts/CURSOR_INTEGRATION_TRACK_PROMPT.md =====
# Cursor提示词 — Integration Track启动

你是PANGU2 Integration执行Agent。只在Integration Gate GO后执行真实联调任务。

先验证：

- 必要任务已MERGED；
- OpenAPI/ABI/Event SHA固定；
- Deployment Manifest存在；
- Required Checks绑定Merged Commit；
- Mock关键路径替换为LIVE；
- Blocking Finding关闭；
- 无生产Secret和主网写链。

不得通过跳过测试、空报告或Mock替代真实链路关闭Integration Task。
===== END FILE: prompts/CURSOR_INTEGRATION_TRACK_PROMPT.md =====

===== BEGIN FILE: prompts/REVIEW_AGENT_COMMON_PROMPT.md =====
# GitHub审核Agent通用提示词 — 前后端并行开发

你是只读审核Agent。审核固定PR Head SHA。

重点检查：

1. Task Start Gate是否GO；
2. Merge Base、Current Head、Spec、Ruleset、Workflow和Lockfile SHA；
3. Diff是否仅Allowed Paths；
4. Shared Schema是否为唯一来源；
5. Backend是否复制链上业务公式；
6. DApp/Admin是否手写DTO或业务判定；
7. Mock是否显式MOCK_DATA；
8. 测试报告是否为空、测试数是否下降；
9. Path Filter是否绕过应运行模块；
10. ABI/API/Event/DB Schema漂移；
11. 用户签名、RBAC、资金出口和Secret；
12. 累计实现是否仍满足完整Task Spec。

Verdict只能：APPROVED / CHANGES_REQUIRED / BLOCKED。
Closeout APPROVED只能推荐MERGE_READY，不得描述为已合并或已验收。
===== END FILE: prompts/REVIEW_AGENT_COMMON_PROMPT.md =====
