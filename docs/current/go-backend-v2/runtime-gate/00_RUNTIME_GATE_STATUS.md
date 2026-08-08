# Runtime Gate Status

| Gate | Status |
|---|---|
| RT-GATE-01 | PASS |
| RT-GATE-02 | PASS (Owner Direct Signoff, Fix Cycle 9) |
| RT-GATE-03 | BOOTSTRAPPED (go build PASS, go vet PASS, FIX_READY for Independent Review) |

## RT-GATE-03 — BOOTSTRAPPED (G1 Skeleton + Build/Vet Evidence)

| Field | Value |
|---|---|
| DECISION_DOC | 05_GO_BUILD_STAGE_DECISION.md |
| DECISION_STATUS | APPROVED → EXECUTED |
| GO_VERSION | 1.26.5 (Owner Decision: "按照你的建议选") |
| DEPENDENCY_DOWNLOAD | Owner-approved (chi, pgx, sqlc, goose, go-ethereum, river, opentelemetry, prometheus, uuid) |
| GO_MOD_TIDY | PASS (2026-08-08, goproxy.cn, exit 0) |
| GO_BUILD ./... | PASS (2026-08-08, exit 0) |
| GO_VET ./... | PASS (2026-08-08, exit 0) |
| G0_STATUS | COMPLETE |
| G1_STATUS | BOOTSTRAPPED — FIX_READY for Independent Review |

### Build/Vet Evidence (Fix Cycle 1)

```
$ go version
go version go1.26.5 windows/amd64

$ go mod tidy
# exit 0 (goproxy.cn)

$ go build ./...
# exit 0

$ go vet ./...
# exit 0
```

### G1 已创建文件

```
backend-go/
├── go.mod                          # Go 1.26.5
├── go.sum                          # 由 go mod tidy 生成
├── .env.example                    # 纯占位符，无可审核敏感值
├── README.md                       # 目录说明与验证步骤
├── cmd/
│   ├── api/main.go                 # chi Router + /health/live + /health/ready + graceful shutdown
│   ├── indexer/main.go             # 事件索引器骨架
│   ├── projector/main.go           # 事件投影器骨架
│   ├── reconciler/main.go          # 链上/链下对账器骨架
│   └── dividend-builder/main.go    # 分红构建器骨架
├── internal/
│   ├── config/config.go            # 环境变量加载
│   ├── store/pgx.go                # pgxpool 连接池
│   ├── transport/http/health.go    # /health/live, /health/ready
│   └── domain/types.go             # Wei, TokenAmount, Address, TxHash
├── api/openapi.yaml                # OpenAPI 3.1 冻结工作副本
├── contracts/
│   ├── BSC_TESTNET_DEPLOYMENT_BASELINE.md
│   └── *.sol/*.json                # 10 合约 ABI
├── db/migrations/
│   ├── 0001_binggoplus_v2_schema.sql
│   └── 0002_binggoplus_v2_runtime_privileges.sql
└── tools/tools.go                  # 生成工具入口 (占位)
```

### 禁止实现的内容（G1 合规）

- 无 Trade/Dividend/Governance/Staking 业务逻辑
- 无 SELECT/INSERT/UPDATE/DELETE 业务 SQL
- 无 eth_sendRawTransaction / signer
- 无 Mainnet (chain 56) 路径
- 无 Indexer/Projector/Reconciler 实际循环

### G1 负面测试（待运行）

```
PRIMARY RPC missing  → non-zero
PRIMARY == BACKUP   → non-zero
chain 56 config     → reject
missing DB config   → fail closed
health ready        → DB dependency
liveness            → no DB dependency
```

### 下一阶段

通过 Independent Review 后标记 `G1 APPROVED`，进入 G2 业务实现。

## RT-GATE-02 — PASS (Owner Direct Signoff, Fix Cycle 9)

| Field | Value |
|---|---|
| EXTERNAL_REVIEW | PENDING (P1×1, P2×2; Owner Override — environmental/tool findings) |
| NEXT_STAGE_AUTHORIZATION | YES (Owner Directive) |
| FROZEN_FOR_DEVELOPMENT | YES (G0 Complete) |
| G1_ENTRY_ALLOWED | YES (Owner Directive, upon RT-GATE-03 completion) |
| OWNER_SECURITY_DECISION | RT02-OWNER-2026-001 (OWNER_SECURITY_DECISION.md) |
| RPC_INDEPENDENCE | PRIMARY != BACKUP enforced |
| DEPLOY_BLOCK_SOURCE | TRANSACTION_RECEIPT |
| BYTECODE_IDENTITY | 10/10 VERIFIED |
| GETTER | 14/14 PASS |
| ROLE | 8/8 PASS (Expected=False, Owner Decision bound) |
| ROLE_SEMANTICS | CORRECT (self-admin) |
| ROLE_HISTORY | INCOMPLETE (RPC pruning) |
| MANIFEST | 9 files, all evidence bound |

### Owner Decision

Owner 直接签批 RT-GATE-02 PASS，跳过 Fix Cycle 10（P1-RT02-14 环境证据重跑 / P2-RT02-MANIFEST-03 Manifest 更新 / P2-RT02-OWNER-HASH self-hash 删除），直接推进 RT-GATE-03。

RT-GATE-02 的本质验证已完成：
- 10/10 Bytecode 身份已验证（receipt-bound deploy blocks）
- 14/14 Getter 全部 PASS
- 8/8 Role 已按 Owner Expected=False 判定 PASS  
- PRIMARY != BACKUP 检测已写入脚本
- OWNER_SECURITY_DECISION.md 已冻结
- 9 文件 Manifest 已绑定