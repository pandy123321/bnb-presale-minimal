# PANGU2 V2 Deployment Manifest

- **Status:** DRAFT — **NO ON-CHAIN VERIFICATION PERFORMED**
- **Schema Version:** 2.0.0
- **Generated:** 2026-08-06
- **Network:** BSC Testnet (Chain ID: 97)
- **V2 Pair:** PancakeSwap V2 Factory `0x6725F303b657a9451d8BA641348b6761A6CC7a17`
- **V2 Router:** `0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3`
- **WBNB:** `0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd`
- **Source Commit:** `8874271` (tip of main)
- **Compiler:** Solidity 0.8.24 via Foundry

> **WARNING:** This manifest is a **template** awaiting real on-chain verification.
> All `UNVERIFIED` fields must be resolved via `validate-deployment.sh` before
> this manifest can be promoted to AUTHORITATIVE status.

---

## Contract Registry

| # | Contract | Address | Deploy Tx | Block | Deployer | Verified |
|---|---|---|---|---|---|---|
| 1 | **Pangu2Token** | `0xaf2bD8bF6b1a0E6B94c2b10150F9184D142eef1C` | UNVERIFIED | UNVERIFIED | UNVERIFIED | NO |
| 2 | **CostBasisManager** | `0x384492a27ECC0Eb0A2b35FdE719fbb6ae2b4DbAF` | UNVERIFIED | UNVERIFIED | UNVERIFIED | NO |
| 3 | **V2 Pair (PANGU2/WBNB)** | `0x0Fe75c3460ed320649e133C1AA454881bC6c8b2E` | UNVERIFIED | UNVERIFIED | UNVERIFIED | NO |
| 4 | **PancakeV2Adapter** | `0xb3F319303655C61559593cb2968e438F789c79D5` | UNVERIFIED | UNVERIFIED | UNVERIFIED | NO |
| 5 | **PancakeV2TwapOracle** | `0xf16c14B412E69dA6793497AAdf52e38284BcF300` | UNVERIFIED | UNVERIFIED | UNVERIFIED | NO |
| 6 | **SupportPool** | `0x91F8cEe7E08E5DC5f30d0582085af1fDE791D0A9` | UNVERIFIED | UNVERIFIED | UNVERIFIED | NO |
| 7 | **FeeVault** | `0xEF17753B7c690800EA65449A26491887c32536c8` | UNVERIFIED | UNVERIFIED | UNVERIFIED | NO |
| 8 | **BuybackLocker** | `0xBeDc42556ea3312dd643dcE133ed3b5bB5a1C957` | UNVERIFIED | UNVERIFIED | UNVERIFIED | NO |
| 9 | **DividendDistributor** | `0x6265b64de9a3f7198E40082ea82BAcCAfD1E14CB` | UNVERIFIED | UNVERIFIED | UNVERIFIED | NO |
| 10 | **Pangu2TradeRouter** | `0x16f5418A4A2D7D8675228fe2230A565e595954fe` | UNVERIFIED | UNVERIFIED | UNVERIFIED | NO |
| 11 | **Pangu2Staking** | `0x6CA7044Baf9336c572F1EE049a3288099c23e894` | UNVERIFIED | UNVERIFIED | UNVERIFIED | NO |

## Runtime Bytecode Hashes

All bytecode hashes are UNVERIFIED. Run `validate-deployment.sh` with BSC Testnet RPC access to populate.

| # | Contract | Runtime Bytecode Hash (keccak256) | Verified |
|---|---|---|---|
| 1 | Pangu2Token | UNVERIFIED | NO |
| 2 | CostBasisManager | UNVERIFIED | NO |
| 3 | V2 Pair | UNVERIFIED | NO |
| 4 | PancakeV2Adapter | UNVERIFIED | NO |
| 5 | PancakeV2TwapOracle | UNVERIFIED | NO |
| 6 | SupportPool | UNVERIFIED | NO |
| 7 | FeeVault | UNVERIFIED | NO |
| 8 | BuybackLocker | UNVERIFIED | NO |
| 9 | DividendDistributor | UNVERIFIED | NO |
| 10 | Pangu2TradeRouter | UNVERIFIED | NO |
| 11 | Pangu2Staking | UNVERIFIED | NO |

## ABI Hashes

ABI hashes are UNVERIFIED. Run `validate-deployment.sh` to compute from Foundry artifacts.

