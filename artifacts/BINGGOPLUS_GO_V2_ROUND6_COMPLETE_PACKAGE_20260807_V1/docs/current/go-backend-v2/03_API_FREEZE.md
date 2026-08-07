# BingGoPlus Go Backend V2 API 冻结候选

状态：`FREEZE_CANDIDATE`  
机器规范：[openapi/binggoplus-api-v2.yaml](./openapi/binggoplus-api-v2.yaml)

## 1. 版本与边界

- Public：`/api/v2/projects/binggoplus`
- Admin：`/admin-api/v2/projects/binggoplus`
- V2 不兼容 V1 URL、DTO、分页、Session 或错误格式；
- DApp 链上写操作继续由用户钱包直接调用部署合约，后端不代签用户交易；
- Admin 链上写操作只创建异步 Governance Command，不在 HTTP 请求中同步签名并宣称成功；
- 不提供任意 `target/calldata/selector` 接口；每个高权限动作必须有显式 Endpoint、固定 target contract 和 selector；
- 不返回 `source=mock` 的成功数据；无法证明的数据必须 `UNAVAILABLE` 或明确错误。

## 2. 通用协议

### 2.1 成功与错误

成功：

```json
{
  "data": {},
  "meta": {
    "request_id": "uuid",
    "project": "binggoplus",
    "environment": "bsc_testnet",
    "chain_id": 97,
    "deployment_set_id": "uuid",
    "data_status": "LIVE",
    "observed_block": {
      "number": "123527207",
      "hash": "0x...",
      "finality": "CONFIRMED"
    },
    "generated_at": "2026-08-07T00:00:00Z",
    "schema_version": "v2"
  }
}
```

错误：

```json
{
  "error": {
    "code": "ORACLE_NOT_READY",
    "message": "Quote is unavailable until the deployed oracle is ready.",
    "details": {},
    "retryable": true
  },
  "meta": {}
}
```

成功响应不含 `error`，错误响应不含 `data`。

### 2.2 类型与可观测性

- Amount/Price numerator/denominator：十进制整数字符串；
- Block number：十进制字符串；chain ID、BPS、分页 limit 可用 JSON integer；
- EVM address/hash：小写 `0x` 字符串；
- 时间：UTC RFC 3339；
- 数据状态：`SYNCING | LIVE | STALE | DEGRADED | UNAVAILABLE`；
- 所有链上读结果绑定 observed block number/hash；
- `LIVE` 只表示达到冻结的确认深度，不表示 Mainnet 安全批准；
- 分页统一 `limit + cursor`，响应 `next_cursor`，不使用页码。

### 2.3 错误码

最低冻结集合：

`VALIDATION_ERROR`、`UNAUTHENTICATED`、`FORBIDDEN`、`CSRF_INVALID`、`RATE_LIMITED`、`NOT_FOUND`、`CONFLICT`、`IDEMPOTENCY_CONFLICT`、`DATA_SYNCING`、`DATA_STALE`、`CHAIN_UNAVAILABLE`、`DEPLOYMENT_UNVERIFIED`、`ORACLE_NOT_READY`、`ORACLE_STALE`、`LIQUIDITY_LOW`、`TRADING_NOT_OPEN`、`CONTRACT_PAUSED`、`QUOTE_EXPIRED`、`COMMAND_REJECTED`、`COMMAND_EXPIRED`、`SIGNER_UNAVAILABLE`、`UPSTREAM_ERROR`、`INTERNAL_ERROR`。

## 3. Public API

### 3.1 配置与系统状态

| Method | Path | 语义 |
|---|---|---|
| GET | `/config` | chain、Token 元数据、部署地址、ABI version、DApp 安全参数；只来自 ACTIVE deployment set |
| GET | `/system-status` | Indexer、Oracle、Trading、Pause、Signer-independent 数据状态 |
| GET | `/contracts` | 11 个合约和 Pair 的地址、部署证据、runtime verification 状态 |
| GET | `/market` | 价格、流动性、24h OHLC/volume/holder count；数据不足则字段为 `null` 并给状态，不造数 |

### 3.2 Wallet Session

保留 V1 已提供的能力，采用 HttpOnly/Secure/SameSite Cookie，不返回 Bearer Token：

