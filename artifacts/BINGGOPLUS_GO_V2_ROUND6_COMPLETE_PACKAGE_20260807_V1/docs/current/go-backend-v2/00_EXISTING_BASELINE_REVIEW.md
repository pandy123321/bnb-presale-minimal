# 原 API / 数据库基线审核与 V2 继承决策

审核模式：开发前契约审核（只读代码审查，不运行测试、服务、Migration 或 RPC）。

审核范围：

- `backend/routes/**`、`backend/app/**`、`backend/database/migrations/**`；
- `services/chain-worker/src/**`、`services/chain-worker/migrations/**`；
- `docs/schemas/openapi/pangu2-api-v1.yaml`；
- `packages/api-types/**`；
- DApp/Admin 的真实 API 调用点；
- `contracts-v2/broadcast/**/97/run-latest.json` 和部署提交关系。

没有修改以上生产代码。本报告用于设计新基线，不是发布验收。

## 1. 结论

`CHANGES_REQUIRED_BEFORE_GO_DEVELOPMENT`

原代码能够作为业务能力清单和故障案例来源，但不能直接复制表结构或 API 契约。主要原因是：Laravel Migration、Worker SQL、OpenAPI、共享 TypeScript 类型和真实前端调用已经发生结构漂移；同一业务存在重复表和不同字段语义；部署地址文档也落后于实测广播记录。

V2 的正确策略是“能力继承、契约重冻、链上重建”，不是“表名兼容、JSON 兼容、旧数据搬运”。

## 2. 原 Public API 能力盘点

| V1 能力 | 后端路由证据 | 真实调用 | V2 决策 |
|---|---|---|---|
| Config | `backend/routes/api.php:16` | DApp/Admin | 保留并补 deployment set/version |
| System Status | `backend/routes/api.php:17` | DApp/Admin | 保留，改为组件级 readiness |
| Contracts | `backend/routes/api.php:18` | DApp/Admin | 保留，绑定实测 evidence |
| Wallet nonce/verify/logout | `backend/routes/api.php:25-27` | 当前前端未调用 | 保留能力，改为 Cookie Session；可不接入首轮 UI |
| Buy/Sell Quote | `backend/routes/api.php:30-31` | DApp | 保留；禁止 Mock；买卖都要求 account |
| Wallet Transactions | `backend/routes/api.php:32` | Admin/DApp 意图 | 保留，Cursor 分页 |
| Wallet Summary | V1 OpenAPI 有、Laravel 路由缺失 | 无稳定调用 | 补齐为 V2 正式 Endpoint |
| Dividend current/show/proof | `backend/routes/api.php:35-37` | Admin/DApp | 保留并补 epochs list |
| Buyback/Locker | `backend/routes/api.php:40-41` | Admin | 保留，使用链上投影 |
| Staking earned/positions/status | `backend/routes/api.php:44-46` | DApp/Admin | 保留，使用同一 observed block |

## 3. 原 Admin API 能力盘点

| V1 能力 | 路由证据 | V2 决策 |
|---|---|---|
| CSRF、Login、Me、Logout | `backend/routes/web.php:21-36` | 保留 Session + CSRF，不迁移 Session |
| Dashboard、Contracts | `backend/routes/web.php:38-44` | 保留，响应由 Go Read Model 汇总 |
| Jobs、Retry | `backend/routes/web.php:45-51` | 保留；Retry 需 Idempotency-Key |
| Audit Logs | `backend/routes/web.php:52-56` | 保留 append-only 审计 |
| Staking coverage/fund/rate | `backend/routes/web.php:58-65` | 保留；写操作改成异步 Governance Command |
| Contract Registry CRUD/resync | `backend/routes/web.php:67-73` | 改为 Deployment Evidence 导入、验证、激活/停用；禁止物理删除历史 |
| Governance 6 个只读接口 | `backend/routes/web.php:75-83` | 全部保留，可增加 aggregate readiness |
| setPair/pause/unpause/buyback/oracle/release | `backend/routes/web.php:85-93` | 保留显式业务 Endpoint；内部统一 Command |

