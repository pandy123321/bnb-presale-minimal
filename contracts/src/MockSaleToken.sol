// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Presale Test Token
/// @notice 仅用于本地和 BSC Testnet 测试的标准 ERC-20/BEP-20 代币。
/// @dev 无转账税、无黑名单、无钱包上限，符合第一期私募代币准入要求。
contract MockSaleToken is ERC20 {
    /// @notice 部署时把全部初始供应量铸造给指定接收人。
    /// @param initialHolder 初始代币持有人。
    /// @param initialSupplyRaw 初始供应量，使用最小代币单位。
    constructor(address initialHolder, uint256 initialSupplyRaw) ERC20("Presale Test Token", "PST") {
        if (initialHolder == address(0)) revert ERC20InvalidReceiver(address(0));
        _mint(initialHolder, initialSupplyRaw);
    }
}
