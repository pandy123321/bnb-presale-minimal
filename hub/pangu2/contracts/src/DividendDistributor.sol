// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ICostBasisManager} from "./interfaces/ICostBasisManager.sol";
import {IDividendDistributor} from "./interfaces/IDividendDistributor.sol";
import {MerkleLeafV1} from "./libraries/MerkleLeafV1.sol";

contract DividendDistributor is AccessControl, ReentrancyGuard, IDividendDistributor {
    using SafeERC20 for IERC20;

    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant ROOT_PUBLISHER_ROLE = keccak256("ROOT_PUBLISHER_ROLE");

    uint16 public constant LEAF_SCHEMA_VERSION = 1;
    uint64 public constant MAXIMUM_CLAIM_WINDOW = 30 days;

    IERC20 public immutable rewardToken;
    ICostBasisManager public immutable costBasisManager;

    mapping(uint256 => Epoch) private _epochs;
    mapping(uint256 => mapping(address => bool)) public claimed;
    uint256 public totalReservedClaims;
    uint256 public nextEpochCarry;

    error ZeroAddress();
    error AddressHasNoCode(address account);
    error InvalidEpoch();
    error InvalidRoot();
    error InvalidAmount();
    error InvalidClaimWindow();
    error InvalidSnapshotBlock(uint256 snapshotBlock, uint256 currentBlock);
    error UnsupportedSchema(uint16 schemaVersion);
    error EpochAlreadyExists(uint256 epochId);
    error EpochNotClaimable(uint256 epochId);
    error AlreadyClaimed(uint256 epochId, address account);
    error InvalidProof();
    error InsufficientFunding(uint256 actualBalance, uint256 requiredBalance);
    error ClaimExceedsEpoch(uint256 epochId, uint256 amount);
    error ClaimWindowStillOpen(uint256 epochId, uint256 claimEnd);
    error EpochHasClaims(uint256 epochId);

    event DividendRootPublished(
        uint256 indexed epoch,
        uint256 indexed snapshotBlock,
        uint256 totalAmount,
        bytes32 merkleRoot,
        uint64 claimStart,
        uint64 claimEnd,
        uint16 schemaVersion,
        uint256 carryUsed
    );
    event DividendClaimed(uint256 indexed epoch, address indexed account, uint256 amount);
    event EpochClosed(uint256 indexed epoch, uint256 unclaimedAmount, uint256 nextEpochCarry);
    event EpochCancelled(uint256 indexed epoch, uint256 releasedAmount, uint256 nextEpochCarry);

    constructor(address rewardToken_, address costBasisManager_, address governance, address rootPublisher) {
        _requireContract(rewardToken_);
        _requireContract(costBasisManager_);
        if (governance == address(0) || rootPublisher == address(0)) revert ZeroAddress();

        rewardToken = IERC20(rewardToken_);
        costBasisManager = ICostBasisManager(costBasisManager_);
        _grantRole(DEFAULT_ADMIN_ROLE, governance);
        _grantRole(GOVERNANCE_ROLE, governance);
        _grantRole(ROOT_PUBLISHER_ROLE, rootPublisher);
        _setRoleAdmin(ROOT_PUBLISHER_ROLE, GOVERNANCE_ROLE);
    }

    function epoch(uint256 epochId) external view returns (Epoch memory) {
        return _epochs[epochId];
    }

    function availableUnreservedBalance() public view returns (uint256) {
        uint256 balance = rewardToken.balanceOf(address(this));
        return balance > totalReservedClaims ? balance - totalReservedClaims : 0;
    }

    function publishEpoch(
        uint256 epochId,
        bytes32 merkleRoot,
        uint256 totalAmount,
        uint64 claimStart,
        uint64 claimEnd,
        uint32 snapshotBlock,
        uint16 schemaVersion
    ) external override onlyRole(ROOT_PUBLISHER_ROLE) {
        if (epochId == 0) revert InvalidEpoch();
        if (_epochs[epochId].status != EpochStatus.NONE) revert EpochAlreadyExists(epochId);
        if (merkleRoot == bytes32(0)) revert InvalidRoot();
        if (totalAmount == 0) revert InvalidAmount();
        if (
            claimStart < block.timestamp || claimEnd <= claimStart || claimEnd - claimStart > MAXIMUM_CLAIM_WINDOW
        ) revert InvalidClaimWindow();
        if (schemaVersion != LEAF_SCHEMA_VERSION) revert UnsupportedSchema(schemaVersion);
        if (snapshotBlock == 0 || snapshotBlock > block.number) {
            revert InvalidSnapshotBlock(snapshotBlock, block.number);
        }

        uint256 requiredBalance = totalReservedClaims + totalAmount;
        uint256 actualBalance = rewardToken.balanceOf(address(this));
        if (actualBalance < requiredBalance) revert InsufficientFunding(actualBalance, requiredBalance);

        uint256 carryUsed = nextEpochCarry > totalAmount ? totalAmount : nextEpochCarry;
        nextEpochCarry -= carryUsed;
        totalReservedClaims = requiredBalance;
        _epochs[epochId] = Epoch({
            merkleRoot: merkleRoot,
            totalAmount: totalAmount,
            totalClaimed: 0,
            claimStart: claimStart,
            claimEnd: claimEnd,
            snapshotBlock: snapshotBlock,
            schemaVersion: schemaVersion,
            status: EpochStatus.PUBLISHED
        });
        emit DividendRootPublished(
            epochId, snapshotBlock, totalAmount, merkleRoot, claimStart, claimEnd, schemaVersion, carryUsed
        );
    }

    function claim(uint256 epochId, uint256 amount, bytes32[] calldata proof) external override nonReentrant {
        Epoch storage e = _epochs[epochId];
        if (
            e.status != EpochStatus.PUBLISHED || block.timestamp < e.claimStart || block.timestamp > e.claimEnd
        ) revert EpochNotClaimable(epochId);
        if (amount == 0) revert InvalidAmount();
        if (claimed[epochId][msg.sender]) revert AlreadyClaimed(epochId, msg.sender);

        bytes32 leaf = MerkleLeafV1.hash(
            block.chainid, address(this), epochId, address(rewardToken), msg.sender, amount
        );
        if (!MerkleProof.verifyCalldata(proof, e.merkleRoot, leaf)) revert InvalidProof();
        if (e.totalClaimed + amount > e.totalAmount) revert ClaimExceedsEpoch(epochId, amount);

        claimed[epochId][msg.sender] = true;
        e.totalClaimed += amount;
        totalReservedClaims -= amount;
        rewardToken.safeTransfer(msg.sender, amount);
        costBasisManager.recordZeroCost(msg.sender, amount);
        emit DividendClaimed(epochId, msg.sender, amount);
    }

    function closeEpoch(uint256 epochId) external override onlyRole(GOVERNANCE_ROLE) returns (uint256 carryAmount) {
        Epoch storage e = _epochs[epochId];
        if (e.status != EpochStatus.PUBLISHED) revert InvalidEpoch();
        if (block.timestamp <= e.claimEnd) revert ClaimWindowStillOpen(epochId, e.claimEnd);

        carryAmount = e.totalAmount - e.totalClaimed;
        e.status = EpochStatus.CLOSED;
        totalReservedClaims -= carryAmount;
        nextEpochCarry += carryAmount;
        emit EpochClosed(epochId, carryAmount, nextEpochCarry);
    }

    function cancelUnclaimedEpoch(uint256 epochId) external onlyRole(GOVERNANCE_ROLE) returns (uint256 carryAmount) {
        Epoch storage e = _epochs[epochId];
        if (e.status != EpochStatus.PUBLISHED) revert InvalidEpoch();
        if (e.totalClaimed != 0) revert EpochHasClaims(epochId);
        if (block.timestamp >= e.claimStart && block.timestamp <= e.claimEnd) {
            revert ClaimWindowStillOpen(epochId, e.claimEnd);
        }

        carryAmount = e.totalAmount;
        e.status = EpochStatus.CANCELLED;
        totalReservedClaims -= carryAmount;
        nextEpochCarry += carryAmount;
        emit EpochCancelled(epochId, carryAmount, nextEpochCarry);
    }

    function leafFor(uint256 epochId, address account, uint256 amount) external view returns (bytes32) {
        return MerkleLeafV1.hash(block.chainid, address(this), epochId, address(rewardToken), account, amount);
    }

    function _requireContract(address account) private view {
        if (account == address(0)) revert ZeroAddress();
        if (account.code.length == 0) revert AddressHasNoCode(account);
    }
}
