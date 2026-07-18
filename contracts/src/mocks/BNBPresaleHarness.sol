// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { BNBPresale } from "../BNBPresale.sol";

/// @notice 仅用于覆盖不可从正常外部入口触发的防御性分支，不参与部署。
contract BNBPresaleHarness is BNBPresale {
    constructor(
        address initialOwner,
        address saleTokenAddress,
        address initialTreasuryAddress,
        uint256 initialTokenPerBNB,
        uint256 initialMinPurchaseBNB,
        uint256 initialMaxPurchaseBNB,
        uint256 initialMaxPurchasePerWallet,
        bool initialAllowRepeatPurchase,
        uint256 initialMaxTokensSold
    )
        BNBPresale(
            initialOwner,
            saleTokenAddress,
            initialTreasuryAddress,
            initialTokenPerBNB,
            initialMinPurchaseBNB,
            initialMaxPurchaseBNB,
            initialMaxPurchasePerWallet,
            initialAllowRepeatPurchase,
            initialMaxTokensSold
        )
    { }

    /// @notice 测试 buyer 为零地址的防御性校验。
    function exposedPurchase(address buyer) external payable {
        _purchase(buyer, msg.value);
    }

    /// @notice 测试价格状态被异常破坏为零时的防御性校验。
    function forceSetTokenPerBNB(uint256 value) external {
        tokenPerBNB = value;
    }
}
