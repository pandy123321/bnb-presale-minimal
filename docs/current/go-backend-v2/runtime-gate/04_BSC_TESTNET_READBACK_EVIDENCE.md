# RT-GATE-02 BSC Testnet Fixed-Block Readback Evidence

## Fix Cycle 7 + Owner Security Decision

### Evidence Block

| Field | Value |
|---|---|
| Block Number | 123877114 |
| Block Hash | 0x7b21cf04b7062412f9ec975f4fb8e80a724a5274040af1d20a941bcb2ecc5ded |
| Primary RPC | publicnode (env-injected) |
| Chain ID | 97 |

### 1. Chain — PASS

### 2. Bytecode — 10/10 IDENTITY_VERIFIED (receipt-bound)

Deploy blocks from eth_getTransactionReceipt. No hardcoded, no offset fallback.

| # | Contract | Block | Match | Verdict |
|---|---|---|---|---|
| 1 | Pangu2Token | 123502176 | True | IDENTITY_VERIFIED |
| 2 | CostBasisManager | 123502181 | True | IDENTITY_VERIFIED |
| 3 | PancakeV2TwapOracle | 123502202 | True | IDENTITY_VERIFIED |
| 4 | SupportPool | 123502210 | True | IDENTITY_VERIFIED |
| 5 | FeeVault | 123502218 | True | IDENTITY_VERIFIED |
| 6 | BuybackLocker | 123502225 | True | IDENTITY_VERIFIED |
| 7 | DividendDistributor | 123502234 | True | IDENTITY_VERIFIED |
| 8 | Pangu2TradeRouter | 123502248 | True | IDENTITY_VERIFIED |
| 9 | Pangu2Staking | 123502253 | True | IDENTITY_VERIFIED |
| 10 | PancakeV2Adapter | 123502195 | True | IDENTITY_VERIFIED |

PancakeV2Pair + PancakeFactory: FINGERPRINT_CAPTURED.

### 3. Pair — PASS

### 4. Role — 8/8 PASS (Expected=False, Owner Decision bound)

OWNER_SECURITY_DECISION.md — RT02-OWNER-2026-001.
FROZEN_SECURITY_MODEL_CHANGE: True -> False. DEPLOYMENT_MANIFEST "NO" correct.

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

Non-AC: BuybackLocker, TwapOracle, Pair, Factory -> N/A.

getRoleAdmin(DA) = DA (self-admin). Not permanent lock.
ROLE_EVIDENCE = STATE_ONLY (historical events INCOMPLETE via RPC pruning).

### 5. Getter — 14/14 PASS

### 6. Count — 34/34 PASS, exit 0

### 7. Verdict — FIX_READY / INDEPENDENT_RETEST_PENDING

### 8. Finding Closure

| Finding | Status |
|---|---|
| P0-GOV-RT02-02 Owner Decision | CLOSED — OWNER_SECURITY_DECISION.md |
| P1-RT02-BLOCK-BINDING | FIXED — receipt-bound |
| P1-RT02-ROLE-SEMANTICS | FIXED — self-admin |
| P2-RT02-SUBMISSION | FIXED — UTF-8 NO BOM |