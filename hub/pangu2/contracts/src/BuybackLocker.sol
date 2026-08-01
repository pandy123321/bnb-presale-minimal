// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IBuybackLocker} from "./interfaces/IBuybackLocker.sol";

contract BuybackLocker is ReentrancyGuard, IBuybackLocker {
    using SafeERC20 for IERC20;

    enum LockMode {
        PERMANENT,
        FIXED_DURATION
    }

    enum BatchStatus {
        NONE,
        LOCKED,
        RELEASED
    }

    struct Batch {
        uint256 buybackId;
        uint256 amount;
        uint64 lockedAt;
        uint64 unlockAt;
        uint64 sourceBlock;
        BatchStatus status;
    }

    IERC20 public immutable token;
    address public immutable supportPool;
    LockMode public immutable mode;
    uint64 public immutable duration;
    address public immutable releaseRecipient;

    uint256 public nextBatchId = 1;
    uint256 public override outstandingLocked;
    mapping(uint256 => Batch) public batches;
    mapping(uint256 => uint256) public batchByBuybackId;

    error ZeroAddress();
    error AddressHasNoCode(address account);
    error InvalidConfiguration();
    error UnauthorizedCaller();
    error InvalidAmount();
    error BuybackAlreadyRegistered(uint256 buybackId);
    error InsufficientBacking(uint256 actualBalance, uint256 requiredBalance);
    error PermanentMode();
    error BatchNotLocked(uint256 batchId);
    error BatchStillLocked(uint256 batchId, uint256 unlockAt);

    event LockBatchCreated(
        uint256 indexed batchId,
        uint256 indexed buybackId,
        uint256 tokenAmount,
        uint256 lockedAt,
        uint256 unlockAt,
        uint256 sourceBlock
    );
    event LockBatchReleased(uint256 indexed batchId, address indexed recipient, uint256 tokenAmount);

    constructor(
        address token_,
        address supportPool_,
        LockMode mode_,
        uint64 duration_,
        address releaseRecipient_
    ) {
        _requireContract(token_);
        _requireContract(supportPool_);
        if (releaseRecipient_ == address(0)) revert ZeroAddress();
        if (mode_ == LockMode.PERMANENT && duration_ != 0) revert InvalidConfiguration();
        if (
            mode_ == LockMode.FIXED_DURATION
                && (duration_ == 0 || block.timestamp + uint256(duration_) > type(uint64).max)
        ) revert InvalidConfiguration();

        token = IERC20(token_);
        supportPool = supportPool_;
        mode = mode_;
        duration = duration_;
        releaseRecipient = releaseRecipient_;
    }

    function registerBuyback(uint256 buybackId, uint256 amount) external override returns (uint256 batchId) {
        if (msg.sender != supportPool) revert UnauthorizedCaller();
        if (amount == 0 || buybackId == 0) revert InvalidAmount();
        if (batchByBuybackId[buybackId] != 0) revert BuybackAlreadyRegistered(buybackId);

        if (block.number > type(uint64).max) revert InvalidConfiguration();
        uint256 requiredBacking = outstandingLocked + amount;
        uint256 actualBalance = token.balanceOf(address(this));
        if (actualBalance < requiredBacking) revert InsufficientBacking(actualBalance, requiredBacking);

        batchId = nextBatchId++;
        uint64 lockedAt = uint64(block.timestamp);
        uint256 unlockAtValue = mode == LockMode.PERMANENT ? 0 : block.timestamp + uint256(duration);
        if (unlockAtValue > type(uint64).max) revert InvalidConfiguration();
        uint64 unlockAt = uint64(unlockAtValue);
        batches[batchId] = Batch({
            buybackId: buybackId,
            amount: amount,
            lockedAt: lockedAt,
            unlockAt: unlockAt,
            sourceBlock: uint64(block.number),
            status: BatchStatus.LOCKED
        });
        batchByBuybackId[buybackId] = batchId;
        outstandingLocked = requiredBacking;
        emit LockBatchCreated(batchId, buybackId, amount, lockedAt, unlockAt, block.number);
    }

    function release(uint256 batchId) external nonReentrant {
        if (mode == LockMode.PERMANENT) revert PermanentMode();
        Batch storage batch = batches[batchId];
        if (batch.status != BatchStatus.LOCKED) revert BatchNotLocked(batchId);
        if (block.timestamp < batch.unlockAt) revert BatchStillLocked(batchId, batch.unlockAt);

        batch.status = BatchStatus.RELEASED;
        outstandingLocked -= batch.amount;
        token.safeTransfer(releaseRecipient, batch.amount);
        emit LockBatchReleased(batchId, releaseRecipient, batch.amount);
    }

    function surplus() external view returns (uint256) {
        uint256 balance = token.balanceOf(address(this));
        return balance > outstandingLocked ? balance - outstandingLocked : 0;
    }

    function isSolvent() external view returns (bool) {
        return token.balanceOf(address(this)) >= outstandingLocked;
    }

    function _requireContract(address account) private view {
        if (account == address(0)) revert ZeroAddress();
        if (account.code.length == 0) revert AddressHasNoCode(account);
    }
}
