# RT-GATE-03：Go Build 阶段定义 Decision

## 状态

```text
RT-GATE-03_GO_BUILD_STAGE = DECISION_READY
```

## 执行环境

| 项 | 值 |
|---|---|
| `backend-go/` | 不存在 |
| `go.mod` | 不存在 |
| Go 工具链 | 未安装 |
| Go 精确版本 | `UNRESOLVED_VERSION_PIN`（冻结文档声明） |
| 开源依赖批准 | `NO_DOWNLOAD_AUTHORIZED`（所有依赖均为 ADOPTION_CANDIDATE / CONDITIONAL_ADOPTION_CANDIDATE） |

## 执行 Agent 决策

按 Gate 指令，不得为了通过 `go build ./...` 而擅自实现 Handler、Repository、Indexer、Projector 或业务代码。

### 推荐方案：G0 → G1 两阶段

```text
G0 = Pre-development Freeze（当前阶段）
G1 = Go Skeleton / Bootstrap（Freeze 完成后）
```

### G0：Pre-development Freeze

G0 包含：

- 设计冻结已由 Round10 独立复验批准（`APPROVED_FOR_RESPONSIBLE_OWNER_FREEZE`）
- Responsible Owner Freeze 已由 `pd123` 签署（`RESPONSIBLE_OWNER_FREEZE_SIGNOFF = COMPLETE`）
- PostgreSQL Migration + Role Runtime 验证（RT-GATE-01）— 待执行
- BSC Testnet Readback（RT-GATE-02）— 待执行
- 依赖下载批准 — 待人工 Decision Record

G0 完成后：

```text
FROZEN_FOR_DEVELOPMENT = YES
```

### G1：Go Skeleton / Bootstrap

G1 仅允许创建：

| 文件/目录 | 内容约束 |
|---|---|
| `backend-go/go.mod` | Go 精确版本 + 冻结依赖（需先获 `APPROVE_DOWNLOAD`） |
| `backend-go/cmd/api/main.go` | 最小骨架：config load + health endpoint + graceful shutdown |
| `backend-go/cmd/indexer/main.go` | 最小骨架 |
| `backend-go/cmd/projector/main.go` | 最小骨架 |
| `backend-go/cmd/reconciler/main.go` | 最小骨架 |
| `backend-go/cmd/dividend-builder/main.go` | 最小骨架 |
| `backend-go/internal/config/` | 配置加载骨架 |
| `backend-go/internal/store/pgx.go` | 数据库连接池骨架 |
| `backend-go/internal/transport/http/health.go` | health/live + health/ready |
| `backend-go/api/openapi.yaml` | 冻结 OpenAPI 工作副本 |
| `backend-go/contracts/` | ABI + deployment 基线 |
| `backend-go/db/migrations/` | SQL Migration 工作副本 |
| `backend-go/internal/domain/` | 仅类型定义（value objects），无业务逻辑 |
| `backend-go/tools/` | 生成工具入口 |

**G1 严禁实现：**

- Trade 买卖逻辑
- Dividend 分红构建/发布业务逻辑
- Governance execution
- Indexer 实际扫描循环
- Projector 实际投影逻辑
- Signer 签名
- 实际链上写入（eth_sendRawTransaction）
- 任何 `SELECT/INSERT/UPDATE/DELETE` 的业务 SQL 查询

G1 完成后执行：

```bash
go build ./...
go vet ./...
```

以及冻结允许的静态工具（`staticcheck`, `golangci-lint` 需先获准入）。

通过后：

```text
GO_BUILD_GATE = PASS
```

再进入 G2 业务实现。

### 如果治理坚持"Build 必须在 Freeze 之前"

当前现状：

- `backend-go/` 不存在
- Go 工具链未安装
- 没有任何 Go 代码

因此：

```text
RT-GATE-03 = BLOCKED_CIRCULAR_GATE
```

**说明：**

```text
No Go project exists before development freeze,
therefore Go Build cannot logically be a prerequisite
for development freeze.
```

按 Gate 指令，此情况应交 Responsibility Owner（`pd123`）重新签署 Gate 顺序。

但当前 Responsible Owner Freeze 已签署为 `G0 → G1` 路径，不存在强制"Build 在 Freeze 之前"的冲突。因此本 Decision 采用推荐方案。

## Go 版本 Decision

根据 `07_FRAMEWORK_AND_DEPENDENCIES.md`：

```text
Go 精确 minor/patch 为 UNRESOLVED_VERSION_PIN
```

必须从 Go 官方稳定发布中选定版本。截至 2026-08，Go 最新稳定版本序列为 Go 1.23.x / 1.24.x（具体需核实 Go 官方 release page）。该 Decision 需要人工完成。

## 依赖准入

所有依赖（chi, pgx, sqlc, goose, oapi-codegen, go-ethereum, river, opentelemetry, prometheus, uuid）均为 `ADOPTION_CANDIDATE` 或 `CONDITIONAL_ADOPTION_CANDIDATE`，等待 `APPROVE_DOWNLOAD`。

特别是：

- `go-ethereum`：LGPL/GPL 组件风险，必须逐包法律复核后才能集成
- `river`：MPL-2.0 候选，需文件边界复核

G1 的 `go mod init` 在下发 `APPROVE_DOWNLOAD` 之前不得添加任何 `require` 行。

## Decision 结论

```text
RT-GATE-03 = DECISION_READY

G0 = Pre-development Freeze（包含 RT-GATE-01 + RT-GATE-02 + 依赖下载批准）
G1 = Go Skeleton / Bootstrap（G0 完成后允许创建骨架，禁止业务实现）

CURRENT: backend-go/ does not exist → G0 not yet complete → G1 not yet authorized
```

本 Decision 不授权任何 Go 业务代码实现，不授权下载未经批准的依赖，不授权创建 `go.mod` 的 `require` 行。
