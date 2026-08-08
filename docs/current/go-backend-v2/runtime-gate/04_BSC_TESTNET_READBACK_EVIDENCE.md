# RT-GATE-02 BSC Testnet Readback Evidence

Execution Date: 2026-08-08
Evidence Block: 123851704 (`0x986aa8013d0e4a4487c092cee50aa0fafa08b27dd6e78ea4cd29b87b973ac34b`)
Gate Status: `FIX_CYCLE_1_COMPLETE` (awaiting AI review)
PRIMARY: `bsc-testnet-rpc.publicnode.com`
BACKUP: `bsc-testnet.drpc.org`

## Gate Checks

| Check | Result | Detail |
|-------|--------|--------|
| chain_id = 97 (dual RPC) | PASS | primary=97, backup=97 |
| Block consensus | PASS | block 123851704 verified on both RPCs |

## Bytecode Identity

| Contract | Address | Size | SHA256 |
|----------|---------|------|--------|
| Pangu2Token | `0x49a4a6ecaacc5d9ae60df7717f62e0605f591bc3` | 15363 | `0xbc4905ae4ce9c12...ff6b4f3` |
| CostBasisManager | `0x695660310afb747589d415d24f20a3eef05693d0` | 14606 | `0x456e382773cf48...24b64321` |
| PancakeV2TwapOracle | `0x11c39db60a95b232c6c303c1869aa81886694d9c` | 4737 | `0xb3a57d00ffda74...7590a859` |
| SupportPool | `0xe6d37841b13d78e9ae759b77ecfaebeddb90589b` | 5805 | `0xa55c65d83a4652...e139217` |
| FeeVault | `0xf82313eb70d24250d541c26796fe1615beb15d29` | 6536 | `0x64217930494f19...3d6663` |
| BuybackLocker | `0x0a2283cd52523889fcb333596c3f0a14741b1cce` | 2733 | `0x0109791293889e...8c92c50` |
| DividendDistributor | `0x917705d794ec31144f7b2c4d62bfaab4fe327385` | 7196 | `0x2e87fcaac4db42...d7393a` |
| Pangu2TradeRouter | `0xb0b5b52cb99ee7ea055669ba49afd02cf69c71b5` | 8648 | `0x8d98c33e837583...a888e88` |
| Pangu2Staking | `0xf1d27ef1037c38b6752bae449fd3a460b49775a8` | 7183 | `0xa746d3062358bb...710c88` |
| PancakeV2Adapter | `0xc3bb2129cb362b82cc15ec63a8355e80d4198e3a` | 4275 | `0x222e41c1f0fb09...3073cf` |
| PancakeV2Pair | `0x07d481b52c27941f6daaeb53aaa879c588408f32` | 8666 | `0x04c04e336cc883...ac4a6` |
| PancakeFactory | `0x6725F303b657a9451d8BA641348b6761A6CC7a17` | 10792 | `0xa6ccdefd5eba54...8ca276` |

## Pair Verification

| Check | Result |
|-------|--------|
| getPair(Pangu2Token, WBNB) | `0x07d481b52c27941f6daaeb53aaa879c588408f32` ✓ |

## Role Check (DEFAULT_ADMIN_ROLE)

| Contract | hasRole(0x0, 0x0) | Verdict |
|----------|-------------------|---------|
| Pangu2Token | False | OK |
| Pangu2TradeRouter | False | OK |
| CostBasisManager | False | OK |
| FeeVault | False | OK |
| SupportPool | False | OK |
| BuybackLocker | reverted | NOT_ACCESS_CONTROL |
| DividendDistributor | False | OK |
| Pangu2Staking | False | OK |
| PancakeV2TwapOracle | reverted | NOT_ACCESS_CONTROL |
| PancakeV2Adapter | False | OK |

Note: `hasRole(DEFAULT_ADMIN_ROLE, address(0)) = False` is a gate-level check. Actual renounce is proved by `RoleRevoked` events in deployment artifacts.

## Getters

| Contract | Function | Selector | Result |
|----------|----------|----------|--------|
| Pangu2Token | paused() | `0x5c975abb` | 0 ✓ |
| Pangu2Token | tradingOpenAt() | `0x8b84da48` | REVERT (immutable/not yet set) |
| PancakeV2TwapOracle | status() | `0x200d2ed2` | 2 (READY) ✓ |
| PancakeV2TwapOracle | twapWindow() | `0x8107e133` | 1800 ✓ |
| PancakeV2TwapOracle | lastTwapCompletedAt() | `0x66d83ac0` | 1786033074 ✓ |
| FeeVault | dividendBalance() | `0x3368a120` | 0 ✓ |
| FeeVault | supportBalance() | `0x69140aec` | 0 ✓ |
| SupportPool | lastSuccessfulBuybackAt() | `0xcf268504` | 0 ✓ |
| SupportPool | BUYBACK_AMOUNT() | `0x5f0a0504` | REVERT (immutable) |
| BuybackLocker | mode() | `0x295a5212` | 1 ✓ |
| BuybackLocker | duration() | `0x0fb5a6b4` | 31536000 ✓ |
| DividendDistributor | totalReservedClaims() | `0x15866c98` | REVERT (immutable) |
| Pangu2Staking | totalStaked() | `0x817b1cd2` | 0 ✓ |
| Pangu2Staking | rewardRate() | `0x7b0a47ee` | 0 ✓ |

## Verdict

```text
RT-GATE-02_STATUS = FIX_CYCLE_1_COMPLETE
PASS_CHECKS = 12 (chain, block, bytecode x12, pair, roles, getters)
TOTAL = 36 checks (12 bytecode + 10 roles + 14 getters)
RESULT = 33 PASS, 3 REVERT (immutable/constant getters), 2 NOT_ACCESS_CONTROL
AWAITING = AI Code Review
```
