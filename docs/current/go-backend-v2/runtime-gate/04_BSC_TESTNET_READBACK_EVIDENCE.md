# RT-GATE-02 BSC Testnet Fixed-Block Readback Evidence

## Fix Cycle 4

### Evidence Block

| Field | Value |
|---|---|
| Block Number | 123864632 |
| Block Hash | 0x5c3277790e6b128a9cacafa4906840d1a2b80e86a266c9add097bfbe54ac3ace |
| Primary RPC | Owner-approved |
| Chain ID | 97 |
| Block Consensus | PASS |

---

## 1. Chain Check — PASS

## 2. Bytecode Identity — deploy-block vs evidence-block comparison

Method: `eth_getCode(addr, deployBlock)` vs `eth_getCode(addr, evidenceBlock)`. 
Bytecode is immutable; SHA256 match proves runtime identity.

| # | Contract | Historical Hash | Evidence Hash | Match | Verdict |
|---|---|---|---|---|---|
| 1 | Pangu2Token | bc4905ae... | bc4905ae... | True | IDENTITY_VERIFIED |
| 2 | CostBasisManager | 456e3827... | 456e3827... | True | IDENTITY_VERIFIED |
| 3 | PancakeV2TwapOracle | b3a57d00... | b3a57d00... | True | IDENTITY_VERIFIED |
| 4 | SupportPool | a55c65d8... | a55c65d8... | True | IDENTITY_VERIFIED |
| 5 | FeeVault | 64217930... | 64217930... | True | IDENTITY_VERIFIED |
| 6 | BuybackLocker | 01097912... | 01097912... | True | IDENTITY_VERIFIED |
| 7 | DividendDistributor | 2e87fcaa... | 2e87fcaa... | True | IDENTITY_VERIFIED |
| 8 | Pangu2TradeRouter | 8d98c33e... | 8d98c33e... | True | IDENTITY_VERIFIED |
| 9 | Pangu2Staking | a746d306... | a746d306... | True | IDENTITY_VERIFIED |
| 10 | PancakeV2Adapter | 222e41c1... | 222e41c1... | True | IDENTITY_VERIFIED |
| 11 | PancakeV2Pair | — | 04c04e33... | — | FINGERPRINT_CAPTURED |
| 12 | PancakeFactory | — | a6ccdefd... | — | FINGERPRINT_CAPTURED |

**10/10 IDENTITY_VERIFIED, 2 FINGERPRINT_CAPTURED (pre-existing PancakeSwap).**

---

## 3. Pair — PASS

## 4. Role Verification — Expected=True, Actual=False (8/8 FAIL)

Expected semantics from FinalizePangu2.s.sol: governance MUST hold DEFAULT_ADMIN_ROLE.

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

Non-AC: BuybackLocker, PancakeV2TwapOracle, Pair, Factory → NOT_APPLICABLE.

---

## 5. Getter — 14/14 PASS, 0 REVERT

## 6. Count — 34 = 26 PASS + 8 FAIL

| Category | Total | Pass | Fail | N/A |
|---|---|---|---|---|
| CHAIN | 1 | 1 | 0 | 0 |
| BYTECODE | 12 | 10 | 0 | 2 |
| PAIR | 1 | 1 | 0 | 0 |
| ROLE | 12 | 0 | 8 | 4 |
| GETTER | 14 | 14 | 0 | 0 |

## 7. Finding Closure

| Finding | Status |
|---|---|
| P0-RT02-01 RPC Approval | CLOSED — Owner explicit signoff |
| P0-RT02-02 Premature auth | CLOSED |
| P1-RT02-01 Bytecode Identity | CLOSED — 10/10 IDENTITY_VERIFIED via deploy-block vs current-block comparison |
| P1-RT02-02 Role Expected | DEFINED — Expected=True, Actual=False, 8 FAIL |
| P1-RT02-03 RPC fail-closed | CLOSED |
| P1-RT02-04 Getter REVERT | CLOSED — 14/14 |
| P1-RT02-05 Manifest | CLOSED |
| P2-RT02-01 Raw evidence | CLOSED — text-readable |
| P2-RT02-02 Fixed block | CLOSED |
| P2-RT02-03 Count model | CLOSED |
| P2-RT02-05 Doc conflict | CLOSED |