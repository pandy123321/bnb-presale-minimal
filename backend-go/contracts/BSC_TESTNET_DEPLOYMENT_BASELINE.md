# BSC Testnet 实测合约继承基线

状态：`STATIC_EVIDENCE_CAPTURED / LIVE_READBACK_PENDING`

Deployment Set：`binggoplus-bsc-testnet-97-3ef50b6-20260806`

产品品牌已冻结为 **BingGoPlus**。`Pangu2Token`、`Pangu2TradeRouter`、合约地址、事件名以及链上 Token name/symbol 属于已部署且不可改写的链上身份；品牌更名不触发重部署，也不得在 API 中伪造不同的链上 Token 元数据。

该台账来自本地 Foundry 广播文件和 Git 历史的静态读取，没有访问 RPC、没有重放交易、没有部署。Go V2 只能导入这套新地址，不能导入旧 `0xaf2b...` 地址组。

## 1. 证据来源

- Source commit：`3ef50b6d77a31c092e9353e255e672836f36ece8`；
- Deploy：`contracts-v2/broadcast/DeployPangu2.s.sol/97/run-latest.json`；
- Bootstrap：`contracts-v2/broadcast/BootstrapPangu2.s.sol/97/run-latest.json`；
- Finalize：`contracts-v2/broadcast/FinalizePangu2.s.sol/97/run-latest.json`；
- Open Trading：`contracts-v2/broadcast/OpenTradingPangu2.s.sol/97/run-latest.json`；
- DApp address mirror：`apps/dapp/src/features/wallet/deployed.ts:4-14`；
- Network：BSC Testnet，`chain_id=97`。

部署广播含 73 个 receipt，静态记录的 status 均为 `0x1`。这证明广播文件记录成功，不等于已经完成当前链上 bytecode/role readback。

## 2. 长期合约实例

| 合约 | 地址 | 部署/创建区块 | 交易哈希 | 区块哈希 |
|---|---|---|---:|---:|---|
| Pangu2Token | `0x49a4a6ecaacc5d9ae60df7717f62e0605f591bc3` | 123502176 | `0x8f6ddf160a6d010d78748095a0bfa0a576e8ca7cd93dbdcc671806b43805398f` | `0x4525982663b89b10751223f2eb461c2daf58dba5905dc2b80f7ebadfa1aae6a4` |
| CostBasisManager | `0x695660310afb747589d415d24f20a3eef05693d0` | 123502181 | `0x00dff4728b02e46d4aab34de4864ca8f260d9c3691070f8b589e039b107c489e` | `0x65d5aef0c487e83b47a61ae42f67931f2754f7130984de37421ce010103011f2` |
| Pancake V2 Pair | `0x07d481b52c27941f6daaeb53aaa879c588408f32` | 123502187 | `0x0126544f883371b8cccb5df4e8c1b5368765a27b9162186febf55a08fda8770b` | `0x06a66c470fe8cc5196a398723be1aeae11b12a341a312f970e246e1d42be125d` |
| PancakeV2Adapter | `0xc3bb2129cb362b82cc15ec63a8355e80d4198e3a` | 123502195 | `0xcc6de4cd4a191d9e16c64a73999ef7bdff3eac2748b25c511749b3214b7ebe16` | `0x971f3175daaaf9e9864adb7b4691d980148de747e854923eb6f775205e80de81` |
| PancakeV2TwapOracle | `0x11c39db60a95b232c6c303c1869aa81886694d9c` | 123502202 | `0xbd85ea70b006874a7a995ed047d1c8c83401335f61ede206de890da43e724382` | `0x6442518ec15d6cf17a36e93cc2843a458f87976a2cbf1ba294deeeda9825144b` |
| SupportPool | `0xe6d37841b13d78e9ae759b77ecfaebeddb90589b` | 123502210 | `0x5e5c58303fa25fd937fc5d099478886c0d85a677d9d8603308b57f1feaf12b63` | `0xa2cab5fe4566bb5730d00bee6807a429a950d15e906e6aa43c21255a2d241ce4` |
| FeeVault | `0xf82313eb70d24250d541c26796fe1615beb15d29` | 123502218 | `0x418e592e4f56eabff5773b93f9053ac3a13372319c71ee64dbf13130f9659312` | `0x7314d98104b6e0062e13fd3c3175fc5a8591e217cd1f43310d2e03f4335db648` |
| BuybackLocker | `0x0a2283cd52523889fcb333596c3f0a14741b1cce` | 123502225 | `0x7f299e80f5017b94d1db8c6c0783c1c397afbe03ebafd7235d6e368ce8271d1a` | `0x4cb0a505722cb87fcf245afc1f5e76a8035c189248addfedbf48d8f0b065b774` |
| DividendDistributor | `0x917705d794ec31144f7b2c4d62bfaab4fe327385` | 123502234 | `0xb749c44f0e31ec21df27b386061da518bc321dbaa9d048a33e30dc57865d5591` | `0x02bb3dde095a05f31f299c431ce8ee536e318411922bb5f2667874321b8da9ff` |
| Pangu2TradeRouter | `0xb0b5b52cb99ee7ea055669ba49afd02cf69c71b5` | 123502248 | `0x36d1b0662777c539732e726e47a0a5bc48471431f31ea0916a992a95510966bb` | `0x87ef6a1b935446026a4fa908842e81852a79cab05dd32ec9bf1a0561f8b4d719` |
| Pangu2Staking | `0xf1d27ef1037c38b6752bae449fd3a460b49775a8` | 123502253 | `0xd503e6c381fa6fe8326ab3d6299e6263e038db3d94faf6155a4a79d85f80c1bf` | `0xa5dc8ab64f77697bff1a85a6cc4bf5b5dbba1674eed3d0983b5fdd372a0c7692` |

