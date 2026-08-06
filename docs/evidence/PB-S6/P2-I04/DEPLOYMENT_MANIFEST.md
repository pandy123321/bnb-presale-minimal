# PANGU2 V2 BSC Testnet Deployment Manifest

> **STATUS: SUPERSEDED** — replaced by [`docs/current/DEPLOYMENT_MANIFEST.md`](../current/DEPLOYMENT_MANIFEST.md)
> This file is retained for historical reference only. The new manifest includes
> bytecode hashes, constructor args, ABI hashes, and a full verification matrix.
> All deployment status claims in this document were unverifiable at time of archiving.

- **Network:** BSC Testnet (Chain ID: 97)
- **Date:** 2026-08-05 (superseded 2026-08-06)
- **Reason for supersession:** Missing bytecode hashes, constructor args, ABI hashes, deploy tx evidence, and independent verification.
- **Deployer Address:** `0x6E257B171338BDe98fa1eA3aa62C41AfB0864C53`
- **Governance Address:** `0x6E257B171338BDe98fa1eA3aa62C41AfB0864C53`
- **Compiler:** Solidity 0.8.24 + Foundry v1.7.1
- **Framework:** PancakeSwap V2 (Factory `0x6725F303b657a9451d8BA641348b6761A6CC7a17`, Router `0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3`)

## Contract Registry

| # | Contract | Address | Deploy Tx |
|---|---|---|---|
| 1 | Pangu2Token | `0xaf2bD8bF6b1a0E6B94c2b10150F9184D142eef1C` | `0x6920e9a4a273b5e7b7c1b7dee19ef98c6d6aff5ac6fe87dc7cdd995c4145a94a` |
| 2 | CostBasisManager | `0x384492a27ECC0Eb0A2b35FdE719fbb6ae2b4DbAF` | TBD |
| 3 | V2 Pair (PANGU2/WBNB) | `0x0Fe75c3460ed320649e133C1AA454881bC6c8b2E` | TBD |
| 4 | PancakeV2Adapter | `0xb3F319303655C61559593cb2968e438F789c79D5` | TBD |
| 5 | PancakeV2TwapOracle | `0xf16c14B412E69dA6793497AAdf52e38284BcF300` | TBD |
| 6 | SupportPool | `0x91F8cEe7E08E5DC5f30d0582085af1fDE791D0A9` | TBD |
| 7 | FeeVault | `0xEF17753B7c690800EA65449A26491887c32536c8` | TBD |
| 8 | BuybackLocker | `0xBeDc42556ea3312dd643dcE133ed3b5bB5a1C957` | TBD |
| 9 | DividendDistributor | `0x6265b64de9a3f7198E40082ea82BAcCAfD1E14CB` | TBD |
| 10 | Pangu2TradeRouter | `0x16f5418A4A2D7D8675228fe2230A565e595954fe` | TBD |
| 11 | Pangu2Staking | `0x6CA7044Baf9336c572F1EE049a3288099c23e894` | TBD |

## Bootstrap Status

| Stage | Status | Notes |
|---|---|---|
| Deploy | ✅ Complete | 2026-08-05, 11 contracts deployed |
| Bootstrap | ⏳ Pending | `.\deploy-and-test.ps1 -Bootstrap` |
| Oracle TWAP | ⏳ Pending | Wait 30 min after Bootstrap |
| Finalize | ⏳ Pending | `.\deploy-and-test.ps1 -Finalize` |

## Key Parameters

| Parameter | Value |
|---|---|
| TWAP Window | 30 minutes |
| Max Deviation | 300 bps (3%) |
| Locker Duration | 365 days |
| SupportPool Buyback | 0.01 BNB |

## Config Files (Updated)

All 5 env files have been filled with contract addresses:

| File | Status |
|---|---|
| `contracts-v2/.env` | ✅ Updated |
| `backend/.env` | ✅ Updated |
| `apps/dapp/.env` | ✅ Created |
| `apps/admin/.env` | ✅ Created |
| `services/chain-worker/.env` | ✅ Created |

## Verification Checklist

- [ ] Bootstrap liquidity added (`.\deploy-and-test.ps1 -Bootstrap`)
- [ ] Oracle `update()` called twice (after Bootstrap, after TWAP window)
- [ ] Oracle `validatedQuote()` returns non-zero both directions
- [ ] Each contract verified on BscScan
- [ ] Backend API returns live chain data (not mock)
- [ ] DApp buy/sell flow works end-to-end
