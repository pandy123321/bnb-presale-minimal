# Owner Decision — Go Version & Dependency Download Authorization

## Decision Record

| Field | Value |
|---|---|
| DECISION_ID | RT03-OWNER-2026-001 |
| DECISION_TYPE | G1 BOOTSTRAP AUTHORIZATION |
| OWNER_IDENTITY | Project Owner (pandy123321) |
| DECISION_TIMESTAMP | 2026-08-08 |
| SOURCE_CONVERSATION_ID | e9294865-10ed-4d01-9374-c3726a246e49 |
| SOURCE_REFERENCE_GO_VERSION | "Go 精确版本你建议选哪个，按照你的建议选" |
| SOURCE_REFERENCE_DEPENDENCIES | "依赖可以下载" |

## Decision 1: Go Exact Version

| Field | Value |
|---|---|
| PREVIOUS_STATE | UNRESOLVED_VERSION_PIN |
| DECISION | APPROVED |
| APPROVED_GO_VERSION | 1.26.5 |
| GO_VERSION_RELEASE_DATE | 2026-07-07 |
| GO_VERSION_SOURCE | https://go.dev/dl/ (latest stable with security fixes for crypto/tls, os) |
| RATIONALE | Latest stable release as of 2026-08-08; 1.26.x major line; includes security patches |

## Decision 2: Dependency Download Authorization

| Field | Value |
|---|---|
| PREVIOUS_STATE | NO_DOWNLOAD_AUTHORIZED |
| DECISION | APPROVED |
| APPROVE_DOWNLOAD | YES |

### Approved Direct Dependencies (G1 Skeleton)

| Dependency | Version | License | Use Case |
|---|---|---|---|
| github.com/go-chi/chi/v5 | v5.2.1 | MIT | HTTP Router/Middleware |
| github.com/jackc/pgx/v5 | v5.7.4 | MIT | PostgreSQL Driver/Pool |

### Approved Future Dependencies (G2+)

| Dependency | Version | License | Use Case | Note |
|---|---|---|---|---|
| github.com/pressly/goose/v3 | v3.24.2 | Apache-2.0 | SQL Migration CLI | Not yet imported by G1 |
| github.com/ethereum/go-ethereum | v1.15.8 | LGPLv3 | ABI/RPC/binding | G1: ABI only (read-only); full integration pending license review |
| github.com/riverqueue/river | v0.20.0 | MPL-2.0 | PostgreSQL Job queue | Not yet imported by G1; pending file boundary review |
| github.com/prometheus/client_golang | v1.22.0 | Apache-2.0 | Metrics exporter | Not yet imported by G1 |
| github.com/google/uuid | v1.6.0 | BSD-3 | Application UUID | Not yet imported by G1 |
| go.opentelemetry.io/otel | v1.36.0 | Apache-2.0 | Tracing interface | Not yet imported by G1 |

### License Risk Acknowledgement

- `go-ethereum` (LGPLv3): ABI JSON reading only in G1. Full EVM client integration requires separate legal review before G2.
- `river` (MPL-2.0): File boundary review required before G2 integration.
- Owner accepts these risks for G1 skeleton phase. G2 entry blocked until formal license signoff.

## Decision 3: G1 Entry Authorization

| Field | Value |
|---|---|
| G0_STATUS | COMPLETE (RT-GATE-01 PASS + RT-GATE-02 Owner Signoff) |
| FROZEN_FOR_DEVELOPMENT | YES |
| G1_ENTRY_ALLOWED | YES |
| G1_SCOPE | Skeleton only — no business logic, no chain write, no business SQL |

## G1 Entry Conditions

G1 must remain skeleton-only:
- NO Trade/Dividend/Governance/Staking business logic
- NO eth_sendRawTransaction or signer
- NO business SELECT/INSERT/UPDATE/DELETE
- NO Mainnet (chain 56) access
- NO Indexer/Projector/Reconciler scan loops

## Binding

This decision is binding for:
- RT-GATE-03 Go Build Stage Definition
- G1 Skeleton Bootstrap
- Go 1.26.5 version pin
- G1 dependency download authorization

| Bind | Value |
|---|---|
| Manifest SHA | bound in RT03_PAYLOAD_MANIFEST.csv (OWNER_DECISION_V2.md) |
| External binding | RT03_PAYLOAD_MANIFEST.csv → RT03_PAYLOAD_MANIFEST.csv.sha256 |

Note: This file is externally bound by the RT03 stage Manifest. Internal self-hash is intentionally omitted. See RT03_PAYLOAD_MANIFEST.csv for actual SHA binding.
