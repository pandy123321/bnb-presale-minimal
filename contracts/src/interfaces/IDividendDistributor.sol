// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IDividendDistributor {
    enum EpochStatus {
        NONE,
        PUBLISHED,
        CLOSED,
        CANCELLED
    }

    struct Epoch {
        bytes32 merkleRoot;
        bytes32 artifactChecksum;
        uint256 totalAmount;
        uint256 totalClaimed;
        uint64 claimStart;
        uint64 claimEnd;
        uint32 snapshotBlock;
        uint16 schemaVersion;
        EpochStatus status;
    }

    struct EpochCommitment {
        bytes32 merkleRoot;
        bytes32 artifactChecksum;
        uint256 totalAmount;
        uint64 claimStart;
        uint64 claimEnd;
        uint32 snapshotBlock;
        uint16 schemaVersion;
    }

    function approveEpochCommitment(uint256 epochId, EpochCommitment calldata commitment)
        external
        returns (bytes32 commitmentHash);

    function publishEpoch(uint256 epochId, EpochCommitment calldata commitment) external;
    function claim(uint256 epochId, uint256 amount, bytes32[] calldata proof) external;
    function closeEpoch(uint256 epochId) external returns (uint256 carryAmount);
}
