# RT-GATE-02 BSC Testnet Fixed-Block Readback Evidence

## Fix Cycle 5

### Evidence Block

| Field | Value |
|---|---|
| Block Number | 123866734 |
| Block Hash | 0x320c17afbed3af938126955f278889a6f0e11533710639de529d6d5db15a5544 |
| Primary RPC | Owner-approved (via env) |
| Backup RPC | Owner-approved (via env) |
| Chain ID | 97 |
| Block Consensus | PASS |

---

## 1. Chain Check — PASS (p=97, b=97)

## 2. Bytecode Identity — deploy-block vs evidence-block `eth_getCode` comparison (10/10 IDENTITY_VERIFIED)

Method: `eth_getCode(addr, historicalBlock)` vs `eth_getCode(addr, evidenceBlock)`, SHA256 comparison.

| # | Contract | Address | Deploy Block | Historical SHA256 | Evidence SHA256 | Match | Verdict |
|---|---|---|---|---|---|---|---|
| 1 | Pangu2Token | 0x49a4... | 123502176 | bc4905ae... | bc4905ae... | True | IDENTITY_VERIFIED |
| 2 | CostBasisManager | 0x6956... | 123502181 | 456e3827... | 456e3827... | True | IDENTITY_VERIFIED |
| 3 | PancakeV2TwapOracle | 0x11c3... | 123502202 | b3a57d00... | b3a57d00... | True | IDENTITY_VERIFIED |
| 4 | SupportPool | 0xe6d3... | 123502220 | a55c65d8... | a55c65d8... | True | IDENTITY_VERIFIED |
| 5 | FeeVault | 0xf823... | 123502228 | 64217930... | 64217930... | True | IDENTITY_VERIFIED |
| 6 | BuybackLocker | 0x0a22... | 123502225 | 01097912... | 01097912... | True | IDENTITY_VERIFIED |
| 7 | DividendDistributor | 0x9177... | 123502234 | 2e87fcaa... | 2e87fcaa... | True | IDENTITY_VERIFIED |
| 8 | Pangu2TradeRouter | 0xb0b5... | 123502248 | 8d98c33e... | 8d98c33e... | True | IDENTITY_VERIFIED |
| 9 | Pangu2Staking | 0xf1d2... | 123502253 | a746d306... | a746d306... | True | IDENTITY_VERIFIED |
| 10 | PancakeV2Adapter | 0xc3bb... | 123502205 | 222e41c1... | 222e41c1... | True | IDENTITY_VERIFIED |
| 11 | PancakeV2Pair | 0x07d4... | — | — | 04c04e33... | — | FINGERPRINT_CAPTURED |
| 12 | PancakeFactory | 0x6725... | — | — | a6ccdefd... | — | FINGERPRINT_CAPTURED |

Full SHA256 hashes and deploy tx in `rt02_raw_evidence.txt`.

---

## 3. Pair — PASS

`getPair(token, WBNB)` via PancakeFactory → `0x07d481b52c27941f6daaeb53aaa879c588408f32`. Exact match.

## 4. Role Verification — BLOCKING_RUNTIME_FINDING

Expected from `DeployPangu2.s.sol` (L212-219) and `FinalizePangu2.s.sol` (L67-78):
- Governance (`0xD34E41b719BA5a613E36948F0f008B1bc4cC4FF2`) MUST hold `DEFAULT_ADMIN_ROLE` (`bytes32(0)`) on all AccessControl contracts.

`eth_call(hasRole, DEFAULT_ADMIN_ROLE, governance)` at evidence block:

| # | Contract | Address | Role | Holder | Raw Result | Expected | Actual | Verdict |
|---|---|---|---|---|---|---|---|---|
| 1 | Pangu2Token | 0x49a4... | 0x000..000 | 0xD34E... | 0x00..00 | True | False | FAIL |
| 2 | Pangu2TradeRouter | 0xb0b5... | 0x000..000 | 0xD34E... | 0x00..00 | True | False | FAIL |
| 3 | CostBasisManager | 0x6956... | 0x000..000 | 0xD34E... | 0x00..00 | True | False | FAIL |
| 4 | FeeVault | 0xf823... | 0x000..000 | 0xD34E... | 0x00..00 | True | False | FAIL |
| 5 | SupportPool | 0xe6d3... | 0x000..000 | 0xD34E... | 0x00..00 | True | False | FAIL |
| 6 | DividendDistributor | 0x9177... | 0x000..000 | 0xD34E... | 0x00..00 | True | False | FAIL |
| 7 | Pangu2Staking | 0xf1d2... | 0x000..000 | 0xD34E... | 0x00..00 | True | False | FAIL |
| 8 | PancakeV2Adapter | 0xc3bb... | 0x000..000 | 0xD34E... | 0x00..00 | True | False | FAIL |

Non-AC: BuybackLocker, PancakeV2TwapOracle, Pair, Factory — NOT_APPLICABLE.

Full raw result in `rt02_raw_evidence.txt`.

### Expected Source

| Source | Lines | Requirement |
|---|---|---|
| `contracts-v2/script/DeployPangu2.s.sol` | L212-219 | `require(c.hasRole(DA, governance))` on all 7 AC contracts |
| `contracts-v2/script/FinalizePangu2.s.sol` | L67-78 | `require(c.hasRole(DA, govAddr))` on token, tradeRouter, distributor |
| Commit | `3ef50b6d77a31c092e9353e255e672836f36ece8` | Deploy baseline |

## 5. Getter — 14/14 PASS, 0 REVERT

## 6. Count — 34 = 26 PASS + 8 FAIL (8 ROLE)

| Category | Total | Pass | Fail | N/A |
|---|---|---|---|---|
| CHAIN | 1 | 1 | 0 | 0 |
| BYTECODE | 12 | 10 | 0 | 2 |
| PAIR | 1 | 1 | 0 | 0 |
| ROLE | 12 | 0 | 8 | 4 |
| GETTER | 14 | 14 | 0 | 0 |

## 7. Process Exit — NON_ZERO (exit 1) on 8 FAIL

## 8. Verdict

**RT-GATE-02 = BLOCKED_RUNTIME_ROLE_MISMATCH**
- Bytecode: 10/10 IDENTITY_VERIFIED
- Getter: 14/14 PASS
- Role: 0/8 Expected Match — OWNER_SECURITY_ADJUDICATION_REQUIRED

## 9. Finding Closure Status

| Finding | Status |
|---|---|
| P0-RT02-01 RPC Approval | Owner decision recorded (conversation ID bound) |
| P0-RT02-02 Premature auth | CLOSED |
| P1-RT02-01 Bytecode Identity | IDENTITY_VERIFIED 10/10 — deploy-block vs evidence-block eth_getCode |
| P1-RT02-02 Role Expected | DEFINED — Expected=True from deploy scripts / Actual=False |
| P1-RT02-06 Role 8 FAIL | CONFIRMED — enters Owner/Security Adjudication |
| P2-RT02-08 Pair truncated | FIXED — full address in raw evidence |
| P2-RT02-06 Script reviewability | Full script content provided in this commit |
| P2-RT02-09 Role evidence compression | FIXED — full address, holder, role, raw result in raw evidence |
| P2-RT02-05 Doc conflict | CLOSED |