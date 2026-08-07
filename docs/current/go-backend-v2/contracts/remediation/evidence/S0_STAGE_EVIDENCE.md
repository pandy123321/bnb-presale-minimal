# S0 Stage Evidence

| Field | Value |
|---|---|
| Document ID | `S0_SE_V3` |
| Stage | S0 — Design and Invariant Freeze |
| Status | `CANDIDATE (FINAL REVISION)` |
| Base Commit (deployed) | `3ef50b6d77a31c092e9353e255e672836f36ece8` |
| Planning Review Head | `4d33669b41568fa573e9c0e5865be8b1cea803c3` |
| Initial S0 Candidate Commit | `046e40291a66904a4141b1c083561f381daec265` |
| S0 Review Commit (revised) | `ff8d693179fbea11f80ed3e491a41b8054f2693a` |
| S0 Design Agent | Cursor Agent (session `7668e4db-0a98-45f6-82a4-19b44b5c54e4`) |
| Independent Review Agent | ChatGPT (BNB合约 dedicated review session) |
| Review Adjudication Agent | ChatGPT GPT-5.6 Sol (separate BNB合约 adjudication session) |
| Revised After Review | 2026-08-07T19:45+08:00 |

---

## 1. Execution Baseline

```text
S0 Base Commit               3ef50b6d77a31c092e9353e255e672836f36ece8
Deployed Source Commit       3ef50b6d77a31c092e9353e255e672836f36ece8
Planning Review Head         4d33669b41568fa573e9c0e5865be8b1cea803c3
Initial S0 Candidate Commit  046e40291a66904a4141b1c083561f381daec265
S0 Review Commit (revised)   ff8d693179fbea11f80ed3e491a41b8054f2693a
Files Read                   15 rules/baseline docs + 24 deployed .sol sources
Files Modified               5 (all evidence documents, final revision)
Solidity Files Modified      NONE
Tests Executed               NO
Build Executed               NO
RPC Used                     NO
Deployment Executed          NO
```

**Note**: The `Initial S0 Candidate Commit` field records the first S0 document submission. The current revised content is in the commit identified by the external submission manifest. This avoids the Git SHA self-reference cycle problem.

---

## 2. Design Decision Checklist (FINAL — all 12 frozen)

| Decision ID | Design Question | Frozen Result | Impact Stage | Economic Baseline Change | Internal Rep Change | Status |
|---|---|---|---|---|---|---|
| D-1 | CostBasis dual ledger | knownBalance + knownCostWbnbWei + unknownBalance per EOA user | S1 | NO | YES | `FROZEN` |
| D-2 | Mixed sell and rounding | UNKNOWN=10%, KNOWN=4% if TWAP <= costCeil | S1 | NO | NO | `FROZEN` |
| D-3 | Preview vs Execute | Option A — Diagnostic Only with complete Buy/Sell limit params | S1 | NO | NO | `FROZEN` |
| D-4 | Canonical tax control surface | Pangu2Token as sole source of truth | S1 | NO | NO | `FROZEN` |
| D-5 | Staking phase boundaries | S3 = principal, S4A = reward | S3, S4A | NO | NO | `FROZEN` |
| D-6 | Staking typed mutation path | Token -> CostBasis single path with positionId | S3, S4A | NO | NO | `FROZEN` |
| D-7 | Staking reward accounting | Per-position RewardAccounting, funding invariant | S4A, S5 | NO | NO | `FROZEN` |
| D-8 | Staking pause | Block stake/claim/fund, allow principal exit | S3, S4A | NO | NO | `FROZEN` |
| D-9 | Oracle rollover and long-gap | `>=` MAX_TWAP_AGE = re-anchor; 8999/9000/9001 boundary specified | S1 | NO | NO | `FROZEN` |
| D-10 | Approved user vs fee whitelist | Independent governance attributes | S3/S4A or N/A | NO | NO | `FROZEN` |
| D-11 | Contract account lifecycle | NOT SUPPORTED — EOA-only, permanent V2 boundary | N/A | NO | NO | `FROZEN` |
| D-12 | Support/Dividend/economic params | All frozen as-is from deployed baseline | S1 | NO | NO | `FROZEN` |

**Frozen: 12 | Blocked: 0**

---

## 3. Invariant Checklist (17 mandatory + 1 deferred)

