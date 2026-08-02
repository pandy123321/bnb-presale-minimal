// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

library MerkleLeafV1 {
    uint16 internal constant SCHEMA_VERSION = 1;

    function hash(
        uint256 chainId,
        address distributor,
        uint256 epochId,
        address rewardToken,
        address account,
        uint256 amount
    ) internal pure returns (bytes32) {
        return keccak256(
            bytes.concat(keccak256(abi.encode(chainId, distributor, epochId, rewardToken, account, amount)))
        );
    }
}