| Method | Path | 语义 |
|---|---|---|
| POST | `/auth/nonce` | 生成一次性 EIP-191 challenge，绑定 address、chain ID、domain、issued/expiry |
| POST | `/auth/verify` | 验签、原子消费 nonce、创建 Session |
| POST | `/auth/logout` | 撤销当前 Session |

Nonce 只用一次、短时过期、服务端存 Hash；验签必须绑定 `chain_id=97` 和服务域，拒绝跨链/跨域重放。

### 3.3 Quote

| Method | Path | 必要输入 | 权威调用 |
|---|---|---|---|
| POST | `/quotes/buy` | `buyer`, `bnb_in_raw`, `slippage_bps`, `deadline_seconds` | Router `previewBuyFor(buyer, amount)` |
| POST | `/quotes/sell` | `seller`, `token_in_raw`, `slippage_bps`, `deadline_seconds` | Router `previewSell(seller, amount)` |

Quote 返回 amount、minimum out、税率和税费拆分、成本状态、Oracle 状态、deadline、Router 地址、observed block。后端不得自行重算税率替代合约，不得省略 buyer/seller 导致 whitelist/成本语义错误。非 `LIVE`、Oracle 非 READY、流动性不足、交易未开或合约暂停时 fail closed。

### 3.4 Wallet、交易与质押

| Method | Path | 语义 |
|---|---|---|
| GET | `/wallets/{address}/summary` | Token、BNB、有效余额候选、已质押本金、应计奖励、可领取分红、排名 |
| GET | `/wallets/{address}/transactions` | canonical confirmed 交易活动，cursor 分页 |
| GET | `/wallets/{address}/staking/positions` | 质押仓位 |
| GET | `/wallets/{address}/staking/earned` | 部署合约只读 earned + observed block |
| GET | `/staking/status` | reward rate、reserve、coverage、limits |

DApp 的 `stake/withdraw/claim` 仍由钱包调用 Pangu2Staking；API 不提供代签 Endpoint。

### 3.5 分红、回购与 Locker

| Method | Path | 语义 |
|---|---|---|
| GET | `/dividends/epochs/current` | 当前 Epoch 和生命周期 |
| GET | `/dividends/epochs/{epoch_id}` | 固定 snapshot、root、总额、领取窗口、carry |
| GET | `/dividends/epochs/{epoch_id}/proofs/{address}` | amount、leaf、proof、artifact checksum |
| GET | `/buybacks` | 回购记录，cursor 分页 |
| GET | `/locker/batches` | 锁仓批次，cursor 分页 |

Proof 只能在 artifact checksum、root 与链上 commitment 一致时返回 `LIVE`；否则 `UNAVAILABLE`。

### 3.6 产品文档中的未落地能力

`PRODUCT_PLANNING.md` 中“团队、推荐链接、推荐列表、佣金记录”没有部署合约、现有 Backend API 或可信数据源。V2 冻结不创建这些 Endpoint，也不从转账关系猜测推荐人。若产品确认新增，必须先冻结身份绑定、反女巫、佣金资金来源、隐私、撤销和链上/链下事实来源，作为独立大版本进入。

## 4. Admin 身份与 RBAC

### 4.1 Session

| Method | Path | 语义 |
|---|---|---|
| GET | `/csrf` | 设置/刷新 CSRF Cookie，返回请求 Token |
| POST | `/auth/login` | 建立 HttpOnly Session |
| GET | `/auth/me` | 当前管理员与权限 |
| POST | `/auth/logout` | 撤销 Session |

所有非 GET 请求必须同时通过 Session、Origin/Host 校验与 CSRF。链上写请求还必须带 `Idempotency-Key`。

### 4.2 角色

| 能力 | SUPER_ADMIN | OPERATOR | AUDITOR | VIEWER |
|---|:---:|:---:|:---:|:---:|
| Dashboard/Contract/Job 只读 | ✓ | ✓ | ✓ | ✓ |
| Audit 只读 | ✓ | ✓ | ✓ | — |
| Job retry | ✓ | ✓ | — | — |
| Governance command 创建 | ✓ | 限定低风险 action | — | — |
| Governance approve/reject | ✓ | — | — | — |
| Contract registry/evidence 管理 | ✓ | — | — | — |
| Admin user 管理 | ✓ | — | — | — |

