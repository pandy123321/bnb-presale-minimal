# PB-S1 Dependency Lock

- Solidity compiler: `0.8.24` (`pragma solidity 0.8.24` in every source)
- Foundry stable: `v1.7.1`
- OpenZeppelin Contracts: `v5.0.2`
- forge-std: `v1.16.2`
- EVM target: `paris`

Install exactly:

```bash
forge install OpenZeppelin/openzeppelin-contracts@v5.0.2 --no-git
forge install foundry-rs/forge-std@v1.16.2 --no-git
```

Do not upgrade dependencies inside PB-S1 without a new approved Task/Decision.