Pair 地址来自 createPair 参数后 factory 的确定结果、后续 constructor 参数和 DApp 地址镜像；上线前仍须以 factory `getPair(token,wbnb)` 在固定块读回确认。

## 3. 实测关键参数

| 参数 | 实测部署值 | 来源 |
|---|---|---:|
| Pancake Factory | `0x6725f303b657a9451d8ba641348b6761a6cc7a17` | Adapter/Oracle constructor |
| Pancake Router | `0x9ac64cc6e4415144c455bd8e4837fea55603e5c3` | Adapter constructor |
| WBNB | `0xae13d989dac2f0debff460ac112a837c89baa7cd` | Adapter/Oracle/Pool/Vault constructor |
| TWAP window | 1800 seconds | Oracle constructor |
| Maximum spot/TWAP deviation | 300 bps | Oracle constructor |
| Minimum token reserve | `100000000000000000` raw | Oracle constructor |
| Minimum WBNB reserve | `1000000000000000` wei | Oracle constructor |
| SupportPool max slippage | 300 bps | SupportPool constructor |
| SupportPool quote deadline | 300 seconds | SupportPool constructor |
| FeeVault max conversion | `1000000000000000000000000` raw | FeeVault constructor |
| FeeVault max slippage | 300 bps | FeeVault constructor |
| Locker mode | `FIXED_DURATION` (`1`) | Locker constructor |
| Locker duration | 31,536,000 seconds（365 days） | Locker constructor |
| Bootstrap token amount | `100000000000000000000` raw | Bootstrap proxy constructor |
| Bootstrap BNB amount | `10000000000000000` wei（0.01 BNB） | Bootstrap proxy constructor |

上述地址统一以 lowercase 存储；UI 可按 checksum 格式展示。

## 4. 实测执行时间线

