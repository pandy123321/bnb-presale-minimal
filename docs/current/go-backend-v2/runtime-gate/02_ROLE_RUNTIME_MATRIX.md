# RT-GATE-01 Role Runtime Permission Validation Matrix

## Status

```text
RT-GATE-01_ROLE_RUNTIME = PASS
```

**Evidence Timestamp**: 2026-08-08T12:40+08:00
**PostgreSQL**: 16.14 (Docker postgres:16-alpine, container bgp-pg16:5433)

## Test Result Summary (Unified Counts)

| Category | Count | Result |
|----------|------:|:--:|
| ROLE_IDENTITY_CHECKS | 8/8 | PASS |
| CLUSTER_PRIVILEGE_CHECKS | 32/32 | PASS |
| ROLE_INHERITANCE_CHECKS | 1/1 | PASS |
| PERMISSION_BOUNDARY_CHECKS | 36/36 | PASS |
| STATE_PROTECTION_CHECKS (SP-01~SP-12) | 12/12 | PASS |
| MUTATION_SAFETY_CHECK | 1/1 | PASS |
| **TOTAL** | **90/90** | **PASS** |

## 1. ROLE_IDENTITY_CHECKS (8/8)

Each LOGIN role confirmed via independent `psql -U <role>` connection:
`session_user = current_user = role_name` (exact match, no SET ROLE, no inheritance)

| Role | session_user | current_user | Result |
|------|:---|:---|:--:|
| bgp_api | bgp_api | bgp_api | PASS |
| bgp_indexer | bgp_indexer | bgp_indexer | PASS |
| bgp_projector | bgp_projector | bgp_projector | PASS |
| bgp_dividend | bgp_dividend | bgp_dividend | PASS |
| bgp_reconciler | bgp_reconciler | bgp_reconciler | PASS |
| bgp_auditor | bgp_auditor | bgp_auditor | PASS |
| bgp_readonly | bgp_readonly | bgp_readonly | PASS |
| bgp_migrator | bgp_migrator | bgp_migrator | PASS |

## 2. CLUSTER_PRIVILEGE_CHECKS (32/32)

All 8 roles × 4 checks (superuser, createdb, createrole, bypassrls): all `false`

## 3. ROLE_INHERITANCE_CHECKS (1/1)

0 role memberships between any bgp_* roles. bgp_migrator NOT inherited.

## 4. PERMISSION_BOUNDARY_CHECKS (36/36)

### bgp_api
| ID | Operation | Expected | Actual |
|----|-----------|:--:|:--:|
| API-01 | SELECT environments | ALLOWED | PASS |
| API-02 | INSERT admin_audit_logs | ALLOWED | PASS |
| API-03 | INSERT governance_commands | ALLOWED | PASS |
| API-04 | INSERT chain_raw_events | DENIED | PASS |
| API-05 | INSERT signer_nonces | DENIED | PASS |

### bgp_indexer
| ID | Operation | Expected | Actual |
|----|-----------|:--:|:--:|
| IDX-01 | SELECT chain_streams | ALLOWED | PASS |
| IDX-02 | INSERT chain_raw_events | ALLOWED | PASS |
| IDX-03 | INSERT chain_blocks | ALLOWED | PASS |
| IDX-04 | DELETE chain_raw_events | DENIED | PASS |
| IDX-05 | INSERT token_balances_current | DENIED | PASS |

### bgp_projector
| ID | Operation | Expected | Actual |
|----|-----------|:--:|:--:|
| PRJ-01 | SELECT chain_raw_events (read-only) | ALLOWED | PASS |
| PRJ-02 | INSERT projection_receipts | ALLOWED | PASS |
| PRJ-03 | UPDATE chain_raw_events | DENIED | PASS |
| PRJ-04 | INSERT chain_raw_events | DENIED | PASS |

