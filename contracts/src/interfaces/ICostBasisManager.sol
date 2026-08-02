// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface ICostBasisManager {
    enum PositionStatus {
        NONE,
        KNOWN,
        UNKNOWN
    }

    struct Position {
        uint256 costWbnbWei;
        uint256 trackedBalance;
        PositionStatus status;
    }

    function positionOf(address account) external view returns (Position memory);
    function liquidityPositionOf(address account) external view returns (Position memory);
    function lpPositionFor(address account, uint256 tokenId) external view returns (Position memory);
    function proportionalCost(address account, uint256 tokenAmount)
        external view returns (uint256 costWbnbWei, PositionStatus status);

    function recordBuy(address account, uint256 costWbnbWei, uint256 netTokenAmount) external;
    function recordZeroCost(address account, uint256 tokenAmount) external;
    function markUnknown(address account, uint256 tokenAmount, bytes32 reason) external;
    function consumeSell(address account, uint256 tokenAmount)
        external returns (uint256 consumedCostWbnbWei, PositionStatus previousStatus);
    function onUserTransfer(address from, address to, uint256 tokenAmount) external;
    function onLiquidityDeposit(address account, uint256 tokenAmount) external;
    function onLiquidityWithdrawal(address account, uint256 tokenAmount) external;
    function onLiquidityFeeCollection(address account, uint256 tokenAmount) external;
    function onSystemCreditUnknown(address account, uint256 tokenAmount, bytes32 reason) external;
    function setSystemAddress(address account, bool enabled) external;

    function bindLpTokenId(address account, uint256 tokenId, uint256 tokenUsed, uint256 wbnbUsed) external;
    function consumeLpTokenId(address account, uint256 tokenId, uint256 actualTokenReturned)
        external returns (uint256 clearedTracked, uint256 clearedCost);
    function migrateLpCost(address from, address to, uint256 tokenId)
        external returns (uint256 costWbnbWei, uint256 trackedTokens);

    function lpTrackedTotal(address account) external view returns (uint256);
    function lpCostTotal(address account) external view returns (uint256);
}
