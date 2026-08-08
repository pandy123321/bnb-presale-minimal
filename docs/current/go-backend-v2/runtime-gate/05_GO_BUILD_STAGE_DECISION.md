# RT-GATE-03：Go Build 阶段定义 Decision

## 状态

```text
RT-GATE-03_GO_BUILD_STAGE = APPROVED
OWNER_DECISION_REF = OWNER_DECISION_V2.md (RT03-OWNER-2026-001)
```

## Decision 结论

```text
RT-GATE-03 = APPROVED

G0 = Pre-development Freeze（RT-GATE-01 PASS + RT-GATE-02 Owner Signoff）
G1 = Go Skeleton / Bootstrap（G0 完成 → 骨架已创建）

CURRENT: backend-go/ exists, G1 bootstrapped with go build/go vet PASS.
         See OWNER_DECISION_V2.md for Go 1.26.5 + dependency authorization.
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

### Go 版本 Decision

根据 `07_FRAMEWORK_AND_DEPENDENCIES.md` 和 `OWNER_DECISION_V2.md (RT03-OWNER-2026-001)`：

```text
Go 精确版本 = 1.26.5 (2026-07-07 发布，最新稳定版含安全修复)
Owner Decision: "按照你的建议选" → APPROVED
```

## 依赖准入

所有依赖（chi, pgx, sqlc, goose, oapi-codegen, go-ethereum, river, opentelemetry, prometheus, uuid）已通过 `OWNER_DECISION_V2.md (RT03-OWNER-2026-001)` 获得 `APPROVE_DOWNLOAD`。

G1 当前仅实际 import chi + pgx（Skeleton 所需）。其余依赖批准用于 G2+，不在 G1 阶段导入。

特别注意：

- `go-ethereum`：LGPL/GPL 组件风险，G1 仅限 ABI JSON 读取；完整 EVM 集成需 G2 前法律复核
- `river`：MPL-2.0 候选，G1 不导入；G2 前需文件边界复核

G1 的 `go.mod` 已通过 `go mod tidy` 精简至仅包含实际所需的直接依赖和间接依赖。

## Decision 结论

```text
RT-GATE-03 = APPROVED
OWNER_DECISION_REF = OWNER_DECISION_V2.md (RT03-OWNER-2026-001)

G0 = Pre-development Freeze（RT-GATE-01 PASS + RT-GATE-02 Owner Signoff）
G1 = Go Skeleton / Bootstrap（G0 完成 → 骨架已创建，go build/go vet PASS）

CURRENT: backend-go/ exists, G1 BOOTSTRAPPED, FIX_READY for Independent Review
```

本 Decision 不授权任何 Go 业务代码实现，不授权 G2 stage entry 直到 G1 通过 Independent Review。
