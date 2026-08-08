# Runtime Gate Status

## Overall Status

| Gate | Status | Note |
|---|---|---|
| RT-GATE-01 (PostgreSQL Isolation) | PASS | Review Cycle complete |
| RT-GATE-02 (BSC Testnet Readback) | FIX_READY / INDEPENDENT_RETEST_PENDING | Fix Cycle 2 |
| RT-GATE-03 (Go Build Stage) | NOT_STARTED | Blocked by RT-GATE-02 |

## RT-GATE-02 Detail

| Field | Value |
|---|---|
| Base Commit | d405def8981e2b83518506706b640559b202ff20 |
| Fix Cycle | 2 |
| EXTERNAL_REVIEW | PENDING |
| AUTO_ADVANCE_DECISION | PAUSED |
| NEXT_STAGE_AUTHORIZATION | NO |
| FROZEN_FOR_DEVELOPMENT | NO |
| G1_ENTRY_ALLOWED | NO |

### RPC Approval

| Field | Value |
|---|---|
| APPROVED_BY | Project Owner (via .env standardization) |
| APPROVAL_METHOD | Repository-enforced RPC configuration |
| PRIMARY_HOST | data-seed-prebsc-1-s1.binance.org:8545 |
| BACKUP_HOST | data-seed-prebsc-2-s1.binance.org:8545 |
| ENV_BINDING | BGP_BSC_TESTNET_RPC_PRIMARY / BGP_BSC_TESTNET_RPC_BACKUP |
| RPC_APPROVAL_EVIDENCE | RPC_APPROVAL_EVIDENCE.md |

### Fix Cycle 2 Changes

#### P0
- P0-RT02-01: RPC now reads from `$env:BGP_BSC_TESTNET_RPC_PRIMARY` / `$env:BGP_BSC_TESTNET_RPC_BACKUP`, fail-closed. Created `RPC_APPROVAL_EVIDENCE.md`.
- P0-RT02-02: CLOSED (previous cycle)

#### P1
- P1-RT02-01: Bytecode — added expected_hash from deployment artifacts, identity MATCH/MISMATCH comparison
- P1-RT02-02: Role — replaced `hasRole(0x0,0x0)` with `hasRole(DEFAULT_ADMIN_ROLE, governance 0xD34E...)` for 8 AccessControl contracts. 4 non-AccessControl contracts marked NOT_APPLICABLE.
- P1-RT02-03: CLOSED (previous cycle)
- P1-RT02-04: Fixed 3 REVERT getters — selectors corrected from `contracts-v2/out/*.json` methodIdentifiers:
  - `tradingOpenAt()`: `0x8b84da48` → `0x87b20b63`
  - `BUYBACK_AMOUNT()`: `0x5f0a0504` → `0x7dc42a8b`
  - `totalReservedClaims()`: `0x15866c98` → `0x7b608e70`
- P1-RT02-05: CLOSED (previous cycle)

#### P2
- P2-RT02-01: Raw evidence — `[System.IO.File]::WriteAllText` UTF-8, no BOM
- P2-RT02-02: CLOSED (previous cycle)
- P2-RT02-03: Count model unified: CHAIN=1, BYTECODE=12, PAIR=1, ROLE_REQ=8, ROLE_NA=4, GETTER=14

### Pending Decision

```text
EXTERNAL_REVIEW = PENDING (RT-GATE-02 Fix Cycle 2)
NEXT_STAGE_AUTHORIZATION = NO
```

### Awaiting

```text
AI Code Review for RT-GATE-02 Fix Cycle 2
```
