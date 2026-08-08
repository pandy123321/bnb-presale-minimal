# S0 Candidate Submission Manifest

| Field | Value |
|---|---|
| Manifest ID | `S0_MANIFEST_V3` |
| Created | 2026-08-08T09:15+08:00 |
| Design Agent Session | `7668e4db-0a98-45f6-82a4-19b44b5c54e4` |
| Prior Reviewed Candidate Commit | `ff8d693179fbea11f80ed3e491a41b8054f2693a` |

## This Commit Changed Files (3)

| # | File | Type |
|---|---|---|
| 1 | `docs/current/go-backend-v2/contracts/remediation/evidence/S0_DESIGN_DECISION_REGISTER.md` | M |
| 2 | `docs/current/go-backend-v2/contracts/remediation/evidence/S0_STAGE_EVIDENCE.md` | M |
| 3 | `docs/current/go-backend-v2/contracts/remediation/evidence/SUBMISSION_MANIFEST.md` | M |

## Complete S0 Candidate Evidence Set (5 core documents)

These 5 files constitute the full S0 design freeze. Their SHA-256 values are:

| # | File | SHA-256 |
|---|---|---|
| 1 | `S0_DESIGN_DECISION_REGISTER.md` | `5AF0305B3893B633E51F91779FFC858D21C745BE0116517D2E6D8D1CD1D447CC` |
| 2 | `S0_ABI_AND_STATE_MACHINE_FREEZE.md` | `0E5D35E4DEA1F505D373733AFD8529B3CB9868174F5E1172201156D93F1F39C8` |
| 3 | `S0_BASELINE_COMPLIANCE_MATRIX.md` | `A1A354A4AFE584521AD7E78EE82F971D591012F68BECF8EC440272FAD91BB2F0` |
| 4 | `S0_INVARIANT_SPECIFICATION.md` | `0AA09EA9024B24729FAB7154DF29017CF46860D080438E9F5313C9966CC3B0D7` |
| 5 | `S0_STAGE_EVIDENCE.md` | `D86822D5F2600193C3C34D722EABB4F09937C57D4251781B434BC50AD5175626` |

## Submission Metadata

| # | File | Type |
|---|---|---|
| 1 | `SUBMISSION_MANIFEST.md` | This file (metadata, not part of evidence set) |

**Note**: The current Git Commit SHA must be bound externally after commit creation. Do NOT attempt to write the commit SHA back into this file (Git SHA self-reference cycle). The commit SHA should be recorded in the external submission envelope/message.

## Summary

- 12 mandatory design decisions: ALL FROZEN
- 17 mandatory invariants: frozen
- 1 deferred invariant: REG-INV-02 (NOT_APPLICABLE per D-11)
- 31 mandatory ABI items: frozen
- D-11: EOA-only, user directive approved, ACCEPTED_DEVIATION, P3-TKN-01 PENDING_S8_CLOSURE
- Oracle: `>=` MAX_TWAP_AGE, 8999/9000/9001 boundary verifiable
- Economic baseline: NO change
- Role separation: Design Agent confirmed; Adjudication Agent NOT YET ASSIGNED
- Solidity: NONE modified
