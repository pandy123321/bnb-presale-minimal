# BingGoPlus Go Backend V2 — G1 Skeleton Bootstrap

状态：`BOOTSTRAPPED / AWAITING_GO_TOOLCHAIN`

## 目录结构

```
backend-go/
├── go.mod                          # Go 1.26.5, 依赖已声明 (需 go mod tidy)
├── .env.example                    # 环境变量模板
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

## G1 验证步骤

在安装 Go 1.26.5 后执行：

```bash
cd backend-go
go mod tidy      # 解析依赖、更新 go.sum
go build ./...   # 全部编译通过
go vet ./...     # 静态检查通过
```

## G1 禁止事项

- 不实现任何业务逻辑（交易、分红、治理、质押等）
- 不执行 `SELECT/INSERT/UPDATE/DELETE` 的业务 SQL
- 不发 `eth_sendRawTransaction` 或签名交易
- 不修改已部署合约字节码或 ABI
- 不连接 BSC Mainnet

## G1 完成后

G1 通过 `go build ./...` 和 `go vet ./...` 后，标记 `GO_BUILD_GATE = PASS`，再进入 G2 业务实现。
