# Runtime Gate Status

> `HISTORICAL_PANGU2_GO_V2_RUNTIME_GATE`：本文件保留原 G0/G1/G2 Runtime Gate 证据和未关闭项，不得改写为已通过。2026-08-09 后当前产品阶段为 `FLAP-F0`，以 [../27_FLAP_PRODUCT_PIVOT_DECISION.md](../27_FLAP_PRODUCT_PIVOT_DECISION.md) 和 [../30_FLAP_F0_F10_EXECUTION_PLAN.md](../30_FLAP_F0_F10_EXECUTION_PLAN.md) 为准。本文件不授权旧 G2 继续开发，也不阻止读取其风险作为新架构输入。

| Gate | Status |
|---|---|
| RT-GATE-01 | PASS |
| RT-GATE-02 | BLOCKED_EVIDENCE / INDEPENDENT_RETEST_PENDING |
| RT-GATE-03 | FIX_READY / INDEPENDENT_RETEST_PENDING |

## RT-GATE-02 — BLOCKED_EVIDENCE / INDEPENDENT_RETEST_PENDING

| Field | Value |
|---|---|
| OWNER_SECURITY_DECISION | RT02-OWNER-2026-001 (OWNER_SECURITY_DECISION.md) |
| P1-RT02-14 DISPOSITION | OWNER_ACCEPTED_ENVIRONMENTAL_LIMITATION (RT02-OWNER-2026-002) |
| TECHNICAL_GATE_PASS | NO — Runtime Evidence = BLOCKED_EVIDENCE (EXIT_CODE=1) |
| OWNER_RISK_ACCEPTANCE | YES — Owner accepts environmental limitation, does NOT claim technical fix |
| RUNTIME_RETEST | PENDING/BLOCKED — approved Binance RPC unreachable in sandbox |
| EXTERNAL_REVIEW | FIX_READY — pending Independent Review |
| RPC_INDEPENDENCE | PRIMARY != BACKUP enforced in script |
| DEPLOY_BLOCK_SOURCE | TRANSACTION_RECEIPT |
| BYTECODE_IDENTITY | 10/10 VERIFIED |
| GETTER | 14/14 PASS |
| ROLE | 8/8 PASS (Expected=False, Owner Decision bound) |
| MANIFEST | RT02_FINAL_PAYLOAD_MANIFEST.csv (byte-exact binding pending regeneration) |

### Owner Risk Acceptance (NOT Technical PASS)

RT02-OWNER-2026-002 (`OWNER_DECISION_P1_RT02_14.md`) records Owner acceptance of P1-RT02-14 as an environmental limitation. This acceptance:

- DOES authorize closing P1-RT02-14 as a code defect
- DOES NOT replace Runtime Evidence with PASS
- DOES NOT claim the new PRIMARY!=BACKUP script has been executed and passed in the sandbox
- DOES NOT supersede the requirement for dual-RPC Runtime Retest in an environment that can reach approved Binance RPCs

Current Runtime Evidence (`rt02_raw_evidence.txt`):

```
STATUS=BLOCKED_EVIDENCE
REASON=Approved RPC endpoints unreachable
RESULT=RPC_FAILED_AFTER_RETRY
EXIT_CODE=1
```

### Closed Findings

| Finding | Status | Disposition |
|---|---|---|
| P1-RT02-14 | BLOCKED_EVIDENCE (Owner-accepted environmental limit) | RT02-OWNER-2026-002 |
| P2-RT02-MANIFEST-03 | FIX_REQUIRED (Manifest stale after db85f534) | Pending regeneration |
| P2-RT02-OWNER-HASH | CLOSED (self-hash removed) | External binding only |

## RT-GATE-03 — FIX_READY / INDEPENDENT_RETEST_PENDING

| Field | Value |
|---|---|
| DECISION_REF | 05_GO_BUILD_STAGE_DECISION.md (FIX_READY / INDEPENDENT_RETEST_PENDING) |
| OWNER_DECISION | OWNER_DECISION_V2.md (RT03-OWNER-2026-001) |
| GO_VERSION | 1.26.5 (Owner Decision) |
| DEPENDENCY_DOWNLOAD | APPROVED |
| GO_MOD_TIDY | PASS (exit 0) |
| GO_BUILD ./... | PASS (exit 0) |
| GO_VET ./... | PASS (exit 0) |
| BUILD_EVIDENCE | rt03_build_evidence.txt |
| MANIFEST | RT03_PAYLOAD_MANIFEST.csv (3 files) |
| INDEPENDENT_REVIEW | PENDING |
| G1_COMPLETE | NO — Independent Review + negative tests pending |

### G1 Negative Tests (PENDING)

| Test | Status | Condition |
|---|---|---|
| missing DB config → fail closed | NOT_RUN | Requires isolated PostgreSQL |
| DB unavailable → /health/ready not ready | NOT_RUN | Requires isolated PostgreSQL |
| DB unavailable → /health/live still alive | NOT_RUN | Requires isolated PostgreSQL |
| graceful shutdown → clean exit | NOT_RUN | Requires process supervision |
| chain 56 config → reject (Mainnet NO-GO) | NOT_RUN | Safety redline — must PASS before G2 |

These tests cannot be marked COMPLETE by deletion. They remain NOT_RUN until executed with evidence.

### License Gates (BLOCKED for G2)

Per `OWNER_DECISION_V2.md` (RT03-OWNER-2026-001):

| Dependency | License | Status |
|---|---|---|
| go-ethereum | LGPLv3 | G1: ABI only (read-only). Full integration requires separate legal review before G2. |
| river | MPL-2.0 | File boundary review required before G2 integration. |

G2 entry blocked until formal license signoff for both dependencies.

## Stage Authorization

| Field | Value |
|---|---|
| G0 COMPLETE | YES |
| FROZEN_FOR_DEVELOPMENT | YES |
| G1 ENTRY AUTHORIZED | YES (skeleton only) |
| G1_COMPLETE | NO (Independent Review + negative tests + license gates unresolved) |
| G2 ENTRY AUTHORIZED | NO |
| NEXT_STAGE_AUTHORIZATION | NO |

G2 entry conditions (all required):
1. G1 Independent Review APPROVED
2. G1 negative tests executed (or formally deferred with evidence)
3. go-ethereum formal license signoff
4. river MPL-2.0 file-boundary disposition
5. RT02 dual-RPC Runtime Retest with EXIT_CODE=0 (or Owner formally waives Runtime Gate as governance rule change)
6. All Decision / Status / Manifest files cross-consistent
7. Independent Review confirms G2 authorization

## Current Execution Hold

```
CURRENT_STAGE = G0 → G1 transition
G1_ENTRY_AUTHORIZED = YES (skeleton only)
G2_ENTRY_AUTHORIZED = NO
AUTO_ADVANCE = PAUSED
```

G0/G1 通过结论保持不变。G2 的实现开发在 license gates、Independent Review、和 RT02 Runtime Retest 关闭之前不会开始。
