# BingGoPlus Go Backend V2 框架与依赖准入

状态：`LEGACY_DEPENDENCY_CANDIDATE / FLAP_F1_REASSESSMENT_REQUIRED / NO_DOWNLOAD_AUTHORIZED`

> Go 技术栈候选继续作为输入，但 Flap ABI/RPC、Vault 示例、SDK 与新依赖必须在 F1 重新完成开源准入。既有条件许可证批准不得自动扩展到新使用边界。

## 1. 结论

采用单 Go Module 的模块化单体，不采用微服务框架、ORM、通用智能合约网关或任意 Calldata SDK。以 Go 标准库为默认，外部库只解决成熟、边界清晰的问题：HTTP 路由、PostgreSQL Driver、SQL 生成、Migration、OpenAPI 生成、EVM ABI/RPC、可靠 Job、Telemetry。

本文件仅形成 `REFERENCE_PROJECT` 与 `ADOPTION_CANDIDATE`。依据《开源项目通用引用准入规则 V1.0》，当前未获得 `APPROVE_DOWNLOAD`，不得由执行 Agent 下载、安装、复制或提交任何候选依赖；人工完成许可证、版本、POC、TCO、SBOM 和 Decision Record 后，才可把候选改为 `APPROVED_DEPENDENCY`。

## 2. Go 基线

| 项目 | 候选决策 |
|---|---|
| 语言 | Go；精确 minor/patch 为 `UNRESOLVED_VERSION_PIN` |
| Module | 单一 `backend-go/go.mod` |
| 架构 | modular monolith + ports/adapters；不引入框架 DI 容器 |
| HTTP | 标准 `net/http` + 候选轻量 Router |
| DB | 显式 SQL；不使用 Active Record/反射 ORM |
| Amount | `math/big.Int` + 领域值对象；禁止 float |
| JSON | OpenAPI 生成 DTO；领域模型不直接暴露 |
| Chain | 批准 ABI 生成 binding；RPC/receipt/signer 有自有端口接口 |
| Queue | PostgreSQL 事务 Job；不是业务事实源 |
| Config | 标准环境变量解析 + 强类型校验；不引入远程动态配置作为资金规则 |
| Logging | 标准 `log/slog`，结构化且默认脱敏 |

Go 精确版本必须从 Go 官方稳定发布中选定，记录 release、校验值和 EOL/支持策略。禁止 `latest`、浮动 Docker tag、浮动 Git branch。

## 3. 开源项目分类

