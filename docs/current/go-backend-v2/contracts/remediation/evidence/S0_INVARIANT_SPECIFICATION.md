# S0 Invariant Specification

| Field | Value |
|---|---|
| Document ID | `S0_INV_V2` |
| Stage | S0 |
| Status | `CANDIDATE (REVISED)` |
| Base Commit (deployed) | `3ef50b6d77a31c092e9353e255e672836f36ece8` |
| Planning Review Head | `4d33669b41568fa573e9c0e5865be8b1cea803c3` |
| S0 Review Commit (revised) | `ff8d693179fbea11f80ed3e491a41b8054f2693a` |
| Initial S0 Candidate Commit | `046e40291a66904a4141b1c083561f381daec265` |

---

## Cost Basis Invariants

### CB-INV-01: Balance Identity
| Item | Detail |
|---|---|
| **Contract** | CostBasisManager |
| **Precondition** | account is an eligible liquid user |
| **Invariant** | `actualBalance == knownBalance + unknownBalance` |
| **Post-change** | After any token transfer, the invariant holds |
| **Revert atomicity** | If violated, revert `InvalidPositionState()` |
| **Verification** | Unit: balance after transfer; Fuzz: random amounts; Invariant: stateful fuzz |

### CB-INV-02: Cost Non-Increase on Transfer
| Item | Detail |
|---|---|
| **Contract** | CostBasisManager |
| **Precondition** | transfer from user A to user B |
| **Invariant** | `aggregate knownCost across ALL users <= aggregate knownCost before transfer` |
| **Revert atomicity** | Cost is never created in transfer; only destroyed on sell |
| **Verification** | Invariant: track sum of all knownCostWbnbWei across all tracked users |

### CB-INV-03: Unknown Input Cannot Reduce Receiver Cost
| Item | Detail |
|---|---|
| **Contract** | CostBasisManager |
| **Precondition** | sender is UNKNOWN, receiver is KNOWN |
| **Invariant** | receiver.costWbnbWei AFTER transfer == receiver.costWbnbWei BEFORE transfer |
| **Revert atomicity** | N/A (invariant is equality) |
| **Verification** | Unit: UNKNOWN dust to KNOWN recipient; Fuzz: random amounts |

### CB-INV-04: Unknown Tokens Cannot Consume Known Cost
| Item | Detail |
|---|---|
| **Contract** | CostBasisManager, Pangu2TradeRouter |
| **Precondition** | sell where portion of sellAmount is UNKNOWN |
| **Invariant** | unknown portion is taxed at PROFIT_SELL_TAX_BPS (10%), never at NORMAL_SELL_TAX_BPS (4%) |
| **Revert atomicity** | Tax rate determined before cost deduction |
| **Verification** | Unit: mixed sell; Fuzz: random known/unknown splits |

### CB-INV-05: Split Action Tax >= Single Action Tax
| Item | Detail |
|---|---|
| **Contract** | CostBasisManager, Pangu2TradeRouter |
| **Precondition** | same Oracle snapshot, same total sell amount |
| **Invariant** | aggregate canonical tax from N partial sells >= canonical tax from 1 full sell |
| **Revert atomicity** | Per-transaction atomic |
| **Verification** | Fuzz: split ratios; Invariant: verify monotonic tax |

---

## Sell Invariants

### SELL-INV-01: Preview Components Sum to Execute
| Item | Detail |
|---|---|
| **Contract** | Pangu2TradeRouter |
| **Precondition** | Oracle quote unchanged, sell amount unchanged |
| **Invariant** | preview.support == execute.support, preview.burn == execute.burn, preview.swapTokens == execute.swapTokens |
| **Revert atomicity** | Execute reverts if user limits not met |
| **Verification** | Unit: preview then execute |

### SELL-INV-02: Total Allocation Identity
| Item | Detail |
|---|---|
| **Contract** | Pangu2TradeRouter, Pangu2Token |
| **Precondition** | sell execution |
| **Invariant** | `supportAmount + burnAmount + swapAmount == sellAmount` |
| **Revert atomicity** | Atomic within settleSell |
| **Verification** | Unit: post-sell check; Fuzz: random sell amounts |

---

## Staking Invariants

### STK-INV-01: Liquid + Active Lots Conservation
| Item | Detail |
|---|---|
| **Contract** | Pangu2Staking, CostBasisManager |
| **Precondition** | stake/unstake events |
| **Invariant** | `liquidLotCount + activeStakingLotCount = const` (across single user, for principal lots) |
| **Revert atomicity** | Per-operation atomic |
| **Verification** | Invariant: track user lot counts across stake/unstake cycles |

