// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {FullMath} from "./FullMath.sol";

/// @notice Frozen PB-S1 reference percentages for the off-chain top-100 Merkle calculation.
library DividendTiers {
    uint16 internal constant BPS_DENOMINATOR = 10_000;
    uint16 internal constant TIER_1_BPS = 3_500; // ranks 1-10
    uint16 internal constant TIER_2_BPS = 3_000; // ranks 11-30
    uint16 internal constant TIER_3_BPS = 2_000; // ranks 31-60
    uint16 internal constant TIER_4_BPS = 1_500; // ranks 61-100

    error RankOutOfRange(uint256 rank);
    error InvalidTierTotal(uint256 totalBps);

    function totalBps() internal pure returns (uint16 total) {
        total = TIER_1_BPS + TIER_2_BPS + TIER_3_BPS + TIER_4_BPS;
        if (total != BPS_DENOMINATOR) revert InvalidTierTotal(total);
    }

    function bpsForRank(uint256 rank) internal pure returns (uint16) {
        if (rank == 0 || rank > 100) revert RankOutOfRange(rank);
        if (rank <= 10) return TIER_1_BPS;
        if (rank <= 30) return TIER_2_BPS;
        if (rank <= 60) return TIER_3_BPS;
        return TIER_4_BPS;
    }

    function tierPool(uint256 epochAmount, uint16 tierBps) internal pure returns (uint256) {
        return FullMath.mulDiv(epochAmount, tierBps, BPS_DENOMINATOR);
    }
}
