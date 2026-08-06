# PANGU2 Audit Baseline

- **Version:** 2.0.0
- **Status:** AUTHORITATIVE
- **Source Commit:** `a155e3e` (HEAD, local — 7 commits ahead of `origin/main` at `cd7bde9`)
- **Last Updated:** 2026-08-06
- **Next Audit Target:** External review via `user-ai-code-review` on project `bnb1`

---

## 1. Git Baseline

| Field | Value |
|---|---|
| **Branch** | `main` |
| **HEAD (local)** | `a155e3ed506775248b4c9522f0982d6a17495cf7` |
| **origin/main (remote)** | `cd7bde9b977674fa49d8527346e8a666cd9fe450` |
| **Local vs Remote** | Local is **7 commits ahead** of origin/main |
| **Workspace Clean?** | NO — 9 untracked files/directories (no tracked files modified) |
| **Fetch Status** | Remote fetch failed (network connectivity issue) |

### Untracked Files (not committed)

```
.project-ai/
apps/admin/.env.example
apps/dapp/.env.example
apps/dapp/public/
apps/dapp/src/features/wallet/deployed.ts
docs/current/FRONTEND_MIGRATION_V7_1.md
docs/current/FRONTEND_REFACTOR_PLAN.md
docs/current/FRONTEND_REFACTOR_PROMPTS.md
logo视觉/
```

> None of these untracked files constitute business code changes. `deployed.ts` contains an older (2026-08-03) contract registry that conflicts with the 2026-08-05 authoritative registry in `CONTRACTS_AUTHORITY.md`.

---

## 2. Phase 1-7 Commit Chain (Local Only — Not Yet Pushed)

| Phase | Commit SHA (40-char) | Description | Files |
|-------|---------------------|-------------|-------|
| P1 | `c3ce8e13845346f9fa67e111bcc91900db9ebeb7` | fix(staking): complete controlled deposit flow | 5 |
| P2 | `d435aa31fa3bc5bdca3c62a473409d5e1be8008c` | fix(oracle): implement true v2 counterfactual twap | 2 + test |
| P3 | `393506c28e7f4aa4a1cd968b70c9a7f6548f01c3` | fix(deploy): separate bootstrap governance and liquidity roles | 3 + test |
| P4 | `aed668e4121ec6e44b64943b4ab84c296e60e340` | fix(worker): enforce fencing and lossless projection | 9 + test |
| P5 | `b6df5b806ccbbd3a81d1a1685902560949a08656` | fix(api): enforce dependency aware status and schema | 10 + test |
| P6 | `8874271845abb1a42777a2e8273a4150f85f8bfe` | fix(dapp): remove mocks and complete ui workspace | 9 |
| P7 | `4298f441b847f5d802536bb8eab83f7afe2d4f0f` | docs: rebuild verifiable deployment authority | 6 |
| FINAL | `a155e3ed506775248b4c9522f0982d6a17495cf7` | docs: add final audit report — Phase 1-7 verification | 1 |
| **P0** | _pending_ | (this commit — Phase 0 baseline docs) | 3 |

### Remote Baseline (origin/main)

```
cd7bde9b977674fa49d8527346e8a666cd9fe450
docs: P7 — MODULE_STATUS audit chain + CONTRACTS_AUTHORITY
```

All Phase 1-7 commits (P1 through FINAL + P0) are local-only and need to be pushed after external review approval.

---

## 3. Audit Series Status

### Current Audit Chain (Phase 1-7 + P0)

| Job | Scope | Status | Verdict |
|-----|-------|--------|---------|
| Phase 1 job | Staking deposit circuit | **Submitted** | PENDING |
| Phase 2 job | Oracle counterfactual TWAP | **Submitted** | PENDING |
| `7df1f3cfafba` | Bootstrap multi-role flow | **Submitted** | PENDING |
| `c96bdf235c22` | Chain worker fencing + projection | **Submitted** | PENDING |
| `d3bd42b0187b` | Backend DataStatus + OpenAPI | **Submitted** | PENDING |
| `3932c0db720c` | DApp mock cleanup + UI workspace | **Submitted** | PENDING |
| `a1226a5753b7` | Deployment authority docs | **Submitted** | PENDING |
| `f9c1e2c54cb7` | **Final comprehensive (repo-level)** | **Submitted** | PENDING |
| _pending_ | Phase 0 economic model + requirement trace | _pending submission_ | PENDING |

### Legacy Audit Series (Superseded)

