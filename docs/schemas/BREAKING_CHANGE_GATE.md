# PANGU2 — Breaking Change Gate

> Version: 1.0.0  
> Project: PANGU2  
> Effective: 2026-08-02  
> Owner: Shared Schema (P2-X03)

## Purpose

This document defines what constitutes a **breaking change** to the PANGU2 API contract, and what does not.
It is enforced by CI and serves as the canonical reference for all contributors.

## Gate Mechanism

1. Every PR that touches `docs/schemas/openapi/pangu2-api-v1.yaml` triggers a **Breaking Change Gate**.
2. The gate compares the modified YAML against the baseline (`main` branch).
3. If any breaking change is detected:
   - **WARNING** in the PR if the PR author acknowledges it with `BREAKING: <reason>` in the commit message.
   - **FAIL** in CI if no acknowledgement is present.
4. The gate output is a machine-readable JSON report written to `docs/evidence/PB-S0/P2-X03/breaking-change-{timestamp}.json`.

## Breaking Changes (CI FAILS)

### 1. Field Removals
- **Deleting** a field from any request or response schema.
- Example: removing `cost_basis` from `WalletSummary`.

### 2. Field Type Changes
- Changing a field's type in a way that breaks existing consumers.
- **BREAKING** type changes:
  - `string` → `integer`
  - `integer` → `string`
  - `string` → `object`
  - `object` → `string`
  - `array` → `object`
  - Adding `nullable: true` → removing it (was nullable, now required)
- **NOT breaking** if the change is non-breaking (see below).

### 3. Enum Value Removals or Renames
- Removing any value from an enum.
- Renaming an enum value (this is effectively a delete + add).
- Example: removing `DROPPED` from `TransactionStatus`.
- **NOT breaking**: adding new enum values (see below).

### 4. Required Field Additions
- Adding `required: [new_field]` where previously the field was optional.
- Example: adding `wallet_address` as required to the `/quotes/sell` request body.

### 5. URL Path Changes
- Changing the path of any endpoint.
- Example: `/projects/pangu2/quotes/buy` → `/projects/pangu2/trade/buy-quote`.

### 6. HTTP Method Changes
- Changing the HTTP method of any endpoint.
- Example: `POST /auth/nonce` → `GET /auth/nonce`.

### 7. Semantic Changes
- Changing the business meaning or calculation rule of a field without changing its type.
- Example: `balance_token_raw` previously returned "total balance" but now returns "available balance".
- **Detection**: requires human review. The gate flags any `description` changes in production schemas.

### 8. Schema Version Bumping
- Changing `info.version` in the OpenAPI YAML from `1.0.0` to any other value.
- The version is frozen at `1.0.0` during Phase 1/2 development.
- A version change requires a formal decision record.

## Non-Breaking Changes (CI PASSES)

### 1. Adding Optional Fields
- Adding a new field to a response schema that is **NOT** listed in `required`.
- All consumers must be designed to ignore unknown fields.

### 2. Adding New Enum Values
- Adding a new value to an existing enum.
- Existing code that only handles specific enum values continues to work.

### 3. Adding New Endpoints
- Any new `path` entry that does not modify existing endpoints.

### 4. Adding New Schemas
- Any new `#/components/schemas/` entry.

### 5. Description / Example Changes
- Changing `description`, `example`, or `summary` fields.

### 6. Adding `pattern` Constraints
- Adding a regex `pattern` to a field that already matches it.

### 7. Relaxing `required`
- Moving a field from `required` to optional.

## CI Enforcement

### GitHub Actions Configuration

```yaml
name: Schema Breaking Change Gate

on:
  pull_request:
    paths:
      - "docs/schemas/**"

jobs:
  check-breaking:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # need full history for diff
      - uses: actions/setup-node@v4
        with:
          node-version: 22
      - run: |
          cd packages/schema-validator
          npm install
          npx tsx src/check-breaking-changes.ts ${{ github.event.pull_request.base.sha }}
```

### Local Pre-Check

```bash
cd packages/schema-validator
npm install
npx tsx src/check-breaking-changes.ts main
```

Compares current working tree's `pangu2-api-v1.yaml` against `main` branch.

## Acknowledgements

If a breaking change is intentional (e.g., Phase 3 restructure), the commit message MUST contain:

```
BREAKING: <description of change and why it's necessary>
```

Example:
```
BREAKING: Remove cost_basis from WalletSummary — replaced by on-chain previewCostBasis in PB-S1
```

The CI gate will read the commit message. If `BREAKING:` is present, it emits a **WARNING** instead of a **FAILURE**, and records the acknowledgement in the evidence report.

## Related Documents

- `docs/schemas/openapi/pangu2-api-v1.yaml` — the API contract
- `docs/schemas/errors/pangu2-errors-v1.json` — error code catalog
- `docs/schemas/state-machines/pangu2-state-machines-v1.json` — state machine definitions
- `packages/api-types/` — TypeScript types generated from the OpenAPI spec
- `docs/evidence/PB-S0/P2-X03/` — evidence reports from this task
