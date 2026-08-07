# S0 Stage Evidence

| Field | Value |
|---|---|
| Document ID | `S0_SE_V2` |
| Stage | S0 — Design and Invariant Freeze |
| Status | `CANDIDATE (REVISED)` |
| Base Commit (deployed) | `3ef50b6d77a31c092e9353e255e672836f36ece8` |
| Planning Review Head | `4d33669b41568fa573e9c0e5865be8b1cea803c3` |
| S0 Review Commit | `046e40291a66904a4141b1c083561f381daec265` |
| S0 Design Agent | Cursor Agent (session `7668e4db-0a98-45f6-82a4-19b44b5c54e4`) |
| Independent Review Agent | ChatGPT (BNB合约 dedicated review session) |
| Revised After Review | 2026-08-07T19:30+08:00 |

---

## 1. Execution Baseline

```text
S0 Base Commit               3ef50b6d77a31c092e9353e255e672836f36ece8
Deployed Source Commit       3ef50b6d77a31c092e9353e255e672836f36ece8
Planning Review Head         4d33669b41568fa573e9c0e5865be8b1cea803c3
S0 Review Commit             046e40291a66904a4141b1c083561f381daec265
Files Read                   15 rules/baseline docs + 24 deployed .sol sources
Files Modified               5 (all evidence documents, revised after review)
Solidity Files Modified      NONE
Tests Executed               NO
Build Executed               NO
RPC Used                     NO
Deployment Executed          NO
```

---

## 2. Design Decision Checklist (post-revision)

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
| D-9 | Oracle rollover and long-gap | `>=` MAX_TWAP_AGE = re-anchor; boundary values specified | S1 | NO | NO | `FROZEN` |
| D-10 | Approved user vs fee whitelist | Independent governance attributes | S3/S4A or N/A | NO | NO | `FROZEN` |
| D-11 | Contract account lifecycle | EOA-only until user decision; ALL contract ABI items REMOVED from S0 freeze | N/A until resolved | NO | NO | `BLOCKED_DECISION` |
| D-12 | Support/Dividend/economic params | All frozen as-is from deployed baseline | S1 | NO | NO | `FROZEN` |

**Frozen: 11 | Blocked: 1 (D-11 — all dependent ABI items removed from freeze)**

---

## 3. Invariant Checklist (18 items — confirmed complete)

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
| ORC-INV-01 | PancakeV2TwapOracle | elapsed >= MAX_TWAP_AGE produces re-anchor, never READY | Status stays ACCUMULATING | Unit (warp at boundary values) |
| REG-INV-01 | Token | Approved user never gets protocol roles | By design | Unit |
| REG-INV-02 | Token | Revocation never permanently locks balance | transfer() succeeds | Unit (if contracts supported after user decision) |
| FEE-INV-01 | FeeVault | Balance covers dividend + support buckets | _assertSolvent revert | Invariant |
| DIV-INV-01 | DividendDistributor | totalAmount = claimed + carry | closeEpoch atomic | Unit |

---

## 4. ABI and State Machine Checklist (revised — 31 mandatory items)

Contract-account-related ABI items (ABI-06, ABI-15, ABI-16, ABI-27, ABI-33) have been REMOVED from this freeze pending user decision D-11.

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

**Legacy ABI retained: Position struct, PositionStatus enum, proportionalCost(), liquidityPositionOf(), existing TradeRouter signatures**

---

## 5. Baseline Compliance Summary

| Category | Count |
|---|---|
| UNCHANGED | 18 |
| CLARIFIED | 8 |
| IMPLEMENTATION_CHANGE_REQUIRED | 2 (dual ledger, staking mutation) |
| BLOCKED_DECISION | 1 (contract accounts — all dependent ABI removed) |
| NEW (phase separation) | 1 |
| ECONOMIC_BASELINE_CHANGE | NO |
| INTERNAL_REPRESENTATION_CHANGE | YES (dual ledger only) |

**No economic parameters changed. No tax rates, supply, lock durations, buyback amounts, or dividend windows modified.**

---

## 6. Revision Log (post-initial-review)

| Fix | Finding | Resolution |
|---|---|---|
| P2-01 | Contract accounts in frozen design | Removed from D-1 eligibility; all contract ABI items (ABI-06,15,16,27,33) removed; marked BLOCKED_DECISION |
| P2-02 | Economic baseline conflict | Unified: NO economic baseline change; YES internal representation change |
| P2-03 | Oracle boundary contradiction | Unified to `>=`; specified boundary values for 8999/9000/9001 |
| P2-04 | Buy constraints incomplete | Added complete Buy limit params (maxTax, minNet, deadline) with semantics |
| P2-05 | Short commit SHAs | All SHAs updated to full 40-character |

---

## 7. Cross-Document Consistency Verification

| Check | Result |
|---|---|
| 12 Decisions complete and readable | YES |
| 18 Invariants complete and readable | YES |
| 31 mandatory ABI items (5 contract items removed) | YES |
| 30-point Compliance Matrix | YES |
| All SHAs full 40-char | YES |
| No "PENDING" in frozen decisions | YES |
| No "if supported" in mandatory ABI | YES |
| No "USER_DECISION_REQUIRED" except D-11 | YES |
| Economic baseline = NO across all 5 docs | YES |

---

## 8. Unresolved

| ID | Problem | User Decision Required | Affected Stages | S0 Closing Impact |
|---|---|---|---|---|
| D-11 | Contract account lifecycle — EOA-only vs smart contract support | YES | S3, S4A | `BLOCKED_DECISION` — S0 cannot close until resolved; all dependent ABI removed |

---

## 9. Next Gate

```text
S0_PRE_REVIEW_READY = YES
INDEPENDENT_DESIGN_REVIEW_REQUIRED = YES
REVIEW_ADJUDICATION_REQUIRED = YES

S0_APPROVED_DESIGN_BASELINE = NO (D-11 BLOCKED_DECISION)
S1_ALLOWED = NO
SOLIDITY_IMPLEMENTATION_ALLOWED = NO

DEPLOYMENT_APPROVAL = NOT_GRANTED
BSC_TESTNET_RUNTIME_FIXED = NO
MAINNET = NO-GO
```

## 10. Files Modified

| File | Changes | Purpose |
|---|---|---|
| `evidence/S0_DESIGN_DECISION_REGISTER.md` | Full SHAs, D-1 eligibility fixed, D-1 economic baseline NO, D-3 Buy constraints complete, D-9 Oracle `>=` | All 5 P2 findings addressed |
| `evidence/S0_ABI_AND_STATE_MACHINE_FREEZE.md` | Full SHAs, 5 contract ABI items removed | P2-01 addressed |
| `evidence/S0_BASELINE_COMPLIANCE_MATRIX.md` | Full SHAs, economic baseline summary fixed, contract accounts row updated | P2-02 addressed |
| `evidence/S0_INVARIANT_SPECIFICATION.md` | ORC-INV-01 updated to `>=` | P2-03 consistency |
| `evidence/S0_STAGE_EVIDENCE.md` | Full SHAs, revision log, cross-doc consistency matrix, reduced ABI count | All P2 findings consolidated |

**Solidity files modified: NONE**