请求者不能审批自己的高风险 Command。确切 action/role 矩阵在冻结时生成并以 deny-by-default 执行。

## 5. Admin Read API

| Method | Path | 语义 |
|---|---|---|
| GET | `/dashboard` | 交易、Epoch、回购、Locker、同步和异常总览 |
| GET | `/contracts` | Contract Registry + deployment evidence |
| GET | `/contracts/{contract_key}` | 地址、ABI、bytecode/readback/role 检查 |
| POST | `/contracts/evidence/readback-jobs` | 创建只读链上核验 Job，不改合约 |
| GET | `/jobs` | Job 列表 |
| GET | `/jobs/{job_id}` | Job 详情 |
| POST | `/jobs/{job_id}/retry` | 幂等重试符合策略的失败 Job |
| GET | `/audit-logs` | Append-only 审计日志 |
| GET | `/governance/read/trading-status` | tradingOpenAt、launch protection、whitelist 摘要 |
| GET | `/governance/read/buyback-status` | balance、last execution、next eligible、fixed amount/interval |
| GET | `/governance/read/oracle-status` | status、window、age、deviation、liquidity |
| GET | `/governance/read/pause-status` | 每个 Pausable 合约状态 |
| GET | `/governance/read/system-addresses` | Pair/System/Router/Vault/Pool/Locker 等绑定 |
| GET | `/governance/read/operator-balance` | signer 地址与 BNB 余额；不暴露 Secret |
| GET | `/staking/coverage` | reserve、liability、coverage |
| GET | `/governance/commands` | Command 列表 |
| GET | `/governance/commands/{command_id}` | 审批、attempt、receipt、finality |
| GET | `/dividends/epochs` | Epoch 列表与构建状态 |

## 6. Admin Write API

所有 Endpoint 返回 `202 Accepted` + Command/Job，不返回伪造的 `CONFIRMED`。

### 6.1 Command 控制

| Method | Path | Action |
|---|---|---|
| POST | `/governance/commands/{id}/approve` | 独立审批 |
| POST | `/governance/commands/{id}/reject` | 拒绝并记录原因 |
| POST | `/governance/commands/{id}/cancel` | 未签名前取消 |

### 6.2 明确的合约动作

| Method | Path | 约束 |
|---|---|---|
| POST | `/governance/actions/token-set-pair` | 仅部署 Pair；变更前后做地址/code/factory 检查 |
| POST | `/governance/actions/token-set-fee-whitelist` | address + enabled；批量有固定上限 |
| POST | `/governance/actions/token-set-system-address` | 仅冻结的 system type/address |
| POST | `/governance/actions/contract-pause` | body 指定 allowlist contract_key |
| POST | `/governance/actions/contract-unpause` | 高风险，需独立审批 |
| POST | `/governance/actions/buyback-trigger` | 合约仍强制 0.01 BNB/60 秒/Locker 去向 |
| POST | `/governance/actions/oracle-update` | permissionless update；仍经固定 Oracle target |
| POST | `/governance/actions/locker-release` | 仅到期 batch，recipient 由合约固定 |
| POST | `/governance/actions/fee-vault-convert-support` | amount/max slippage/deadline 不超过部署上限 |
| POST | `/governance/actions/fee-vault-fund-dividend` | epoch/amount，防重复业务审批 |
| POST | `/governance/actions/staking-fund-rewards` | 固定 Staking target，记录 reserve 变化 |
| POST | `/governance/actions/staking-set-reward-rate` | 不超过部署合约 cap 且 coverage 预检 |

这些 URL 由机器规范中的有限 `action` enum 与 action-specific parameter schema 生成；请求体不能提供 target、selector 或 calldata。不提供 `open-trading`：部署集已经成功开盘且该操作一次生效不可逆。API 只展示证据，重复尝试必须被拒绝。

### 6.3 Dividend 生命周期