| Audit # | Commit | Scope | Verdict |
|---------|--------|-------|---------|
| #89 | `f8df5c35` | 6 P1 initial CI | Baseline |
| #302 | `bc278c7a` | Oracle CF TWAP (old) | CHANGES_REQUIRED |
| #307 | `f722a684` | Mock-as-LIVE (old) | CHANGES_REQUIRED |
| #313 | `58b5bd66` | API contracts (old) | CHANGES_REQUIRED |
| #316 | `4299870` | DApp mock cleanup (old) | PENDING |

> Audits #302-#316 are **SUPERSEDED** by Phase 1-7 code. The issues flagged in those audits were addressed in the corresponding Phase 1-7 commits. Old verdicts are no longer authoritative.

---

## 4. Severity Classification (Independent from Gate Status)

| Severity | Definition | Count |
|----------|-----------|-------|
| **P0** | Core financial invariant, security boundary, or launch-blocker | 8 |
| **P1** | Data integrity, deployment safety, oracle dependency | 5 |
| **P2** | Documentation, developer experience | 1 |
| **P3** | Frontend display, cosmetic | 1 |

### Per-Requirement Severity

| Req ID | Requirement | Severity |
|--------|-------------|----------|
| R-01 | Token TransferContext | P0 |
| R-02 | Buy Tax 4% | P0 |
| R-03 | Sell Tax 4%/10% | P0 |
| R-04 | Staking Deposit | P0 |
| R-05 | Staking Return/Reward | P0 |
| R-06 | Oracle TWAP | P1 |
| R-07 | Bootstrap Roles | P1 |
| R-08 | Lease Fencing | P1 |
| R-09 | Lossless Projection | P1 |
| R-10 | Backend DataStatus | P1 |
| R-11 | DApp Mock Removal | P3 |
| R-12 | Deployment Manifest | P1 |
| R-13 | Launch Tax 30% | P0 |
| R-14 | Whitelist 0% | P0 |
| R-15 | Mainnet Block | P1 |
| R-16 | OpenAPI Schema | P2 |

---

## 5. Gate Status (Independent from Severity)

| Gate | Status | Evidence |
|------|--------|----------|
| **Testnet Gate** | **CONDITIONAL YES** | All code-level checks pass; on-chain bytecode UNVERIFIED |
| **Mainnet Gate** | **NO-GO (permanent)** | Chain 56 blocked at contract/script/test level |
| **External Review Gate** | **BLOCKED** | All 8 Phase 1-7 review jobs PENDING |
| **On-Chain Verification** | **BLOCKED** | BSC Testnet RPC access required |
| **Bootstrap Gate** | **BLOCKED** | 3 private keys required; external review must approve first |
| **Merge Gate** | **BLOCKED** | Must not push to origin/main before external APPROVE |

> **GATE RULE:** Gate status and severity are independent. A P3 cosmetic issue (R-11) has the same "Blocked by external review" gate as a P0 financial invariant (R-01). Severity determines what work must be done; Gate determines when it can be promoted.

**PENDING is never written as PASS.** Items remain PENDING until external review returns APPROVE.

---

## 6. Document Submission ≠ Code Fix

The following are documentation-only commits — they do NOT modify business code:

| Commit | Type | Scope |
|--------|------|-------|
| `4298f44` | Docs only | DEPLOYMENT_MANIFEST, CONTRACTS_AUTHORITY, MODULE_STATUS, DEPLOYMENT_GUIDE, validate-deployment.sh |
| `a155e3e` | Docs only | FINAL_AUDIT_REPORT.md |
| _(this commit)_ | Docs only | ECONOMIC_MODEL, REQUIREMENT_TRACE, AUDIT_BASELINE |

Documentation commits do not constitute code fixes. R-13 (Launch Tax) and R-14 (Whitelist) remain NOT_IMPLEMENTED regardless of being documented.

---

## 7. Next Actions (Strict Sequence)

1. **DO NOT push to origin/main** before external review returns APPROVE
2. Submit Phase 0 external review (this commit)
3. Wait for all Phase 1-7 + P0 external reviews to return a verdict
4. **Only after APPROVE**: push local Phase 1-7 + P0 + FINAL commits to origin/main
5. Run `scripts/validate-deployment.sh` with BSC Testnet RPC to fill UNVERIFIED fields
6. Execute Bootstrap → wait 30 min → Finalize
7. **Mainnet (chain 56): NEVER**
