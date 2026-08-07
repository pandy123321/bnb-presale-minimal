# S0 Stage Evidence

| Field | Value |
|---|---|
| Document ID | `S0_SE_V1` |
| Stage | S0 — Design and Invariant Freeze |
| Status | `CANDIDATE` |
| S0 Base Commit | `3ef50b6` |
| Planning Review Head | `4d33669` |
| Created | 2026-08-07 |

---

## 1. Execution Baseline

```text
S0 Base Commit               3ef50b6
Deployed Source Commit       3ef50b6
Planning Review Head         4d33669
Files Read                   15 rules/baseline docs + 24 deployed .sol sources
Files Modified               5 (all new evidence documents)
Solidity Files Modified      NONE
Tests Executed               NO
Build Executed               NO
RPC Used                     NO
Deployment Executed          NO
```

---

## 2. Design Decision Checklist

| Decision ID | Design Question | Frozen Result | Impact Stage | Economic Baseline Change | Status |
|---|---|---|---|---|---|
| D-1 | CostBasis dual ledger | knownBalance + knownCostWbnbWei + unknownBalance per user | S1 | YES (internal representation) | `FROZEN` |
| D-2 | Mixed sell and rounding | UNKNOWN=10%, KNOWN=4% if TWAP <= costCeil | S1 | CLARIFIED | `FROZEN` |
| D-3 | Preview vs Execute | Option A — Diagnostic Only with user limit params | S1 | NO | `FROZEN` |
| D-4 | Canonical tax control surface | Pangu2Token as sole source of truth | S1 | NO | `FROZEN` |
| D-5 | Staking phase boundaries | S3 = principal, S4A = reward | S3, S4A | NO | `FROZEN` |
| D-6 | Staking typed mutation path | Token -> CostBasis single path with positionId | S3, S4A | NO | `FROZEN` |
| D-7 | Staking reward accounting | Per-position RewardAccounting, funding invariant | S4A, S5 | NO | `FROZEN` |
| D-8 | Staking pause | Block stake/claim/fund, allow principal exit | S3, S4A | NO | `FROZEN` |
| D-9 | Oracle rollover and long-gap | MAX_TWAP_AGE = 5*window, re-anchor | S1 | NO | `FROZEN` |
| D-10 | Approved user vs fee whitelist | Independent governance attributes | S3/S4A or N/A | NO | `FROZEN` |
| D-11 | Contract account lifecycle | EOA-only vs smart contract support | S3, S4A | PENDING | `BLOCKED_DECISION` |
| D-12 | Support/Dividend/economic params | All frozen as-is from deployed baseline | S1 | NO | `FROZEN` |

**Frozen: 11 | Blocked: 1 (D-11)**

---

## 3. Invariant Checklist

| Invariant ID | Contract | Invariant | Revert Atomicity | Verification Method |
|---|---|---|---|---|
| CB-INV-01 | CostBasisManager | actualBalance = knownBalance + unknownBalance | InvalidPositionState revert | Unit + Fuzz + Invariant |
| CB-INV-02 | CostBasisManager | Aggregate cost never increases on transfer | N/A (invariant) | Invariant (stateful fuzz) |
| CB-INV-03 | CostBasisManager | Unknown input cannot reduce receiver KNOWN cost | N/A (equality) | Unit (dust transfer) |
| CB-INV-04 | CostBasisManager + TradeRouter | Unknown tokens always 10% tax | Per-transaction | Unit (mixed sell) |
| CB-INV-05 | CostBasisManager + TradeRouter | Split actions cannot lower aggregate tax | Per-transaction | Fuzz (split ratios) |
| SELL-INV-01 | TradeRouter | Preview components sum = execute components | Execute revert | Unit |
| SELL-INV-02 | TradeRouter + Token | support + burn + swapTokens = sellAmount | settleSell atomic | Unit + Fuzz |
| STK-INV-01 | Staking + CostBasis | Liquid lots + active lots conservation | Per-operation | Invariant |
| STK-INV-02 | Staking | Balance = all buckets sum | Per-operation | Invariant |
| STK-INV-03 | Staking | Locked reward cannot be claimed | StillLocked revert | Unit |
| STK-INV-04 | Staking | Forfeited reward -> available reserve | earlyUnstake atomic | Unit |
| STK-INV-05 | CostBasis + Token | Only Token mutates CostBasis | UnauthorizedHook revert | Unit |
| STK-INV-06 | Staking | No reward when totalStaked == 0 | setRewardRate revert | Unit |
| ORC-INV-01 | PancakeV2TwapOracle | Long-gap cannot produce READY | Status stays ACCUMULATING | Unit (warp) |
| REG-INV-01 | Token | Approved user never gets protocol roles | By design | Unit |
| REG-INV-02 | Token | Revocation never permanently locks balance | transfer() succeeds | Unit |
| FEE-INV-01 | FeeVault | Balance covers dividend + support buckets | _assertSolvent revert | Invariant |
| DIV-INV-01 | DividendDistributor | totalAmount = claimed + carry | closeEpoch atomic | Unit |