合约后来增加但 V1 Admin 未完整覆盖的控制能力，例如 fee whitelist、FeeVault conversion/funding、Dividend commitment/publish/close/cancel、Staking reward 管理，也必须进入 V2 的显式 allowlist API，不能依赖通用任意 calldata 接口。

## 4. 发现与设计修正

### P1-DB-01：重复表表达同一事实

- `chain_sync_cursors`：`backend/database/migrations/2026_01_01_000003...:10-23`；
- `chain_cursors`：`backend/database/migrations/2026_08_02_010001...:12-26`；
- `contract_event_logs` 与 `chain_raw_events` 同时保存链上日志；
- `nonces` 与 `wallet_nonces` 同时保存钱包 challenge。

影响：读写者可能连接不同“当前表”，恢复、Reorg 和认证清理语义不一致。

V2 修正：每类事实只保留一张主表；不迁移上述旧表。

### P1-DB-02：Worker SQL 与 Laravel DDL 不兼容

Laravel 的 `transaction_projections` 使用 `id` 主键、列名 `tx_hash/type/amount_in_raw/amount_out_raw/event_timestamp`，见 `2026_08_02_010002...:12-40`。Worker 则读写 `transaction_hash/event_name/to_address/amount_raw/timestamp/log_index`，见 `services/chain-worker/src/workers/projection-worker.ts:21-67`。

影响：同一部署中 Migration 即使成功，Projection Worker 也会因不存在列或冲突键不匹配而失败。

V2 修正：SQL Migration 与 sqlc query 同仓同源；禁止第二套 Worker Migration。

### P1-DB-03：Worker Migration 编号重复且包含破坏性重建

- 同时存在 `002_add_block_checkpoints.sql` 和 `002_block_checkpoints.sql`；
- `003_add_maintenance_lease.sql:12-20` 直接 drop/recreate checkpoint 表。

影响：执行顺序不确定，已有 checkpoint 会被丢弃。

V2 修正：全局单调 Migration 版本；生产只允许向前迁移；canonical block history 不做 drop/recreate。

### P1-DB-04：Transaction Projection 唯一维度不足

Laravel 对 `(chain_id, tx_hash)` 唯一，见 `2026_08_02_010002...:36`；同一交易多个 Log 会被合并。Worker 后续试图增加 `log_index`，但列名和主键又与 Laravel 表不一致。

影响：一次交易里的多个业务事件可能静默丢失或覆盖。

V2 修正：Raw Event 唯一键为 `(environment_id, tx_hash, log_index, block_hash)`；每个领域投影必须保存 `raw_event_id` 并以其幂等。

### P1-DB-05：Cursor 的“已处理块”语义容易出现边界错误

旧 Worker 使用 `last_scanned_block + 1`，见 `event-scanner.ts:98-104`；表名仍叫 last scanned，恢复时需要额外推理。

影响：首次扫描、空区块、Reorg rewind 容易产生 off-by-one。

V2 修正：只存 `next_block`，语义固定为“下一次扫描的第一块”；成功提交 `[from,to]` 后原子更新为 `to+1`。

### P1-API-01：OpenAPI、路由、DTO 和前端调用漂移

V1 OpenAPI 只冻结少量 Admin 读接口，而 `backend/routes/web.php:45-93` 已包含 Job retry、Registry、Staking 和 Governance；`packages/api-types/src/api.ts` 仍是人工维护的部分类型。

影响：Go 若照任一单独来源实现，会漏接口或产生响应不兼容。

V2 修正：以真实能力矩阵重建 OpenAPI；Go Server 与两个前端 Client 全部生成，生成文件禁止手改。

### P1-API-02：Quote 仍是 Mock 计算

`QuoteService.php:28-43,56-113` 使用固定 block/rate，虽然标记 `UNAVAILABLE`，HTTP 仍返回成功 Envelope。

影响：调用方可能把非执行级报价当成可交易数值。