| 项目 | 用途 | 分类 | 许可证初筛 | 结论 |
|---|---|---|---|---|
| [go-chi/chi](https://github.com/go-chi/chi) | HTTP Router/Middleware 组合 | ADOPTION_CANDIDATE | MIT 候选 | 做基准与 API 可读性 POC |
| [jackc/pgx](https://github.com/jackc/pgx) | PostgreSQL Driver/Pool | ADOPTION_CANDIDATE | MIT 候选 | 优先候选 |
| [sqlc-dev/sqlc](https://github.com/sqlc-dev/sqlc) | SQL -> 类型安全 Go | ADOPTION_CANDIDATE | 需核验当前 release/license | 生成代码必须可复现 |
| [pressly/goose](https://github.com/pressly/goose) | SQL Migration CLI | ADOPTION_CANDIDATE | Apache-2.0 候选 | 只允许唯一 Migration 来源 |
| [oapi-codegen/oapi-codegen](https://github.com/oapi-codegen/oapi-codegen) | OpenAPI -> Go Server/Client | ADOPTION_CANDIDATE | Apache-2.0 候选 | 与前端生成策略一起 POC |
| [ethereum/go-ethereum](https://github.com/ethereum/go-ethereum) / [abigen](https://geth.ethereum.org/docs/tools/abigen) | ABI、RPC、类型、binding | CONDITIONAL_ADOPTION_CANDIDATE | LGPL/GPL 组件风险，必须逐包法律复核 | 不批准前不得集成或静态发布 |
| [riverqueue/river](https://github.com/riverqueue/river) | PostgreSQL Job、重试、唯一 Job | CONDITIONAL_ADOPTION_CANDIDATE | MPL-2.0 候选，需文件边界复核 | 可替换为最小自研队列，但先做 POC/TCO |
| [OpenTelemetry Go](https://github.com/open-telemetry/opentelemetry-go) | Trace/Metric 接口 | ADOPTION_CANDIDATE | Apache-2.0 候选 | 只采集脱敏数据 |
| [Prometheus client_golang](https://github.com/prometheus/client_golang) | Metrics exporter | ADOPTION_CANDIDATE | Apache-2.0 候选 | label cardinality 需限制 |
| [Google UUID](https://github.com/google/uuid) | 应用 UUID | ADOPTION_CANDIDATE | BSD 候选 | 可由更小实现替代 |
| [Hyperledger FireFly Transaction Manager](https://github.com/hyperledger-firefly/transaction-manager) | nonce、重试、receipt 状态模型参考 | REFERENCE_PROJECT | 不集成 | 只提炼中立状态/需求，不复制结构或代码 |

“许可证初筛”不是批准。必须读取拟采用精确 release/commit 内的 LICENSE、NOTICE、依赖树和生成代码许可，再作决定。

## 4. 为什么这样选

### 4.1 HTTP

API 已由 OpenAPI 冻结，HTTP 层只需路由、中间件与标准 `net/http` 互操作。候选 Router 不得把领域逻辑、Session、RBAC、错误结构绑定到框架私有 Context。

### 4.2 PostgreSQL

资金、事件、Cursor、Governance 需要明确 SQL、事务、行锁、条件唯一索引和 fencing token。pgx + sqlc 候选比 ORM 更容易审核真实 SQL、数值类型和锁语义。Migration 工具只执行仓库内已签署 SQL，不在启动时自动改表。

### 4.3 EVM

Go 服务只读取已部署合约并对批准动作编码。成熟 ABI/RPC 工具优于手写 Keccak/RLP/ECDSA，但 go-ethereum 的许可证与静态链接义务必须先解决。若法律/开源负责人不批准，则重新评估宽松许可证客户端或把签名/编码封装成独立进程；不得为了绕过准入自行复制 geth 代码。

### 4.4 Job

Indexer Cursor 不依赖 Queue；链上原始事件也不依赖 Queue。Job 只承载可重试异步工作。River 只作为候选，必须验证：事务入队、唯一 Job、取消/重试、fencing、多实例、Migration 所有权、MPL 文件级义务、停用和数据导出。

### 4.5 FireFly Transaction Manager

只参考它对 nonce、交易替换、receipt、确认和失败的中立问题分解。BingGoPlus 使用自己的显式 Governance action、审批和数据库状态机，不复制其代码、包结构、类型名或部署模型。

## 5. 依赖准入卡

每个候选必须单独提交 Decision Record：

```text
Dependency ID
Name / Upstream URL
Use Case
Lifecycle Status: REFERENCE_PROJECT | ADOPTION_CANDIDATE | APPROVED_DEPENDENCY
Upper-Rule Classification: DIRECT_ADOPT | WRAP_AND_USE | OPTIMIZED_FORK | CLEAN_ROOM_REIMPLEMENT | REFERENCE_ONLY | REJECT
Exact Release / Tag / Commit
Release Date / Maintenance Activity
Direct and Transitive Licenses
NOTICE / Attribution Obligations
Security Policy / Advisories / CVEs
Packages Actually Imported
Generated Code License
Alternatives Considered
POC Scope and Result
Benchmark Result
Maintenance Cost Estimate
Operational Complexity
Security / Compliance Delta
Exit / Replacement Cost
DIRECT_ADOPT_TCO
WRAP_AND_USE_TCO
OPTIMIZED_FORK_TCO
CLEAN_ROOM_REIMPLEMENT_TCO
Operational Failure Modes
Upgrade and Rollback Plan
SBOM Entry
Decision Owner
Security Review
Legal/Open-Source Review
Decision: APPROVED | REJECTED
APPROVE_DOWNLOAD Reference
```

四项通用 TCO（维护成本估算、运行复杂度、安全/合规差异、退出/替换成本）与四种采用方式的 TCO 必须分别填写；不适用项填写 `N/A` 并说明原因。`Lifecycle Status` 描述项目内准入进度，`Upper-Rule Classification` 描述最终采用方式，二者不得互相替代。任何候选在 `APPROVE_DOWNLOAD` 前仍为 `REFERENCE_PROJECT` 或 `ADOPTION_CANDIDATE`，不得下载、加入 `go.mod` 或进入工具镜像。

任何字段为空都不能进入 `go.mod` 或工具镜像。

## 6. POC 与基准任务

### D-01 HTTP/OpenAPI

- 用最小 Config/Quote/Command Endpoint 验证生成 DTO、strict request、错误映射和 middleware；
- 比较标准 Router 与 chi 候选的可读性、分配、依赖数和维护成本；
- 验证生成 Client 不允许未声明字段和 amount float。

### D-02 PostgreSQL

- 验证 `numeric(78,0)` <-> `big.Int`、address/hash domain、partial unique index；
- 验证 `SELECT ... FOR UPDATE`、fencing token、Cursor 原子推进和 Reorg 标记；
- 比较手写 scan 与 sqlc 生成结果；禁止 ORM 隐式事务。

### D-03 ABI/RPC

- 从部署 Commit ABI 生成 binding，并验证 function/event signature 与 manifest；
- 在固定测试网 block/hash 只读调用 `previewBuyFor/previewSell` 和关键 getter；
- 验证 RPC 超时、batch、backup 分歧、revert reason、receipt/log decode；
- 完成 go-ethereum 精确包级许可证分析后才能决定采用。

### D-04 Job/Reconciler

- 验证事务创建 Command+Job、唯一键、重试、worker crash、lease/fencing、dead letter；
- 验证相同 signer nonce 不双发、replacement 保留 Command、receipt 最终一致；
- 比较 River 与最小 PostgreSQL Job 实现的 12 个月 TCO 和退出成本。

### D-05 Telemetry

- 验证 Secret/RPC URL/cookie/signature/raw tx 不进入 log/trace；
- 验证高基数地址/tx hash 不作为 metric label；
- Telemetry 故障不得阻断资金/治理正确性。

POC 代码必须在隔离目录，未批准候选不得合并到生产 Module。POC 不是自动采用批准。

## 7. 版本与生成物

冻结后必须提交：

- `go.mod` 和 `go.sum`，所有 module 精确版本；
- 工具版本清单，工具二进制/容器 digest；
- OpenAPI、SQL、ABI 输入 Hash；
- 生成命令和生成文件 Header；
- SBOM、许可证清单、NOTICE；
- 依赖漏洞扫描结果及人工解释；
- Renovation/升级只创建审查请求，不自动合并或自动部署。

禁止：

- `go get ...@latest`；
- pseudo-version 指向未批准 commit；
- replace 到本地路径或浮动 branch；
- 未审 submodule、来源不明压缩包、聊天内容复制代码；
- 依赖失败后静默换库/降级；
- 审计后自动升级依赖。

## 8. 研究成果隔离

对参考项目的研究只允许输出中立规格：状态、约束、失败模式、性能指标和取舍。禁止复制独特代码、目录、接口名、注释、数据库表或文案；任何片段引用必须记录来源、许可证、行范围和采用理由。

## 9. 开发启动 Gate

- 人工批准 Go 精确版本；
- 每个正式依赖拥有完整 Decision Record 与 `APPROVE_DOWNLOAD`；
- go-ethereum/River 的条件许可证审查明确通过、拒绝或隔离使用；
- POC/benchmark/12-month TCO 完成；
- SBOM/NOTICE/回滚方案就绪；
- 安全负责人批准 ABI/Signer/Crypto 不自行重写；
- 全部版本写入 `v2-dependencies-1` 后才能开始 G1。
