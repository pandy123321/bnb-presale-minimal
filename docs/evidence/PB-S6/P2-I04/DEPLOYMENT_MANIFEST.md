# PANGU2 BSC Testnet Deployment Manifest

- **Network:** BSC Testnet (Chain ID: 97)
- **Date:** TBD (to be filled after deployment)
- **Deployer Address:** TBD
- **Compiler:** Solidity 0.8.24 + Foundry
- **Repository:** `E:\github\bnb\bnb-presale-minimal` / `contracts/`

## Contract Registry

| ID | Contract | Address | Deploy Tx Hash | Block | ABI Version |
|---|---|---|---|---|---|
| 1 | Pangu2Token | `TBD` | `TBD` | `TBD` | 1.0.0 |
| 2 | Pangu2TradeRouter | `TBD` | `TBD` | `TBD` | 1.0.0 |
| 3 | DividendDistributor | `TBD` | `TBD` | `TBD` | 1.0.0 |
| 4 | SupportPool | `TBD` | `TBD` | `TBD` | 1.0.0 |
| 5 | BuybackLocker | `TBD` | `TBD` | `TBD` | 1.0.0 |
| 6 | FeeVault | `TBD` | `TBD` | `TBD` | 1.0.0 |
| 7 | CostBasisManager | `TBD` | `TBD` | `TBD` | 1.0.0 |
| 8 | GovernanceAdapter | `TBD` | `TBD` | `TBD` | 1.0.0 |
| 9 | Timelock | `TBD` | `TBD` | `TBD` | 1.0.0 |

## Constructor Parameters

### Pangu2Token
```solidity
constructor(
    string name,        // "PANGU2"
    string symbol,      // "PANGU2"
    uint256 totalSupply // 1,000,000,000 × 10^18
)
```

### Pangu2TradeRouter
```solidity
constructor(
    address _token,          // Pangu2Token address
    address _feeVault,       // FeeVault address
    address _supportPool,    // SupportPool address
    address _dividendDist,   // DividendDistributor address
    address _costBasisMgr,   // CostBasisManager address
    address _buybackLocker,  // BuybackLocker address
    address _treasury        // Treasury multisig
)
```

## Verification

All contracts verified on BscScan with flattened source + compiler metadata.

### Verification Commands (post-deployment)

```bash
# Deploy
forge script script/DeployPangu2.s.sol \
  --rpc-url "$BSC_TESTNET_RPC_URL" \
  --broadcast \
  --verify \
  --verifier blockscout \
  --verifier-url https://api-testnet.bscscan.com/api \
  -vvv
```

## Exclusions

This manifest does **NOT** include:
- Private keys
- RPC API keys  
- Treasury multisig member addresses (separate security document)
- Mainnet addresses or configurations

## Verification Checklist

- [ ] All `TBD` fields filled with actual values after deployment
- [ ] Each contract address verified on BscScan (https://testnet.bscscan.com)
- [ ] Deploy tx hash returns successful receipt for each contract
- [ ] ABI version matches `contracts/out/*.json` MD5 checksums
- [ ] No private keys, mnemonics, or API keys in this document
