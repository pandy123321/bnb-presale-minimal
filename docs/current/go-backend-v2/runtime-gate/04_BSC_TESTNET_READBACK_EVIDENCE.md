# RT-GATE-02 BSC Testnet Fixed-Block Readback Evidence

## Fix Cycle 8 (Evidence Closure)

### Evidence Block

| Field | Value |
|---|---|
| Block Number | 123877114 |
| Block Hash | 0x7b21cf04b7062412f9ec975f4fb8e80a724a5274040af1d20a941bcb2ecc5ded |
| Chain ID | 97 |
| RPC Independence | PRIMARY != BACKUP enforced (script throw on equality) |

### 1. Chain — PASS (dual RPC)

### 2. Bytecode — 10/10 IDENTITY_VERIFIED (receipt-bound)

DEPLOY_BLOCK_SOURCE = TRANSACTION_RECEIPT. No hardcoded blocks. Drift eliminated.

| # | Contract | Deploy Block | Verdict |
|---|---|---|---|
| 1 | Pangu2Token | 123502176 | IDENTITY_VERIFIED |
| 2 | CostBasisManager | 123502181 | IDENTITY_VERIFIED |
| 3 | PancakeV2TwapOracle | 123502202 | IDENTITY_VERIFIED |
| 4 | SupportPool | 123502210 | IDENTITY_VERIFIED |
| 5 | FeeVault | 123502218 | IDENTITY_VERIFIED |
| 6 | BuybackLocker | 123502225 | IDENTITY_VERIFIED |
| 7 | DividendDistributor | 123502234 | IDENTITY_VERIFIED |
| 8 | Pangu2TradeRouter | 123502248 | IDENTITY_VERIFIED |
| 9 | Pangu2Staking | 123502253 | IDENTITY_VERIFIED |
| 10 | PancakeV2Adapter | 123502195 | IDENTITY_VERIFIED |

PancakeV2Pair + PancakeFactory: FINGERPRINT_CAPTURED.

### 3. Pair — PASS

### 4. Role — 8/8 PASS (Expected=False, Owner Decision bound)

OWNER_SECURITY_DECISION.md — RT02-OWNER-2026-001.
FROZEN_SECURITY_MODEL_CHANGE: True -> False.
ORIGINAL_FINDING = CONFIRMED (not erased).
DISPOSITION = ACCEPTED_BY_OWNER_SECURITY_MODEL_CHANGE.

| # | Contract | hasRole | Expected | Verdict |
|---|---|---|---|---|
| 1 | Pangu2Token | False | False | PASS |
| 2 | Pangu2TradeRouter | False | False | PASS |
| 3 | CostBasisManager | False | False | PASS |
| 4 | FeeVault | False | False | PASS |
| 5 | SupportPool | False | False | PASS |
| 6 | DividendDistributor | False | False | PASS |
| 7 | Pangu2Staking | False | False | PASS |
| 8 | PancakeV2Adapter | False | False | PASS |

Non-AC: 4 -> N/A.

Technical facts:
- governance_has_DA = false (8/8), deployer_has_DA = false (8/8)
- getRoleAdmin(DA) = DA (self-admin)
- OTHER_DA_HOLDERS = UNVERIFIED
- HISTORICAL_ROLE_SCAN = INCOMPLETE (RPC pruning)
- FINAL_ADMIN_RENOUNCE_HISTORY = UNVERIFIED

### 5. Getter — 14/14 PASS

### 6. Count — 34/34 PASS, exit 0

### 7. Verdict — FIX_READY / INDEPENDENT_RETEST_PENDING

### 8. Finding Closure

| Finding | Status |
|---|---|
| P0-RT02-01 RPC independence | FIXED — PRIMARY==BACKUP throw |
| P0-GOV-RT02-02 Owner Decision | CLOSED — OWNER_SECURITY_DECISION.md refined |
| P1-RT02-MANIFEST-01 Manifest SHA | FIXED — regenerated |
| P1-RT02-MANIFEST-02 Missing evidence | FIXED — RPC_APPROVAL + role_evidence.txt restored |
| P1-GOV-RT02-03 STATE_ONLY overstatement | FIXED — qualified UNVERIFIED |
| P2-GOV-RT02-01 Effective Revision | FIXED — 0f05e4a |