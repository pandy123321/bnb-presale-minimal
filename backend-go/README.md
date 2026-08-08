# BingGoPlus Go Backend V2 — G1 Skeleton Bootstrap

状态：`BOOTSTRAPPED / GO_BUILD_PASS / GO_VET_PASS / FIX_READY`

## 构建证据 (Fix Cycle 1, 2026-08-08)

```
go version go1.26.5 windows/amd64

go mod tidy   → exit 0 (goproxy.cn)
go build ./... → exit 0
go vet ./...   → exit 0
```

## 目录结构

```
backend-go/
├── go.mod                          # Go 1.26.5
├── go.sum                          # 由 go mod tidy 生成
├── .env.example                    # 纯占位符
├── cmd/
│   ├── api/main.go                 # Public API 服务 (chi + health + graceful shutdown)
│   ├── indexer/main.go             # 链上事件索引器骨架
│   ├── projector/main.go           # 事件投影器骨架
│   ├── reconciler/main.go          # 链上/链下对账器骨架
│   └── dividend-builder/main.go    # 分红构建器骨架
├── internal/
│   ├── config/config.go            # 环境变量配置加载
│   ├── store/pgx.go                # PostgreSQL 连接池
│   ├── transport/http/health.go    # /health/live + /health/ready
│   └── domain/types.go             # 值对象定义 (Wei, TokenAmount, Address, TxHash)
├── api/
│   └── openapi.yaml                # OpenAPI 3.1 冻结工作副本
├── contracts/
│   ├── BSC_TESTNET_DEPLOYMENT_BASELINE.md
│   ├── Pangu2Token.sol/Pangu2Token.json
│   ├── Pangu2TradeRouter.sol/Pangu2TradeRouter.json
│   ├── CostBasisManager.sol/CostBasisManager.json
│   ├── FeeVault.sol/FeeVault.json
│   ├── SupportPool.sol/SupportPool.json
│   ├── BuybackLocker.sol/BuybackLocker.json
│   ├── DividendDistributor.sol/DividendDistributor.json
│   ├── Pangu2Staking.sol/Pangu2Staking.json
│   ├── PancakeV2TwapOracle.sol/PancakeV2TwapOracle.json
│   └── PancakeV2Adapter.sol/PancakeV2Adapter.json
├── db/migrations/
│   ├── 0001_binggoplus_v2_schema.sql
│   └── 0002_binggoplus_v2_runtime_privileges.sql
└── tools/tools.go                  # 生成工具入口 (占位)
```

## G1 禁止事项

- 不实现任何业务逻辑（交易、分红、治理、质押等）
- 不执行 `SELECT/INSERT/UPDATE/DELETE` 的业务 SQL
- 不发 `eth_sendRawTransaction` 或签名交易
- 不修改已部署合约字节码或 ABI
- 不连接 BSC Mainnet

## G1 验证通过

```
GO_BUILD = PASS (exit 0)
GO_VET   = PASS (exit 0)
```

## G1 负面测试（待环境就绪后运行）

```
PRIMARY RPC missing  → non-zero
PRIMARY == BACKUP   → non-zero
chain 56 config     → reject
missing DB config   → fail closed
health ready        → DB dependency
liveness            → no DB dependency
graceful shutdown   → works
no chain write path → confirmed
```

## 下一阶段

通过 Independent Review 后标记 `G1 APPROVED`，进入 G2 业务实现。