**Total invariants: 18**

---

## 4. ABI and State Machine Checklist

| ID | Type | Current State | Proposed Freeze | Impact Contract | Compatibility |
|---|---|---|---|---|---|
| ABI-01-04 | New structs (4) | Not exist | DualPosition, RewardAccounting, SellPreview, BuyPreview | CostBasis, Staking, TradeRouter | Additive only |
| ABI-05-06 | New enums (2) | Not exist | StakingOperationKind, ContractStatus | TransferContext, Token | Additive only |
| ABI-07-16 | New functions (10) | Not exist | resolveTax, setWhitelist, dualPositionOf, setContractStatus, contractStatus | Token, CostBasis, TradeRouter | Overloaded on TradeRouter |
| ABI-17-18 | New hooks (2) | Not exist | Staking context in _update, onStakingPrincipalReturn | Token, CostBasis | Internal |
| ABI-19-22 | Interface changes (4) | Exist | Add functions to 4 interfaces | ICostBasis, IPangu2Token, IPangu2Staking, IPangu2TradeRouter | Additive |
| ABI-23-27 | New events (5) | Not exist | WhitelistUpdated, StakingContext*, DualPositionChanged, ContractStatusUpdated | Multiple | Additive |
| ABI-28-33 | New errors (6) | Not exist | Buy/SellConstraint, UnauthorizedStaking, InvalidPositionId, etc. | Multiple | Additive |
| ABI-34-36 | New TransferContext kinds (3) | Not exist | STAKING_DEPOSIT, STAKING_REWARD_CLAIM, STAKING_PRINCIPAL_RETURN | TransferContext | Additive |

**Legacy ABI retained: Position struct, PositionStatus enum, proportionalCost(), liquidityPositionOf(), existing TradeRouter signatures**

---

## 5. Baseline Compliance Summary

| Result | Count |
|---|---|
| UNCHANGED | 18 |
| CLARIFIED | 8 |
| IMPLEMENTATION_CHANGE_REQUIRED | 2 |
| USER_DECISION_REQUIRED | 1 |
| NEW | 1 |
| ECONOMIC_BASELINE_CHANGE | 0 |

**No economic parameters changed. No tax rates, supply, lock durations, buyback amounts, or dividend windows modified.**

---

## 6. Files Modified

| File | Purpose | Status |
|---|---|---|
| `evidence/S0_DESIGN_DECISION_REGISTER.md` | 12 design decisions frozen | CREATED |
| `evidence/S0_INVARIANT_SPECIFICATION.md` | 18 invariants specified | CREATED |
| `evidence/S0_ABI_AND_STATE_MACHINE_FREEZE.md` | 36 ABI/state machine items frozen | CREATED |
| `evidence/S0_BASELINE_COMPLIANCE_MATRIX.md` | 30-point baseline compliance check | CREATED |
| `evidence/S0_STAGE_EVIDENCE.md` | Stage evidence summary (this file) | CREATED |

---

## 7. Unresolved

| ID | Problem | Why Cannot Assume | User Decision Required | Affected Stages | S0 Closing Impact |
|---|---|---|---|---|---|
| D-11 | Contract account lifecycle — EOA-only vs smart contract support | Smart wallets (Gnosis Safe, Argent) and counterfactual addresses (ERC-4337) will be permanently locked if only EOA allowed; but wrong implementation opens protocol to untrusted contract risk | YES | S3, S4A | `BLOCKED_DECISION` — S0 cannot close until resolved |

---

## 8. Next Gate

```text
S0_PRE_REVIEW_READY = YES
INDEPENDENT_DESIGN_REVIEW_REQUIRED = YES
REVIEW_ADJUDICATION_REQUIRED = YES

S0_APPROVED_DESIGN_BASELINE = NO
S1_ALLOWED = NO
SOLIDITY_IMPLEMENTATION_ALLOWED = NO

S0_STATUS = BLOCKED_DECISION (D-11 unresolved)

DEPLOYMENT_APPROVAL = NOT_GRANTED
BSC_TESTNET_RUNTIME_FIXED = NO
MAINNET = NO-GO
```