### Mandatory Invariants (17)

| Invariant ID | Contract | Invariant | Revert Atomicity | Verification Method |
|---|---|---|---|---|
| CB-INV-01 | CostBasisManager | actualBalance = knownBalance + unknownBalance | InvalidPositionState revert | Unit + Fuzz + Invariant |
| CB-INV-02 | CostBasisManager | Aggregate cost never increases on transfer | N/A (invariant) | Invariant (stateful fuzz) |
| CB-INV-03 | CostBasisManager | Unknown input cannot reduce receiver KNOWN cost | N/A (equality) | Unit (dust transfer) |
| CB-INV-04 | CostBasisManager + TradeRouter | Unknown tokens always 10% tax | Per-transaction | Unit (mixed sell) |
| CB-INV-05 | CostBasisManager + TradeRouter | Split actions cannot lower aggregate tax | Per-transaction | Fuzz (split ratios) |
| SELL-INV-01 | TradeRouter | Preview components = execute components | Execute revert | Unit |
| SELL-INV-02 | TradeRouter + Token | support + burn + swapTokens = sellAmount | settleSell atomic | Unit + Fuzz |
| STK-INV-01 | Staking + CostBasis | Liquid lots + active lots conservation | Per-operation | Invariant |
| STK-INV-02 | Staking | Balance = all buckets sum | Per-operation | Invariant |
| STK-INV-03 | Staking | Locked reward cannot be claimed | StillLocked revert | Unit |
| STK-INV-04 | Staking | Forfeited reward -> available reserve | earlyUnstake atomic | Unit |
| STK-INV-05 | CostBasis + Token | Only Token mutates CostBasis | UnauthorizedHook revert | Unit |
| STK-INV-06 | Staking | No reward when totalStaked == 0 | setRewardRate revert | Unit |
| ORC-INV-01 | PancakeV2TwapOracle | elapsed >= 9000 produces re-anchor, never READY; test at 8999/9000/9001 | Status stays ACCUMULATING | Unit (warp at 8999, 9000, 9001) |
| REG-INV-01 | Token | Approved user never gets protocol roles | By design | Unit |
| FEE-INV-01 | FeeVault | Balance covers dividend + support buckets | _assertSolvent revert | Invariant |
| DIV-INV-01 | DividendDistributor | totalAmount = claimed + carry | closeEpoch atomic | Unit |

### Deferred Invariants (D-11 Dependent — NOT APPLICABLE to EOA-only V2)

| Invariant ID | Contract | Reason for Deferral | Status |
|---|---|---|---|
| REG-INV-02 | Token | Contract account revocation invariant — not applicable to EOA-only V2 baseline | `NOT_APPLICABLE` |

**Total: 17 mandatory + 1 deferred = 18 described (no conditional invariants in mandatory count)**

---

## 4. ABI and State Machine Checklist (31 mandatory items)

Contract-account-related ABI items permanently removed per D-11 (EOA-only).

| ID | Type | Proposed Freeze | Impact Contract | Compatibility |
|---|---|---|---|---|
| ABI-01-04 | New structs (4) | DualPosition, RewardAccounting, SellPreview, BuyPreview | CostBasis, Staking, TradeRouter | Additive only |
| ABI-05 | New enum (1) | StakingOperationKind | TransferContext | Additive only |
| ABI-07-14 | New functions (8) | resolveTax, setWhitelist, dualPositionOf, extended preview/buy/sell | Token, CostBasis, TradeRouter | Overloaded on TradeRouter |
| ABI-17-18 | New hooks (2) | Staking context in _update, onStakingPrincipalReturn | Token, CostBasis | Internal |
| ABI-19-22 | Interface changes (4) | Add functions to 4 interfaces | ICostBasis, IPangu2Token, IPangu2Staking, IPangu2TradeRouter | Additive |
| ABI-23-26 | New events (4) | WhitelistUpdated, StakingContext*, DualPositionChanged | Multiple | Additive |
| ABI-28-32 | New errors (5) | Buy/SellConstraint, UnauthorizedStaking, InvalidPositionId, RewardNotMatured | Multiple | Additive |
| ABI-34-36 | New TransferContext kinds (3) | STAKING_DEPOSIT, STAKING_REWARD_CLAIM, STAKING_PRINCIPAL_RETURN | TransferContext | Additive |

