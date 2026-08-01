// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {FullMath} from "./FullMath.sol";

/// @notice PB-S1 reference percentages for the off-chain top-100 Merkle calculation.
/// @dev The currently approved ratio remains 35% / 30% / 20% / 15% until a new Decision Record is active.
library DividendTiers {
    uint16 internal constant BPS_DENOMINATOR = 10_000;
    uint16 internal constant TIER_1_BPS = 3_500; // ranks 1-10
    uint16 internal constant TIER_2_BPS = 3_000; // ranks 11-30
    uint16 internal constant TIER_3_BPS = 2_000; // ranks 31-60
    uint16 internal constant TIER_4_BPS = 1_500; // ranks 61-100

    error RankOutOfRange(uint256 rank);
    error InvalidTierTotal(uint256 totalBps);
    error InvalidEffectiveBalance(uint256 userEffectiveBalance, uint256 tierEffectiveBalanceTotal);

    function bpsForRank(uint256 rank) internal pure returns (uint16) {
        if (rank == 0 || rank > 100) revert RankOutOfRange(rank);
        if (rank <= 10) return TIER_1_BPS;
        if (rank <= 30) return TIER_2_BPS;
        if (rank <= 60) return TIER_3_BPS;
        return TIER_4_BPS;
    }

    function totalTierBps() internal pure returns (uint256 totalBps) {
        totalBps = uint256(TIER_1_BPS) + TIER_2_BPS + TIER_3_BPS + TIER_4_BPS;
    }

    function assertValidConfiguration() internal pure {
        uint256 totalBps = totalTierBps();
        if (totalBps != BPS_DENOMINATOR) revert InvalidTierTotal(totalBps);
    }

    function tierPool(uint256 epochAmount, uint16 tierBps) internal pure returns (uint256) {
        assertValidConfiguration();
        return FullMath.mulDiv(epochAmount, tierBps, BPS_DENOMINATOR);
    }

    function userReward(
        uint256 tierPoolAmount,
        uint256 userEffectiveBalance,
        uint256 tierEffectiveBalanceTotal
    ) internal pure returns (uint256 rewardAmount) {
        if (
            tierEffectiveBalanceTotal == 0 || userEffectiveBalance > tierEffectiveBalanceTotal
        ) {
            revert InvalidEffectiveBalance(userEffectiveBalance, tierEffectiveBalanceTotal);
        }
        rewardAmount = FullMath.mulDiv(
            tierPoolAmount, userEffectiveBalance, tierEffectiveBalanceTotal
        );
    }
}
