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
    function proportionalCost(address account, uint256 tokenAmount)
        external
        view
        returns (uint256 costWbnbWei, PositionStatus status);

    function recordBuy(address account, uint256 costWbnbWei, uint256 netTokenAmount) external;
    function recordZeroCost(address account, uint256 tokenAmount) external;
    function markUnknown(address account, uint256 tokenAmount, bytes32 reason) external;
    function consumeSell(address account, uint256 tokenAmount)
        external
        returns (uint256 consumedCostWbnbWei, PositionStatus previousStatus);
    function onUserTransfer(address from, address to, uint256 tokenAmount) external;
    function onLiquidityDeposit(address account, uint256 tokenAmount) external;
    function onLiquidityWithdrawal(address account, uint256 tokenAmount) external;
    function onSystemCreditUnknown(address account, uint256 tokenAmount, bytes32 reason) external;
    function setSystemAddress(address account, bool enabled) external;
}
