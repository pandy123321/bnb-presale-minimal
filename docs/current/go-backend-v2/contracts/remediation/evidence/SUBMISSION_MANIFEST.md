# S0 Candidate Submission Manifest
| Field | Value |
|---|---|
| Manifest ID | S0_MANIFEST_V3 |
| Created | 2026-08-08T09:00+08:00 |
| Design Agent Session | `7668e4db-0a98-45f6-82a4-19b44b5c54e4` |
| Prior Reviewed Candidate Commit | `ff8d693179fbea11f80ed3e491a41b8054f2693a` |
| Current Candidate Commit | (to be filled after commit — see below) |

## Changed Files (5 only)

| File | SHA-256 |
|---|---|
| `docs/current/go-backend-v2/contracts/remediation/evidence/S0_DESIGN_DECISION_REGISTER.md` | (to be computed after commit) |
| `docs/current/go-backend-v2/contracts/remediation/evidence/S0_ABI_AND_STATE_MACHINE_FREEZE.md` | (to be computed after commit) |
| `docs/current/go-backend-v2/contracts/remediation/evidence/S0_BASELINE_COMPLIANCE_MATRIX.md` | (to be computed after commit) |
| `docs/current/go-backend-v2/contracts/remediation/evidence/S0_INVARIANT_SPECIFICATION.md` | (to be computed after commit) |
| `docs/current/go-backend-v2/contracts/remediation/evidence/S0_STAGE_EVIDENCE.md` | (to be computed after commit) |

## Summary

- 12 mandatory design decisions: ALL FROZEN
- 17 mandatory invariants: frozen
- 1 deferred invariant: REG-INV-02 (NOT_APPLICABLE per D-11)
- 31 mandatory ABI items: frozen
- 5 contract-account ABI items permanently removed
- D-11: EOA-only, user-approved ACCEPTED_DEVIATION, P3-TKN-01 closed via S8+M3
- Oracle: `>=` MAX_TWAP_AGE, 8999/9000/9001 boundary verifiable
- Economic baseline: NO change
- 5 files only (no Solidity, no tests, no scripts)
