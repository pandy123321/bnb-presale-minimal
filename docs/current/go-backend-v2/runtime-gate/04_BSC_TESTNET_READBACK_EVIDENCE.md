# RT-GATE-02 BSC Testnet Fixed-Block Readback Evidence

## Fix Cycle 2 -- Commit (pending)

### Evidence Block

| Field | Value |
|---|---|
| Block Number | 123857800 |
| Block Hash | `0x3e3354f0f778121f49d5e946794f1b9badc13fc8b7d3cd298e4eb9bf33a5bab7` |
| Primary RPC | data-seed-prebsc-1-s1.binance.org:8545 |
| Backup RPC | data-seed-prebsc-2-s1.binance.org:8545 |
| Chain ID (primary) | 97 |
| Chain ID (backup) | 97 |
| Block Consensus | PASS (primary hash == backup hash at same block number) |
| RPC Approval | RPC_APPROVAL_EVIDENCE.md |

---

## 1. Chain Check

| Check | Result |
|---|---|
| Primary RPC chain_id == 97 | PASS |
| Backup RPC chain_id == 97 | PASS |
| Block consensus (same N, same H) | PASS |

---

## 2. Bytecode Identity (Reference: commit 3ef50b6 artifacts)

Expected hashes computed from `contracts-v2/out/*.json` `deployedBytecode.object`. Current workspace artifacts may differ from deployment commit due to post-deployment Solidity changes.

| # | Contract | Address | Size (bytes) | Actual SHA256 (on-chain) | Expected SHA256 (artifact) | Match | Verdict |
|---|---|---|---|---|---|---|---|
| 1 | Pangu2Token | 0x49a4a6Ec...1bc3 | 15363 | `bc4905ae...6b4f3` | `c3b9cc97...425e09` | False | IDENTITY_MISMATCH |
| 2 | CostBasisManager | 0x695660...93D0 | 14606 | `456e3827...64321` | `a6a01b17...605e96` | False | IDENTITY_MISMATCH |
| 3 | PancakeV2TwapOracle | 0x11C39D...94D9c | 4737 | `b3a57d00...0a859` | `8e21d2cc...1b79d5` | False | IDENTITY_MISMATCH |
| 4 | SupportPool | 0xe6d378...0589B | 5805 | `a55c65d8...39217` | `8a77e540...b341a5` | False | IDENTITY_MISMATCH |
| 5 | FeeVault | 0xF82313...15D29 | 6536 | `64217930...d6663` | `d5df3bb2...e54aaf` | False | IDENTITY_MISMATCH |
| 6 | BuybackLocker | 0x0a2283...B1cce | 2733 | `01097912...92c50` | `2770b07e...79c9c7` | False | IDENTITY_MISMATCH |
| 7 | DividendDistributor | 0x917705...27385 | 7196 | `2e87fcaa...7393a` | `6484606b...2ed410` | False | IDENTITY_MISMATCH |
| 8 | Pangu2TradeRouter | 0xB0b5b5...C71b5 | 8648 | `8d98c33e...88e88` | `c31a4e55...a290c8` | False | IDENTITY_MISMATCH |
| 9 | Pangu2Staking | 0xf1D27E...975a8 | 7183 | `a746d306...10c88` | `c9ba5f03...0b9961` | False | IDENTITY_MISMATCH |
| 10 | PancakeV2Adapter | 0xC3BB21...98E3a | 4275 | `222e41c1...073cf` | `59f80a58...188d95` | False | IDENTITY_MISMATCH |
| 11 | PancakeV2Pair | 0x07d481...08F32 | 8666 | `04c04e33...ac4a6` | N/A | N/A | FINGERPRINT_CAPTURED |
| 12 | PancakeFactory | 0x6725F3...C7a17 | 10792 | `a6ccdefd...8ca276` | N/A | N/A | FINGERPRINT_CAPTURED |

**Summary**: All 10 identity-verifiable contracts show IDENTITY_MISMATCH between on-chain and current-workspace artifact bytecode. This is expected because the workspace artifacts reflect post-deployment Solidity changes (S2 fixes). Identity verification requires bytecode from deployment commit `3ef50b6`. 2 contracts (Pair, Factory) have no workspace artifacts and are FINGERPRINT_CAPTURED only.

---

## 3. Pair Verification

| Check | Result |
|---|---|
| PancakeFactory.getPair(PANGU2, WBNB) | `0x07d481b52c27941f6daaeb53aaa879c588408f32` |
| Expected Pair address | `0x07d481b52c27941f6daaeb53aaa879c588408f32` |
| Match | PASS |

---

## 4. Role Verification (DEFAULT_ADMIN_ROLE)

Using governance address `0xD34E41b719BA5a613E36948F0f008B1bc4cC4FF2` (from deployment broadcast artifacts, commit 3ef50b6).

**AccessControl contracts:**