V2 修正：生产 V2 不存在 `mock` quote source；只允许 `contract_preview`。RPC、Oracle、deployment readiness 任一不满足即返回 503，不返回报价数值。

### P1-API-03：Buy Quote 缺少 buyer，无法继承白名单与 Launch 优先级

V1 `BuyQuoteRequest` 只有 `amount_bnb_wei`，见 `packages/api-types/src/api.ts:117-120`，但已部署 Router 的权威函数是 `previewBuyFor(buyer, amount)`。

影响：白名单用户显示税率可能与执行不一致。

V2 修正：Buy/Sell Quote 都要求 `account`；后端分别调用 `previewBuyFor`、`previewSell`。

### P1-API-04：Envelope 只有 block number，没有 block hash

`ApiEnvelope.php:25-34` 与 `EnvelopeMeta` 只携带 block number。

影响：同高度 Reorg 后无法证明响应观察的是哪条链。

V2 修正：所有链上响应携带同一对 `observed_block.number/hash`，另加 `finality` 和 `data_status`。

### P1-API-05：Governance HTTP 把同步 receipt 当作普通请求结果

`ChainOperatorService.php:23-59` 在请求链路签名、广播并等待 receipt；`GovernanceController.php:352-356` 直接返回 `CONFIRMED`。

影响：HTTP 超时、进程重启、并发 nonce、替换交易和 receipt 不确定状态难以恢复；客户端重试可能重复广播。

V2 修正：显式 Admin Endpoint 只创建持久化 Command 并返回 `202`；Reconciler 独占 signer/nonce，异步跟踪到 confirmed/finalized。

### P2-API-01：Page pagination 与 Cursor pagination 混用

Buyback/Audit 使用 page/per_page，Staking positions 使用 cursor/limit；排序键没有统一冻结。

V2 修正：链上历史列表统一 opaque cursor，排序固定为 `(block_number DESC, transaction_index DESC, log_index DESC)`；管理员静态列表允许 page pagination。

### P2-API-02：金额字段命名和百分比表达不统一

旧响应混用 `amount`、`amount_raw`、`amount_wei`、`tax_rate='4%'` 和 `tax_rate_bps`。

V2 修正：链上金额一律十进制整数字符串，字段后缀使用 `_wei` 或 `_raw`；税率一律整数 `*_bps`。

### P2-DB-01：地址、Hash、枚举缺少数据库约束

旧 Migration 主要使用任意 string，缺少 lowercase/长度/正则和状态 check。

V2 修正：定义 `evm_address`、`evm_hash`、`uint256` Domain 与数据库 Enum；所有输入先在 API 校验、再由 DB 约束兜底。

## 5. V1 到 V2 的迁移分类

| 分类 | 示例 | 处理方式 |
|---|---|---|
| 链上事实 | Transfer、Trade、Stake、Claim、Buyback、Role | 从实测部署区块重扫，不能丢 |
| 链上当前状态 | pause、tradingOpenAt、role、Oracle status | 在固定证据块只读校验，随后由事件+getter reconciliation 维护 |
| 可重建投影 | wallet history、staking positions、buyback list | 不复制旧表，Go 重建 |
| 批处理 Artifact | dividend snapshot/root/proof | 只有 checksum、root 和输入证据完整时才导入，否则重建草稿，不能重发链上 root |
| 纯链下安全状态 | Admin、Session、CSRF、idempotency | 新建；Session 不迁移 |
| 运行时内部状态 | old jobs、retry token、leases、cursor | 不迁移 |
| Mock 数据 | quote、mock tx、mock staking | 禁止迁移 |

## 6. 允许继续开发前的审核项

- 数据库和 API Freeze 仍需人工签署；
- 实测部署 runtime bytecode hash 与当前角色矩阵仍需只读补录；
- 过期地址文档必须明确标为 superseded，避免部署导入误用；
- 本报告没有运行测试，测试由后续独立 Agent 处理；
- 本轮设计通过不等于发布、合并或主网上线批准。
