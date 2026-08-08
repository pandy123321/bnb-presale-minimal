# BingGoPlus Go Backend V2 事件与状态机冻结候选

状态：`FREEZE_CANDIDATE`  
事件规范：[events/binggoplus-events-v2.yaml](./events/binggoplus-events-v2.yaml)  
状态规范：[states/binggoplus-state-machines-v2.yaml](./states/binggoplus-state-machines-v2.yaml)

## 1. 事实边界

- 链上事实只来自 ACTIVE deployment set 的合约地址、部署 ABI 和 BSC Testnet canonical logs；
- 产品品牌为 BingGoPlus，事件的合约名和 event signature 仍使用已部署 `Pangu2*` ABI；
- 旧 Worker 的 6 个硬编码流只作为覆盖率参考，不作为新目录；
- 同一交易可以有多条有效 Log，唯一身份必须包含 `log_index`；
- Event Catalog 中的 signature 必须由部署 ABI 生成并保存 ABI/manifest hash，禁止手写 topic0；
- Pair 事件使用已部署 Pancake V2 Pair ABI，并绑定已核验 Pair 地址；
- getter/readback 是证据，不伪装成事件；定期 readback 进入 `contract_evidence_checks`。

## 2. 事件流

| Stream | 合约 | 主要事件 | 投影 |
|---|---|---|---|
| TOKEN | Pangu2Token | Transfer、TokensPurchased/Sold、ProtocolBurn、TradingOpened、Pair/System/Whitelist/Context、Pause/Role | 余额、税费、交易补充、控制、角色 |
| TRADE | Pangu2TradeRouter | BuyExecuted、SellExecuted、Pause/Role | trades、报价区块证据 |
| COST_BASIS | CostBasisManager | PositionChanged、CostBasisTransferred、LP 系列、配置/角色 | 成本状态、成本账本 |
| FEE_VAULT | FeeVault | FeeBucketCredited、DividendFunded、FeesConverted、配置/Pause/Role | bucket 流、分红拨款、支持池兑换 |
| SUPPORT | SupportPool | BuybackExecuted、FeeVaultConfigured、LockerConfigured、Pause/Role | buybacks、配置 |
| LOCKER | BuybackLocker | LockBatchCreated、LockBatchReleased、Role | locker_batches |
| DIVIDEND | DividendDistributor | Commitment、Root、Claim、Close/Cancel、Pause/Role | Epoch、artifact、claim、carry |
| STAKING | Pangu2Staking | Staked、Unstaked、EarlyUnstake、RewardClaimed/Funded/Rate、Role | 仓位、奖励、罚金、覆盖率 |
| ORACLE | PancakeV2TwapOracle | Anchored、WindowCompleted、LowLiquidity、Recovered、Reset | Oracle 状态与告警 |
| ADAPTER | PancakeV2Adapter | SwapExecuted、CallerUpdated、Role | swap 证据和 allowlist |
| PAIR | Pancake V2 Pair | Mint、Burn、Swap、Sync、Transfer | 储备、流动性、交易交叉核对 |

AccessControl/Pause 事件在各合约地址分别采集，不能仅扫描 Token。

## 3. 扫描、确认与 Reorg

### 3.1 起始区块

每个 Contract Stream 从 `contract_instances.deploy_block_number` 开始；Pair 从 CreatePair 交易所在区块开始。不能统一从最新区块或 Token 部署区块开始，否则会漏事件。

### 3.2 顺序

规范顺序：`block_number ASC, tx_index ASC, log_index ASC`。Projector 不得按接收时间排序。

### 3.3 确认策略候选

- `confirmation_depth = 20`；
- `reorg_lookback = 200`；
- Shadow 重扫固定 target block number/hash；
- RPC 返回区块 hash 不连续、parent 不匹配或固定 target hash 改变时立即进入 `REORG_RECOVERY`；
- 以上是应用策略候选，不是 BSC 网络事实，需运维/安全负责人批准后冻结。

### 3.4 Reorg 算法

1. 每轮先核对 Cursor 保存的最近确认 hash。
2. 不一致时向后寻找共同祖先，最多回看冻结窗口。
3. 超过窗口找不到共同祖先则 `HALTED`，禁止自动猜测。
4. 共同祖先之后旧 block/event 标记 non-canonical/ORPHANED。
5. 按相反顺序撤销 Projection Receipt，或从最后一致 checkpoint 重建。
6. 扫描新 canonical branch，重新确认后投影。
7. 已广播 Governance 交易单独按 tx hash/nonce 追踪，不能因 API 重试重复发送业务动作。

