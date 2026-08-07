# BingGoPlus Go Backend V2 架构与旁路替换计划

## 1. 决策

采用 Greenfield Go 模块化单体：一个仓库、一个 Go Module、一个独立 PostgreSQL Database、一个 OpenAPI、一个 ABI 生成流程，构建多个可独立运行的进程。

“Greenfield”只针对实现、数据库和 API 大版本，不针对业务事实。合约和测试网历史是外部既有系统，必须继承。

## 2. 目标结构

```text
backend-go/
├── cmd/
│   ├── api/                 # Public API + Admin API
│   ├── indexer/             # Block、Log、Confirmation、Reorg
│   ├── projector/           # Confirmed Event -> Read Model
│   ├── reconciler/          # Governance command、nonce、receipt
│   └── dividend-builder/    # Snapshot、ranking、allocation、Merkle artifact
├── api/
│   ├── openapi.yaml         # 冻结规范的工作副本
│   └── generated/           # 自动生成，禁止手改
├── contracts/
│   ├── abi/                 # 部署提交 ABI + hash manifest
│   ├── bindings/            # abigen 生成，禁止手改
│   └── deployments/         # chain/address/block/runtime hash
├── db/
│   ├── migrations/          # 唯一 Migration 来源
│   ├── queries/             # sqlc SQL
│   └── generated/           # sqlc 生成，禁止手改
├── internal/
│   ├── domain/              # 无 HTTP/SQL/RPC 依赖的业务规则
│   ├── application/         # Use Case 与事务边界
│   ├── chain/               # RPC、binding、receipt、signer 接口
│   ├── indexer/             # stream、cursor、lease、reorg
│   ├── projector/           # 幂等投影器
│   ├── governance/          # command、approval、nonce、receipt
│   ├── dividend/            # snapshot、tier、artifact
│   ├── auth/                # Admin/Wallet session、CSRF、RBAC
│   ├── store/               # repository adapter
│   ├── transport/http/      # handler、middleware、error mapping
│   └── observability/       # log、metric、trace
└── tools/                   # 生成与静态校验入口
```

## 3. 运行组件与所有权

| 进程 | 唯一职责 | 禁止职责 |
|---|---|---|
| `api` | HTTP、认证、RBAC、只读 RPC、创建 command/job | 不长期持有扫描租约，不直接管理链上 nonce，不改写 Command expiry/binding |
| `indexer` | Head、block、log、确认、Reorg、raw event | 不写业务投影，不发送治理交易 |
| `projector` | Confirmed event 的幂等业务投影、Reorg 补偿，以及 Dividend 链上事件派生的 Epoch 状态/Root | 不用 RPC 覆盖链上事件事实，不回写 Builder 的发布前 Epoch 状态 |
| `reconciler` | 审批后的签名、广播、替换、receipt、finality | 不接收外部 HTTP，不构造未列入白名单的 calldata，不创建 Command，不改写 Command expiry/context |
| `dividend-builder` | 固定区块余额、Top 100、分档、artifact、proof、publish preflight | 不直接发布 root；不写 Epoch `merkle_root`；发布必须进入治理 command |

## 4. 不变量

### 4.1 单一事实源

- 合约行为：实测部署字节码和部署提交 ABI；
- 历史事实：BSC Testnet canonical block/log；
- HTTP 契约：OpenAPI；
- 表结构：`binggoplus_v2` SQL Migration；
- 业务解释：业务继承矩阵；
- 金额：DB `NUMERIC(78,0)`、Go `big.Int`、JSON 十进制整数字符串；
- 前端类型：只从 OpenAPI 生成。

### 4.2 单写者

- 每个环境只有一个 Indexer Writer；
- Go 与旧 Worker 永不写同一 Database/Schema；
- Governance 广播只有 Go Reconciler 一个写者；
- 切换写权限前必须先撤销旧写入口；
- API 请求只创建 Command，不同步声称链上成功。

### 4.3 合约继承

- 不运行 Deploy、Bootstrap、Finalize、OpenTrading 脚本；
- 从部署区块重扫，不从“当前块”开始；
- 所有 quote 必须调用部署 Router 的用户感知 preview；
- 所有 control action 必须来自冻结 selector 白名单；
- 后端不得重算税率替代合约，不得生成绕过 TradeRouter 的交易；
- 脚本修复只作为以后运维规程，不反向宣称已改变部署字节码。

## 5. 开发前必须完成的任务

### F00：原系统证据盘点

- 路由、Controller、前端调用、DTO、Migration、Worker SQL 全量对照；
- 标出“已实现并被调用”“已实现未接入”“Mock/501”“重复或冲突”；
- 形成 V1 能力到 V2 Endpoint/Table 的映射。

### F01：测试网合约基线固化

- 导入 `Deploy/Bootstrap/Finalize/OpenTrading` 广播回执；
- 固定 deployment set、source commit、address、deploy tx、deploy block、block hash；
- 只读补录 runtime bytecode hash、当前角色、暂停状态、开盘状态和关键 getter；
- 证明 DApp 地址与 deployment set 一致；
- 明确过期地址组不得激活。

### F02：合约修复与审核继承

