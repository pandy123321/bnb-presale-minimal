// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IPangu2Staking} from "./interfaces/IPangu2Staking.sol";

contract Pangu2Staking is AccessControl, ReentrancyGuard, IPangu2Staking {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;

    bytes32 public constant REWARD_MANAGER_ROLE = keccak256("REWARD_MANAGER_ROLE");

    // ── Staked principal ──
    uint256 public override totalStaked;
    mapping(address => uint256) public userTotalStaked;

    // ── Reward state ──
    uint256 public availableRewardReserve;   // funded tokens not yet committed to any period
    uint256 public accruedRewardLiability;  // rewards already emitted by periods but not yet claimed
    uint256 public totalRewardPaid;         // lifetime rewards paid

    uint256 public rewardRate;              // tokens per second (globally across all stakers)
    uint256 public periodFinish;            // when current reward period ends (0 = inactive)
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;    // scaled 1e18

    uint256 public constant MAX_REWARD_RATE = 115740740740740; // ~1 token/day at 18 decimals
    uint16 public constant EARLY_UNSTAKE_PENALTY_BPS = 1000;
    uint64 public constant MAX_LOCK_SECONDS = 730 days;
    uint256 public constant MIN_STAKE = 1 ether;

    // Per-user reward tracking (O(1), account-level)
    mapping(address => uint256) private _userRewardPerTokenPaid;
    mapping(address => uint256) private _unclaimedRewards;

    // Individual positions (lock metadata only)
    mapping(address => StakePosition[]) private _positions;
    mapping(address => uint256) public override userPositionCount;

    error ZeroAddress();
    error InvalidAmount();
    error InvalidLockDuration();
    error PositionNotFound();
    error StillLocked(uint256 unlockAt);
    error AlreadyClaimed();
    error InsufficientRewardReserve(uint256 required, uint256 available);
    error InvalidRewardRate(uint256 rate, uint256 max);

    event RewardFunded(address indexed funder, uint256 amount);
    event RewardRateUpdated(uint256 newRate, uint256 periodFinish);
    event RewardClaimed(address indexed user, uint256 amount);

    constructor(address token_, address governance) {
        if (token_ == address(0) || governance == address(0)) revert ZeroAddress();
        token = IERC20(token_);
        _grantRole(DEFAULT_ADMIN_ROLE, governance);
        _grantRole(REWARD_MANAGER_ROLE, governance);
    }

    // ── Modifier ──────────────────────────────

    modifier updateReward(address account) {
        // Update global accumulator + settle already-emitted rewards into liability
        _updateGlobalReward();
        if (account != address(0)) {
            _unclaimedRewards[account] = earned(account);
            _userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function _updateGlobalReward() private {
        uint256 elapsed = lastTimeRewardApplicable() - lastUpdateTime;
        if (elapsed == 0) return;
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();

        // Move emitted rewards from 'available' to 'accrued' liability
        uint256 emitted = elapsed * rewardRate;
        if (emitted > 0 && totalStaked > 0) {
            if (emitted > availableRewardReserve) {
                // Period was over-committed — clamp to available
                emitted = availableRewardReserve;
            }
            availableRewardReserve -= emitted;
            accruedRewardLiability += emitted;
        }
    }

    // ── Reward Accounting ─────────────────────

    function lastTimeRewardApplicable() public view returns (uint256) {
        uint256 finish = periodFinish;
        uint256 now_ = block.timestamp;
        return now_ < finish ? now_ : finish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) return rewardPerTokenStored;
        uint256 elapsed = lastTimeRewardApplicable() - lastUpdateTime;
        return rewardPerTokenStored + (rewardRate * elapsed * 1e18) / totalStaked;
    }

    function earned(address account) public view returns (uint256) {
        return _unclaimedRewards[account]
            + (userTotalStaked[account] * (rewardPerToken() - _userRewardPerTokenPaid[account])) / 1e18;
    }

    function outstandingRewards() public view returns (uint256) {
        return accruedRewardLiability;
    }

    // ── Admin: Fund + Rate ─────────────────────

    function fundRewards(uint256 amount) external onlyRole(REWARD_MANAGER_ROLE) {
        if (amount == 0) revert InvalidAmount();
        uint256 beforeBalance = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = token.balanceOf(address(this)) - beforeBalance;
        if (received == 0) revert InvalidAmount();
        availableRewardReserve += received;
        emit RewardFunded(msg.sender, received);
    }

    function setRewardRate(uint256 rate) external onlyRole(REWARD_MANAGER_ROLE) {
        if (rate > MAX_REWARD_RATE) revert InvalidRewardRate(rate, MAX_REWARD_RATE);

        // Settle current state before changing
        _updateGlobalReward();

        if (rate == 0) {
            // Stop current period immediately
            rewardRate = 0;
            periodFinish = block.timestamp;
            lastUpdateTime = block.timestamp;
            emit RewardRateUpdated(0, block.timestamp);
            return;
        }

        // Calculate total liability for the new period
        uint256 maxLiability;
        if (block.timestamp >= periodFinish) {
            rewardRate = rate;
            periodFinish = block.timestamp + 30 days;
            lastUpdateTime = block.timestamp;
            maxLiability = rate * 30 days;
        } else {
            // Extend: leftover reward from old rate distributed at new rate
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = rate;
            periodFinish = block.timestamp + leftover / rate;
            maxLiability = leftover; // same absolute value, just spread over different time
        }

        // Require available reserve covers max new-period liability
        if (availableRewardReserve < maxLiability) {
            revert InsufficientRewardReserve(maxLiability, availableRewardReserve);
        }

        emit RewardRateUpdated(rate, periodFinish);
    }

    // ── Solvency ───────────────────────────────

    function coverageRatio() public view returns (uint256 principal, uint256 reward, uint256 total) {
        uint256 balance = token.balanceOf(address(this));
        principal = totalStaked > 0 ? (balance * 1e18) / totalStaked : type(uint256).max;
        uint256 rewardLiabilities = accruedRewardLiability;
        reward = rewardLiabilities > 0 ? ((balance - totalStaked) * 1e18) / rewardLiabilities : type(uint256).max;
        total = (totalStaked + rewardLiabilities) > 0
            ? (balance * 1e18) / (totalStaked + rewardLiabilities) : type(uint256).max;
    }

    // ── Core Actions ──────────────────────────

    function stake(uint256 amount, uint64 lockSeconds)
        external nonReentrant updateReward(msg.sender) returns (uint256 positionId)
    {
        if (amount < MIN_STAKE) revert InvalidAmount();
        if (lockSeconds == 0 || lockSeconds > MAX_LOCK_SECONDS) revert InvalidLockDuration();

        uint256 beforeBalance = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = token.balanceOf(address(this)) - beforeBalance;
        if (received < MIN_STAKE) revert InvalidAmount();

        uint64 unlockAt = uint64(block.timestamp) + lockSeconds;
        positionId = _positions[msg.sender].length;

        _positions[msg.sender].push(StakePosition({
            amount: received,
            lockedAt: uint64(block.timestamp),
            unlockAt: unlockAt,
            claimed: false
        }));

        userPositionCount[msg.sender] = positionId + 1;
        userTotalStaked[msg.sender] += received;
        totalStaked += received;

        emit Staked(msg.sender, received, unlockAt, positionId);
    }

    function unstake(uint256 positionId)
        external nonReentrant updateReward(msg.sender) returns (uint256 amount)
    {
        StakePosition storage pos = _requireOwnPosition(msg.sender, positionId);
        if (pos.claimed) revert AlreadyClaimed();
        if (block.timestamp < pos.unlockAt) revert StillLocked(pos.unlockAt);

        amount = pos.amount;
        pos.claimed = true;
        userTotalStaked[msg.sender] -= amount;
        totalStaked -= amount;

        token.safeTransfer(msg.sender, amount);
        emit Unstaked(msg.sender, amount, 0, positionId);
    }

    function earlyUnstake(uint256 positionId)
        external nonReentrant updateReward(msg.sender) returns (uint256 amount, uint256 penalty)
    {
        StakePosition storage pos = _requireOwnPosition(msg.sender, positionId);
        if (pos.claimed) revert AlreadyClaimed();
        if (block.timestamp >= pos.unlockAt) revert("use unstake() instead");

        amount = pos.amount;
        penalty = (amount * EARLY_UNSTAKE_PENALTY_BPS) / 10000;
        uint256 netAmount = amount - penalty;

        // Forfeit only THIS position's proportional rewards
        uint256 accountReward = _unclaimedRewards[msg.sender];
        uint256 totalBefore = userTotalStaked[msg.sender];
        uint256 forfeitedReward = totalBefore > 0 ? (accountReward * amount) / totalBefore : 0;
        _unclaimedRewards[msg.sender] = accountReward - forfeitedReward;

        pos.claimed = true;
        userTotalStaked[msg.sender] -= amount;
        totalStaked -= amount;
        availableRewardReserve += penalty;

        token.safeTransfer(msg.sender, netAmount);
        emit EarlyUnstake(msg.sender, amount, penalty, positionId);
    }

    function claimRewards() external nonReentrant updateReward(msg.sender) returns (uint256 reward) {
        reward = _unclaimedRewards[msg.sender];
        if (reward == 0) return 0;

        // Clamp to available balance (principal is always safe, only rewards capped)
        uint256 principalOwed = userTotalStaked[msg.sender];
        uint256 availableForRewards = token.balanceOf(address(this)) > principalOwed
            ? token.balanceOf(address(this)) - principalOwed : 0;
        if (reward > availableForRewards) reward = availableForRewards;

        _unclaimedRewards[msg.sender] -= reward;
        accruedRewardLiability -= reward;
        totalRewardPaid += reward;

        token.safeTransfer(msg.sender, reward);
        emit RewardClaimed(msg.sender, reward);
    }

    // ── Views ─────────────────────────────────

    function positions(address user, uint256 positionId) external view override returns (StakePosition memory) {
        if (positionId >= _positions[user].length) revert PositionNotFound();
        return _positions[user][positionId];
    }

    function _requireOwnPosition(address user, uint256 positionId) private view returns (StakePosition storage) {
        if (positionId >= _positions[user].length) revert PositionNotFound();
        return _positions[user][positionId];
    }
}
