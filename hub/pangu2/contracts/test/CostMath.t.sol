// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {CostMath} from "pangu2/libraries/CostMath.sol";

contract CostMathHarness {
    function proportional(uint256 cost, uint256 amount, uint256 tracked) external pure returns (uint256) {
        return CostMath.proportionalFloor(cost, amount, tracked);
    }
}

contract CostMathTest is Test {
    CostMathHarness internal harness = new CostMathHarness();

    function testFullTransferMovesAllRemainingCost() public view {
        assertEq(harness.proportional(101, 7, 7), 101);
    }

    function testFuzz_ProportionalCostNeverExceedsTotal(uint128 cost, uint128 amount, uint128 tracked) public view {
        vm.assume(tracked > 0);
        uint256 result = harness.proportional(cost, amount, tracked);
        assertLe(result, cost);
        if (amount >= tracked) assertEq(result, cost);
    }
}
