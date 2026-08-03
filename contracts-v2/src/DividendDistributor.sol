// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { ICostBasisManager } from "./interfaces/ICostBasisManager.sol";
import { IDividendDistributor } from "./interfaces/IDividendDistributor.sol";
import { IPangu2Token } from "./interfaces/IPangu2Token.sol";
import { MerkleLeafV1 } from "./libraries/MerkleLeafV1.sol";
import { TransferContext } from "./libraries/TransferContext.sol";

contract DividendDistributor is AccessControl, Pausable, ReentrancyGuard, IDividendDistributor {
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant ROOT_PUBLISHER_ROLE = keccak256("ROOT_PUBLISHER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UNPAUSER_ROLE = keccak256("UNPAUSER_ROLE");

    uint16 public constant LEAF_SCHEMA_VERSION = 1;
    uint64 public constant TESTNET_CLAIM_WINDOW = 30 days;

    IPangu2Token public immutable rewardToken;
    ICostBasisManager public immutable costBasisManager;

    mapping(uint256 => Epoch) private _epochs;
    mapping(uint256 => mapping(address => bool)) public claimed;
    mapping(uint256 => bytes32) public approvedCommitmentHash;
    mapping(uint256 => bool) public commitmentConsumed;
    uint256 public totalReservedClaims;
    uint256 public nextEpochCarry;

    error ZeroAddress();
    error AddressHasNoCode(address account);
    error InvalidEpoch();
    error InvalidRoot();
    error InvalidChecksum();
    error InvalidAmount();
    error InvalidClaimWindow();
    error InvalidSnapshotBlock(uint256 snapshotBlock, uint256 currentBlock);
    error UnsupportedSchema(uint16 schemaVersion);
    error EpochAlreadyExists(uint256 epochId);
    error CommitmentAlreadyApproved(uint256 epochId);
    error CommitmentNotApproved(uint256 epochId);
    error CommitmentMismatch(uint256 epochId, bytes32 expected, bytes32 actual);
    error CommitmentAlreadyConsumed(uint256 epochId);
    error EpochNotClaimable(uint256 epochId);
    error AlreadyClaimed(uint256 epochId, address account);
    error InvalidProof();
    error InsufficientFunding(uint256 actualBalance, uint256 requiredBalance);
    error ClaimExceedsEpoch(uint256 epochId, uint256 amount);
    error ClaimWindowStillOpen(uint256 epochId, uint256 claimEnd);
    error EpochHasClaims(uint256 epochId);

    // New: allow governance to revoke stale unconsumed commitments
    error CommitmentAlreadyConsumedCantRevoke(uint256 epochId);

    event EpochCommitmentApproved(
        uint256 indexed epoch,
        bytes32 indexed commitmentHash,
        bytes32 indexed artifactChecksum,
        bytes32 merkleRoot,
        uint256 totalAmount,
        uint256 snapshotBlock,
        uint64 claimStart,
        uint64 claimEnd,
        uint16 schemaVersion
    );
    event DividendRootPublished(
        uint256 indexed epoch,
        uint256 indexed snapshotBlock,
        uint256 totalAmount,
        bytes32 merkleRoot,
        bytes32 indexed artifactChecksum,
        uint64 claimStart,
        uint64 claimEnd,
        uint16 schemaVersion,
        uint256 carryUsed
    );
    event DividendClaimed(uint256 indexed epoch, address indexed account, uint256 amount);
    event EpochClosed(uint256 indexed epoch, uint256 unclaimedAmount, uint256 nextEpochCarry);
    event EpochCancelled(uint256 indexed epoch, uint256 releasedAmount, uint256 nextEpochCarry);
    event CommitmentRevoked(uint256 indexed epochId, bytes32 revokedHash);

    constructor(
        address rewardToken_,
        address costBasisManager_,
        address governance,
        address rootPublisher,
        address emergencyAccount
    ) {
        _requireContract(rewardToken_);
        _requireContract(costBasisManager_);
        if (governance == address(0) || rootPublisher == address(0) || emergencyAccount == address(0)) {
            revert ZeroAddress();
        }

        rewardToken = IPangu2Token(rewardToken_);
        costBasisManager = ICostBasisManager(costBasisManager_);
        _grantRole(DEFAULT_ADMIN_ROLE, governance);
        _grantRole(GOVERNANCE_ROLE, governance);
        _grantRole(ROOT_PUBLISHER_ROLE, rootPublisher);
        _grantRole(PAUSER_ROLE, emergencyAccount);
        _grantRole(UNPAUSER_ROLE, governance);
        _setRoleAdmin(ROOT_PUBLISHER_ROLE, GOVERNANCE_ROLE);
        _setRoleAdmin(PAUSER_ROLE, GOVERNANCE_ROLE);
        _setRoleAdmin(UNPAUSER_ROLE, GOVERNANCE_ROLE);
    }

    function epoch(uint256 epochId) external view returns (Epoch memory) {
        return _epochs[epochId];
    }

    function availableUnreservedBalance() public view returns (uint256) {
        uint256 balance = rewardToken.balanceOf(address(this));
        return balance > totalReservedClaims ? balance - totalReservedClaims : 0;
    }

    function approveEpochCommitment(uint256 epochId, EpochCommitment calldata commitment)
        external
        override
        onlyRole(GOVERNANCE_ROLE)
        returns (bytes32 hash)
    {
        _validateCommitment(epochId, commitment);
        if (commitment.claimStart < block.timestamp) revert InvalidClaimWindow();
        if (_epochs[epochId].status != EpochStatus.NONE) revert EpochAlreadyExists(epochId);
        if (approvedCommitmentHash[epochId] != bytes32(0)) revert CommitmentAlreadyApproved(epochId);

        hash = commitmentHash(epochId, commitment);
        approvedCommitmentHash[epochId] = hash;
        emit EpochCommitmentApproved(
            epochId,
            hash,
            commitment.artifactChecksum,
            commitment.merkleRoot,
            commitment.totalAmount,
            commitment.snapshotBlock,
            commitment.claimStart,
            commitment.claimEnd,
            commitment.schemaVersion
        );
    }

    function publishEpoch(uint256 epochId, EpochCommitment calldata commitment)
        external
        override
        onlyRole(ROOT_PUBLISHER_ROLE)
        whenNotPaused
    {
        _validateCommitment(epochId, commitment);
        // Publisher must publish BEFORE the claim window opens.
        if (commitment.claimStart <= block.timestamp) revert InvalidClaimWindow();
        if (commitment.claimStart >= commitment.claimEnd) revert InvalidClaimWindow();
        if (_epochs[epochId].status != EpochStatus.NONE) revert EpochAlreadyExists(epochId);
        if (commitmentConsumed[epochId]) revert CommitmentAlreadyConsumed(epochId);

        bytes32 expected = approvedCommitmentHash[epochId];
        if (expected == bytes32(0)) revert CommitmentNotApproved(epochId);
        bytes32 actual = commitmentHash(epochId, commitment);
        if (expected != actual) revert CommitmentMismatch(epochId, expected, actual);

        uint256 requiredBalance = totalReservedClaims + commitment.totalAmount;
        uint256 actualBalance = rewardToken.balanceOf(address(this));
        if (actualBalance < requiredBalance) revert InsufficientFunding(actualBalance, requiredBalance);

        commitmentConsumed[epochId] = true;
        uint256 carryUsed = nextEpochCarry > commitment.totalAmount ? commitment.totalAmount : nextEpochCarry;
        nextEpochCarry -= carryUsed;
        totalReservedClaims = requiredBalance;
        _epochs[epochId] = Epoch({
            merkleRoot: commitment.merkleRoot,
            artifactChecksum: commitment.artifactChecksum,
            totalAmount: commitment.totalAmount,
            totalClaimed: 0,
            claimStart: commitment.claimStart,
            claimEnd: commitment.claimEnd,
            snapshotBlock: commitment.snapshotBlock,
            schemaVersion: commitment.schemaVersion,
            status: EpochStatus.PUBLISHED
        });
        emit DividendRootPublished(
            epochId,
            commitment.snapshotBlock,
            commitment.totalAmount,
            commitment.merkleRoot,
            commitment.artifactChecksum,
            commitment.claimStart,
            commitment.claimEnd,
            commitment.schemaVersion,
            carryUsed
        );
    }

    function claim(uint256 epochId, uint256 amount, bytes32[] calldata proof)
        external
        override
        whenNotPaused
        nonReentrant
    {
        Epoch storage e = _epochs[epochId];
        if (e.status != EpochStatus.PUBLISHED || block.timestamp < e.claimStart || block.timestamp > e.claimEnd) {
            revert EpochNotClaimable(epochId);
        }
        if (amount == 0) revert InvalidAmount();
        if (claimed[epochId][msg.sender]) revert AlreadyClaimed(epochId, msg.sender);

        bytes32 leaf =
            MerkleLeafV1.hash(block.chainid, address(this), epochId, address(rewardToken), msg.sender, amount);
        if (!MerkleProof.verifyCalldata(proof, e.merkleRoot, leaf)) revert InvalidProof();
        if (e.totalClaimed + amount > e.totalAmount) revert ClaimExceedsEpoch(epochId, amount);

        claimed[epochId][msg.sender] = true;
        e.totalClaimed += amount;
        totalReservedClaims -= amount;
        rewardToken.systemTransfer(msg.sender, amount, TransferContext.Kind.DIVIDEND_CLAIM);
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

    /// @notice Governance can revoke a commitment that has not been consumed (published) yet.
    ///         Once consumed, commitments are immutable.
    function revokeCommitment(uint256 epochId) external onlyRole(GOVERNANCE_ROLE) {
        if (commitmentConsumed[epochId]) revert CommitmentAlreadyConsumedCantRevoke(epochId);
        bytes32 hash = approvedCommitmentHash[epochId];
        if (hash == bytes32(0)) revert CommitmentNotApproved(epochId);
        delete approvedCommitmentHash[epochId];
        emit CommitmentRevoked(epochId, hash);
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

    function commitmentHash(uint256 epochId, EpochCommitment calldata commitment) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                block.chainid,
                address(this),
                epochId,
                address(rewardToken),
                commitment.merkleRoot,
                commitment.totalAmount,
                commitment.snapshotBlock,
                commitment.claimStart,
                commitment.claimEnd,
                commitment.schemaVersion,
                commitment.artifactChecksum
            )
        );
    }

    function leafFor(uint256 epochId, address account, uint256 amount) external view returns (bytes32) {
        return MerkleLeafV1.hash(block.chainid, address(this), epochId, address(rewardToken), account, amount);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(UNPAUSER_ROLE) {
        _unpause();
    }

    function _validateCommitment(uint256 epochId, EpochCommitment calldata commitment) private view {
        if (epochId == 0) revert InvalidEpoch();
        if (commitment.merkleRoot == bytes32(0)) revert InvalidRoot();
        if (commitment.artifactChecksum == bytes32(0)) revert InvalidChecksum();
        if (commitment.totalAmount == 0) revert InvalidAmount();
        if (
            commitment.claimEnd <= commitment.claimStart
                || commitment.claimEnd - commitment.claimStart != TESTNET_CLAIM_WINDOW
        ) revert InvalidClaimWindow();
        if (commitment.schemaVersion != LEAF_SCHEMA_VERSION) {
            revert UnsupportedSchema(commitment.schemaVersion);
        }
        if (commitment.snapshotBlock == 0 || commitment.snapshotBlock > block.number) {
            revert InvalidSnapshotBlock(commitment.snapshotBlock, block.number);
        }
    }

    function _requireContract(address account) private view {
        if (account == address(0)) revert ZeroAddress();
        if (account.code.length == 0) revert AddressHasNoCode(account);
    }
}