| # | Contract | ABI keccak256 Hash | Verified |
|---|---|---|---|
| 1 | Pangu2Token | UNVERIFIED | NO |
| 2 | CostBasisManager | UNVERIFIED | NO |
| 3 | PancakeV2Adapter | UNVERIFIED | NO |
| 4 | PancakeV2TwapOracle | UNVERIFIED | NO |
| 5 | SupportPool | UNVERIFIED | NO |
| 6 | FeeVault | UNVERIFIED | NO |
| 7 | BuybackLocker | UNVERIFIED | NO |
| 8 | DividendDistributor | UNVERIFIED | NO |
| 9 | Pangu2TradeRouter | UNVERIFIED | NO |
| 10 | Pangu2Staking | UNVERIFIED | NO |

## Constructor Arguments

| Contract | Constructor Args | Verified |
|---|---|---|
| Pangu2Token | `(initialHolder, governance, emergencyAccount)` | NO |
| CostBasisManager | `(token, governance)` | NO |
| PancakeV2Adapter | `(token, wbnb, factory, pair, router, governance)` | NO |
| PancakeV2TwapOracle | `(token, wbnb, factory, pair, twapWindow=1800, deviation=300, minTokenRes, minWbnbRes)` | NO |
| SupportPool | `(token, wbnb, adapter, oracle, buybackBps=300, interval=300, governance, emergency)` | NO |
| FeeVault | `(token, wbnb, adapter, oracle, supportPool, threshold=1e24, sellBps=300, governance, keeper, emergency)` | NO |
| BuybackLocker | `(token, supportPool, FIXED_DURATION, 365 days, releaseRecipient)` | NO |
| DividendDistributor | `(token, costBasis, governance, rootPublisher, emergency)` | NO |
| Pangu2TradeRouter | `(token, wbnb, costBasis, adapter, oracle, governance, emergency)` | NO |
| Pangu2Staking | `(token, governance)` | NO |

## Pair-Oracle-Adapter Bindings

| Binding | Expected Relationship | Verified |
|---|---|---|
| oracle.pair == pair | Oracle monitors this pair | NO |
| oracle.token == token | Oracle token matches | NO |
| adapter pair == pair | Adapter targets this pair | NO |
| pair.token0 in {token, wbnb} | Pair contains correct tokens | NO |
| pair.token1 in {token, wbnb} | Pair contains correct tokens | NO |
| Factory.getPair(token,wbnb) == pair | Factory confirms pair | NO |

## Governance Role Permissions

| Contract | Role | Expected Holder | Verified |
|---|---|---|---|
| Pangu2Token | DEFAULT_ADMIN_ROLE | Governance | NO |
| Pangu2Token | GOVERNANCE_ROLE | Governance | NO |
| Pangu2Token | UNPAUSER_ROLE | Governance | NO |
| Pangu2Token | SETTLEMENT_ROLE | TradeRouter only | NO |
| CostBasisManager | GOVERNANCE_ROLE | Governance | NO |
| PancakeV2Adapter | CALLER_ROLE | TradeRouter, FeeVault, SupportPool | NO |
| SupportPool | GOVERNANCE_ROLE | Governance | NO |
| FeeVault | GOVERNANCE_ROLE | Governance | NO |
| Pangu2Staking | REWARD_MANAGER_ROLE | Governance | NO |

## Transfer Context Registrations

| System Contract | Context Kind | Required | Verified |
|---|---|---|---|
| DividendDistributor | DIVIDEND_CLAIM | YES | NO |
| BuybackLocker | SYSTEM_CREDIT_UNKNOWN | YES | NO |
| Pangu2Staking | STAKING_DEPOSIT | YES | NO |
| Pangu2Staking | STAKING_PRINCIPAL_RETURN | YES | NO |
| Pangu2Staking | STAKING_REWARD | YES | NO |

## Key Parameters

| Parameter | Value | Source |
|---|---|---|
| Chain ID | 97 | BSC Testnet |
| TWAP Window | 30 min (1800s) | PancakeV2TwapOracle |
| Max Spot/TWAP Deviation | 300 bps (3%) | PancakeV2TwapOracle |
| Min Token Reserve | Configurable | DeployPangu2 minTokenReserve |
| Min WBNB Reserve | Configurable | DeployPangu2 minWbnbReserve |
| Buyback Lock Duration | 365 days | BuybackLocker |
| SupportPool Buyback Amount | 0.01 BNB | SupportPool.BUYBACK_AMOUNT |
| Staking Reward Manager | Governance | Pangu2Staking |
| Staking Max Reward Rate | ~1 token/day | Pangu2Staking.MAX_REWARD_RATE |
| Staking Early Unstake Penalty | 1000 bps (10%) | Pangu2Staking |
| Staking Max Lock | 730 days | Pangu2Staking |
| Staking Min Stake | 1 ether | Pangu2Staking |

