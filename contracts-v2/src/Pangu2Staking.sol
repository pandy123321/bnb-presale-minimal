// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPangu2Staking} from "./interfaces/IPangu2Staking.sol";

contract Pangu2Staking is ReentrancyGuard, IPangu2Staking {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    uint256 public override totalStaked;
    uint256 public rewardRate;        // reward tokens per second per staked token (scaled by 1e18)
    uint256 public lastRewardTime;    // last timestamp rewards were updated
    uint256 public rewardPerTokenStored; // accumulated reward per token (scaled 1e18)
    uint16 public constant EARLY_UNSTAKE_PENALTY_BPS = 1000; // 10% penalty

    address public rewardSource;      // address that can fund rewards

    mapping(address => StakePosition[]) private _positions;
    mapping(address => uint256) public override userPositionCount;

    mapping(address => uint256) private _userRewardPerTokenPaid;
    mapping(address => uint256) private _rewards;

    error ZeroAddress();
    error InvalidAmount();
    error InvalidLockDuration();
    error PositionNotFound();
    error StillLocked(uint256 unlockAt);
    error AlreadyClaimed();
    error NotPositionOwner();
    error TransferFailed();

    event RewardFunded(address indexed funder, uint256 amount);
    event RewardRateUpdated(uint256 newRate);

    constructor(address token_, address rewardSource_) {
        if (token_ == address(0) || rewardSource_ == address(0)) revert ZeroAddress();
        token = IERC20(token_);
        rewardSource = rewardSource_;
    }

    // ── Modifiers ──────────────────────────────

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastRewardTime = block.timestamp;
        if (account != address(0)) {
            _rewards[account] = earned(account);
            _userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    // ── Reward Accounting ─────────────────────

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) return rewardPerTokenStored;
        return rewardPerTokenStored + (rewardRate * (block.timestamp - lastRewardTime) * 1e18) / totalStaked;
    }

    function earned(address account) public view returns (uint256) {
        uint256 accumulated = 0;
        for (uint256 i = 0; i < _positions[account].length; i++) {
            StakePosition storage pos = _positions[account][i];
            if (pos.claimed) continue;
            accumulated += (pos.amount * (rewardPerToken() - _userRewardPerTokenPaid[account])) / 1e18;
        }
        return accumulated + _rewards[account];
    }

    function setRewardRate(uint256 rate) external {
        require(msg.sender == rewardSource, "only reward source");
        rewardRate = rate;
        emit RewardRateUpdated(rate);
    }

    // ── Core Actions ──────────────────────────

    function stake(uint256 amount, uint64 lockSeconds)
        external
        nonReentrant
        updateReward(msg.sender)
        returns (uint256 positionId)
    {
        if (amount == 0) revert InvalidAmount();
        if (lockSeconds == 0 || lockSeconds > 730 days) revert InvalidLockDuration();

        token.safeTransferFrom(msg.sender, address(this), amount);

        uint64 unlockAt = uint64(block.timestamp) + lockSeconds;
        positionId = _positions[msg.sender].length;

        _positions[msg.sender].push(StakePosition({
            amount: amount,
            rewardDebt: 0,
            lockedAt: uint64(block.timestamp),
            unlockAt: unlockAt,
            claimed: false
        }));

        userPositionCount[msg.sender] = positionId + 1;
        totalStaked += amount;

        emit Staked(msg.sender, amount, unlockAt, positionId);
    }

    function unstake(uint256 positionId)
        external
        nonReentrant
        updateReward(msg.sender)
        returns (uint256 amount, uint256 reward)
    {
        _requireOwnPosition(msg.sender, positionId);
        StakePosition storage pos = _positions[msg.sender][positionId];
        if (pos.claimed) revert AlreadyClaimed();
        if (block.timestamp < pos.unlockAt) revert StillLocked(pos.unlockAt);

        amount = pos.amount;
        reward = _rewards[msg.sender];
        pos.claimed = true;
        totalStaked -= amount;
        _rewards[msg.sender] = 0;

        if (reward > 0) {
            // Rewards come from the rewardSource having pre-funded this contract
            token.safeTransfer(msg.sender, amount + reward);
        } else {
            token.safeTransfer(msg.sender, amount);
        }

        emit Unstaked(msg.sender, amount, reward, positionId);
    }

    function earlyUnstake(uint256 positionId)
        external
        nonReentrant
        updateReward(msg.sender)
        returns (uint256 amount, uint256 penalty)
    {
        _requireOwnPosition(msg.sender, positionId);
        StakePosition storage pos = _positions[msg.sender][positionId];
        if (pos.claimed) revert AlreadyClaimed();
        if (block.timestamp >= pos.unlockAt) revert("use unstake() instead");

        amount = pos.amount;
        penalty = (amount * EARLY_UNSTAKE_PENALTY_BPS) / 10000;
        uint256 netAmount = amount - penalty;
        pos.claimed = true;
        totalStaked -= amount;
        _rewards[msg.sender] = 0; // forfeit all rewards on early exit

        // Penalty stays in contract (acts as additional staking reward pool)
        token.safeTransfer(msg.sender, netAmount);

        emit EarlyUnstake(msg.sender, amount, penalty, positionId);
    }

    function positions(address user, uint256 positionId)
        external view override returns (StakePosition memory)
    {
        return _positions[user][positionId];
    }

    function _requireOwnPosition(address user, uint256 positionId) private view {
        if (positionId >= _positions[user].length) revert PositionNotFound();
    }
}
