# BingGoPlus Go Backend V2 部署环境冻结候选

状态：`FREEZE_CANDIDATE`

## 1. 部署原则

- 旁路新建，不修改现有 Laravel、旧 Worker、DApp/Admin 的当前运行环境；
- 同一不可变 Go 镜像按不同 command 运行 `api/indexer/projector/reconciler/dividend-builder`；
- V2 使用独立 Database、账号、Secret、网络和路由前缀；
- 测试网已部署合约只读接入，不运行 Deploy/Bootstrap/Finalize/OpenTrading；
- BSC Mainnet `chain_id=56` 为配置、数据库、进程启动和 Signer 四重 NO-GO；
- API 进程不持有私钥，Signer/Reconciler 单独隔离；
- 不将真实 `.env`、私钥、助记词、带 API Key 的 RPC URL 写入仓库或镜像；
- 不把前端配置当安全边界，地址、chain ID、权限和上限均由后端/合约校验。

## 2. 环境矩阵

| 环境 | Chain | 合约 | 数据库 | 链上写入 | 用途 |
|---|---:|---|---|---|---|
| LOCAL | 97 的录制/代理只读数据，或独立本地链 | 不使用生产式部署脚本 | 本机独立库 | 禁止 | 开发结构与 API |
| DEV | 97 | 已实测 deployment set | 独立 DEV 库 | 默认禁止 | 集成开发 |
| SHADOW | 97 | 已实测 deployment set | 独立 SHADOW 库 | 禁止 | 从部署块重扫、差异分析 |
| BSC_TESTNET_RELEASE | 97 | 已实测 deployment set | Release 库 | 经审批的显式动作 | 正式测试网服务 |
| BSC_MAINNET | 56 | 无 | 无 | 永久禁止 | 不在本基线范围 |

LOCAL 不得把任意本地地址误标为已实测 deployment set。需要合约行为时，由独立测试 Agent 规划固定本地部署或固定区块 Fork；本轮不搭建、不执行。

## 3. 服务与端口

以下端口是 V2 候选，不修改旧 Compose：

| 入口/进程 | 容器端口 | 本地映射 | 暴露范围 |
|---|---:|---:|---|
| Edge/Gateway | 8080 | 8080 | 浏览器入口；按路径切 V1/V2 |
| Go API | 8081 | 8081 | 内网；Public + Admin API |
| DApp Vite | 5173 | 5173 | 本地开发 |
| Admin Vite | 5174 | 5174 | 本地开发 |
| PostgreSQL | 5432 | 5433 | 仅本地可映射；其他环境内网 |
| API metrics | 9091 | 不默认暴露 | 监控网 |
| Indexer metrics | 9092 | 不默认暴露 | 监控网 |
| Projector metrics | 9093 | 不默认暴露 | 监控网 |
| Reconciler metrics | 9094 | 不默认暴露 | 监控网 |
| Dividend Builder metrics | 9095 | 不默认暴露 | 监控网 |

V2 不依赖旧 Mock API。Redis 不是业务事实或队列的必需组件；若后续只为限流/缓存引入，必须走开源准入和故障降级设计，不能影响资金/治理正确性。

## 4. 进程拓扑

```text
Browser
  -> Edge 8080
      -> /api/v1, /admin-api/v1        -> Laravel V1（切换前）
      -> /api/v2, /admin-api/v2        -> Go API 8081
      -> DApp/Admin static assets

Go API ----------- read/write ----------> binggoplus_go.binggoplus_v2
Indexer ---------- RPC read + raw write -> same database
Projector -------- confirmed event read -> same database
Dividend Builder - fixed snapshot read --> same database/artifact store
Reconciler ------- approved command read -> isolated signer -> BSC Testnet RPC

Old Worker/Laravel ----------------------> old database only
```

进程使用独立数据库角色：

- `bgp_api`：业务读、Session/Command/Approval、Dividend DRAFT 创建和 append-only Audit；Command 仅列级更新 `state/updated_at`；不能写 raw event、signer nonce 或 tx attempt；
- `bgp_indexer`：block/raw event/cursor/lease；
- `bgp_projector`：projection、anomaly，以及对 Dividend 链上事件派生的 Epoch 列级更新（`state/merkle_root/claim window/carry`）；
- `bgp_dividend`：只读 finalized block、projection coverage、Token/Staking 历史视图并写 artifact/allocation/preflight/job；不能读取 current 表生成固定快照，不能写 Epoch `merkle_root`，不能发布 root；
- `bgp_reconciler`：读取 approved command 与 Dividend evidence/View，列级更新 Command `state/updated_at`，并写 signer nonce、tx attempt 和 append-only Audit；不得 INSERT Command；
- `bgp_auditor`：治理、部署证据、Audit、Job/Anomaly 只读；不读取认证或 signer 状态；
- `bgp_migrator`：仅发布阶段执行 DDL，运行进程不持有该权限；
- `bgp_readonly`：产品投影、状态与排障数据只读。

角色和对象权限以 [sql/0002_binggoplus_v2_runtime_privileges.sql](./sql/0002_binggoplus_v2_runtime_privileges.sql) 为机器规范。平台预先创建 Login/Group Role、Database `CONNECT` 和 Secret；仓库脚本不创建密码。运行时角色不得拥有 Superuser/CreateRole/CreateDB/BypassRLS，不得拥有 Schema、继承 `bgp_migrator` 或获得切换到迁移角色的能力。

四个 Dividend `security_barrier` View 由 `bgp_migrator` 持有；`bgp_dividend` 只有 View SELECT，不能读取底层 Raw Event/Receipt/Ledger/Staking 表，也不能 CREATE/REPLACE View。部署验收必须核对实际 owner、继承关系和 `information_schema.role_table_grants`，不能只检查脚本文本。