| Method | Path | 语义 |
|---|---|---|
| POST | `/dividends/epochs` | 创建 DRAFT；snapshot block/hash 必须来自 canonical + finalized 候选视图 |
| POST | `/dividends/epochs/{id}/build` | 异步锁定 projector manifest，从窄化历史视图重放到固定 block/hash，构建排名、分档、allocation、Merkle artifact |
| POST | `/dividends/epochs/{id}/approve` | 批准精确 checksum/root/amount |
| POST | `/dividends/epochs/{id}/publish` | 创建发布 root 的 Governance Command |
| POST | `/dividends/epochs/{id}/close` | 领取窗口后创建 close Command |
| POST | `/dividends/epochs/{id}/cancel` | 仅合约和状态允许时取消 |

Root builder 与 publisher 分权；任何重建导致 checksum/root 改变都使原批准失效。

Builder 禁止使用不断前进的 `token_balances_current/staking_positions` 冒充历史快照。Artifact 必须保存 projector key/version manifest、规范化输入 checksum/row count、snapshot block/hash、算法版本和完整内容 checksum；发布前再次确认目标 block/hash 仍为 canonical + finalized，覆盖率或输入发生变化时 fail closed 并撤销旧批准。

## 7. Governance Command 语义

1. API 校验 Session、RBAC、CSRF、Idempotency、ACTIVE deployment、参数上限和当前链上状态。
2. 生成规范化参数和 request hash，固定 target/selector，创建 `CREATED/VALIDATED` Command。
3. 高风险动作进入 `PENDING_APPROVAL`；批准后才可 `QUEUED`。
4. Reconciler 独占 signer nonce，签名、广播、跟踪替换和回执。
5. 只有成功 receipt 达到确认深度后为 `FINALIZED`；revert 为 `FAILED`。
6. 相同 Idempotency-Key + 相同请求返回原 Command；相同 Key + 不同请求返回 `409 IDEMPOTENCY_CONFLICT`。
7. 交易已广播后 HTTP 重试不得创建第二笔业务动作。

## 8. 限流与缓存

- Auth、Quote、Proof、Admin write 分别限流；具体阈值在部署配置冻结，不写死于业务代码；
- Quote 缓存 key 必须包含 buyer/seller、amount、slippage、deployment set 和 observed block；
- Admin write、Session、Proof 不经公共 CDN 缓存；
- 所有缓存条目在 deployment set 切换、Reorg 或 pause/trading/oracle 状态变化时失效；
- `Retry-After` 只在可重试错误返回。

## 9. 冻结前人工决策

- 产品批准 Public 字段、未落地推荐域的排除以及 Dividend 有效余额规则；
- 前端/后端共同批准 OpenAPI，前端承诺只使用生成 Client；
- 安全批准 Session、CSRF、RBAC、Command 审批和 selector allowlist；
- 运维批准数据状态、确认深度、限流和超时；
- 签署后标记 `v2-api-1 / FROZEN_FOR_DEVELOPMENT`，任何破坏性变化必须升 API 大版本或形成 Decision Record。
## Dividend 写接口精确绑定补充

Dividend 的 `build/approve/publish/close/cancel` 使用独立路径和独立 closed schema，不再共用可选字段的通用 transition body：

- `approve` 必须提交 `artifact_id/artifact_sha256/expected_merkle_root/expected_total_reward_raw/decision`；
- `publish` 必须提交上述 Artifact 身份与 `publish_preflight_id`，成功返回 Governance Command；
- 发布请求只能创建 action=`DIVIDEND_PUBLISH` 的 Command，数据库要求其 `dividend_publish_preflight_id` 非空，且同一 Preflight 最多创建一个 Publish Command；
- API 只消费已存在且未过期的不可变 Preflight，不拥有历史 View 的底表权限，也不得自行伪造 coverage 结论；过期后必须由 Builder INSERT 新的 `validation_revision`，旧 Preflight 永不重新启用；
- Preflight 必须通过数据库复合外键精确匹配 Artifact 的 input/projector manifest hash；
- Reconciler 在签名前必须用同一 coverage 规范化协议重新检查 snapshot canonical/finalized、coverage、input/content checksum、审批与 root/amount；任何漂移均 fail closed，且不签名、不广播；
- Reconciler 不得创建 Command，也不得改写 Command 的 expiry/context/binding；过期 Command 只能失败关闭或经新 Preflight/新 Command 重新进入流程。
