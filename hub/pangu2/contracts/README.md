# Pangu2 Contracts（未审核草稿）

```text
Status: UNAUDITED / UNREVIEWED DRAFT
Project: PANGU2
Path: hub/pangu2/contracts/src/
Network: NOT AUTHORIZED FOR MAINNET
Automatic Deploy: FORBIDDEN
```

本目录存放盘古2合约**开发中、未审核**源码。当前仅作版本托管与后续审核输入，不构成：

- 第三方审计结论；
- PB-S1 Closeout / ABI FROZEN；
- 测试网或主网部署授权；
- 生产可用性声明。

## 源文件

| Contract | File |
|---|---|
| Pangu2Token | `src/Pangu2Token.sol` |
| Pangu2TradeRouter | `src/Pangu2TradeRouter.sol` |
| CostBasisManager | `src/CostBasisManager.sol` |
| FeeVault | `src/FeeVault.sol` |
| SupportPool | `src/SupportPool.sol` |
| BuybackLocker | `src/BuybackLocker.sol` |
| DividendDistributor | `src/DividendDistributor.sol` |
| GovernanceAdapter | `src/GovernanceAdapter.sol` |

Compiler target per sources: Solidity `0.8.24` + OpenZeppelin imports（Foundry 工程/锁文件尚未齐备时，本目录可能无法独立编译）。

## 使用约束

1. 不得将本目录合约直接用于 BSC_MAINNET。
2. 未通过审核 Agent 固定 SHA 审核与人工批准前，不得标为 FROZEN ABI。
3. 不得从 `hub/pixiu1/**` 运行时依赖归档合约。
4. 后续应补齐 `foundry.toml`、 remappings、测试与 CI；本次提交仅为源码入库。
