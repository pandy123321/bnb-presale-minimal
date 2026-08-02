// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {FullMath} from "./FullMath.sol";

library CostMath {
    error InvalidTrackedBalance();

    function proportionalFloor(uint256 totalCost, uint256 amount, uint256 trackedBalance)
        internal
        pure
        returns (uint256)
    {
        if (trackedBalance == 0) revert InvalidTrackedBalance();
        if (amount >= trackedBalance) return totalCost;
        return FullMath.mulDiv(totalCost, amount, trackedBalance);
    }
}
