// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IPangu2Staking {
    struct StakePosition {
        uint256 amount;
        uint256 rewardDebt;
        uint64 lockedAt;
        uint64 unlockAt;
        bool claimed;
    }

    event Staked(address indexed user, uint256 amount, uint64 unlockAt, uint256 positionId);
    event Unstaked(address indexed user, uint256 amount, uint256 reward, uint256 positionId);
    event EarlyUnstake(address indexed user, uint256 amount, uint256 penalty, uint256 positionId);

    function stake(uint256 amount, uint64 lockSeconds) external returns (uint256 positionId);
    function unstake(uint256 positionId) external returns (uint256 amount, uint256 reward);
    function earlyUnstake(uint256 positionId) external returns (uint256 amount, uint256 penalty);
    function positions(address user, uint256 positionId) external view returns (StakePosition memory);
    function userPositionCount(address user) external view returns (uint256);
    function totalStaked() external view returns (uint256);
}
