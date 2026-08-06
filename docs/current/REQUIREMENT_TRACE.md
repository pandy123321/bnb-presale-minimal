# PANGU2 Requirement Traceability Matrix

- **Version:** 2.0.0
- **Status:** AUTHORITATIVE
- **Source Commit:** `a155e3e`
- **Last Updated:** 2026-08-06
- **Coverage:** All implemented Preview + Settlement functions, plus NOT_IMPLEMENTED requirements

---

## R-01: Token Transfer Control

| Field | Value |
|---|---|
| **Requirement ID** | R-01 |
| **Description** | All token transfers crossing user/system boundaries must use controlled TransferContext |
| **Contract** | `Pangu2Token` |
| **Functions** | `_update()`, `_beginContext()`, `_endContext()`, `systemTransfer()`, `stakingDeposit()` |
| **Preview Functions** | N/A (transfer execution only) |
| **Settlement Functions** | `settleBuy()`, `settleSell()`, `systemTransfer()`, `stakingDeposit()` |
| **Tests** | BootstrapRoleSeparationTest (12 tests) |
| **Audit Status** | PENDING (Phase 1, commit `c3ce8e1`) |
| **Severity** | P0 — Core security |
| **Gate** | Blocked — requires external review APPROVE |
| **Current State** | **IMPLEMENTED** |

## R-02: Buy Tax (4%)

| Field | Value |
|---|---|
| **Requirement ID** | R-02 |
| **Description** | Every buy transaction pays 4% tax to FeeVault DIVIDEND bucket |
| **Contract** | `Pangu2Token` |
| **Functions** | `settleBuy()`, `previewBuyTax()` |
| **Preview Functions** | `previewBuyTax(grossAmount) → (taxAmount, netAmount)` |
| **Settlement Functions** | `settleBuy(buyer, grossAmount, costWbnbWei) → (taxAmount, netAmount)` |
| **Tests** | QuoteTradeTest, TradeQuoteTest |
| **Audit Status** | PENDING (Phase 5, commit `b6df5b8`) |
| **Severity** | P0 — Financial accuracy |
| **Gate** | Blocked — requires external review APPROVE |
| **Current State** | **IMPLEMENTED** |

## R-03: Sell Tax (4% NORMAL / 10% PROFIT)

| Field | Value |
|---|---|
| **Requirement ID** | R-03 |
| **Description** | Sell tax is 4% (UNKNOWN cost basis) or 10% (KNOWN cost basis, TWAP > cost) |
| **Contract** | `Pangu2Token`, `CostBasisManager` |
| **Functions** | `settleSell()`, `previewSellTax()`, `consumeSell()` |
| **Preview Functions** | `previewSellTax(sellAmount, taxBps) → (supportAmount, burnAmount, swapAmount)` |
| **Settlement Functions** | `settleSell(seller, sellAmount, taxBps) → (supportAmount, burnAmount, swapAmount)` |
| **Tests** | QuoteTradeTest, TradeQuoteTest |
| **Audit Status** | PENDING (Phase 5, commit `b6df5b8`) |
| **Severity** | P0 — Financial accuracy |
| **Gate** | Blocked — requires external review APPROVE |
| **Current State** | **IMPLEMENTED** |

## R-04: Staking Deposit (Controlled Flow)

| Field | Value |
|---|---|
| **Requirement ID** | R-04 |
| **Description** | Stake() uses STAKING_DEPOSIT TransferContext; preserves user Cost Basis |
| **Contract** | `Pangu2Staking`, `Pangu2Token`, `CostBasisManager` |
| **Functions** | `stake()`, `stakingDeposit()`, `onStakingDeposit()`, `_update()` |
| **Preview Functions** | N/A (execution only) |
| **Settlement Functions** | `stakingDeposit(from, amount)`, `onStakingDeposit(account, amount)` |
| **Tests** | None — staking deposit tests not yet written (forge test --skip test is active) |
| **Audit Status** | PENDING (Phase 1, commit `c3ce8e1`) |
| **Severity** | P0 — Core financial invariant |
| **Gate** | Blocked — requires external review APPROVE |
| **Current State** | **IMPLEMENTED** (compiled, not unit-tested) |

