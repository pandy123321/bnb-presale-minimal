# TASK-20260805-001 — DApp V7.1 Refactor — Acceptance

## Status: COMPLETED (all 5 phases + FIX-01~07 safety fixes)

## Phase 1: Infrastructure ✅
## Phase 2: Home Page ✅
## Phase 3: Trade Page ✅
## Phase 4: Portfolio Page ✅
## Phase 5: Cleanup ✅

## Post-Completion Fixes (FIX-01~07)
- ✅ FIX-01: false positive verification (duplicate chainId removed, deployed addresses aligned, apiLogin throttle added)
- ✅ FIX-02: CSS tokens unified (global.css vars merged into tokens.css)
- ✅ FIX-03: Chain Worker extended to 6 event streams
- ✅ FIX-04: CSS var cleanup, unused imports, button type="button"
- ✅ FIX-05: Session encrypt true, env() to config()
- ✅ FIX-06: TransactionProjector firstOrCreate, DB-driven buildTiers
- ✅ FIX-07: Admin CSRF-protected adminFetch unification

## Governance Panel (GE-A01~A04)
- ✅ GE-A01: Contract Registry CRUD + resync
- ✅ GE-A02: Governance read-only 6 endpoints (eth_call)
- ✅ GE-A03: Auth middleware on 6 admin routes
- ✅ GE-A04: Governance write 6 endpoints (eth_sendRawTransaction + ECDSA)

## Known Remaining
- QuoteService still mock/UNAVAILABLE
- Staking fundRewards/setRewardRate → 501
- DApp views not wired to data layer (all `—` placeholders)
- Admin GovernanceView not wired to /governance/* endpoints