| # | Contract | hasRole(DEFAULT_ADMIN_ROLE, governance) | Verdict |
|---|---|---|---|
| 1 | Pangu2Token | False | FAIL |
| 2 | Pangu2TradeRouter | False | FAIL |
| 3 | CostBasisManager | False | FAIL |
| 4 | FeeVault | False | FAIL |
| 5 | SupportPool | False | FAIL |
| 6 | DividendDistributor | False | FAIL |
| 7 | Pangu2Staking | False | FAIL |
| 8 | PancakeV2Adapter | False | FAIL |

All 8 AccessControl contracts return `hasRole(DEFAULT_ADMIN_ROLE, governance) = False`. This is consistent with admin fully renounced via Bootstrap/Finalize scripts (deployer renounced in bootstrap, governance may have renounced in finalize). The system appears to be in a fully decentralized (admin-free) state on chain.

**Non-AccessControl contracts:**

| # | Contract | Classification |
|---|---|---|
| 9 | BuybackLocker | NOT_APPLICABLE -- no AccessControl |
| 10 | PancakeV2TwapOracle | NOT_APPLICABLE -- no AccessControl |
| 11 | PancakeV2Pair | NOT_APPLICABLE -- PancakeSwap factory pair |
| 12 | PancakeFactory | NOT_APPLICABLE -- PancakeSwap factory |

---

## 5. Getter Readback

All selectors verified against `contracts-v2/out/*.json` `methodIdentifiers`.

| # | Contract | Getter | Selector | Return Value | Verdict |
|---|---|---|---|---|---|
| 1 | Pangu2Token | paused() | 0x5c975abb | 0 (not paused) | PASS |
| 2 | Pangu2Token | tradingOpenAt() | 0x87b20b63 | 1786033554 | PASS |
| 3 | PancakeV2TwapOracle | status() | 0x200d2ed2 | 2 | PASS |
| 4 | PancakeV2TwapOracle | twapWindow() | 0x8107e133 | 1800 | PASS |
| 5 | PancakeV2TwapOracle | lastTwapCompletedAt() | 0x66d83ac0 | 1786033074 | PASS |
| 6 | FeeVault | dividendBalance() | 0x3368a120 | 0 | PASS |
| 7 | FeeVault | supportBalance() | 0x69140aec | 0 | PASS |
| 8 | SupportPool | lastSuccessfulBuybackAt() | 0xcf268504 | 0 | PASS |
| 9 | SupportPool | BUYBACK_AMOUNT() | 0x7dc42a8b | 10000000000000000 | PASS |
| 10 | BuybackLocker | mode() | 0x295a5212 | 1 | PASS |
| 11 | BuybackLocker | duration() | 0x0fb5a6b4 | 31536000 | PASS |
| 12 | DividendDistributor | totalReservedClaims() | 0x7b608e70 | 0 | PASS |
| 13 | Pangu2Staking | totalStaked() | 0x817b1cd2 | 0 | PASS |
| 14 | Pangu2Staking | rewardRate() | 0x7b0a47ee | 0 | PASS |

**Summary**: 14/14 getters PASS, 0 REVERT. All 3 previously-failing getters now return valid data after selector fix.

---

## 6. Count Model

| Category | Total | Pass | Fail | N/A |
|---|---|---|---|---|
| CHAIN | 1 | 1 | 0 | 0 |
| BYTECODE | 12 | 0 | 10 | 2 |
| PAIR | 1 | 1 | 0 | 0 |
| ROLE | 12 | 0 | 8 | 4 |
| GETTER | 14 | 14 | 0 | 0 |

```
TOTAL_REQUIRED (identity-capable) = 1 + 10 + 1 + 8 + 14 = 34
PASS_REQUIRED = 1 + 0 + 1 + 0 + 14 = 16
FAIL_REQUIRED = 0 + 10 + 0 + 8 + 0 = 18
N/A = 2 (fingerprint-only bytecode) + 4 (non-AccessControl roles) = 6

PASS_REQUIRED (16) + FAIL_REQUIRED (18) = TOTAL_REQUIRED (34)
```

---

## 7. Verdict

| Metric | Value |
|---|---|
| REQUIRED_GETTER_REVERT | 0 |
| BYTECODE_IDENTITY_MATCH | 0/10 |
| ROLE_PASS | 0/8 |
| CHAIN_CONSENSUS | PASS |
| PAIR_VERIFICATION | PASS |

### P1-RT02-04 Status

**FIXED**: All 3 previously REVERT'ing getters now return valid data:
- `Pangu2Token.tradingOpenAt()` -- selector corrected `0x8b84da48` to `0x87b20b63`, returns `1786033554`
- `SupportPool.BUYBACK_AMOUNT()` -- selector corrected `0x5f0a0504` to `0x7dc42a8b`, returns `10000000000000000`
- `DividendDistributor.totalReservedClaims()` -- selector corrected `0x15866c98` to `0x7b608e70`, returns `0`

Root cause: incorrect 4-byte function selectors in the previous script version. Selectors were not derived from actual contract ABI `methodIdentifiers`.