## 4. 投影规则

- Raw Event 先持久化再投影；
- `OBSERVED` 事件不进入最终 Public 数据；达到确认深度后转 `CONFIRMED`；
- 每个 projector 使用 `(raw_event_id, projector_key, projector_version)` 幂等；
- Raw Event 不设置单一 `PROJECTED` 状态：同一事件可能由多个 projector/version 消费，投影完成度必须由所需 projector/version 的 `APPLIED` receipt 集合推导；
- Projector 对 Raw Event 只读；成功、失败、重试与 Reorg 撤销分别记录为 `projection_receipts.APPLIED/FAILED/REVERTED`，不得为表示投影完成而修改原始事件；
- 任何 decode 失败保存原 topic/data 并进入 `DECODE_FAILED`，不丢弃；
- 同一经济动作可能同时产生 Token、Router、Adapter、Pair 事件，必须以 tx/log 关联而不是重复计数；
- `TokensPurchased/Sold` 与 `BuyExecuted/SellExecuted` 是主交易语义，ERC20 Transfer 用于守恒与余额；
- Fee bucket、burn、support、locker 必须分别投影，禁止把 10% 简化为单一 fee；
- CostBasis 状态以 CostBasisManager 事件为准，后端不得从平均价格自行推断；
- 定时 getter 只能做 reconciliation/anomaly，不可静默覆盖事件账本。

### 4.1 Dividend 固定区块输入协议

1. API 只能从 `dividend_finalized_blocks_v1` 选择并固定 snapshot `block_number + block_hash`。
2. Builder 在 `REPEATABLE READ` 事务中锁定 Epoch，并固定所需 projector manifest；V1 至少包含 `TOKEN/token_ledger` 与 `STAKING/staking` 的精确版本。
3. Builder 通过 `dividend_projection_coverage_v1` 确认目标块及之前相关 Stream 的每条 canonical confirmed Raw Event 均存在对应版本的 `APPLIED` receipt；缺失、`FAILED` 或 `REVERTED` 均 fail closed。
4. Wallet Token 余额只从 `dividend_token_balance_history_v1` 重放；active staked principal 只从 `dividend_staking_history_v1` 重放。查询必须按 `block_number, tx_index, log_index` 截止目标块，并显式筛选 projector version。
5. `token_balances_current` 与 `staking_positions` 只服务当前状态 API，禁止作为历史 Dividend Artifact 输入。
6. Builder 对规范化、稳定排序后的全部输入行计算 `input_sha256`，保存 row count、projector manifest、算法版本、snapshot block/hash、排除原因、排名、取整中间量和最终 Allocation。
7. Artifact 重建、projector version 改变、覆盖率改变、输入 checksum 改变或目标块不再 canonical + finalized 时，旧批准失效并回到审批前状态。
8. Publish 前再次核验目标 block/hash、projector manifest、input/content checksum 与批准记录；任一不一致均不得发布 Root。

### 4.2 Coverage checksum 规范化协议

`coverage_sha256` 必须由 Builder 与 Reconciler 用完全相同的字节序列计算：

1. 从 `dividend_projection_coverage_v1` 读取目标 snapshot 及之前、属于固定 projector manifest 的全部 coverage 行。
2. 按以下键升序稳定排序：

```text
environment_id
deployment_set_id
stream_key
block_number
tx_index
log_index
raw_event_id
projector_key
projector_version
```

3. 每一行编码为一行 UTF-8 canonical JSON object，字段顺序固定为：

```text
environment_id
deployment_set_id
stream_key
block_number
block_hash
tx_hash
tx_index
log_index
raw_event_id
projector_key
projector_version
receipt_status
```

4. 缺失 Receipt 时 `receipt_status` 必须编码为 JSON `null`，不得省略字段，也不得写成空字符串。
5. 行与行之间用单个 `\n` 连接，最后一行后不追加额外空行。
6. `coverage_sha256 = SHA-256(exact UTF-8 bytes)`，输出为 64 位小写 hex。
7. `coverage_event_count` 等于参与 hash 的行数；任一行排序、字段、NULL 编码或换行差异都视为不同 coverage。

