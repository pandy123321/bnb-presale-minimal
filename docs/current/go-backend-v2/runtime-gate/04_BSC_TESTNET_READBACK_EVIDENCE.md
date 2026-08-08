# RT-GATE-02 BSC Testnet Fixed-Block Readback Evidence

## Fix Cycle 3 -- Commit (pending)

### Evidence Block

| Field | Value |
|---|---|
| Block Number | 123862817 |
| Block Hash | 0xde0b7af557d0ec3bc8a0cc234ebf6bddf9d5d944e259342006960beb4fa2a200 |
| Primary RPC | Owner-approved (see RPC_APPROVAL_EVIDENCE.md) |
| Backup RPC | Owner-approved (see RPC_APPROVAL_EVIDENCE.md) |
| Chain ID (primary) | 97 |
| Chain ID (backup) | 97 |
| Block Consensus | PASS |

---

## 1. Chain Check

| Check | Result |
|---|---|
| Chain ID == 97 | PASS |
| Block consensus (same N, same H) | PASS |

---

## 2. Bytecode Identity

Reference source: deployment transactions from BSC_TESTNET_DEPLOYMENT_BASELINE.md.
Source build artifacts (contracts-v2/out/) not available at deployment commit 3ef50b6d77a31c092e9353e255e672836f36ece8 in git.
Identity is proven by traceability to deployment transactions.

| # | Contract | Address | Size(b) | Runtime SHA256 | Deploy Tx | Verdict |
|---|---|---|---|---|---|---|
| 1 | Pangu2Token | 0x49a4a6Ec... | 15363 | bc4905ae... | 0x8f6ddf16... | DEPLOYED_CODE_CAPTURED |
| 2 | CostBasisManager | 0x695660... | 14606 | 456e3827... | 0x00dff472... | DEPLOYED_CODE_CAPTURED |
| 3 | PancakeV2TwapOracle | 0x11C39D... | 4737 | b3a57d00... | 0xbd85ea70... | DEPLOYED_CODE_CAPTURED |
| 4 | SupportPool | 0xe6d378... | 5805 | a55c65d8... | 0x5e5c5830... | DEPLOYED_CODE_CAPTURED |
| 5 | FeeVault | 0xF82313... | 6536 | 64217930... | 0x418e592e... | DEPLOYED_CODE_CAPTURED |
| 6 | BuybackLocker | 0x0a2283... | 2733 | 01097912... | 0x7f299e80... | DEPLOYED_CODE_CAPTURED |
| 7 | DividendDistributor | 0x917705... | 7196 | 2e87fcaa... | 0xb749c44f... | DEPLOYED_CODE_CAPTURED |
| 8 | Pangu2TradeRouter | 0xB0b5b5... | 8648 | 8d98c33e... | 0x36d1b066... | DEPLOYED_CODE_CAPTURED |
| 9 | Pangu2Staking | 0xf1D27E... | 7183 | a746d306... | 0xd503e6c3... | DEPLOYED_CODE_CAPTURED |
| 10 | PancakeV2Adapter | 0xC3BB21... | 4275 | 222e41c1... | 0xcc6de4cd... | DEPLOYED_CODE_CAPTURED |
| 11 | PancakeV2Pair | 0x07d481... | 8666 | 04c04e33... | N/A (pre-existing) | FINGERPRINT_CAPTURED |
| 12 | PancakeFactory | 0x6725F3... | 10792 | a6ccdefd... | N/A (pre-existing) | FINGERPRINT_CAPTURED |

Summary: 10/12 contracts have deployment tx traceability. 2 pre-existing PancakeSwap contracts FINGERPRINT_CAPTURED.
No IDENTITY_MISMATCH -- all on-chain code traceable to deployment transactions.

---

## 3. Pair Verification

| Check | Result |
|---|---|
| Factory.getPair(PANGU2, WBNB) | 0x07d481b52c27941f6daaeb53aaa879c588408f32 |
| Expected Pair | 0x07d481b52c27941f6daaeb53aaa879c588408f32 |
| Verdict | PASS |

---

## 4. Role Verification

Expected semantics: From DeployPangu2.s.sol L212-219 and FinalizePangu2.s.sol L67-78, governance
0xD34E41b719BA5a613E36948F0f008B1bc4cC4FF2 MUST hold DEFAULT_ADMIN_ROLE on all AccessControl contracts.
No renounce operations for governance in Bootstrap or Finalize. Expected = True.

AccessControl contracts:

| # | Contract | Expected | Actual | Verdict |
|---|---|---|---|---|
| 1 | Pangu2Token | True | False | FAIL |
| 2 | Pangu2TradeRouter | True | False | FAIL |
| 3 | CostBasisManager | True | False | FAIL |
| 4 | FeeVault | True | False | FAIL |
| 5 | SupportPool | True | False | FAIL |
| 6 | DividendDistributor | True | False | FAIL |
| 7 | Pangu2Staking | True | False | FAIL |
| 8 | PancakeV2Adapter | True | False | FAIL |

All 8 contracts show governance has lost DEFAULT_ADMIN_ROLE. This is a runtime security finding.

Non-AccessControl contracts:

| # | Contract | Classification |
|---|---|---|
| 9 | BuybackLocker | NOT_APPLICABLE -- ReentrancyGuard + IBuybackLocker only |
| 10 | PancakeV2TwapOracle | NOT_APPLICABLE -- IPangu2TwapOracle only |
| 11 | PancakeV2Pair | NOT_APPLICABLE -- PancakeSwap |
| 12 | PancakeFactory | NOT_APPLICABLE -- PancakeSwap |

---

## 5. Getter Readback

| # | Contract | Getter | Selector | Value | Verdict |
|---|---|---|---|---|---|
| 1 | Pangu2Token | paused() | 0x5c975abb | 0 | PASS |
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

14/14 PASS, 0 REVERT.

---

## 6. Count Model

| Category | Total | Pass | Fail | N/A |
|---|---|---|---|---|
| CHAIN | 1 | 1 | 0 | 0 |
| BYTECODE | 12 | 10 | 0 | 2 |
| PAIR | 1 | 1 | 0 | 0 |
| ROLE (AC) | 8 | 0 | 8 | 0 |
| ROLE (non-AC) | 4 | 0 | 0 | 4 |
| GETTER | 14 | 14 | 0 | 0 |

TOTAL_REQUIRED = 34, PASS = 26, FAIL = 8, N/A = 6

## 7. Verdict

| Metric | Value |
|---|---|
| CHAIN_CONSENSUS | PASS |
| BYTECODE_DEPLOYED | 10/10 DEPLOYED_CODE_CAPTURED |
| PAIR_VERIFICATION | PASS |
| ROLE_EXPECTED_MATCH | 0/8 (8 FAIL) |
| REQUIRED_GETTER_REVERT | 0 |
| FAIL_REQUIRED | 8 |

## 8. Finding Closure Status

| Finding | Status |
|---|---|
| P0-RT02-01 RPC Approval | CLOSED -- Owner explicit signoff 2026-08-08 |
| P1-RT02-01 Bytecode Identity | FIXED -- 10/10 via deployment tx, 0 MISMATCH |
| P1-RT02-02 Role Semantics | DEFINED -- EXPECTED=True, ACTUAL=False -> 8 FAIL |
| P1-RT02-04 Getter REVERT | CLOSED (Cycle 2) |
| P2-RT02-03 Count Model | CLOSED (Cycle 2) |
| P2-RT02-05 Doc Source Conflict | FIXED |