### bgp_dividend
| ID | Operation | Expected | Actual |
|----|-----------|:--:|:--:|
| DIV-01 | SELECT dividend_token_balance_history_v1 | ALLOWED | PASS |
| DIV-02 | INSERT dividend_artifacts | ALLOWED | PASS |
| DIV-03 | INSERT dividend_allocations | ALLOWED | PASS |
| DIV-04 | SELECT token_balances_current | DENIED | PASS |
| DIV-05 | UPDATE dividend_epochs.merkle_root | DENIED | PASS |

### bgp_reconciler
| ID | Operation | Expected | Actual |
|----|-----------|:--:|:--:|
| REC-01 | SELECT governance_commands | ALLOWED | PASS |
| REC-02 | UPDATE governance_commands.state | ALLOWED | PASS |
| REC-03 | INSERT governance_commands | DENIED | PASS |
| REC-04 | INSERT signer_nonces | ALLOWED | PASS |
| REC-05 | INSERT governance_tx_attempts | ALLOWED | PASS |

### bgp_auditor
| ID | Operation | Expected | Actual |
|----|-----------|:--:|:--:|
| AUD-01 | SELECT governance_commands | ALLOWED | PASS |
| AUD-02 | SELECT dividend_epochs | ALLOWED | PASS |
| AUD-03 | INSERT governance_commands | DENIED | PASS |
| AUD-04 | UPDATE governance_commands | DENIED | PASS |
| AUD-05 | DELETE governance_commands | DENIED | PASS |

### bgp_readonly
| ID | Operation | Expected | Actual |
|----|-----------|:--:|:--:|
| RO-01 | SELECT token_balances_current | ALLOWED | PASS |
| RO-02 | SELECT trades | ALLOWED | PASS |
| RO-03 | SELECT dividend_epochs | ALLOWED | PASS |
| RO-04 | INSERT any table | DENIED | PASS |
| RO-05 | UPDATE trades | DENIED | PASS |

### bgp_migrator
| ID | Operation | Expected | Actual |
|----|-----------|:--:|:--:|
| MIG-01 | SELECT environments (schema owner) | ALLOWED | PASS |

## 5. STATE_PROTECTION_CHECKS (SP-01~SP-12: 12/12)

All tests executed with appropriate roles via assertion-style helpers (assert_must_fail / assert_must_pass).
Each test validates the trigger-enforced state machine rules. Evidence: machine-readable pipe-delimited format.

| ID | Test | Role | Expected | SQLSTATE | Actual | Verdict |
|----|------|------|:--:|:--:|:--:|:--:|
| SP-01 | CANCELLED Epoch -> DRAFT | bgp_dividend | FAIL | 55000 | FAIL | PASS |
| SP-02 | CLOSED Epoch -> DRAFT | bgp_dividend | FAIL | 55000 | FAIL | PASS |
| SP-03 | CLAIM_OPEN modify merkle_root | bgp_dividend | FAIL | 42501 | FAIL | PASS |
| SP-04 | FINALIZED Command -> QUEUED | bgp_reconciler | FAIL | 55000 | FAIL | PASS |
| SP-05 | CANCELLED Command -> SIGNING | bgp_reconciler | FAIL | 55000 | FAIL | PASS |
| SP-06 | FAILED Command -> APPROVED | bgp_reconciler | FAIL | 55000 | FAIL | PASS |
| SP-07 | QUEUED + pending cancel -> SIGNING | bgp_reconciler | FAIL | 55000 | FAIL | PASS |
| SP-08 | APPROVED + REQUESTED cancel -> REJECTED | bgp_reconciler | FAIL | 55000 | FAIL | PASS |
| SP-09 | REJECTED + REQUESTED cancel -> REJECTED | bgp_reconciler | SUCCESS | — | SUCCESS | PASS |
| SP-10 | CANCELLED + REQUESTED cancel -> CONSUMED | bgp_reconciler | SUCCESS | — | SUCCESS | PASS |
| SP-11 | Historical FAILED command isolation | postgres | SUCCESS | — | SUCCESS | PASS |
| SP-12 | Binding mutation guard (column-level) | bgp_reconciler | FAIL | 42501 | FAIL | PASS |

