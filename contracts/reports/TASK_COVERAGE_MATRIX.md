# PANGU2 PB-S1 Repair Task Coverage

| Task | Production implementation | Verification source |
|---|---|---|
| P2-C01 | `Pangu2Token.sol`固定供应、税费结算、Pair/System边界、不可伪造Transfer Context | `Pangu2Integration.t.sol`、`CostBasisTransferContext.t.sol`、Security |
| P2-C02 | `Pangu2TradeRouter.sol`、Pancake V3 Adapter、30分钟TWAP Fail Closed | Integration、Security、BSC Testnet Fork |
| P2-C03 | `CostBasisManager.sol`用户/流动性双仓位，余额差异UNKNOWN，专用Liquidity Gateway | CostBasis Transfer Context、Stateful Invariant、Fork |
| P2-C04 | `FeeVault.sol`Bucket隔离、TWAP最小输出、Keeper转换 | Integration、Invariant、Fork |
| P2-C05 | `SupportPool.sol`固定0.01 BNB、60秒间隔、直接到Locker | Integration、Security、Invariant、Fork |
| P2-C06 | `BuybackLocker.sol`固定7天模式、显式UNKNOWN释放上下文 | Locker Unit、Integration、Fork |
| P2-C07 | `DividendDistributor.sol`完整Commitment/checksum/domain、精确30天、Pause/Unpause | Dividend Commitment、Security、Invariant、Fork |
| P2-C08 | `GovernanceAdapter.sol`、1小时Timelock部署与角色交接 | Governance Deployment、Security、部署脚本 |
| P2-C09 | Unit、Fuzz、真实入口Integration、Stateful Invariant、Attack、固定区块真实Pancake V3 Fork | `test/**` |