- 将既往 P0/P1/P2/P3 结论绑定到提交；
- 判断修复是否为部署提交祖先；
- 区分 runtime 修复、测试/文档修复、部署后脚本修复；
- 未关闭项转为 API fail-closed、Admin 警告或独立合约修复决策。

### F03：业务逻辑冻结

- 冻结税率优先级、成本状态、资金路径、回购、锁仓、分红、质押和权限矩阵；
- 每条规则绑定 deployed source 函数、事件、API 字段和 DB 投影；
- 任何旧文档与 deployed source 冲突时以部署事实为准并记录差异。

### F04：数据库冻结

- 批准 `binggoplus_go.binggoplus_v2`；
- 批准地址/hash/金额/区块/时间类型；
- 批准 cursor 的 `next_block` 语义；
- 批准 raw event 唯一键和 canonical/reorg 规则；
- 批准链上重建与纯链下重新初始化边界；
- 旧 Laravel Migration 和 Worker SQL 不进入新运行链路。

### F05：API 冻结

- 保留 V1 已有能力，补齐前端和合约已需要但 V1 未冻结的能力；
- 删除 Mock 作为可返回成功数据源；
- quote 增加 buyer/seller 地址并绑定观察区块；
- Admin 写操作统一为 202 Command，保留显式业务 Endpoint；
- 固定认证、RBAC、CSRF、Idempotency、错误码和分页。

### F06：事件与状态机冻结

- 事件必须从部署 ABI 自动核对；
- 每个事件明确 stream、projector、unique key、reorg 行为；
- Contract、Cursor、Raw Event、Projection、Job、Governance、Dividend 状态机无歧义。

### F07：框架、工具链与许可证冻结

- 固定 Go minor/patch 和所有依赖版本；
- 固定 OpenAPI、ABI、SQL 生成工具；
- 审查 LGPL/MIT/Apache 等许可证与 NOTICE；
- CI 禁止 `@latest` 和非冻结依赖回退。

### F08：部署与安全边界冻结

- 固定 Local/Dev/Shadow/Testnet Release 环境；
- 固定端口、镜像、Database、RPC、Secret、Signer 和网络边界；
- API 不持有明文私钥；
- `chain_id=56` 永久拒绝启动写进程；
- 固定旁路路由、单写者切换和回滚方式。

测试矩阵由独立测试 Agent 在实现后制定和执行，不阻断本轮 F00-F08 的设计产出。

## 6. 开发执行阶段

### G0：签署冻结包

输入：F00-F08 文档与机器规范。

输出：审批记录、未决项归零、版本标记 `v2-contract-1 / v2-db-1 / v2-api-1`。

### G1：Go 基础骨架

只实现配置、日志、数据库连接、Migration runner、OpenAPI/ABI/sqlc 生成、health 和优雅退出。不实现业务 Handler。

### G2：部署基线导入与 Indexer 旁路重扫

- 导入实测 deployment set；
- 从每个合约的 deployment block 扫描到固定目标块，再追最新块；
- 写 `chain_blocks`、`chain_raw_events`、`chain_cursors`；
- 旧 Worker 继续服务旧系统，但不能访问新 Database。

### G3：Projector 与读模型

按顺序落地 Token ledger、Trade、Cost Basis、Staking、Dividend、Fee Vault、Buyback、Locker、Oracle、Role/Control。所有读模型可从 canonical raw event 重建。

### G4：Public API 影子运行

发布 `/api/v2/...`，不改 DApp。Quote 只调用已部署 Router preview；非 LIVE 时 fail closed。对读接口做语义影子比较，不要求兼容 V1 JSON。

### G5：DApp 分域切换

使用生成 TypeScript Client，按 Config/Status、Trade、Wallet、Staking、Dividend、Buyback 分域切换。链上写交易仍由钱包直接调用已部署合约。

### G6：Admin Auth 与只读切换

新建管理员账号；不迁移旧 Session。切换 Dashboard、Contract Evidence、Jobs、Audit、Governance Read、Staking Coverage。

### G7：Governance 写路径切换

先关闭 Laravel 写入口，再启用 Go Command/Approval/Signer/Reconciler。显式 Endpoint 创建异步 Command；只有 confirmed receipt 才是成功。

### G8：Dividend Builder 与业务 Job

从 canonical + finalized 的固定 snapshot block/hash 出发，锁定 projector manifest，通过窄化 Token/Staking 历史视图重放构造 Top 100、35/25/25/15 分档、档内按有效余额分配、整数尾差、input/artifact checksum 和 Merkle root；禁止用 current 表回填历史。批准与发布分别进入治理流程。

### G9：停用旧后端

停止旧 Worker 和 Laravel API/Job；旧库只读归档，不导入新库。确认旧进程不再持有租约、数据库写权限、RPC 写权限或签名权限。

## 7. 回滚

- G2-G6 可按 Endpoint Family 将读流量切回 V1；
- G7 后不能恢复双写，Go Reconciler 必须继续跟踪已经广播的交易；
- 新 Schema 只做向前修正，不做破坏性 down migration；
- Projection 可删除后从 canonical raw event 重建，raw event 不手工改造成“正确结果”；
- 链上交易、已发布 Dividend Root 和已开启 Trading 不可由数据库回滚。
