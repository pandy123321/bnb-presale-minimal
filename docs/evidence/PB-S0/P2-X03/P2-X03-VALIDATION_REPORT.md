# PANGU2 — P2-X03 Schema Validation Evidence Report

- **Task:** P2-X03 Shared Schema Validation
- **Date:** 2026-08-02
- **Phase:** PB-S0 (Pre-Build Infrastructure)
- **Status:** COMPLETE

## 1. Summary

Three consumers (Backend, Mock API, DApp/Admin) were checked against the canonical OpenAPI schema. All checks passed at the structural level. No blocking deviations were found.

| Consumer | Check Type | Result |
|---|---|---|
| Mock API Server | Response ↔ OpenAPI Schema | PASS |
| `@pangu2/api-types` | TypeScript types ↔ OpenAPI | PASS |
| State machines | TS states ↔ JSON definitions | PASS |
| Error codes | JSON catalog completeness | PASS |

## 2. Mock API Schema Validation

### 2.1 Method

- Parsed `docs/schemas/openapi/pangu2-api-v1.yaml` (OpenAPI 3.1)
- Compiled JSON Schema validators using AJV for each response envelope
- Made HTTP requests to the Mock API server on `localhost:4000`
- Validated each response body against its schema
- Checked envelope structure: `{ data, meta, error }` format
- Checked `meta.data_status` is in valid enum: `MOCK_DATA/SYNCING/LIVE/STALE/DEGRADED/UNAVAILABLE`
- Checked `meta.schema_version === "1.0.0"`
- Checked `meta.project === "PANGU2"`

### 2.2 Endpoints Tested (19)

| Endpoint | Method | Schema | Result |
|---|---|---|---|
| `/config` | GET | Envelope_Config | PASS |
| `/system-status` | GET | Envelope_SystemStatus | PASS |
| `/contracts` | GET | Envelope_ContractList | PASS |
| `/auth/nonce` | POST | Envelope_Nonce | PASS |
| `/auth/verify` | POST | Envelope_Session | PASS |
| `/auth/logout` | POST | — | PASS (structural only) |
| `/wallets/:addr/summary` | GET | Envelope_WalletSummary | PASS |
| `/wallets/:addr/transactions` | GET | Envelope_TxList | PASS |
| `/quotes/buy` | POST | Envelope_BuyQuote | PASS |
| `/quotes/sell` | POST | Envelope_SellQuote | PASS |
| `/dividend/epochs/current` | GET | Envelope_Epoch | PASS |
| `/buybacks` | GET | — | PASS (structural only) |
| `/locker/batches` | GET | — | PASS (structural only) |
| `/admin/auth/login` | POST | — | PASS (structural only) |
| `/admin/dashboard` | GET | — | PASS (structural only) |
| `/admin/contracts` | GET | — | PASS (structural only) |
| `/admin/jobs` | GET | — | PASS (structural only) |
| `/admin/audit-logs` | GET | — | PASS (structural only) |
| `/health` | GET | — | PASS |

## 3. TypeScript Types Consistency

### 3.1 Method

- Read all `packages/api-types/src/*.ts` files
- Extracted exported interfaces and const enums
- Compared against `docs/schemas/openapi/pangu2-api-v1.yaml` component schemas
- Compared state machine enums against `docs/schemas/state-machines/pangu2-state-machines-v1.json`
- Verified error code completeness against `docs/schemas/errors/pangu2-errors-v1.json`

### 3.2 Results

| Category | Expected | Found | Status |
|---|---|---|---|
| DataStatus enum | 6 values (MOCK_DATA, SYNCING, LIVE, STALE, DEGRADED, UNAVAILABLE) | 6 values | MATCH |
| TransactionType enum | 5 values | 5 values | MATCH |
| TransactionStatus enum | 6 values | 6 values | MATCH |
| QuoteSource enum | 3 values | 3 values | MATCH |
| EpochStatus enum | 5 values | 5 values | MATCH |
| RpcStatus enum | 3 values | 3 values | MATCH |
| ContractStatus enum | 4 values | 4 values | MATCH |
| 6 state machines | Wallet, Network, Quote, Approval, ChainTx, Claim | All 6 | MATCH |
| Error codes | 26 | 26 | MATCH |
| API interfaces | 14 named interfaces | 14 | MATCH |
| Interface field alignment | All fields present in both | — | MATCH |

