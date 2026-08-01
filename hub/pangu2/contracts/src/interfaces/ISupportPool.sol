// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface ISupportPool {
    enum BuybackBlockReason {
        NONE,
        PAUSED,
        LOCKER_NOT_CONFIGURED,
        INSUFFICIENT_BNB,
        COOLDOWN,
        ORACLE_UNAVAILABLE,
        INVALID_QUOTE
    }

    function BUYBACK_AMOUNT() external view returns (uint256);
    function MIN_BUYBACK_INTERVAL() external view returns (uint256);

    function canExecuteBuyback()
        external
        view
        returns (
            bool allowed,
            BuybackBlockReason reason,
            uint256 poolBalance,
            uint256 nextAllowedAt
        );

    function buyback() external returns (uint256 tokenOut);
}
