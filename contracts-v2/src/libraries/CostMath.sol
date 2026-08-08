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

    /// @notice Ceiling-rounded proportional cost — used for profit/loss classification.
    ///         Never use floor-rounded cost for 4%/10% tax decisions (P1-TAX-02).
    function proportionalCeil(uint256 totalCost, uint256 amount, uint256 trackedBalance)
        internal
        pure
        returns (uint256)
    {
        if (trackedBalance == 0) revert InvalidTrackedBalance();
        if (amount >= trackedBalance) return totalCost;
        return FullMath.mulDivRoundingUp(totalCost, amount, trackedBalance);
    }
}