> **SP-08**: APPROVED command is a cancellable state. Frozen rule: cancellation request REJECTED requires command in non-cancellable state (SIGNING/SUBMITTED/CONFIRMED/FINALIZED/FAILED/EXPIRED/REJECTED). APPROVED is not in that list → FAIL (55000). Trigger matches frozen AC.
> **SP-09**: REJECTED command is a non-cancellable terminal state. Frozen rule (P2-R9-01): `Command=REJECTED → Request=REJECTED = SUCCESS`. Trigger updated to include `REJECTED` in allowed command states for REJECTED resolution → SUCCESS. Trigger matches frozen AC.
> **SP-10**: CANCELLED command → Request=CONSUMED = SUCCESS. Trigger matches frozen AC (P2-R9-01).

### SP Traceability (Assertion-Style)

Each test uses `assert_must_fail_as(test_id, role, expected_sqlstate, operation)`:
- On expected FAIL: RAISE NOTICE with PASS / expected_sqlstate / actual_sqlstate / error message
- On UNEXPECTED SUCCESS: RAISE EXCEPTION with FAIL / UNEXPECTED_SUCCESS
- On WRONG SQLSTATE: RAISE EXCEPTION with FAIL / actual vs expected SQLSTATE mismatch

This is the opposite of fail-open: no silent pass, any deviation from expectations is a hard failure.

## Key Boundary Verifications

| Boundary | Result |
|----------|:--:|
| bgp_reconciler cannot INSERT governance_commands | PASS |
| bgp_dividend cannot SELECT token_balances_current | PASS |
| bgp_dividend cannot UPDATE merkle_root | PASS |
| bgp_projector read-only on chain_raw_events | PASS |
| bgp_auditor/bgp_readonly cannot INSERT/UPDATE/DELETE | PASS |
| 0 role memberships between bgp_* | PASS |
| All roles NO SUPERUSER/CREATEDB/CREATEROLE/BYPASSRLS | PASS |
| 8/8 independent connections: session_user=current_user | PASS |

## Evidence Files

All evidence file SHA-256 hashes are recorded in PAYLOAD_MANIFEST.csv.
Refer to PAYLOAD_MANIFEST.csv.sha256 for integrity verification.

File list: 00_RUNTIME_GATE_STATUS.md, 01_POSTGRESQL_MIGRATION_EVIDENCE.md, 02_ROLE_RUNTIME_MATRIX.md,
../sql/0001_binggoplus_v2_schema.sql, ../sql/0002_binggoplus_v2_runtime_privileges.sql,
rt01_setup_env.sql, rt01_transfer_ownership.sql, rt01_validate_objects.sql,
rt01_permission_tests.sql, rt01_sp_tests.sql, rt01_mutation_test.sql,
rt01_objects_evidence.txt, rt01_permission_evidence.txt, rt01_sp_evidence.txt,
rt01_mutation_evidence.txt

## MUTATION_SAFETY_CHECK

| Check | Result |
|-------|:--:|
| MUT-01 trigger_before = ENABLED | PASS |
| MUT-01 trigger_temporarily_disabled = YES | PASS |
| MUT-01 illegal FINALIZED->QUEUED without guard = SUCCESS | PASS |
| MUT-01 state_verification = QUEUED_CONFIRMED | PASS |
| MUT-01 trigger_restored = YES, trigger_after = ENABLED | PASS |
| MUT_SP04_proof guarded transition blocked = 55000 | PASS |
| MUT-01 mutation_environment_cleaned = YES (rolled back) | PASS |

## Conclusion

```
RT-GATE-01_ROLE_RUNTIME = PASS
All 90 checks passed. 0 violations.
12/12 assertion-style SP tests (not fail-open).
1/1 mutation safety check with independent evidence.
```
