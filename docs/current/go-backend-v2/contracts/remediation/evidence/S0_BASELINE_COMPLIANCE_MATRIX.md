# S0 Baseline Compliance Matrix

| Field | Value |
|---|---|
| Document ID | `S0_BCM_V2` |
| Stage | S0 |
| Status | `CANDIDATE` |
| Base Commit (deployed) | `3ef50b6d77a31c092e9353e255e672836f36ece8` |
| Planning Review Head | `4d33669b41568fa573e9c0e5865be8b1cea803c3` |
| S0 Review Commit (revised) | `ff8d693179fbea11f80ed3e491a41b8054f2693a` |
| Initial S0 Candidate Commit | `046e40291a66904a4141b1c083561f381daec265` |

---

| # | Baseline Item | Existing Requirement (from 05_BUSINESS / deployment baseline) | S0 Result | Change? | Evidence |
|---|---|---|---|---|---|
| 1 | **Initial Supply** | 1,000,000,000 PANGU2, minted once in constructor | UNCHANGED | NO | `Pangu2Token.sol:INITIAL_SUPPLY`, `_mint(initialHolder, INITIAL_SUPPLY)` |
| 2 | **Mint Authority** | No mint function beyond constructor; `_mint` only called once | UNCHANGED | NO | No public/external `mint()`; ERC20 `_mint` is internal, constructor-only |
| 3 | **Trading Gate** | `tradingOpenAt` set by GOVERNANCE_ROLE, one-time | UNCHANGED | NO | `setTradingOpenAt()` gated by `GOVERNANCE_ROLE`, `TradingAlreadyOpen` guard |
| 4 | **Fee Whitelist** | `feeWhitelist` mapping in Pangu2Token, GOVERNANCE_ROLE managed | CLARIFIED | NO (clarified control surface) | `feeWhitelist[address]` mapping; `setFeeWhitelist()` added to canonical surface |
| 5 | **Launch Protection** | 15 min after `tradingOpenAt`, 30% buy/sell tax | UNCHANGED | NO | `LAUNCH_PROTECTION_DURATION = 15 minutes`, `LAUNCH_BUY_TAX_BPS = 3000`, `LAUNCH_SELL_TAX_BPS = 3000` |
| 6 | **Normal Buy Tax** | 4% | UNCHANGED | NO | `BUY_TAX_BPS = 400` |
| 7 | **Normal Sell Tax** | 4% (no profit) | UNCHANGED | NO | `NORMAL_SELL_TAX_BPS = 400` |
| 8 | **Profit Sell Tax** | 10% (9% Support + 1% Burn) | CLARIFIED (profit comparison now specified) | NO | `PROFIT_SELL_TAX_BPS = 1000`, `PROFIT_SUPPORT_BPS = 900`, `PROFIT_BURN_BPS = 100` |
| 9 | **Burn** | 1% of profit sell (burn from supply) | UNCHANGED | NO | `_burn()` in `settleSell()` |
| 10 | **FeeVault Buckets** | DIVIDEND + SUPPORT, separate accounting | UNCHANGED | NO | `_dividendBalance`, `_supportBalance` in FeeVault |
| 11 | **Support Buyback** | 0.01 BNB, 60s interval, BuybackLocker recipient | UNCHANGED | NO | `BUYBACK_AMOUNT`, `MIN_BUYBACK_INTERVAL`, `buyback()` flow |
| 12 | **BuybackLocker** | Fixed duration or permanent, governance-set | UNCHANGED | NO | `BuybackLocker.LockMode`, constructor params |
| 13 | **Dividend** | Merkle proof, 30-day claim window on testnet | UNCHANGED | NO | `TESTNET_CLAIM_WINDOW = 30 days`, `claim()` with MerkleProof |
| 14 | **Staking** | Lock-based, penalty on early unstake | IMPLEMENTATION_CHANGE_REQUIRED (add typed mutation, reward tracking) | NO (economic params unchanged) | `Pangu2Staking.sol` at commit `3ef50b6` |
| 15 | **Oracle** | V2 TWAP, 1800s window, 300 bps deviation max | CLARIFIED (long-gap rule now explicit) | NO | `PancakeV2TwapOracle.sol` at commit `3ef50b6` |
| 16 | **Pause** | PAUSER_ROLE / UNPAUSER_ROLE separated | UNCHANGED | NO | `PAUSER_ROLE`, `UNPAUSER_ROLE` as separate keccak256 hashes |
| 17 | **Role Separation** | GOVERNANCE, SETTLEMENT, PAUSER, UNPAUSER distinct | UNCHANGED | NO | 4 distinct keccak256 role constants |
| 18 | **Direct Pair Protection** | Users cannot transfer direct to Pair; only Router can | UNCHANGED | NO | `DirectPairInteractionForbidden` in `_update()` |
| 19 | **TransferContext** | System contracts use typed context for transfers | CLARIFIED (add Staking context kinds) | NO | `TransferContext.Kind` enum + systemTransferContextAllowed |
| 20 | **CostBasis** | NONE/KNOWN/UNKNOWN triple-state | IMPLEMENTATION_CHANGE_REQUIRED (dual ledger replaces single struct) | YES (internal representation change, view compatibility maintained) | `CostBasisManager.sol` at commit `3ef50b6` |
| 21 | **Contract Accounts** | Not supported in deployed baseline | FROZEN — NOT SUPPORTED (permanent V2 boundary, EOA-only) | NO | D-11 FROZEN; all dependent ABI removed; REG-INV-02 deferred |
| 22 | **Mainnet** | NO-GO | UNCHANGED | NO | `MAINNET = NO-GO` in all documentation |
| 23 | **Deployment Script** | DeployPangu2 + Bootstrap + Finalize + OpenTrading | UNCHANGED | NO | 4-script deployment pipeline at commit `3ef50b6` |
| 24 | **Token Name/Symbol** | PANGU2 / PANGU2 | UNCHANGED | NO | ERC20 constructor params |
| 25 | **Locker Duration** | Governance-configured at deploy | UNCHANGED | NO | `BuybackLocker` constructor `lockMode` + `lockDuration` |
| 26 | **Fee Whitelist Separation** | Whitelist != approved-user; both independent | CLARIFIED | NO | Decision D-10 |
| 27 | **Tax Order** | Trading Gate -> Whitelist -> Launch Protection -> Cost Basis | CLARIFIED | NO | Decision D-4 |
| 28 | **Preview Semantics** | Diagnostic only with user limits | CLARIFIED | NO | Decision D-3 |
| 29 | **Staking S3/S4A Split** | S3 = principal only; S4A = reward | NEW (phase separation) | NO (economic unchanged) | Decision D-5 |
| 30 | **Oracle Long-Gap** | >5x window = re-anchor, not READY | CLARIFIED | NO | Decision D-9 |

---

## Summary

| Category | Count |
|---|---|
| UNCHANGED | 18 |
| CLARIFIED | 8 |
| IMPLEMENTATION_CHANGE_REQUIRED | 2 (dual ledger, staking mutation) |
| FROZEN / NOT SUPPORTED | 1 (contract accounts — EOA-only, permanent V2 boundary) |
| NEW (phase separation) | 1 |
| BLOCKED_DECISION | 0 |
| USER_DECISION_REQUIRED | 0 |
| ECONOMIC_BASELINE_CHANGE | NO (no rate/parameter changes; internal representation changes are NOT economic baseline changes) |
| INTERNAL_REPRESENTATION_CHANGE | YES (dual ledger replaces single Position struct — tax rates, supply, and all economic semantics unchanged) |