### 4.3 Projector manifest 规范化协议

`dividend_artifacts.projector_manifest` 是 Artifact 的唯一权威 projector manifest；`dividend_publish_preflights` 不保存第二份原始 JSON。Preflight 只能通过 `artifact_id` 和复合外键绑定该 Artifact 的 `projector_manifest_sha256`。

`projector_manifest_sha256` 必须按以下规则计算：

1. manifest 顶层必须为 JSON object；key 按 Unicode code-point 升序递归排序；
2. 值只允许 JSON object、array、string、boolean、null 和十进制整数字符串；禁止 JSON number、浮点数、指数表示、重复 key 和未定义字段；
3. object 输出不含空白，格式为 `{"key":value}`；array 保持声明顺序；string 使用 RFC 8259 JSON escaping；
4. 使用 UTF-8 编码，不添加 BOM 或尾随换行；
5. `projector_manifest_sha256 = SHA-256(exact UTF-8 bytes)`，输出为 64 位小写 hex；
6. Builder 在写入 Artifact 时计算该 hash；Preflight 和 Reconciler 只接受与 Artifact 已存 hash 完全相等的值，并从 Artifact 读取原始 manifest；任何不一致均 fail closed。

## 5. 守恒与异常

Indexer/Projector 必须生成但不自动“修正”的异常：

- Token Transfer ledger 与 `totalSupply/balanceOf` readback 不一致；
- Router 交易与 Token/Adapter/Pair 的数量或税费拆分不一致；
- FeeVault 实际余额小于 bucket accounting；
- SupportPool 回购不是 0.01 BNB、间隔小于 60 秒或 Token recipient 不是 Locker；
- Locker release 未到期、recipient 不一致或永久模式被释放；
- Dividend allocation/claim/root/checksum/carry 不一致或重复 claim；
- Staking 累计奖励责任超过实际 reserve；
- Oracle stale、deviation、LIQUIDITY_LOW 或状态跳转异常；
- 未知地址产生治理事件、角色变化、Pause/Unpause 或 system/pair/whitelist 变更。

异常进入 `system_anomalies`，按安全规范映射 P0/P1/P2/P3/INFO，并绑定 block/hash/tx/log 证据。

## 6. 状态机

### 6.1 Deployment

`DISCOVERED -> STATIC_VERIFIED -> LIVE_VERIFIED -> ACTIVE`。任何证据失败进入 `REJECTED`；新 deployment set 激活前旧集先 `SUPERSEDED/DEACTIVATED`，禁止同时 ACTIVE。

### 6.2 Cursor

`BOOTSTRAP -> SCANNING -> HEALTHY`；RPC/延迟异常进入 `DEGRADED`；Hash 不一致进入 `REORG_RECOVERY`；证据无法恢复进入 `HALTED`。只有人工或满足冻结的自动恢复条件才能离开 HALTED。

### 6.3 Raw Event

`OBSERVED -> CONFIRMED`。分支失效可从 `OBSERVED/CONFIRMED/DECODE_FAILED` 进入 `ORPHANED`；解码失败进入 `DECODE_FAILED`，ABI 修正后可重新解码但必须保留原记录。投影是否完成不属于 Raw Event 状态，由所需 `(projector_key, projector_version)` 的 receipt 集合判断。

### 6.4 Governance Command

`CREATED -> VALIDATED -> PENDING_APPROVAL -> APPROVED -> QUEUED -> SIGNING -> SUBMITTED -> CONFIRMED -> FINALIZED`。可按规范进入 `REJECTED/CANCELLED/FAILED/EXPIRED`。HTTP cancel 只创建不可变 cancellation intent；Reconciler 在锁定 Command 与 intent 后，才可消费 intent 并在 `CREATED/VALIDATED/PENDING_APPROVAL/APPROVED/QUEUED` 写入 `CANCELLED`。存在未消费 intent 的 `QUEUED` Command 不得进入 `SIGNING`；intent 只能在 Command 已处于不可取消状态时解析为 `REJECTED`，不得出现 `REQUESTED -> REJECTED -> SIGNING`。`SUBMITTED` 后取消不撤销链上交易，只能停止替换并继续跟踪结果。

### 6.5 Dividend Epoch

