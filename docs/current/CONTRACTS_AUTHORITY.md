# PANGU2 Contracts Authority

## Active Contract Source: `contracts-v2/` (AUTHORITATIVE)

Active deployment contracts for BSC Testnet. This is the **primary** contract directory.

Full deployment manifest: [`docs/current/DEPLOYMENT_MANIFEST.md`](./DEPLOYMENT_MANIFEST.md)

### Contract Registry

| # | Contract | Address (Testnet) | Deploy Tx | Verified |
|---|---|---|---|---|
| 1 | Pangu2Token | `0xaf2bD8bF6b1a0E6B94c2b10150F9184D142eef1C` | UNVERIFIED | NO |
| 2 | CostBasisManager | `0x384492a27ECC0Eb0A2b35FdE719fbb6ae2b4DbAF` | UNVERIFIED | NO |
| 3 | V2 Pair (PANGU2/WBNB) | `0x0Fe75c3460ed320649e133C1AA454881bC6c8b2E` | UNVERIFIED | NO |
| 4 | PancakeV2Adapter | `0xb3F319303655C61559593cb2968e438F789c79D5` | UNVERIFIED | NO |
| 5 | PancakeV2TwapOracle | `0xf16c14B412E69dA6793497AAdf52e38284BcF300` | UNVERIFIED | NO |
| 6 | SupportPool | `0x91F8cEe7E08E5DC5f30d0582085af1fDE791D0A9` | UNVERIFIED | NO |
| 7 | FeeVault | `0xEF17753B7c690800EA65449A26491887c32536c8` | UNVERIFIED | NO |
| 8 | BuybackLocker | `0xBeDc42556ea3312dd643dcE133ed3b5bB5a1C957` | UNVERIFIED | NO |
| 9 | DividendDistributor | `0x6265b64de9a3f7198E40082ea82BAcCAfD1E14CB` | UNVERIFIED | NO |
| 10 | Pangu2TradeRouter | `0x16f5418A4A2D7D8675228fe2230A565e595954fe` | UNVERIFIED | NO |
| 11 | Pangu2Staking | `0x6CA7044Baf9336c572F1EE049a3288099c23e894` | UNVERIFIED | NO |

> **EVERY FIELD ABOVE REQUIRES ON-CHAIN VERIFICATION.** Run `scripts/validate-deployment.sh`
> from a machine with BSC Testnet RPC access. Until then, treat all addresses as UNVERIFIED.

### Source Commits (Phase 1-7 Repair Chain)

| Phase | Commit | Description | Audit |
|---|---|---|---|
| P1 | `c3ce8e1` | Staking TransferContext + controlled deposit flow | Pending |
| P2 | `d435aa3` | Oracle counterfactual TWAP | Pending |
| P3 | `393506c` | Bootstrap governance/liquidity role separation | Pending |
| P4 | `aed668e` | Chain worker lease fencing + lossless projection | Pending |
| P5 | `b6df5b8` | Backend data status + OpenAPI schema | Pending |
| P6 | `8874271` | DApp mock cleanup + UI workspace | Pending |

All Phase 1-7 commits are compiled and tested locally. External review has been
submitted via `user-ai-code-review` jobs. See `docs/current/MODULE_STATUS.md` for
audit status.

### Audit Chain

```
Phase 1-7 current audit chain (submitted, awaiting results):
  P1: c3ce8e1 (staking)       → submitted
  P2: d435aa3 (oracle)        → submitted
  P3: 393506c (bootstrap)     → submitted
  P4: aed668e (chain-worker)  → submitted
  P5: b6df5b8 (backend-api)   → submitted
  P6: 8874271 (dapp-ui)       → submitted
  P7: <current> (docs)        → pending submission
```

## Deployment Stage Flow

```
Stage 1: Deploy
  forge script DeployPangu2.s.sol --broadcast --rpc-url <bsc-testnet>
  → 11 contracts on-chain (UNVERIFIED — awaiting validate-deployment.sh)

Stage 2: Bootstrap (PENDING)
  forge script BootstrapPangu2.s.sol --broadcast --rpc-url <bsc-testnet>
  → Add initial liquidity + Oracle anchor
  Requires 3 independent private keys: GOVERNANCE, LP, INITIAL_HOLDER

Stage 3: Finalize (PENDING)
  forge script FinalizePangu2.s.sol --broadcast --rpc-url <bsc-testnet>
  → Confirm Oracle READY after 30min TWAP window
  → Validate all pair-oracle-adapter bindings
  → Validate governance permissions
```

## Governance

| Role | Address | Source |
|---|---|---|
| Governance | `0xD34E41b719BA5a613E36948F0f008B1bc4eC4FF2` | contracts-v2/.env |
| Initial Holder | `0x6E257B171338BDe98fa1eA3aa62C41AfB0864C53` | contracts-v2/.env |
| Deployer | UNVERIFIED (renounced all admin roles per DeployPangu2.s.sol stage 7) | — |

## Hard Constraints

- **BSC Mainnet (chain 56): PERMANENTLY BLOCKED** in `DeployPangu2.s.sol`
- **Deployer must differ from Governance** (asserted in deploy script)
- **No contract addresses may be committed to Mainnet env files**
- **All deploy private keys are never committed** (in .gitignore)

## Superseded Documents

- `docs/evidence/PB-S6/P2-I04/DEPLOYMENT_MANIFEST.md` — SUPERSEDED by `docs/current/DEPLOYMENT_MANIFEST.md`
- `contracts/` — LEGACY V3 code, NOT deployed, retained for reference

## Next Actions

1. Run `scripts/validate-deployment.sh` with BSC Testnet RPC
2. Fill UNVERIFIED fields from validation output
3. Execute Bootstrap + Finalize
4. Promote manifest to AUTHORITATIVE
