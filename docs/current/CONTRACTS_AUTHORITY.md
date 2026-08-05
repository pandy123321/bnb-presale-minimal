# PANGU2 Contracts Authority

## contracts-v2/ (AUTHORITATIVE)

Active deployment contracts for BSC Testnet. This is the **primary** contract directory.

| Contract | Address (Testnet) | Audit Status |
|----------|-------------------|:---:|
| Pangu2Token | `0xaf2bD8bF6b1a0E6B94c2b10150F9184D142eef1C` | Pending |
| CostBasisManager | `0x384492a27ECC0Eb0A2b35FdE719fbb6ae2b4DbAF` | Pending |
| PancakeV2Adapter | `0xb3F319303655C61559593cb2968e438F789c79D5` | Pending |
| PancakeV2TwapOracle | `0xf16c14B412E69dA6793497AAdf52e38284BcF300` | #302 |
| SupportPool | `0x91F8cEe7E08E5DC5f30d0582085af1fDE791D0A9` | Pending |
| FeeVault | `0xEF17753B7c690800EA65449A26491887c32536c8` | Pending |
| BuybackLocker | `0xBeDc42556ea3312dd643dcE133ed3b5bB5a1C957` | Pending |
| DividendDistributor | `0x6265b64de9a3f7198E40082ea82BAcCAfD1E14CB` | Pending |
| Pangu2TradeRouter | `0x16f5418A4A2D7D8675228fe2230A565e595954fe` | Pending |
| Pangu2Staking | `0x6CA7044Baf9336c572F1EE049a3288099c23e894` | #302 |

## contracts/ (LEGACY, V3 PancakeSwap)

Contains V3 PancakeSwap adapter and oracle implementations. **NOT deployed**. Retained for reference only. Raise a breaking-change gate escalation before restoring V3 code.

## Deployment Stage Flow

```
Stage 1: Deploy (deploy-and-test.ps1)
  → 11 contracts on-chain (DONE)
Stage 2: Bootstrap (deploy-and-test.ps1 -Bootstrap)
  → Add initial liquidity + Oracle anchor (PENDING)
Stage 3: Finalize (deploy-and-test.ps1 -Finalize)
  → Confirm Oracle READY after 30min TWAP (PENDING)
```

## Governance

- Deployer renounced all admin roles
- Governance: `0x6E257B171338BDe98fa1eA3aa62C41AfB0864C53`
- Mainnet deployment: NO-GO (chain 56 blocked in DeployPangu2.s.sol)