## 5. 配置冻结

配置分为非秘密配置和 Secret 引用。

### 5.1 非秘密配置

- `APP_ENV`、`HTTP_ADDR`、`METRICS_ADDR`；
- `PROJECT=binggoplus`、`CHAIN_ID=97`；
- `DEPLOYMENT_SET_ID`、ABI manifest 路径；
- confirmation depth、reorg lookback、RPC 超时/重试上限；
- Session/Challenge/Idempotency TTL；
- 各进程 enable flag；
- `MAINNET_WRITES_DISABLED=true`，不可由普通环境变量改为 false。

### 5.2 Secret 引用

- PostgreSQL DSN；
- primary/backup RPC URL；
- Admin password/pepper、Session/CSRF key；
- Signer provider credential/keystore 解密材料；
- Artifact Store credential；
- 告警通道 credential。

配置日志只记录 Secret 名称和 Hash/版本，不记录值。RPC URL 需脱敏 query/userinfo。

## 6. Signer 边界

- API 永远不接收、存储或记录私钥；
- Reconciler 通过最小接口请求签名，Signer 只接受 `chain_id=97`、固定 sender、固定 target/selector allowlist；
- 签名前再次读取 ACTIVE deployment、Command approval、expiry、expected state、nonce 和余额；
- Signer 不接受任意 raw calldata；编码由批准 ABI 和 action schema 生成；
- 同一 signer/chain 只有一个 nonce writer，使用数据库租约与 fencing token；
- 高风险动作 requester 与 approver 分离；
- Signer 不可用时 Command 留在可追踪状态，API 不回退到本地私钥；
- Mainnet chain ID、未知 target、未知 selector、过期 command、状态变化全部 fail closed。

## 7. 镜像与发布

### 7.1 镜像

- 多阶段构建，运行镜像无编译器、包管理器和源码写权限；
- 非 root、只读 root filesystem、临时目录单独挂载；
- 镜像用 digest 部署，禁止 floating tag；
- 镜像记录 Go version、module graph、OpenAPI/SQL/ABI hash、source commit 和 SBOM；
- 同一 digest 推进 DEV -> SHADOW -> TESTNET_RELEASE，不在环境内重建。

### 7.2 发布顺序

1. 人工批准 DB/API/Event/State/Dependency freeze。
2. 构建镜像和 SBOM，签名并登记 digest。
3. 以 `bgp_migrator` 只执行向前 Schema Migration，并应用运行时最小权限脚本；
4. 导入 deployment evidence，完成只读 runtime/readback Gate。
5. 启动 Indexer，在固定 target block/hash 完成重扫。
6. 启动 Projector，完成 invariant/anomaly 检查。
7. 启动 API Shadow，只比较语义，不接流量。
8. 按 Config/Status -> Trade -> Wallet -> Staking -> Dividend/Buyback 切 Public 读流量。
9. 新建 Admin 用户，切 Admin 只读。
10. 撤销 Laravel 治理写权限后，才允许 Go Reconciler 接管测试网写入。
11. 观察期后停旧 Worker/Laravel；旧库只读归档。

## 8. 健康与就绪

- `/health/live`：仅进程存活，不访问依赖；
- `/health/ready`：数据库、ACTIVE deployment、必要 RPC、Cursor freshness；
- Reconciler readiness 额外检查 signer、chain ID、nonce lease、target allowlist；
- API 可在 Indexer STALE 时保持存活，但相关链上数据返回 STALE/UNAVAILABLE；
- 不因 backup RPC 有响应就忽略 block hash 不一致；多 RPC 分歧必须告警并 fail closed。

## 9. 备份、恢复与回滚

- 数据库持续备份并定期验证恢复；raw event、governance、audit 永久保留；
- Artifact 按 checksum 不可变保存，root 发布后禁止覆盖；
- Projection 可从 canonical raw event 重建；raw event 不可人工改成“正确结果”；
- G2-G6 可由 Edge 将读流量切回 V1；
- Governance 切换后严禁恢复双写，Go Reconciler继续追踪所有已广播交易；
- 链上 Trading、Root、Role、Pause 和交易不可通过数据库或镜像回滚；
- 严重事件按通用合约安全规范保全交易、回执、block/hash、日志和签名证据。

## 10. 监控与告警

必须覆盖：

- Head/Cursor lag、RPC 错误、RPC block hash 分歧、Reorg 深度；
- decode/projector failure、anomaly 数量；
- runtime code hash、Role、Pause、Pair/System/Whitelist、Trading 状态变化；
- Oracle stale/low liquidity/deviation；
- Fee bucket/accounting、Support balance、0.01 BNB/60 秒回购；
- Locker 到期/释放、Dividend commitment/root/claim/carry；
- Staking reserve/liability coverage；
- Governance approval、signer nonce、stuck/replaced/reverted tx；
- Admin auth failure、CSRF、RBAC deny、idempotency conflict；
- 不在日志、metric label 或 trace 中放地址以外的认证 Secret。

## 11. 环境冻结 Gate

- 平台负责人批准端口、网络、镜像、数据库角色/继承关系与备份；
- 安全负责人批准 Secret/Signer/RBAC/CSRF/Mainnet NO-GO；
- 数据负责人批准单写者与恢复策略；
- 合约负责人批准 deployment set 和 readback 清单；
- 前端负责人批准 Edge 路由与分域切换；
- Gate 通过后生成实际 Compose/Helm/IaC，本轮不创建运行环境。