`DRAFT -> SNAPSHOT_BUILDING -> SNAPSHOT_READY -> APPROVAL_PENDING -> APPROVED -> PUBLISH_QUEUED -> CLAIM_OPEN -> CLOSE_QUEUED -> CLOSED`。重建 artifact 会回到审批前并撤销旧批准。合约允许时可 `CANCELLED`；任何构建错误为 `FAILED`。API 在 `APPROVED` 绑定当前 Publish Command 后，Builder 才可进入 `PUBLISH_QUEUED`。若该**当前绑定** Command 被 Reconciler 判定为 `FAILED/CANCELLED/EXPIRED`，Reconciler 在同一事务把 Epoch 写为 `FAILED`；失败后必须经 `SNAPSHOT_BUILDING` 重建，不能直接回到 `PUBLISH_QUEUED` 复用旧 Command。

### 6.6 Job

`QUEUED -> RUNNING -> SUCCEEDED`；失败可在上限内重新 `QUEUED`，耗尽后 `DEAD_LETTER`。重试必须沿用业务 dedupe key，不创建第二个 Governance Command。

## 7. 冻结前 Gate

- 用部署 Commit ABI 自动生成完整 signature/topic0 并和 YAML 一致；
- 核对 11 个合约、Pair、各自 deployment block；
- 运维/安全批准 confirmation depth 与 reorg lookback；
- 数据负责人批准事件唯一键、投影顺序和回滚策略；
- 业务负责人批准每个事件到 API/DB 的映射；
- 完成后标记 `v2-event-1` 和 `v2-state-1 / FROZEN_FOR_DEVELOPMENT`。
## Artifact 重建与发布前复验

Artifact revision 是不可变构建结果。输入、coverage、projector version、snapshot、content、root 或 amount 任一变化，都必须创建新 revision；旧 Approval 不适用于新 revision。发布前由 Dividend Builder 生成有期限的 append-only Preflight：

- 每次验证使用独立 `validation_revision`；相同 Artifact/coverage/validator 在过期后可 INSERT 新 Preflight，旧记录永久保留且永不重新启用；
- Preflight 通过复合外键精确绑定 Artifact 的 content hash、root、amount、`input_sha256` 与 `projector_manifest_sha256`；它不复制原始 projector manifest，避免两份 JSON 证据漂移；
- 一个 Preflight 最多创建一个 `DIVIDEND_PUBLISH` Command；HTTP 重试必须返回原 Command；若旧 Command 在签名前永久失效，必须先生成新的 Preflight revision；
- API 仅将未过期 Preflight 绑定到 Command；Reconciler 在签名前按第 4.2 节复算 coverage，并重新读取四个固定快照 View；
- Preflight 过期、区块失去 canonical/finalized、Receipt 状态变化、checksum 不一致或审批不精确匹配时，Command 必须失败关闭，且不签名、不广播。

Dividend Epoch 生命周期写者边界：

- `bgp_dividend` 只驱动发布前状态，以及 `CLAIM_OPEN -> CLOSE_QUEUED`，不能写 `merkle_root`；
- `bgp_projector` 消费 `DividendRootPublished / EpochClosed`，对 event-derived 字段做列级更新：`state/merkle_root/claim_start/claim_end/carry_raw/updated_at`；`EpochCancelled` 只允许在 State YAML 明确的发布前 Builder 路径发生，不能由 Projector扩大成发布后取消。
- 数据库 Trigger 必须逐边匹配 State YAML：Builder 只走发布前边与 `CLAIM_OPEN -> CLOSE_QUEUED`；Projector 只走 `PUBLISH_QUEUED -> CLAIM_OPEN`、`CLOSE_QUEUED -> CLOSED/FAILED`；API 仅通过受控 bind function 在 `APPROVED` 绑定不可替换的当前 Publish Command，不拥有 Epoch 直接 UPDATE；Reconciler 只在该当前 `DIVIDEND_PUBLISH` Command 终止失败、取消或过期时走 `PUBLISH_QUEUED -> FAILED`；`CLOSED/CANCELLED` 不可离开。
- `PUBLISH_QUEUED -> CLAIM_OPEN` 是首次写入 root/claim window 的唯一边。进入 `CLAIM_OPEN` 后 `merkle_root/claim_start/claim_end` 不可原地改写；same-state 更新只允许角色拥有的非冻结字段与 `updated_at`。
