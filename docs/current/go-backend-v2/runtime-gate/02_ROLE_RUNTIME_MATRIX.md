# RT-GATE-01 Role Runtime Permission Validation Matrix

## Status

```text
RT-GATE-01_ROLE_RUNTIME = PASS (FIX_READY)
```

**Evidence Timestamp**: 2026-08-08T12:00+08:00
**PostgreSQL**: 16.14 (Docker postgres:16-alpine, container bgp-pg16:5433)

## Test Result Summary (Unified Counts)

| Category | Count | Result |
|----------|------:|:--:|
| ROLE_IDENTITY_CHECKS | 8/8 | PASS |
| CLUSTER_PRIVILEGE_CHECKS | 32/32 | PASS |
| ROLE_INHERITANCE_CHECKS | 1/1 | PASS |
| PERMISSION_BOUNDARY_CHECKS | 36/36 | PASS |
| STATE_PROTECTION_CHECKS (SP-01~SP-11) | 11/11 | PASS |
| **TOTAL** | **88/88** | **PASS** |

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

## 5. STATE_PROTECTION_CHECKS (SP-01~SP-11: 11/11)

All tests executed with appropriate roles (bgp_dividend for epoch transitions, bgp_reconciler for command transitions).

| ID | Test | Role | Expected | Actual |
|----|------|------|:--:|:--:|
| SP-01 | CANCELLED Epoch -> DRAFT | bgp_dividend | FAIL | PASS |
| SP-02 | CLOSED Epoch -> DRAFT | bgp_dividend | FAIL | PASS |
| SP-03 | CLAIM_OPEN modify merkle_root | bgp_dividend | FAIL | PASS |
| SP-04 | FINALIZED Command -> QUEUED | bgp_reconciler | FAIL | PASS |
| SP-05 | CANCELLED Command -> SIGNING | bgp_reconciler | FAIL | PASS |
| SP-06 | FAILED Command -> APPROVED | bgp_reconciler | FAIL | PASS |
| SP-07 | APPROVED + REQUESTED cancel -> SIGNING | bgp_reconciler | FAIL | PASS |
| SP-08 | APPROVED + REQUESTED cancel -> CONSUMED | bgp_reconciler | SUCCESS | PASS |
| SP-09 | REJECTED + REQUESTED cancel -> REJECTED | bgp_reconciler | SUCCESS | PASS |
| SP-10 | CANCELLED + REQUESTED cancel -> CONSUMED | bgp_reconciler | SUCCESS | PASS |
| SP-11 | Binding mutation guard (target_contract_key) | bgp_reconciler | FAIL | PASS |

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

| File | SHA-256 |
|------|---------|
| rt01_objects_evidence.txt | 3747F72E... |
| rt01_permission_evidence.txt | BEA595F7... |
| rt01_permission_tests.sql | 9AC9F2A7... |
| rt01_sp_tests.sql | 66D228A3... |
| rt01_sp_evidence.txt | 0613217A... |
| PAYLOAD_MANIFEST.csv | 56272288... |
| PAYLOAD_MANIFEST.csv.sha256 | (external) |

## Conclusion

```
RT-GATE-01_ROLE_RUNTIME = PASS (FIX_READY, INDEPENDENT_RETEST_PENDING)
All 88 checks passed. 0 violations.
```