**Total mandatory ABI items: 31**

---

## 5. Baseline Compliance Summary

| Category | Count |
|---|---|
| UNCHANGED | 18 |
| CLARIFIED | 8 |
| IMPLEMENTATION_CHANGE_REQUIRED | 2 (dual ledger, staking mutation) |
| FROZEN — NOT SUPPORTED | 1 (contract accounts — permanent V2 EOA-only boundary) |
| NEW (phase separation) | 1 |
| BLOCKED_DECISION | 0 |
| USER_DECISION_REQUIRED | 0 |
| ECONOMIC_BASELINE_CHANGE | NO |
| INTERNAL_REPRESENTATION_CHANGE | YES (dual ledger only) |

**No economic parameters changed. No tax rates, supply, lock durations, buyback amounts, or dividend windows modified.**

---

## 6. Revision Log (cumulative)

| Revision | Findings Addressed |
|---|---|
| V2 (ff8d693) | P2-02 unified economic baseline; P2-03 Oracle `>=` boundary; P2-04 Buy constraints complete; P2-05 full SHAs |
| V3 (current) | P2-06 D-11 closed as EOA-only NOT SUPPORTED; P2-07 commit binding renamed to Initial S0 Candidate Commit; P2-08 REG-INV-02 moved to DEFERRED; P2-09 Oracle verification at 8999/9000/9001; P3-01 compliance summary unified; ORC-INV-01 boundary verification explicit |

---

## 7. Cross-Document Consistency Verification (FINAL)

| Check | Result |
|---|---|
| 12 Decisions complete and readable | YES |
| All 12 Decisions FROZEN (0 blocked) | YES |
| 17 Mandatory Invariants complete | YES |
| 1 Deferred Invariant (REG-INV-02, not in mandatory count) | YES |
| 31 Mandatory ABI items | YES |
| 30-point Compliance Matrix | YES |
| All SHAs full 40-char | YES |
| Commit binding uses Initial Candidate + external manifest (no SHA self-reference) | YES |
| No "PENDING" in frozen decisions | YES |
| No "if supported" in mandatory ABI | YES |
| No "USER_DECISION_REQUIRED" in FROZEN decisions | YES |
| No "BLOCKED_DECISION" remaining | YES |
| Economic baseline = NO across all 5 docs | YES |
| Oracle 8999/9000/9001 boundary verifiable | YES |
| Role separation: Design Agent, Independent Review, Adjudication Agent identified | YES |

---

## 8. Unresolved

**NONE.** All 12 mandatory design decisions are FROZEN. All 17 mandatory invariants are frozen. All 31 mandatory ABI items are frozen. REG-INV-02 is deferred as NOT_APPLICABLE (contract accounts not supported in V2 per D-11).

---

## 9. Next Gate

```text
S0_PRE_REVIEW_READY = YES
INDEPENDENT_DESIGN_REVIEW_REQUIRED = YES
REVIEW_ADJUDICATION_REQUIRED = YES

S0_APPROVED_DESIGN_BASELINE = PENDING_INDEPENDENT_REVIEW
S1_ALLOWED = NO (pending approved baseline)
SOLIDITY_IMPLEMENTATION_ALLOWED = NO

DEPLOYMENT_APPROVAL = NOT_GRANTED
BSC_TESTNET_RUNTIME_FIXED = NO
MAINNET = NO-GO
```

## 10. Files Modified

| File | Revision |
|---|---|
| `evidence/S0_DESIGN_DECISION_REGISTER.md` | D-11 closed as EOA-only NOT SUPPORTED; commit binding renamed; Unresolved section removed |
| `evidence/S0_ABI_AND_STATE_MACHINE_FREEZE.md` | Commit binding renamed; NOTE updated to "permanently REMOVED" |
| `evidence/S0_BASELINE_COMPLIANCE_MATRIX.md` | D-11 row FROZEN; summary unified to BLOCKED_DECISION: 0, all 30 frozen |
| `evidence/S0_INVARIANT_SPECIFICATION.md` | ORC-INV-01 verification at 8999/9000/9001; REG-INV-02 moved to DEFERRED; mandatory count = 17 |
| `evidence/S0_STAGE_EVIDENCE.md` | Full revision (this file) with updated counts, change log, and consistency matrix |

**Solidity files modified: NONE**