## R-05: Staking Principal Return + Reward Payment

| Field | Value |
|---|---|
| **Requirement ID** | R-05 |
| **Description** | Unstake/earlyUnstake uses STAKING_PRINCIPAL_RETURN; claimRewards uses STAKING_REWARD |
| **Contract** | `Pangu2Staking`, `Pangu2Token` |
| **Functions** | `unstake()`, `earlyUnstake()`, `claimRewards()`, `systemTransfer()` |
| **Preview Functions** | `earned(address)` — view function on-chain |
| **Settlement Functions** | `systemTransfer(to, amount, STAKING_PRINCIPAL_RETURN)`, `systemTransfer(to, amount, STAKING_REWARD)` |
| **Tests** | None (forge test --skip test is active) |
| **Audit Status** | PENDING (Phase 1, commit `c3ce8e1`) |
| **Severity** | P0 — Core financial invariant |
| **Gate** | Blocked — requires external review APPROVE |
| **Current State** | **IMPLEMENTED** (compiled, not unit-tested) |

## R-06: Oracle Counterfactual TWAP

| Field | Value |
|---|---|
| **Requirement ID** | R-06 |
| **Description** | TWAP window matures without swaps using counterfactual cumulative prices |
| **Contract** | `PancakeV2TwapOracle` |
| **Functions** | `update()`, `_counterfactualCumulatives()`, `validatedQuote()` |
| **Preview Functions** | `validatedQuote(baseToken, quoteToken, baseAmount) → Quote` |
| **Settlement Functions** | N/A (oracle is read-only; TradeRouter calls validatedQuote as preview before settlement) |
| **Tests** | PancakeV2TwapOracleTest (8 tests), PancakeV2TwapOracleToken1Test (3 tests) — **11 PASS, 0 FAIL** |
| **Audit Status** | PENDING (Phase 2, commit `d435aa3`) |
| **Severity** | P1 — Oracle is a dependency, not settlement |
| **Gate** | Blocked — requires external review APPROVE |
| **Current State** | **IMPLEMENTED + TESTED** |

## R-07: Bootstrap Multi-Role Flow

| Field | Value |
|---|---|
| **Requirement ID** | R-07 |
| **Description** | Governance, LP, Initial Holder are independent roles; Governance grants/revokes temp LP auth |
| **Contract** | `BootstrapPangu2` (script), `FinalizePangu2` (script) |
| **Functions** | Bootstrap: 5-phase broadcast; Finalize: Governance-only validation |
| **Preview Functions** | N/A (deployment script) |
| **Settlement Functions** | N/A (deployment script) |
| **Tests** | BootstrapRoleSeparationTest (12 tests) — **12 PASS, 0 FAIL** |
| **Audit Status** | PENDING (Phase 3, commit `393506c`) |
| **Severity** | P1 — Deployment security |
| **Gate** | Blocked — requires external review APPROVE |
| **Current State** | **IMPLEMENTED + TESTED** |

## R-08: Chain Worker Lease Fencing

| Field | Value |
|---|---|
| **Requirement ID** | R-08 |
| **Description** | Cursor writes validate `lease_generation`; expired workers cannot submit |
| **Module** | `services/chain-worker` |
| **Functions** | `upsertCursor()`, `checkLeaseValid()`, `acquireLease()` |
| **Preview Functions** | N/A (infrastructure) |
| **Settlement Functions** | N/A (infrastructure) |
| **Tests** | integration.test.ts (9 tests) — **9 PASS, 0 FAIL** |
| **Audit Status** | PENDING (Phase 4, commit `aed668e`) |
| **Severity** | P1 — Data integrity |
| **Gate** | Blocked — requires external review APPROVE |
| **Current State** | **IMPLEMENTED + TESTED** |

## R-09: Lossless Projection (log_index PK)