### STK-INV-02: Token Balance = Sum of All Buckets
| Item | Detail |
|---|---|
| **Contract** | Pangu2Staking |
| **Precondition** | after any staking operation |
| **Invariant** | `stakingTokenBalance == activePrincipal + availableRewardReserve + ownedAccruedRewardLiability + explicitRoundingOrSurplus` |
| **Revert atomicity** | Per-operation atomic |
| **Verification** | Invariant: stateful fuzz after each operation |

### STK-INV-03: Locked Reward Cannot Be Claimed Before Maturity
| Item | Detail |
|---|---|
| **Contract** | Pangu2Staking |
| **Precondition** | position.lockedAt + position.lockDuration > block.timestamp |
| **Invariant** | claimRewards for this position reverts |
| **Revert atomicity** | Revert with `StillLocked` |
| **Verification** | Unit: claim before maturity |

### STK-INV-04: Forfeited Reward Returns to Available Reserve
| Item | Detail |
|---|---|
| **Contract** | Pangu2Staking |
| **Precondition** | early unstake triggers forfeiture |
| **Invariant** | `availableRewardReserve += forfeitedAmount`, `ownedAccruedRewardLiability -= forfeitedAmount` |
| **Revert atomicity** | Atomic within earlyUnstake |
| **Verification** | Unit: early unstake, check reserve increase |

### STK-INV-05: Only Token May Mutate CostBasis
| Item | Detail |
|---|---|
| **Contract** | CostBasisManager, Pangu2Token, Pangu2Staking |
| **Precondition** | any mutation to CostBasisManager state |
| **Invariant** | caller == Pangu2Token (verified via `onlyToken` modifier) |
| **Revert atomicity** | Revert with `UnauthorizedHook` |
| **Verification** | Unit: Staking calls CostBasis directly; Fuzz: random callers |

### STK-INV-06: No Reward Accrual When TotalStaked == 0
| Item | Detail |
|---|---|
| **Contract** | Pangu2Staking |
| **Precondition** | totalStaked == 0 |
| **Invariant** | rewardRate == 0; no reward liability accrues |
| **Revert atomicity** | rewardRate update reverts if totalStaked == 0 and non-zero rate requested |
| **Verification** | Unit: setRewardRate with totalStaked == 0 |

---

## Oracle Invariants

### ORC-INV-01: Long-Gap Cannot Produce READY
| Item | Detail |
|---|---|
| **Contract** | PancakeV2TwapOracle |
| **Precondition** | elapsed >= MAX_TWAP_AGE |
| **Invariant** | status NEVER transitions to READY in this update; re-anchor triggered |
| **Revert atomicity** | status set to ACCUMULATING; READY not produced |
| **Verification** | Unit: warp to 1800+8999 (must NOT re-anchor), warp to 1800+9000 (MUST re-anchor, never READY), warp to 1800+9001 (MUST re-anchor, never READY) |

---

## Registry Invariants

### REG-INV-01: Approved User Never Receives Implicit Protocol Authority
| Item | Detail |
|---|---|
| **Contract** | Pangu2Token |
| **Precondition** | address is approved-user |
| **Invariant** | address hasRole(SETTLEMENT_ROLE) == false; isLiquidityManager(address) == false |
| **Revert atomicity** | N/A (invariant enforced by design — no code path grants roles to approved users) |
| **Verification** | Unit: check approved user role membership |

**Mandatory registry invariants: 1 (REG-INV-01)**

### DEFERRED — D-11 Dependent (Contract Accounts Not Supported in V2)

### REG-INV-02: Revocation Cannot Permanently Lock Balance
| Item | Detail |
|---|---|
| **Contract** | Pangu2Token (contract account registry) |
| **Precondition** | address is in REVOKED state with non-zero balance |
| **Invariant** | User can still transfer() out (exit) or sell via official Router; funds are not unrecoverable |
| **Revert atomicity** | transfer() does not revert for REVOKED address |
| **Verification** | Unit: REVOKED user calls transfer() and sell() |
| **Status** | `DEFERRED — NOT_APPLICABLE to EOA-only V2 baseline (D-11 FROZEN as NOT SUPPORTED)` |

---

## Fee Vault Invariants

### FEE-INV-01: Vault Balance Covers All Buckets
| Item | Detail |
|---|---|
| **Contract** | FeeVault |
| **Precondition** | after any credit, debit, or conversion |
| **Invariant** | `token.balanceOf(FeeVault) >= dividendBalance + supportBalance` |
| **Revert atomicity** | `_assertSolvent()` reverts if violated |
| **Verification** | Invariant: stateful fuzz |

---

## Dividend Invariants

### DIV-INV-01: Reserved + Claimed + Carry Conservation
| Item | Detail |
|---|---|
| **Contract** | DividendDistributor |
| **Precondition** | after epoch close |
| **Invariant** | `epoch.totalAmount == sum(claimed) + carry` |
| **Revert atomicity** | Epoch close is atomic |
| **Verification** | Unit: check epoch accounting |

---
