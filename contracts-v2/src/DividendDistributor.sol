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

/// @notice 分红分配合约
///         采用 Merkle Root 模式：链下 Root Builder 计算 Top-100 持有者分配，
///         治理批准承诺哈希 → Root Publisher 发布 epoch → 用户凭 Merkle 证明领取。
///
///         安全模型：
///         - 双角色批准（Governance + Root Publisher）防止单个角色被劫持
///         - Merkle Leaf 绑定 chainId/Distributor/epochId/rewardToken/account/amount
///         - 已消费的承诺不可被撤销或修改
///         - 治理可撤销未消费的承诺（防止过期承诺锁死）
contract DividendDistributor is AccessControl, Pausable, ReentrancyGuard, IDividendDistributor {
    bytes32 public constant GOVERNANCE_ROLE       = keccak256("GOVERNANCE_ROLE");       // 治理角色
    bytes32 public constant ROOT_PUBLISHER_ROLE  = keccak256("ROOT_PUBLISHER_ROLE");   // Root 发布者
    bytes32 public constant PAUSER_ROLE          = keccak256("PAUSER_ROLE");           // 暂停角色
    bytes32 public constant UNPAUSER_ROLE        = keccak256("UNPAUSER_ROLE");         // 取消暂停

    uint16 public constant LEAF_SCHEMA_VERSION = 1;         // Merkle Leaf 规范版本
    uint64 public constant TESTNET_CLAIM_WINDOW = 30 days;   // 测试网领取窗口

    IPangu2Token public immutable rewardToken;              // 奖励代币（PANGU2）
    ICostBasisManager public immutable costBasisManager;    // 成本管理器

    // ─── 状态映射 ───
    mapping(uint256 => Epoch) private _epochs;                    // epochId → Epoch
    mapping(uint256 => mapping(address => bool)) public claimed;  // epochId → account → 是否已领取
    mapping(uint256 => bytes32) public approvedCommitmentHash;    // epochId → 已批准的承诺哈希
    mapping(uint256 => bool) public commitmentConsumed;           // epochId → 承诺是否已被消费（发布）
    uint256 public totalReservedClaims;                            // 总预留领取金额
    uint256 public nextEpochCarry;                                // 下个 epoch 可用的滚存金额

    // ─────────────────── 错误定义 ───────────────────
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
    error CommitmentAlreadyConsumedCantRevoke(uint256 epochId); // 已消费的承诺不可撤销

    // ─────────────────── 事件 ───────────────────
    event EpochCommitmentApproved(uint256 indexed epoch, bytes32 indexed commitmentHash, bytes32 indexed artifactChecksum, bytes32 merkleRoot, uint256 totalAmount, uint256 snapshotBlock, uint64 claimStart, uint64 claimEnd, uint16 schemaVersion);
    event DividendRootPublished(uint256 indexed epoch, uint256 indexed snapshotBlock, uint256 totalAmount, bytes32 merkleRoot, bytes32 indexed artifactChecksum, uint64 claimStart, uint64 claimEnd, uint16 schemaVersion, uint256 carryUsed);
    event DividendClaimed(uint256 indexed epoch, address indexed account, uint256 amount);
    event EpochClosed(uint256 indexed epoch, uint256 unclaimedAmount, uint256 nextEpochCarry);
    event EpochCancelled(uint256 indexed epoch, uint256 releasedAmount, uint256 nextEpochCarry);
    event CommitmentRevoked(uint256 indexed epochId, bytes32 revokedHash); // 承诺撤销事件

    constructor(address rewardToken_, address costBasisManager_, address governance, address rootPublisher, address emergencyAccount) {
        _requireContract(rewardToken_);
        _requireContract(costBasisManager_);
        if (governance == address(0) || rootPublisher == address(0) || emergencyAccount == address(0)) revert ZeroAddress();

        rewardToken = IPangu2Token(rewardToken_);
        costBasisManager = ICostBasisManager(costBasisManager_);
        _grantRole(DEFAULT_ADMIN_ROLE, governance);
        _grantRole(GOVERNANCE_ROLE, governance);
        _grantRole(ROOT_PUBLISHER_ROLE, rootPublisher);  // Root 发布者独立于治理
        _grantRole(PAUSER_ROLE, emergencyAccount);
        _grantRole(UNPAUSER_ROLE, governance);
        _setRoleAdmin(ROOT_PUBLISHER_ROLE, GOVERNANCE_ROLE);
        _setRoleAdmin(PAUSER_ROLE, GOVERNANCE_ROLE);
        _setRoleAdmin(UNPAUSER_ROLE, GOVERNANCE_ROLE);
    }

    function epoch(uint256 epochId) external view returns (Epoch memory) { return _epochs[epochId]; }

    /// 可用余额（扣除已预留部分）
    function availableUnreservedBalance() public view returns (uint256) {
        uint256 balance = rewardToken.balanceOf(address(this));
        return balance > totalReservedClaims ? balance - totalReservedClaims : 0;
    }

    /// 治理批准 Epoch 承诺 —— 锁定参数但尚未发布
    function approveEpochCommitment(uint256 epochId, EpochCommitment calldata commitment)
        external override onlyRole(GOVERNANCE_ROLE) returns (bytes32 hash)
    {
        _validateCommitment(epochId, commitment);
        if (commitment.claimStart < block.timestamp) revert InvalidClaimWindow(); // claimStart 必须在未来
        if (_epochs[epochId].status != EpochStatus.NONE) revert EpochAlreadyExists(epochId);
        if (approvedCommitmentHash[epochId] != bytes32(0)) revert CommitmentAlreadyApproved(epochId);

        hash = commitmentHash(epochId, commitment);
        approvedCommitmentHash[epochId] = hash;
        emit EpochCommitmentApproved(epochId, hash, commitment.artifactChecksum, commitment.merkleRoot, commitment.totalAmount, commitment.snapshotBlock, commitment.claimStart, commitment.claimEnd, commitment.schemaVersion);
    }

    /// Root Publisher 发布 Epoch —— 必须与已批准的承诺完全一致
    function publishEpoch(uint256 epochId, EpochCommitment calldata commitment)
        external override onlyRole(ROOT_PUBLISHER_ROLE) whenNotPaused
    {
        _validateCommitment(epochId, commitment);
        if (commitment.claimStart <= block.timestamp) revert InvalidClaimWindow(); // 必须在领取开始前发布
        if (commitment.claimStart >= commitment.claimEnd) revert InvalidClaimWindow();
        if (_epochs[epochId].status != EpochStatus.NONE) revert EpochAlreadyExists(epochId);
        if (commitmentConsumed[epochId]) revert CommitmentAlreadyConsumed(epochId);

        bytes32 expected = approvedCommitmentHash[epochId];
        if (expected == bytes32(0)) revert CommitmentNotApproved(epochId);
        bytes32 actual = commitmentHash(epochId, commitment);
        if (expected != actual) revert CommitmentMismatch(epochId, expected, actual); // 发布参数必须与批准的完全一致

        uint256 requiredBalance = totalReservedClaims + commitment.totalAmount;
        uint256 actualBalance = rewardToken.balanceOf(address(this));
        if (actualBalance < requiredBalance) revert InsufficientFunding(actualBalance, requiredBalance); // 余额不足

        commitmentConsumed[epochId] = true;
        // 优先使用滚存
        uint256 carryUsed = nextEpochCarry > commitment.totalAmount ? commitment.totalAmount : nextEpochCarry;
        nextEpochCarry -= carryUsed;
        totalReservedClaims = requiredBalance;
        _epochs[epochId] = Epoch({ merkleRoot: commitment.merkleRoot, artifactChecksum: commitment.artifactChecksum, totalAmount: commitment.totalAmount, totalClaimed: 0, claimStart: commitment.claimStart, claimEnd: commitment.claimEnd, snapshotBlock: commitment.snapshotBlock, schemaVersion: commitment.schemaVersion, status: EpochStatus.PUBLISHED });
        emit DividendRootPublished(epochId, commitment.snapshotBlock, commitment.totalAmount, commitment.merkleRoot, commitment.artifactChecksum, commitment.claimStart, commitment.claimEnd, commitment.schemaVersion, carryUsed);
    }

    /// 用户领取分红 —— 通过 Merkle 证明验证资格
    function claim(uint256 epochId, uint256 amount, bytes32[] calldata proof)
        external override whenNotPaused nonReentrant
    {
        Epoch storage e = _epochs[epochId];
        if (e.status != EpochStatus.PUBLISHED || block.timestamp < e.claimStart || block.timestamp > e.claimEnd) revert EpochNotClaimable(epochId);
        if (amount == 0) revert InvalidAmount();
        if (claimed[epochId][msg.sender]) revert AlreadyClaimed(epochId, msg.sender); // 同一地址同一 epoch 只能领取一次

        // 构建 Merkle Leaf：绑定 chainId + Distributor + epochId + rewardToken + account + amount
        bytes32 leaf = MerkleLeafV1.hash(block.chainid, address(this), epochId, address(rewardToken), msg.sender, amount);
        if (!MerkleProof.verifyCalldata(proof, e.merkleRoot, leaf)) revert InvalidProof();
        if (e.totalClaimed + amount > e.totalAmount) revert ClaimExceedsEpoch(epochId, amount);

        claimed[epochId][msg.sender] = true;
        e.totalClaimed += amount;
        totalReservedClaims -= amount;
        // 通过 systemTransfer 转账（使用 DIVIDEND_CLAIM 上下文）
        rewardToken.systemTransfer(msg.sender, amount, TransferContext.Kind.DIVIDEND_CLAIM);
        // 记录零成本 —— 分红不影响卖出税率计算
        costBasisManager.recordZeroCost(msg.sender, amount);
        emit DividendClaimed(epochId, msg.sender, amount);
    }

    /// 关闭 Epoch（只能由治理在领取窗口结束后调用）
    function closeEpoch(uint256 epochId) external override onlyRole(GOVERNANCE_ROLE) returns (uint256 carryAmount) {
        Epoch storage e = _epochs[epochId];
        if (e.status != EpochStatus.PUBLISHED) revert InvalidEpoch();
        if (block.timestamp <= e.claimEnd) revert ClaimWindowStillOpen(epochId, e.claimEnd);

        carryAmount = e.totalAmount - e.totalClaimed;
        e.status = EpochStatus.CLOSED;
        totalReservedClaims -= carryAmount;
        nextEpochCarry += carryAmount; // 未领取金额滚存到下个 epoch
        emit EpochClosed(epochId, carryAmount, nextEpochCarry);
    }

    /// 治理撤销未消费的承诺（防止过期承诺锁死）
    /// 一旦承诺已被消费（发布），则永远不可撤销
    function revokeCommitment(uint256 epochId) external onlyRole(GOVERNANCE_ROLE) {
        if (commitmentConsumed[epochId]) revert CommitmentAlreadyConsumedCantRevoke(epochId);
        bytes32 hash = approvedCommitmentHash[epochId];
        if (hash == bytes32(0)) revert CommitmentNotApproved(epochId);
        delete approvedCommitmentHash[epochId];
        emit CommitmentRevoked(epochId, hash);
    }

    /// 取消无人领取的 Epoch（只能由治理调用）
    function cancelUnclaimedEpoch(uint256 epochId) external onlyRole(GOVERNANCE_ROLE) returns (uint256 carryAmount) {
        Epoch storage e = _epochs[epochId];
        if (e.status != EpochStatus.PUBLISHED) revert InvalidEpoch();
        if (e.totalClaimed != 0) revert EpochHasClaims(epochId); // 已有领取记录则不可取消
        if (block.timestamp >= e.claimStart && block.timestamp <= e.claimEnd) revert ClaimWindowStillOpen(epochId, e.claimEnd);

        carryAmount = e.totalAmount;
        e.status = EpochStatus.CANCELLED;
        totalReservedClaims -= carryAmount;
        nextEpochCarry += carryAmount;
        emit EpochCancelled(epochId, carryAmount, nextEpochCarry);
    }

    /// 计算承诺哈希 —— 绑定链上所有关键参数
    function commitmentHash(uint256 epochId, EpochCommitment calldata commitment) public view returns (bytes32) {
        return keccak256(abi.encode(block.chainid, address(this), epochId, address(rewardToken), commitment.merkleRoot, commitment.totalAmount, commitment.snapshotBlock, commitment.claimStart, commitment.claimEnd, commitment.schemaVersion, commitment.artifactChecksum));
    }

    function leafFor(uint256 epochId, address account, uint256 amount) external view returns (bytes32) {
        return MerkleLeafV1.hash(block.chainid, address(this), epochId, address(rewardToken), account, amount);
    }

    function pause() external onlyRole(PAUSER_ROLE) { _pause(); }
    function unpause() external onlyRole(UNPAUSER_ROLE) { _unpause(); }

    /// 验证承诺参数合法性
    function _validateCommitment(uint256 epochId, EpochCommitment calldata commitment) private view {
        if (epochId == 0) revert InvalidEpoch();
        if (commitment.merkleRoot == bytes32(0)) revert InvalidRoot();
        if (commitment.artifactChecksum == bytes32(0)) revert InvalidChecksum();
        if (commitment.totalAmount == 0) revert InvalidAmount();
        if (commitment.claimEnd <= commitment.claimStart || commitment.claimEnd - commitment.claimStart != TESTNET_CLAIM_WINDOW) revert InvalidClaimWindow();
        if (commitment.schemaVersion != LEAF_SCHEMA_VERSION) revert UnsupportedSchema(commitment.schemaVersion);
        if (commitment.snapshotBlock == 0 || commitment.snapshotBlock > block.number) revert InvalidSnapshotBlock(commitment.snapshotBlock, block.number);
    }

    function _requireContract(address account) private view {
        if (account == address(0)) revert ZeroAddress();
        if (account.code.length == 0) revert AddressHasNoCode(account);
    }
}
