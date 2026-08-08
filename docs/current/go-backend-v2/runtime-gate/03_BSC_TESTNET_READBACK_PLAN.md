# RT-GATE-02：BSC Testnet Readback Plan

## 状态

```text
RT-GATE-02_TESTNET_READBACK = BLOCKED_APPROVED_RPC_REQUIRED
```

## 阻断原因

执行环境没有已批准的 BSC Testnet RPC endpoint。

按 Gate 指令要求：
- RPC 必须通过环境变量注入（`BGP_BSC_TESTNET_RPC_PRIMARY` / `BGP_BSC_TESTNET_RPC_BACKUP`）
- 不得将 API Key 写入 Git、Markdown、日志、聊天输出或测试证据
- 不得自行寻找公共 RPC 冒充批准输入
- 如果无批准 RPC：`RT-GATE-02 = BLOCKED_APPROVED_RPC_REQUIRED`

## 固定 Evidence Block 候选

根据 `contracts/BSC_TESTNET_DEPLOYMENT_BASELINE.md`，OpenTrading 交易发生在：

```text
block_number = 123527207
tx_hash      = 0x4c780e1168abfd4e5bb6b65aa9d90f6fd924ec5667c49311fee688416470fd6a
```

推荐的固定 evidence block：
- 候选 1：`123527207`（OpenTrading 所在区块）— 但此时 trading 刚开，链上状态不够完整
- 候选 2：在 RPC 可用后，Primary/Backup 各读最新 finalized block，取较高者作为 evidence block

实际固定 block 必须在 RPC 可用后由 Primary 和 Backup 各自读回，且 `number` 和 `hash` 在两个 RPC 之间完全一致。

## RPC 注入方式

```text
环境变量：
  BGP_BSC_TESTNET_RPC_PRIMARY
  BGP_BSC_TESTNET_RPC_BACKUP

代码中读取，不得硬编码或 log 输出。
```

## 只读方法清单（全允许）

| 方法 | 用途 |
|---|---|
| `eth_chainId` | 确认 chain_id = 97 |
| `eth_getBlockByNumber` | 获取 evidence block |
| `eth_getCode` | 读取所有 11 个合约 + Pair 的 runtime bytecode |
| `eth_call` | 调用 getter（roles, pause, tradingOpenAt, Oracle, Fee, Support, Locker, Staking, allowance） |

严禁：`eth_sendRawTransaction`、部署、签名、广播、修改链上状态、Mainnet RPC。

## 必须读回的证据清单

### 1. Runtime Code（11 合约 + Pair）

对每个地址执行 `eth_getCode(address, fixedBlock)`，计算 `keccak256(runtime bytecode)`：

| contract_key | address |
|---|---|
| Pangu2Token | `0x49a4a6ecaacc5d9ae60df7717f62e0605f591bc3` |
| CostBasisManager | `0x695660310afb747589d415d24f20a3eef05693d0` |
| PancakeV2TwapOracle | `0x11c39db60a95b232c6c303c1869aa81886694d9c` |
| SupportPool | `0xe6d37841b13d78e9ae759b77ecfaebeddb90589b` |
| FeeVault | `0xf82313eb70d24250d541c26796fe1615beb15d29` |
| BuybackLocker | `0x0a2283cd52523889fcb333596c3f0a14741b1cce` |
| DividendDistributor | `0x917705d794ec31144f7b2c4d62bfaab4fe327385` |
| Pangu2TradeRouter | `0xb0b5b52cb99ee7ea055669ba49afd02cf69c71b5` |
| Pangu2Staking | `0xf1d27ef1037c38b6752bae449fd3a460b49775a8` |
| PancakeV2Adapter | `0xc3bb2129cb362b82cc15ec63a8355e80d4198e3a` |
| Pancake V2 Pair | `0x07d481b52c27941f6daaeb53aaa879c588408f32` |

### 2. Pair Verification

```solidity
// PancakeFactory.getPair(PANGU2, WBNB)
factory.getPair(0x49a4a6ecaacc5d9ae60df7717f62e0605f591bc3, 0xae13d989dac2f0debff460ac112a837c89baa7cd)
```

结果必须等于 `0x07d481b52c27941f6daaeb53aaa879c588408f32`。

### 3. AccessControl Roles

对每个使用 AccessControl 的合约（Token, Router, CostBasis, FeeVault, Support, Locker, Dividend, Staking, Oracle, Adapter）：

- `DEFAULT_ADMIN_ROLE`：`0x0000000000000000000000000000000000000000000000000000000000000000`
- `hasRole(DEFAULT_ADMIN_ROLE, account)` → 应返回 `false`（admin role 应已被 renounce）
- `PAUSER_ROLE` / `MANAGER_ROLE` / `OPERATOR_ROLE` / `GOVERNANCE_ROLE` 等业务 role
- 具体 role hash 以部署 ABI 的 `keccak256("ROLE_NAME")` 为准

### 4. State Getters

| 合约 | Getter | 预期 / 关注 |
|---|---|---|
| Pangu2Token | `paused()` | 预期 `false` |
| Pangu2Token | `tradingOpenAt()` | 应返回非零 timestamp |
| Pangu2Token | `feeWhitelist(address)` | 检查 whitelist 状态 |
| Pangu2Token | `isPair` / `isLiquidityManager` / `isSystemAddress` | 检查冻结系统地址 |
| PancakeV2TwapOracle | `status()` | 预期 READY / ACCUMULATING |
| PancakeV2TwapOracle | `window()` | 预期 1800 |
| PancakeV2TwapOracle | `last()` | 最后完成时间戳 |
| FeeVault | `dividendBalance()` / `supportBalance()` | bucket accounting |
| SupportPool | `lastBuybackTime()` | 最后回购时间 |
| SupportPool | `buybackAmount()` | 预期 0.01 BNB |
| BuybackLocker | `mode()` / `duration()` / `releaseRecipient()` | 锁仓参数 |
| DividendDistributor | `totalReserved()` / `epochCount()` | 分红储备 |
| Pangu2Staking | `rewardRate()` / `totalStaked()` / `rewardReserve()` | 质押参数 |
| Pangu2TradeRouter | 验证可调用 | Router 存活 |

### 5. Allowance 检查

- Token allowance to Router
- Token allowance to Staking
- WBNB allowance (if applicable)

## Readback 证据格式（每条）

```json
{
  "network": "bsc_testnet",
  "chain_id": 97,
  "rpc_source": "PRIMARY",
  "block_number": 123527207,
  "block_hash": "0x...",
  "contract_key": "Pangu2Token",
  "address": "0x49a4a6ecaacc5d9ae60df7717f62e0605f591bc3",
  "method": "eth_getCode",
  "raw_result": "0x...",
  "decoded_result": { "runtime_bytecode_size": 12345, "runtime_bytecode_hash": "0x..." },
  "expected": "non-empty code",
  "verdict": "PASS"
}
```

不得记录 RPC Secret。

## 失败规则

任一项关键检查（code missing, address mismatch, block hash mismatch, getter mismatch, role mismatch, pair mismatch, decode fail, RPC disagreement）：

```text
RT-GATE-02 = FAILED
DEPLOYMENT_SET_ACTIVE = NO
READY = FALSE
API = UNAVAILABLE
```

不得"先通过以后再查"。

## 当前结论

等待责任人批准并注入 BSC Testnet RPC（PRIMARY + BACKUP）。RPC 就绪后，按本 Plan 执行全量 readback 并产出 `04_BSC_TESTNET_READBACK_EVIDENCE.md`。
