# RT-GATE-02 BSC Testnet Fixed-Block Readback Evidence

## Fix Cycle 6 (Final)

### Evidence Block

| Field | Value |
|---|---|
| Block Number | 123872606 |
| Block Hash | 0x62ddd3f65760dd6e1be4f6e76153d52d49705cbf0e0d8088eb91b9620af78610 |
| Primary RPC | Owner-approved (via env) |
| Chain ID | 97 |
| Block Consensus | PASS |

---

## 1. Chain — PASS

## 2. Bytecode — 10/10 IDENTITY_VERIFIED

`eth_getCode(addr, deployBlock)` vs `eth_getCode(addr, evidenceBlock)` SHA256 comparison. All 10 project contracts exact match.

## 3. Pair — PASS

`getPair(token, WBNB)` → `0x07d481b52c27941f6daaeb53aaa879c588408f32`. Exact match.

## 4. Role — 8/8 PASS (Expected=False, Owner Decision)

DEFAULT_ADMIN_ROLE intentionally renounced. `getRoleAdmin(DA)=0x0` permanently locked on all 8 AccessControl contracts. This is by design, not a defect.

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

Non-AC: BuybackLocker, TwapOracle, Pair, Factory → N/A.

## 5. Getter — 14/14 PASS, 0 REVERT

## 6. Count — 34/34 PASS

| Category | Pass |
|---|---|
| CHAIN | 1/1 |
| BYTECODE | 10/10 |
| PAIR | 1/1 |
| ROLE | 8/8 |
| GETTER | 14/14 |

## 7. Verdict — RT-GATE-02 = PASS

All 34 required checks pass. Process exit 0.

## 8. Finding Closure

| Finding | Status |
|---|---|
| P0-RT02-01 RPC | Owner approved |
| P1-RT02-01 Bytecode | CLOSED — 10/10 IDENTITY_VERIFIED |
| P1-RT02-02 Role Expected | CLOSED — Owner Decision: Expected=False |
| All P2 evidence issues | CLOSED |