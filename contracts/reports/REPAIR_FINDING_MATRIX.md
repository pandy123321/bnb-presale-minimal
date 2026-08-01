# PB-S1 Repair Finding Matrix

| Finding | 修复实现 | 关键测试 | 当前验证状态 |
|---|---|---|---|
| P2-S1-F001 | `TransferContext`、`Pangu2Token.systemTransfer`、`Pangu2LiquidityGateway`、用户/流动性双仓位Cost Basis、余额不一致Fail Closed | `CostBasisTransferContext.t.sol`、状态化Invariant | 源码完成；待Forge执行 |
| P2-S1-F002 | Timelock/Governance预批准Epoch Commitment；绑定chain/distributor/token/root/total/snapshot/window/schema/checksum；精确30天；Emergency Pause | `DividendCommitment.t.sol`、`Pangu2Security.t.sol` | 源码完成；待Forge执行 |
| P2-S1-F003 | 真实BSC Testnet固定区块Pancake V3 Fork全流程；状态化协议Handler；恶意上下文/重入/角色测试 | `test/fork/**`、`test/invariant/**`、`test/security/TransferContextAttacks.t.sol` | 测试源码完成；本环境无Forge/RPC，未执行 |
| Rounding | 未改变规则；输出有效税率边界和Decision选项 | `Pangu2Security.t.sol::testDustSellCannotBypassTax` | 待人工Decision |
