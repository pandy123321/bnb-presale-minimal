# RT-GATE-01 PostgreSQL Migration Evidence

## Status

```text
RT-GATE-01_MIGRATION = PASS
```

**Evidence Timestamp**: 2026-08-08T14:50+08:00 (Fix Cycle 5, clean rebuild)

## Source Binding

```text
SOURCE_COMMIT = 12a26768fd05208a16184b36be010fbd7992efa6
0001_SHA256 = (see PAYLOAD_MANIFEST.csv for exact hash)
0002_SHA256 = (see PAYLOAD_MANIFEST.csv for exact hash)
```

Both `0001_binggoplus_v2_schema.sql` and `0002_binggoplus_v2_runtime_privileges.sql`
are from this commit and included in PAYLOAD_MANIFEST.csv for revision binding.

## Environment

| Item | Value |
|------|-------|
| PostgreSQL Version | 16.14 (Alpine, x86_64-pc-linux-musl) |
| Docker Container | bgp-pg16 |
| Database | binggoplus_go |
| Schema | binggoplus_v2 |
| Migration User | bgp_migrator |
| SQL Files | 0001_binggoplus_v2_schema.sql, 0002_binggoplus_v2_runtime_privileges.sql |
| Migration Exit Code | 0 (both files) |
| Migration Errors | 0 |

## Schema Object Inventory

| Object Type | Count |
|-------------|------:|
| Tables | 44 |
| Views (security_barrier) | 4 |
| Functions | 9 |
| Triggers | 11 |
| Constraints (CK+FK+PK+UQ) | 262 |
| Sequences | 0 |

## Views (Security-Barrier)

1. dividend_finalized_blocks_v1
2. dividend_projection_coverage_v1
3. dividend_staking_history_v1
4. dividend_token_balance_history_v1

## Functions

1. bind_current_dividend_publish_command (trigger, 3 args)
2. enforce_dividend_epoch_writer_boundary (trigger)
3. enforce_dividend_snapshot_block (trigger)
4. enforce_governance_command_cancellation_request_boundary (trigger)
5. enforce_governance_command_state_transition (trigger)
6. reject_admin_audit_log_mutation (trigger)
7. reject_dividend_evidence_mutation (trigger)
8. reject_governance_command_binding_mutation (trigger)
9. reject_projection_receipt_identity_mutation (trigger)

## Triggers (All Enabled)

1. admin_audit_logs_append_only
2. dividend_allocations_append_only
3. dividend_approvals_append_only
4. dividend_artifacts_append_only
5. dividend_epochs_snapshot_block_guard
6. dividend_epochs_writer_boundary
7. dividend_publish_preflights_append_only
8. governance_command_cancellation_requests_boundary
9. governance_commands_binding_guard
10. governance_commands_state_transition_guard
11. projection_receipts_identity_guard

## Migration Execution Log

File: 0001_binggoplus_v2_schema.sql
Result: COMMIT (all DDL executed without errors)

Key DDL operations:
- CREATE SCHEMA binggoplus_v2
- CREATE DOMAIN evm_address, evm_hash, uint256_numeric, bps_value
- CREATE TABLE environments, deployment_sets, contract_instances (and 41 more)
- CREATE VIEW dividend_finalized_blocks_v1, dividend_projection_coverage_v1, dividend_staking_history_v1, dividend_token_balance_history_v1
- CREATE FUNCTION (9 functions)
- CREATE TRIGGER (11 triggers)
- CREATE INDEX (multiple unique/partial indexes)
- ALTER TABLE (FK additions)

File: 0002_binggoplus_v2_runtime_privileges.sql
Result: COMMIT

Key DCL operations:
- DO block: verified current_user = bgp_migrator
- DO block: verified 7 runtime roles exist
- DO block: verified no runtime role has superuser/createrole/createdb/bypassrls
- DO block: verified no runtime role inherits bgp_migrator
- REVOKE ALL from PUBLIC on schema/tables/functions
- REVOKE ALL from runtime roles
- GRANT USAGE on schema to 7 runtime roles
- GRANT table/column privileges per role specification
- ALTER DEFAULT PRIVILEGES

## Evidence Source Files

- rt01_objects_evidence.txt - Full pg_tables/pg_views/pg_proc/pg_trigger/pg_constraint dump
- rt01_permission_evidence.txt - Full permission test output
- rt01_permission_tests.sql - Reproducible test script
- rt01_setup_env.sql - Environment bootstrap script
