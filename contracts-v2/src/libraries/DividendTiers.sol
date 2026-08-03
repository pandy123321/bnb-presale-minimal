// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { FullMath } from "./FullMath.sol";

/// @notice Off-chain reference for Top-100 holder tier allocation.
/// @dev THIS IS A REFERENCE LIBRARY — DividendDistributor does NOT call it.
///
///      Trust boundary:
///      - The off-chain Merkle Root Builder is the trusted computation boundary.
///      - It MUST use these percentages and prove via Artifact Checksum.
///      - The DividendDistributor contract verifies only the Merkle proof
///        (account ∈ root, amount, chainId, epochId, rewardToken) — NOT rank
///        position or tier membership.
///      - Governance + Root Publisher dual-approval gates ensure the root was
///        computed by an authorized off-chain process.
///
///      Allocation rules (enforced off-chain only):
///      - Rank 1–10  : 35% of epoch total
///      - Rank 11–30 : 25%
///      - Rank 31–60 : 25%
///      - Rank 61–100: 15%
///      - Within each tier, split proportionally by effective holdings.
///      - Total allocation must equal epoch totalAmount (verified via Merkle).
///
///      WARNING: Without a deployed Root Builder, this library is purely
///      documentary. Deploying without a verified Root Builder process is a
///      blocking item.
library DividendTiers {
    uint16 internal constant BPS_DENOMINATOR = 10_000;
    // Rank 1–10  : 35%
    uint16 internal constant TIER_1_BPS = 3500;
    // Rank 11–30 : 25%
    uint16 internal constant TIER_2_BPS = 2500;
    // Rank 31–60 : 25%
    uint16 internal constant TIER_3_BPS = 2500;
    // Rank 61–100: 15%
    uint16 internal constant TIER_4_BPS = 1500;

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
