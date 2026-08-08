# RT-GATE-01 Role Runtime Permission Validation Matrix

## Status

```text
RT-GATE-01_ROLE_RUNTIME = PASS
```

**Evidence Timestamp**: 2026-08-08T11:35+08:00

## Environment

| Item | Value |
|------|-------|
| PostgreSQL Version | 16.14 (Alpine, x86_64-pc-linux-musl) |
| Docker Image | postgres:16-alpine |
| Container | bgp-pg16 (port 5433) |
| Database | binggoplus_go |
| Schema | binggoplus_v2 |
| Migration Role | bgp_migrator |

## Cluster Privilege Verification

All 8 roles: NO SUPERUSER, NO CREATEDB, NO CREATEROLE, NO BYPASSRLS.

| Role | superuser | createdb | createrole | bypassrls |
|------|:--:|:--:|:--:|:--:|
| bgp_api | f | f | f | f |
| bgp_indexer | f | f | f | f |
| bgp_projector | f | f | f | f |
| bgp_dividend | f | f | f | f |
| bgp_reconciler | f | f | f | f |
| bgp_auditor | f | f | f | f |
| bgp_readonly | f | f | f | f |
| bgp_migrator | f | f | f | f |

## Role Inheritance Check

No role memberships between any bgp_* roles. bgp_migrator NOT inherited by any runtime role.

## Permission Boundary Matrix

### bgp_api
1. SELECT environments: ALLOWED
2. INSERT admin_audit_logs: ALLOWED
3. INSERT governance_commands: ALLOWED
4. INSERT chain_raw_events: DENIED (EXPECTED)
5. INSERT signer_nonces: DENIED (EXPECTED)

### bgp_indexer
6. SELECT chain_streams: ALLOWED
7. INSERT chain_raw_events: ALLOWED
8. INSERT chain_blocks: ALLOWED
9. DELETE chain_raw_events: DENIED (EXPECTED)
10. INSERT token_balances_current: DENIED (EXPECTED)

### bgp_projector
11. SELECT chain_raw_events: ALLOWED (read-only)
12. INSERT projection_receipts: ALLOWED
13. UPDATE chain_raw_events: DENIED (EXPECTED)
14. INSERT chain_raw_events: DENIED (EXPECTED)

### bgp_dividend
15. SELECT dividend_token_balance_history_v1: ALLOWED
16. INSERT dividend_artifacts: ALLOWED
17. INSERT dividend_allocations: ALLOWED
18. SELECT token_balances_current: DENIED (EXPECTED)
19. UPDATE dividend_epochs.merkle_root: DENIED (EXPECTED)

### bgp_reconciler
20. SELECT governance_commands: ALLOWED
21. UPDATE governance_commands.state: ALLOWED
22. INSERT governance_commands: DENIED (EXPECTED - API intake only)
23. INSERT signer_nonces: ALLOWED
24. INSERT governance_tx_attempts: ALLOWED

### bgp_auditor
25. SELECT governance_commands: ALLOWED
26. SELECT dividend_epochs: ALLOWED
27. INSERT governance_commands: DENIED (EXPECTED)
28. UPDATE governance_commands: DENIED (EXPECTED)
29. DELETE governance_commands: DENIED (EXPECTED)

### bgp_readonly
30. SELECT token_balances_current: ALLOWED
31. SELECT trades: ALLOWED
32. SELECT dividend_epochs: ALLOWED
33. INSERT any table: DENIED (EXPECTED)
34. UPDATE trades: DENIED (EXPECTED)
35. DELETE dividend_epochs: DENIED (EXPECTED)

### bgp_migrator
36. SELECT environments: ALLOWED (schema owner)

## Key Boundary Verifications

| Boundary | Result |
|----------|:--:|
| bgp_reconciler cannot INSERT governance_commands | PASS |
| bgp_dividend cannot SELECT token_balances_current | PASS |
| bgp_dividend cannot UPDATE dividend_epochs.merkle_root | PASS |
| bgp_projector read-only on chain_raw_events | PASS |
| bgp_auditor cannot INSERT/UPDATE/DELETE | PASS |
| bgp_readonly cannot INSERT/UPDATE/DELETE | PASS |
| 0 role memberships between bgp_* | PASS |
| All roles NO SUPERUSER | PASS |
| All roles NO CREATEDB/CREATEROLE/BYPASSRLS | PASS |

## Conclusion

RT-GATE-01_ROLE_RUNTIME = PASS
All 36 permission checks returned expected results. 0 violations.
