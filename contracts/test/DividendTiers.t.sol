// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {DividendTiers} from "pangu2/libraries/DividendTiers.sol";

contract DividendTiersHarness {
    function bps(uint256 rank) external pure returns (uint16) {
        return DividendTiers.bpsForRank(rank);
    }

    function pool(uint256 amount, uint16 tierBps) external pure returns (uint256) {
        return DividendTiers.tierPool(amount, tierBps);
    }

    function totalBps() external pure returns (uint16) {
        return DividendTiers.totalBps();
    }
}

contract DividendTiersTest is Test {
    DividendTiersHarness internal harness = new DividendTiersHarness();

    function testFrozenTierBoundaries() public view {
        assertEq(harness.bps(1), 3_500);
        assertEq(harness.bps(10), 3_500);
        assertEq(harness.bps(11), 3_000);
        assertEq(harness.bps(30), 3_000);
        assertEq(harness.bps(31), 2_000);
        assertEq(harness.bps(60), 2_000);
        assertEq(harness.bps(61), 1_500);
        assertEq(harness.bps(100), 1_500);
    }

    function testTierBpsMustSumToTenThousand() public view {
        assertEq(harness.totalBps(), 10_000);
    }

    function testTierPoolsSumToEpochAmount() public view {
        uint256 amount = 1_000_000 ether;
        uint256 sum = harness.pool(amount, 3_500) + harness.pool(amount, 3_000)
            + harness.pool(amount, 2_000) + harness.pool(amount, 1_500);
        assertEq(sum, amount);
    }
}