| 阶段 | 结果 | 区块 | 交易哈希 |
|---|---|---:|---|
| Deploy contracts/configure roles | 73 receipts，均 `0x1` | 123502176-123502752 | Deploy run-latest |
| Create temporary BootstrapLpProxy | 成功 | 123516946 | `0xd050b4f4127c124496974cbf1eebd6a120651b6a5fd018448fb897438c27b496` |
| Add initial liquidity | 成功 | 123516960 | `0x6e633fbbaafa67cd901d33bdba6904cdae63a16c90cda9237e3b65c8164c9db1` |
| Revoke proxy liquidity manager | 成功 | 123516963 | `0xd747adc6b4392661e0a5b2a14bef01fb02b483ba92c766469cd3561690963c7d` |
| Reset proxy allowance to zero | 成功 | 123516969 | `0x2675f033ed363580a5c40c2e9be8737d2f53556ddfa0b30f1526224f3b88030d` |
| Final Oracle update | 成功 | 123527088 | `0xe2fa5b878bb0f7175ee833e510f440b5f1122cbe81d9355243b11837c21872c4` |
| Open trading | 成功 | 123527207 | `0x4c780e1168abfd4e5bb6b65aa9d90f6fd924ec5667c49311fee688416470fd6a` |

Bootstrap run-latest 中最后一笔 Oracle `update()` 有 transaction 记录但没有 receipt；后续 Finalize 的独立 `update()` 有成功 receipt。V2 台账不能把缺失 receipt 的那一笔标为 confirmed。

## 5. 修复和审核继承

部署提交包含以下关键祖先修复：

- `187f59a`：Launch 15 分钟、30% 税；
- `26ec240`：0% fee whitelist；
- `e965655`：Counterfactual TWAP 与 timestamp rollover；
- `7f4d757`：whitelist-aware preview；
- `ce44425`：用户税率 preview、slippage 和事件对齐；
- 之前的 Cost Basis、Staking、Oracle、Adapter、Governance 安全修复均已在部署提交历史中。

`docs/current/CONTRACT_SECURITY_AUDIT.md` 是 `e2c09c5` 的 CONDITIONAL APPROVE，不是部署提交本身；其中 P1-002 已由 `7f4d757` 和 `ce44425` 覆盖。其他 finding 不能因为部署成功自动标为关闭，应在"继承状态"中保留原结论或显式重新审核。

部署之后的 `67c451b`、`e1721ac`、`4909680`、`28c5790`、`4d33669` 等主要加固 Bootstrap/Finalize 脚本。它们没有改变已部署长期合约的 runtime 实现，且不允许用来重跑现有部署；Go 运行手册应继承其"防重复注入、按部署 artifact 清理、严格储备检查、撤销 stale proxy"等安全约束。

当前 HEAD 相比 `3ef50b6` 的 `contracts-v2/src` 只有 `IPangu2TwapOracle.sol` 接口说明增加，没有长期合约 runtime 代码修改。上线前仍应对部署 ABI 和 current ABI 生成 hash，而不是依赖该陈述。

## 6. Go 开发前必须补录的只读证据

- 每个地址当前 `eth_getCode` 非空和 runtime bytecode SHA-256；
- Pair `token0/token1` 与 factory `getPair`；
- Token `tradingOpenAt`、pair/system/liquidity manager/fee whitelist；
- 每份 AccessControl 合约的当前 role membership；
- Router/Token/Vault/Pool/Distributor 的 pause 状态；
- Oracle status、window、last completed、reserves；
- FeeVault bucket/accounting、SupportPool balance/cooldown、Locker mode/duration/recipient/solvency；
- Staking rate/reserve/liability/coverage；
- 选定固定 evidence block 的 number/hash。

未完成上述 readback 前，API 可显示 deployment `STATIC_VERIFIED`，不得显示 `LIVE_VERIFIED`，Admin 写路径不得启用。

## 7. 禁止事项

- 禁止自动执行任何 Solidity 部署或 Bootstrap 脚本；
- 禁止把旧 `0xaf2b...` 地址组导入为 ACTIVE；
- 禁止把广播记录当成当前角色/暂停状态的替代品；
- 禁止将 `.env`、RPC Secret 或私钥写入 deployment baseline；
- BSC Mainnet 永久 NO-GO。
