// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {DividendTiers} from "pangu2/libraries/DividendTiers.sol";

contract DividendTiersHarness {
    function bps(uint256 rank) external pure returns (uint16) {
        return DividendTiers.bpsForRank(rank);
    }

    function totalBps() external pure returns (uint256) {
        return DividendTiers.totalTierBps();
    }

    function assertValid() external pure {
        DividendTiers.assertValidConfiguration();
    }

    function pool(uint256 amount, uint16 tierBps) external pure returns (uint256) {
        return DividendTiers.tierPool(amount, tierBps);
    }

    function reward(uint256 tierPoolAmount, uint256 userBalance, uint256 tierBalanceTotal)
        external
        pure
        returns (uint256)
    {
        return DividendTiers.userReward(tierPoolAmount, userBalance, tierBalanceTotal);
    }
}

contract DividendTiersTest is Test {
    DividendTiersHarness internal harness = new DividendTiersHarness();

    function testApprovedTierBoundariesRemainUnchangedPendingDecision() public view {
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
        harness.assertValid();
    }

    function testTierPoolsNeverExceedEpochAndRemainderCarries() public view {
        uint256 amount = 1_000_003;
        uint256 sum = harness.pool(amount, 3_500) + harness.pool(amount, 3_000)
            + harness.pool(amount, 2_000) + harness.pool(amount, 1_500);
        assertLe(sum, amount);
        assertEq(amount - sum, 2);
    }

    function testUserRewardUsesEffectiveBalanceAndFloorsRemainder() public view {
        uint256 tierPoolAmount = 1_000;
        uint256 first = harness.reward(tierPoolAmount, 1, 3);
        uint256 second = harness.reward(tierPoolAmount, 2, 3);
        assertEq(first, 333);
        assertEq(second, 666);
        assertEq(tierPoolAmount - first - second, 1);
    }

    function testUserRewardRejectsInvalidEffectiveBalance() public {
        vm.expectRevert(DividendTiers.InvalidEffectiveBalance.selector);
        harness.reward(1_000, 1, 0);

        vm.expectRevert(DividendTiers.InvalidEffectiveBalance.selector);
        harness.reward(1_000, 101, 100);
    }
}
