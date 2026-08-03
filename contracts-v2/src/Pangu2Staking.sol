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

    uint256 public override totalStaked;
    uint256 public rewardReserve;               // funded rewards, separate from user principal
    uint256 public totalRewardPaid;              // lifetime rewards paid

    uint256 public rewardRate;                   // reward per second (total across all stakers)
    uint256 public periodFinish;                 // when current reward period ends (0 = inactive)
    uint256 public lastUpdateTime;               // last time reward accounting was updated
    uint256 public rewardPerTokenStored;          // accumulated reward per staked token (scaled 1e18)

    uint256 public constant MAX_REWARD_RATE = 11574074074074; // ~1e18 / 86400 — approx 1 token/s
    uint16 public constant EARLY_UNSTAKE_PENALTY_BPS = 1000;     // 10%
    uint64 public constant MAX_LOCK_SECONDS = 730 days;
    uint256 public constant MIN_STAKE = 1 ether;                 // 1 token minimum

    // Per-user aggregates (O(1) reward computation — no position-array loop)
    mapping(address => uint256) public userTotalStaked;
    mapping(address => uint256) private _userRewardPerTokenPaid;
    mapping(address => uint256) private _rewards;

    // Individual positions (store lock metadata only; reward accounting is user-level)
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
    event RewardPaid(address indexed user, uint256 amount);

    constructor(address token_, address governance) {
        if (token_ == address(0) || governance == address(0)) revert ZeroAddress();
        token = IERC20(token_);

        _grantRole(DEFAULT_ADMIN_ROLE, governance);
        _grantRole(REWARD_MANAGER_ROLE, governance);
    }

    // ── Modifier ──────────────────────────────

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            _rewards[account] = earned(account);
            _userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    // ── Reward Accounting ─────────────────────

    function lastTimeRewardApplicable() public view returns (uint256) {
        uint256 finish = periodFinish;
        uint256 now_ = block.timestamp;
        return now_ < finish ? now_ : finish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) return rewardPerTokenStored;
        return rewardPerTokenStored
            + (rewardRate * (lastTimeRewardApplicable() - lastUpdateTime) * 1e18) / totalStaked;
    }

    function earned(address account) public view returns (uint256) {
        return _rewards[account]
            + (userTotalStaked[account] * (rewardPerToken() - _userRewardPerTokenPaid[account])) / 1e18;
    }

    // ── Fund Rewards ──────────────────────────

    function fundRewards(uint256 amount) external onlyRole(REWARD_MANAGER_ROLE) {
        if (amount == 0) revert InvalidAmount();
        uint256 beforeBalance = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = token.balanceOf(address(this)) - beforeBalance;
        rewardReserve += received;
        emit RewardFunded(msg.sender, received);
    }

    function setRewardRate(uint256 rate)
        external
        onlyRole(REWARD_MANAGER_ROLE)
        updateReward(address(0))
    {
        if (rate > MAX_REWARD_RATE) revert InvalidRewardRate(rate, MAX_REWARD_RATE);

        // Settle old period first
        if (block.timestamp >= periodFinish) {
            rewardRate = rate;
            periodFinish = block.timestamp + 30 days;
            lastUpdateTime = block.timestamp;
        } else {
            // Extend current period
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = rate;
            periodFinish = block.timestamp + leftover / rate;
        }

        // Verify rate won't exceed reserve within period
        uint256 maxLiability = rate * (periodFinish - block.timestamp);
        if (totalStaked > 0 && rewardReserve < maxLiability) {
            revert InsufficientRewardReserve(maxLiability, rewardReserve);
        }

        emit RewardRateUpdated(rate, periodFinish);
    }

    // ── Solvency Check ────────────────────────

    function solvencyRatio() public view returns (uint256) {
        uint256 balance = token.balanceOf(address(this));
        uint256 liabilities = totalStaked;
        if (balance == 0 || liabilities == 0) return 0;
        return (balance * 1e18) / liabilities; // >1e18 means fully backed
    }

    // ── Core Actions ──────────────────────────

    function stake(uint256 amount, uint64 lockSeconds)
        external
        nonReentrant
        updateReward(msg.sender)
        returns (uint256 positionId)
    {
        if (amount < MIN_STAKE) revert InvalidAmount();
        if (lockSeconds == 0 || lockSeconds > MAX_LOCK_SECONDS) revert InvalidLockDuration();

        uint256 beforeBalance = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = token.balanceOf(address(this)) - beforeBalance;
        if (received == 0) revert InvalidAmount();

        uint64 unlockAt = uint64(block.timestamp) + lockSeconds;
        positionId = _positions[msg.sender].length;

        _positions[msg.sender].push(StakePosition({
            amount: received,
            rewardDebt: 0,
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
        external
        nonReentrant
        updateReward(msg.sender)
        returns (uint256 amount, uint256 reward)
    {
        StakePosition storage pos = _requireOwnPosition(msg.sender, positionId);
        if (pos.claimed) revert AlreadyClaimed();
        if (block.timestamp < pos.unlockAt) revert StillLocked(pos.unlockAt);

        amount = pos.amount;
        reward = _rewards[msg.sender];
        pos.claimed = true;
        userTotalStaked[msg.sender] -= amount;
        totalStaked -= amount;
        _rewards[msg.sender] = 0;

        // Pay reward from reserve, principal always returned
        uint256 rewardFromReserve = reward;
        if (rewardFromReserve > rewardReserve) {
            rewardFromReserve = rewardReserve;
        }
        rewardReserve -= rewardFromReserve;
        if (rewardFromReserve < reward) {
            reward = rewardFromReserve; // clamp to available reserve
        }
        totalRewardPaid += reward;

        token.safeTransfer(msg.sender, amount + reward);
        emit Unstaked(msg.sender, amount, reward, positionId);
        if (reward > 0) emit RewardPaid(msg.sender, reward);
    }

    function earlyUnstake(uint256 positionId)
        external
        nonReentrant
        updateReward(msg.sender)
        returns (uint256 amount, uint256 penalty)
    {
        StakePosition storage pos = _requireOwnPosition(msg.sender, positionId);
        if (pos.claimed) revert AlreadyClaimed();
        if (block.timestamp >= pos.unlockAt) revert("use unstake() instead");

        amount = pos.amount;
        penalty = (amount * EARLY_UNSTAKE_PENALTY_BPS) / 10000;
        uint256 netAmount = amount - penalty;
        pos.claimed = true;
        userTotalStaked[msg.sender] -= amount;
        totalStaked -= amount;
        _rewards[msg.sender] = 0; // forfeit rewards on early exit

        // Penalty goes to reward reserve
        rewardReserve += penalty;

        token.safeTransfer(msg.sender, netAmount);
        emit EarlyUnstake(msg.sender, amount, penalty, positionId);
    }

    // ── Views ─────────────────────────────────

    function positions(address user, uint256 positionId)
        external view override returns (StakePosition memory)
    {
        if (positionId >= _positions[user].length) revert PositionNotFound();
        return _positions[user][positionId];
    }

    function _requireOwnPosition(address user, uint256 positionId)
        private view returns (StakePosition storage)
    {
        if (positionId >= _positions[user].length) revert PositionNotFound();
        return _positions[user][positionId];
    }
}