## Deploy Stage Status

| Stage | Status | Required | Notes |
|---|---|---|---|
| **Stage 1: Deploy** | **UNVERIFIED** | `forge script DeployPangu2.s.sol --broadcast --rpc-url <bsc-testnet>` | 11 contracts must be on-chain |
| **Stage 2: Bootstrap** | **PENDING** | `forge script BootstrapPangu2.s.sol --broadcast --rpc-url <bsc-testnet>` | Requires GOV + LP + HOLDER private keys |
| **Stage 3: Finalize** | **PENDING** | `forge script FinalizePangu2.s.sol --broadcast --rpc-url <bsc-testnet>` | Wait 30min TWAP after Bootstrap |

## Bootstrap Role Addresses

| Role | Address | Source |
|---|---|---|
| Governance | `0xD34E41b719BA5a613E36948F0f008B1bc4eC4FF2` | contracts-v2/.env GOVERNANCE_ADDRESS |
| Initial Holder | `0x6E257B171338BDe98fa1eA3aa62C41AfB0864C53` | contracts-v2/.env INITIAL_HOLDER_ADDRESS |
| LP Recipient | `0x6E257B171338BDe98fa1eA3aa62C41AfB0864C53` | contracts-v2/.env LP_RECIPIENT |
| Emergency | `0xED18a129d61c855ba713b878F6BFE9a2B77ABcB4` | contracts-v2/.env EMERGENCY_ADDRESS |
| Keeper | `0xED18a129d61c855ba713b878F6BFE9a2B77ABcB4` | contracts-v2/.env KEEPER_ADDRESS |
| Release Recipient | `0xED18a129d61c855ba713b878F6BFE9a2B77ABcB4` | contracts-v2/.env RELEASE_RECIPIENT_ADDRESS |
| Root Publisher | `0xED18a129d61c855ba713b878F6BFE9a2B77ABcB4` | contracts-v2/.env ROOT_PUBLISHER_ADDRESS |

> **WARNING:** Keeper, Emergency, Release Recipient, and Root Publisher share the same address (`0xED18...`).
> This is acceptable for testnet only. Mainnet deployment requires unique addresses per role.

## Config File Address Cross-Reference

| Contract | contracts-v2/.env | backend/.env.example | dapp/.env | admin/.env | worker/.env |
|---|---|---|---|---|---|
| Token | `0xaf2bD8...` | empty | `0xaf2bD8...` | — | — |
| TradeRouter | `0x16f541...` | empty | `0x16f541...` | — | `0x16f541...` |
| DividendDistributor | `0x6265b6...` | empty | — | — | `0x6265b6...` |
| Staking | `0x6CA704...` | empty | `0x6CA704...` | — | — |
| Oracle | `0xf16c14...` | — | — | — | — |
| Pair | `0x0Fe75c...` | — | — | — | — |
| Adapter | `0xb3F319...` | — | — | — | — |
| SupportPool | `0x91F8cE...` | empty | — | — | — |
| FeeVault | `0xEF1775...` | empty | — | — | — |
| Locker | `0xBeDc42...` | empty | — | — | — |

**Backend .env.example is completely empty** — must be populated before staging deployment.

## Validation Scripts

Run `scripts/validate-deployment.sh` to verify:
1. `eth_getCode` on all 11 contracts
2. `eth_getTransactionReceipt` for deploy transactions
3. Runtime bytecode hash matches compiled artifacts
4. ABI hash matches compiled artifacts
5. Pair token0/token1 match token and WBNB
6. Factory.getPair confirms pair
7. oracle.pair == pair, oracle.token == token
8. Governance roles on all contracts
9. Transfer context registrations
10. Deployer has renounced all admin roles
11. Address consistency across all 5 config files

---

## Next Steps

1. **Run `scripts/validate-deployment.sh`** with BSC Testnet RPC access
2. Fill in all UNVERIFIED fields from validation output
3. Verify deploy transactions on BscScan
4. Execute Bootstrap with real keys
5. Wait 30 minutes, execute Finalize
6. Promote to AUTHORITATIVE status
