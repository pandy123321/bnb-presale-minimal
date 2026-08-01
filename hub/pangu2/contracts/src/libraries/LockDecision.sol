// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BuybackLocker} from "../BuybackLocker.sol";

/// @notice Deployment-only validation for an explicitly approved locker decision.
library LockDecision {
    error InvalidLockMode(uint256 rawMode);
    error InvalidLockDuration(BuybackLocker.LockMode mode, uint256 duration);
    error InvalidReleaseRecipient();
    error InvalidDecisionId();

    bytes32 private constant TEST_FIXTURE_HASH = keccak256("TEST_FIXTURE_ONLY");
    bytes32 private constant TBD_HASH = keccak256("TBD");
    bytes32 private constant UNAPPROVED_HASH = keccak256("UNAPPROVED");

    function validate(
        uint256 rawMode,
        uint256 rawDuration,
        address releaseRecipient,
        string memory decisionId
    ) internal pure returns (BuybackLocker.LockMode mode, uint64 duration) {
        if (rawMode > uint256(BuybackLocker.LockMode.FIXED_DURATION)) {
            revert InvalidLockMode(rawMode);
        }
        if (releaseRecipient == address(0)) revert InvalidReleaseRecipient();
        if (rawDuration > type(uint64).max) {
            revert InvalidLockDuration(BuybackLocker.LockMode(rawMode), rawDuration);
        }

        bytes memory decisionBytes = bytes(decisionId);
        bytes32 decisionHash = keccak256(decisionBytes);
        if (
            !_hasDecisionPrefix(decisionBytes) || decisionHash == TEST_FIXTURE_HASH
                || decisionHash == TBD_HASH || decisionHash == UNAPPROVED_HASH
        ) revert InvalidDecisionId();

        mode = BuybackLocker.LockMode(rawMode);
        duration = uint64(rawDuration);
        if (mode == BuybackLocker.LockMode.PERMANENT) {
            if (duration != 0) revert InvalidLockDuration(mode, duration);
        } else if (duration == 0) {
            revert InvalidLockDuration(mode, duration);
        }
    }

    function _hasDecisionPrefix(bytes memory value) private pure returns (bool) {
        bytes memory prefix = bytes("DR-P2-");
        if (value.length != prefix.length + 4) return false;
        for (uint256 i; i < prefix.length; ++i) {
            if (value[i] != prefix[i]) return false;
        }
        for (uint256 i = prefix.length; i < value.length; ++i) {
            if (value[i] < bytes1("0") || value[i] > bytes1("9")) return false;
        }
        return true;
    }
}