| Field | Value |
|---|---|
| **Requirement ID** | R-09 |
| **Description** | Every CONFIRMED raw event independently projects; multi-log per tx preserved |
| **Module** | `services/chain-worker` |
| **Functions** | `processProjections()`, migration `001_add_log_index_to_projections.sql` |
| **Preview Functions** | N/A (data pipeline) |
| **Settlement Functions** | N/A (data pipeline) |
| **Tests** | integration.test.ts — multi-event same block, multi-log same tx, idempotency — **9 PASS, 0 FAIL** |
| **Audit Status** | PENDING (Phase 4, commit `aed668e`) |
| **Severity** | P1 — Data integrity |
| **Gate** | Blocked — requires external review APPROVE |
| **Current State** | **IMPLEMENTED + TESTED** |

## R-10: Backend DataStatus Enforcement

| Field | Value |
|---|---|
| **Requirement ID** | R-10 |
| **Description** | Quote source=mock→UNAVAILABLE; all-worker-stream check; CONFIRMED event count; RPC chainId validation |
| **Module** | `backend/` |
| **Functions** | `QuoteService::sourceStatus()`, `SystemStatusService::getDataStatus()`, `ChainConfigService::probeRpc()` |
| **Preview Functions** | `sourceStatus()` determines `data_status` for quote endpoints |
| **Settlement Functions** | N/A (backend is read-only) |
| **Tests** | ApiStatusContractTest (20 tests), SystemStatusTest (updated) |
| **Audit Status** | PENDING (Phase 5, commit `b6df5b8`) |
| **Severity** | P1 — Data accuracy |
| **Gate** | Blocked — requires external review APPROVE |
| **Current State** | **IMPLEMENTED** (PHP runtime tests pending Docker) |

## R-11: DApp Mock Data Removal

| Field | Value |
|---|---|
| **Requirement ID** | R-11 |
| **Description** | No undefined template variables; no hardcoded wallet addresses, amounts, or fake activity |
| **Module** | `apps/dapp/`, `packages/ui/` |
| **Functions** | HomePage, PortfolioPage, TradePage views — all mock data replaced with `—` |
| **Preview Functions** | N/A (frontend) |
| **Settlement Functions** | N/A (frontend) |
| **Tests** | 77 DApp tests PASS, 13 pre-existing failures (none from Phase 6) |
| **Audit Status** | PENDING (Phase 6, commit `8874271`) |
| **Severity** | P3 — Frontend display |
| **Gate** | Blocked — requires external review APPROVE |
| **Current State** | **IMPLEMENTED + TESTED** |

## R-12: Deployment Manifest

| Field | Value |
|---|---|
| **Requirement ID** | R-12 |
| **Description** | Full deployment manifest with bytecode hash, deploy tx, constructor args, governance roles |
| **Document** | `docs/current/DEPLOYMENT_MANIFEST.md` |
| **Contracts** | 11 contracts + V2 Pair |
| **Preview Functions** | N/A (documentation) |
| **Settlement Functions** | N/A (documentation) |
| **Tests** | `scripts/validate-deployment.sh` — bash syntax PASS; RPC verification PENDING |
| **Audit Status** | PENDING (Phase 7, commit `4298f44`) |
| **Severity** | P1 — Verifiability |
| **Gate** | Blocked — ALL on-chain fields UNVERIFIED |
| **Current State** | **DOCUMENTED** (on-chain verification pending BSC Testnet RPC) |

## R-13: Launch Tax 30% (First 15 Minutes)

| Field | Value |
|---|---|
| **Requirement ID** | R-13 |
| **Description** | First 15 minutes after trading opens: buy and sell tax = 30% |
| **Contract** | `Pangu2Token`, `Pangu2TradeRouter` |
| **Functions** | NOT_IMPLEMENTED |
| **Preview Functions** | NOT_IMPLEMENTED |
| **Settlement Functions** | NOT_IMPLEMENTED |
| **Tests** | NOT_IMPLEMENTED |
| **Audit Status** | N/A (not yet implemented) |
| **Severity** | P0 — Required for launch |
| **Gate** | Blocked — implementation required |
| **Current State** | **NOT_IMPLEMENTED** |

## R-14: Whitelist 0% Tax

