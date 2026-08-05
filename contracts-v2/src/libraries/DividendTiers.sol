// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { FullMath } from "./FullMath.sol";

/// @notice Top-100 持有者分档比例参考（仅供链下 Root Builder 使用）
///
///         信任边界说明：
///         - 本库仅用于链下 Merkle Root Builder 的分档比例参照
///         - DividendDistributor 合约不在链上验证排名或分档
///         - 链上只验证 Merkle Proof（account ∈ root, amount, chainId, epochId, rewardToken）
///         - Governance + Root Publisher 双重批准确保 Root 由授权链下流程生成
///
///         分档规则（仅链下执行）：
///         - 排名 1–10   : 总分配额的 35%
///         - 排名 11–30  : 总分配额的 25%
///         - 排名 31–60  : 总分配额的 25%
///         - 排名 61–100 : 总分配额的 15%
///         - 各分档内按有效持币量比例分配
///         - 总分配额必须等于 Epoch totalAmount（通过 Merkle 校验）
///
///         警告：如果没有部署 Root Builder，本库仅作为文档参考。
///         部署前必须完成 Root Builder 实现。
library DividendTiers {
    uint16 internal constant BPS_DENOMINATOR = 10_000;    // 精度基准
    uint16 internal constant TIER_1_BPS = 3500;           // 排名 1–10  : 35%
    uint16 internal constant TIER_2_BPS = 2500;           // 排名 11–30 : 25%
    uint16 internal constant TIER_3_BPS = 2500;           // 排名 31–60 : 25%
    uint16 internal constant TIER_4_BPS = 1500;           // 排名 61–100: 15%

    error RankOutOfRange(uint256 rank);
    error InvalidTierTotal(uint256 totalBps);

    /// 验证四个分档总和恰好等于 100%（10,000 BPS）
    function totalBps() internal pure returns (uint16 total) {
        total = TIER_1_BPS + TIER_2_BPS + TIER_3_BPS + TIER_4_BPS;
        if (total != BPS_DENOMINATOR) revert InvalidTierTotal(total);
    }

    /// 根据排名返回对应分档的 BPS
    function bpsForRank(uint256 rank) internal pure returns (uint16) {
        if (rank == 0 || rank > 100) revert RankOutOfRange(rank);
        if (rank <= 10) return TIER_1_BPS;
        if (rank <= 30) return TIER_2_BPS;
        if (rank <= 60) return TIER_3_BPS;
        return TIER_4_BPS;
    }

    /// 计算分档应分配的总金额
    function tierPool(uint256 epochAmount, uint16 tierBps) internal pure returns (uint256) {
        return FullMath.mulDiv(epochAmount, tierBps, BPS_DENOMINATOR);
    }
}