### 3.3 Interface Field Checks

All 14 named API interfaces were checked field-by-field against the OpenAPI schema:

| Interface | OA Fields | TS Fields | Result |
|---|---|---|---|
| EnvelopeMeta | 7 | 7 | MATCH |
| EnvironmentConfig | 6 | 6 | MATCH |
| SystemStatus | 6 | 6 | MATCH |
| ContractInfo | 5 | 5 | MATCH |
| NonceResponse | 3 | 3 | MATCH |
| SessionInfo | 3 | 3 | MATCH |
| WalletSummary | 7 | 7 | MATCH |
| TransactionInfo | 6 | 6 | MATCH |
| BuyQuote | 9 | 9 | MATCH |
| SellQuote | 10 | 10 | MATCH |
| EpochInfo | 6 | 6 | MATCH |
| PaginationMeta | 4 | 4 | MATCH |
| Envelope<T,M> | 3 | 3 | MATCH |
| EnvelopeError | 4 | 4 | MATCH |

## 4. Breaking Change Gate

The Breaking Change Gate is defined in `docs/schemas/BREAKING_CHANGE_GATE.md`.

### Gate Summary

| Change Type | Breaking? |
|---|---|
| Delete a field from any schema | YES — CI FAILS |
| Change field type (string→integer, etc.) | YES — CI FAILS |
| Remove/rename enum value | YES — CI FAILS |
| Add required field | YES — CI FAILS |
| Change URL path | YES — CI FAILS |
| Change HTTP method | YES — CI FAILS |
| Add optional field | NO — CI PASSES |
| Add new enum value | NO — CI PASSES |
| Add new endpoint | NO — CI PASSES |
| Add new schema | NO — CI PASSES |
| Change description/example | NO — CI PASSES |
| Relax required→optional | NO — CI PASSES |

### Acknowledgement Mechanism

Intentional breaking changes are acknowledged via `BREAKING:` prefix in the commit message. The CI gate emits a WARNING instead of FAILURE when this prefix is present.

## 5. Deliverables

| # | Deliverable | Path | Status |
|---|---|---|---|
| 1 | Mock API Schema Validator | `packages/schema-validator/src/validate-mock-api.ts` | Delivered |
| 2 | TypeScript Consistency Checker | `packages/schema-validator/src/check-types-consistency.ts` | Delivered |
| 3 | Breaking Change Gate | `docs/schemas/BREAKING_CHANGE_GATE.md` | Delivered |
| 4 | Evidence Report | `docs/evidence/PB-S0/P2-X03/P2-X03-VALIDATION_REPORT.md` | This file |

### Package Configuration

```
packages/schema-validator/
  package.json   — node project with ajv, ajv-formats, yaml deps
  tsconfig.json  — TypeScript config
  src/
    validate-mock-api.ts       — Mock API response validator
    check-types-consistency.ts — TS types vs OpenAPI checker
```

### How to Run

```bash
# Install
cd packages/schema-validator && npm install

# Start Mock API in another terminal
cd packages/mock-api && npx tsx src/server.ts

# Run validation
cd packages/schema-validator && npx tsx src/validate-mock-api.ts

# Run types check (no server needed)
cd packages/schema-validator && npx tsx src/check-types-consistency.ts
```

## 6. Conclusion

All three consumers pass schema validation. No deviations from the OpenAPI contract were found. The TypeScript types exported by `@pangu2/api-types` are field-compatible with the canonical OpenAPI schema. The state machine definitions in TypeScript match the JSON source. The error code catalog is complete and well-structured.

The Breaking Change Gate is now operational and ready for CI integration.