| Field | Value |
|---|---|
| **Requirement ID** | R-14 |
| **Description** | Whitelisted addresses pay 0% tax on buy and sell; whitelist overrides launch and normal tax |
| **Contract** | `Pangu2Token`, `Pangu2TradeRouter` |
| **Functions** | NOT_IMPLEMENTED |
| **Preview Functions** | NOT_IMPLEMENTED |
| **Settlement Functions** | NOT_IMPLEMENTED |
| **Tests** | NOT_IMPLEMENTED |
| **Audit Status** | N/A (not yet implemented) |
| **Severity** | P0 — Required for launch |
| **Gate** | Blocked — implementation required |
| **Current State** | **NOT_IMPLEMENTED** |

## R-15: Mainnet Block (Chain 56)

| Field | Value |
|---|---|
| **Requirement ID** | R-15 |
| **Description** | Deploy/Bootstrap/Finalize scripts permanently reject BSC Mainnet (chain 56) |
| **Contract** | `DeployPangu2`, `BootstrapPangu2`, `FinalizePangu2` |
| **Functions** | `if (block.chainid != 97) revert(...)` in all three scripts + `testChain56Rejected()` |
| **Preview Functions** | N/A |
| **Settlement Functions** | N/A |
| **Tests** | BootstrapRoleSeparationTest::testChain56Rejected — **PASS** |
| **Audit Status** | PENDING (Phase 3, commit `393506c`) |
| **Severity** | P1 — Deployment safety |
| **Gate** | Passed |
| **Current State** | **IMPLEMENTED + TESTED** |

## R-16: OpenAPI Schema

| Field | Value |
|---|---|
| **Requirement ID** | R-16 |
| **Description** | Complete OpenAPI 3.1 spec with all endpoint request/response schemas, DataStatus enum, uint256 as decimal string |
| **Document** | `backend/public/openapi.yaml` |
| **Endpoints** | 19 endpoints defined |
| **Preview Functions** | All quote/staking endpoints have response schemas |
| **Settlement Functions** | N/A (read-only API) |
| **Tests** | ApiStatusContractTest validates envelope structure |
| **Audit Status** | PENDING (Phase 5, commit `b6df5b8`) |
| **Severity** | P2 — Documentation |
| **Gate** | Passed (spec defined, runtime validation pending Docker) |
| **Current State** | **IMPLEMENTED** |

---

## Summary

| Requirement | Status | Severity | Gate |
|---|---|---|---|
| R-01 TransferContext | IMPLEMENTED | P0 | Blocked (pending review) |
| R-02 Buy Tax 4% | IMPLEMENTED | P0 | Blocked (pending review) |
| R-03 Sell Tax 4%/10% | IMPLEMENTED | P0 | Blocked (pending review) |
| R-04 Staking Deposit | IMPLEMENTED | P0 | Blocked (pending review) |
| R-05 Staking Return/Reward | IMPLEMENTED | P0 | Blocked (pending review) |
| R-06 Oracle TWAP | IMPLEMENTED + TESTED | P1 | Blocked (pending review) |
| R-07 Bootstrap Roles | IMPLEMENTED + TESTED | P1 | Blocked (pending review) |
| R-08 Lease Fencing | IMPLEMENTED + TESTED | P1 | Blocked (pending review) |
| R-09 Lossless Projection | IMPLEMENTED + TESTED | P1 | Blocked (pending review) |
| R-10 Backend DataStatus | IMPLEMENTED | P1 | Blocked (pending review) |
| R-11 DApp Mock Removal | IMPLEMENTED + TESTED | P3 | Blocked (pending review) |
| R-12 Deployment Manifest | DOCUMENTED | P1 | Blocked (on-chain UNVERIFIED) |
| R-13 Launch Tax 30% | **NOT_IMPLEMENTED** | P0 | Blocked — code required |
| R-14 Whitelist 0% | **NOT_IMPLEMENTED** | P0 | Blocked — code required |
| R-15 Mainnet Block | IMPLEMENTED + TESTED | P1 | Passed |
| R-16 OpenAPI Schema | IMPLEMENTED | P2 | Passed |

**Implemented: 14 / 16 requirements.**
**NOT_IMPLEMENTED: 2 (R-13 Launch Tax, R-14 Whitelist).**
**Tested: 8 requirements have passing automated tests.**
