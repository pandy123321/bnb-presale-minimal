# PANGU2 PB-S1 Contract Suite V1.0 — Repair V1.0

**Scope:** LOCAL / CI / BSC Testnet only. **BSC Mainnet remains NO-GO.**

This package implements the approved DR-P2-0002 through DR-P2-0012 contract scope. It does not authorize a
mainnet deployment, real production funds, production credentials, automatic merge, or automatic deployment.

## Locked toolchain

- Solidity: `0.8.24`
- Foundry: `v1.7.1`
- OpenZeppelin Contracts: `v5.0.2`
- forge-std: `v1.16.2`
- EVM target: `paris`
- Solidity pipeline: optimizer enabled, `via_ir = true`
- PancakeSwap V3 candidate fee tier: `2500` (0.25%)

## Task mapping

| Task | Delivered implementation |
|---|---|
| P2-C01 | `Pangu2Token.sol`: fixed 1B supply, no mint, one-time tax settlement, direct Pair bypass rejection |
| P2-C02 | `Pangu2TradeRouter.sol`, V3 adapter and 30-minute fail-closed TWAP oracle |
| P2-C03 | `CostBasisManager.sol` + `Pangu2LiquidityGateway.sol`: WBNB-wei cost, user/liquidity dual positions, explicit transfer contexts and fail-closed UNKNOWN |
| P2-C04 | `FeeVault.sol`: isolated Dividend/Support buckets and support-only conversion |
| P2-C05 | `SupportPool.sol`: public fixed 0.01 BNB buyback with a 60-second minimum interval |
| P2-C06 | `BuybackLocker.sol`: immutable permanent/fixed modes; testnet script uses seven days |
| P2-C07 | `DividendDistributor.sol`: Timelock-approved immutable commitment, artifact checksum, exact 30-day claims, pause control; Merkle Leaf V1 and 35/30/20/15 reference library |
| P2-C08 | `GovernanceAdapter.sol`, 1-hour Timelock deployment, role handoff and JSON manifest output |
| P2-C09 | Unit, security, stateful invariant and mandatory fixed-block BSC Testnet Pancake V3 fork tests under `test/` |

## Install and validate

```bash
forge install OpenZeppelin/openzeppelin-contracts@v5.0.2 --no-commit
forge install foundry-rs/forge-std@v1.16.2 --no-commit
forge fmt --check
forge clean && forge build --sizes
BSC_TESTNET_RPC_URL=<testnet-rpc> BSC_TESTNET_FORK_BLOCK=<fixed-block> forge test -vvv
BSC_TESTNET_RPC_URL=<testnet-rpc> BSC_TESTNET_FORK_BLOCK=<fixed-block> forge test --fuzz-runs 50000
forge test --match-path 'test/invariant/**' -vvv
forge snapshot
```

## Deployment safety

Before any BSC Testnet write operation, independently verify chain ID 97, all configured code hashes, factory
`getPool`, pool token ordering, fee tier, observation cardinality, minimum harmonic liquidity and every granted
role. The script rejects chains other than Anvil/CI `31337` and BSC Testnet `97`.

Use `deploy.env.example` only as a field list. Never place private keys, mnemonics or production RPC credentials in
this package.

## Validation status in this delivery environment

The source tree was statically checked for imports, balanced delimiters, required constants, forbidden paths and
secret-like content. The current artifact runtime did not contain `forge` or `solc`, so compilation, EVM execution,
fuzzing, invariant runs, gas snapshots and ABI generation must be run in the pinned Foundry environment before a
PR can enter formal review. Generated tests are test source, not a claim that the checks passed.


## PB-S1 Repair V1.0

- F001：用户、系统、Pair和流动性路径使用不可伪造的Transfer Context；用户真实余额与tracked不一致时Fail Closed为UNKNOWN。
- F002：Governance/Timelock先提交完整Epoch Commitment，Root Publisher只能精确匹配发布；checksum写入状态和事件；测试网领取期精确30天；Emergency只能暂停。
- F003：新增固定区块BSC Testnet Pancake V3真实Fork全流程、状态化协议Invariant和上下文伪造/重入/角色攻击测试。
- Fork测试不允许静默跳过；缺少`BSC_TESTNET_RPC_URL`或`BSC_TESTNET_FORK_BLOCK`时验证应失败。
- 税费尘埃舍入未擅自改变，详见`reports/ROUNDING_DECISION_REQUIRED.md`。

## PB-S1 Repair Optimization V1.1

- Test source imports use the project remapping `pangu2/=src/`; depth-sensitive `./src` and `././src` forms are forbidden.
- `SupportPool.canExecuteBuyback()` exposes permissionless buyback readiness without mutating pause or cooldown state.
- Formal deployment has no default locker mode, duration, or recipient. `LOCK_MODE`, `LOCK_DURATION`, `LOCK_RELEASE_RECIPIENT`, and a `DR-` prefixed `LOCK_DECISION_ID` are mandatory.
- A seven-day locker duration appears only as `TEST_FIXTURE_LOCK_DURATION` in tests and is not a frozen deployment parameter.
- Dividend tier constants remain the currently approved 35/30/20/15 baseline; `DividendTiers.totalBps()` enforces a 10,000 BPS total. No 105% candidate split is encoded.
