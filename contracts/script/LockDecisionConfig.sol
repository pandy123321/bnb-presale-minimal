// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BuybackLocker} from "../src/BuybackLocker.sol";

library LockDecisionConfig {
    error MissingLockDecision();
    error InvalidLockDecisionId(string decisionId);
    error InvalidLockMode(string suppliedMode);
    error InvalidLockDuration(BuybackLocker.LockMode mode, uint256 suppliedDuration);
    error InvalidReleaseRecipient(address recipient);

    bytes32 private constant PERMANENT_HASH = keccak256("PERMANENT");
    bytes32 private constant FIXED_DURATION_HASH = keccak256("FIXED_DURATION");

    function validate(
        string memory modeValue,
        uint256 durationValue,
        address releaseRecipient,
        string memory decisionId
    ) internal pure returns (BuybackLocker.LockMode mode, uint64 duration) {
        bytes memory decisionBytes = bytes(decisionId);
        if (decisionBytes.length == 0) revert MissingLockDecision();
        if (
            decisionBytes.length < 4 || decisionBytes[0] != bytes1("D")
                || decisionBytes[1] != bytes1("R") || decisionBytes[2] != bytes1("-")
        ) revert InvalidLockDecisionId(decisionId);
        if (releaseRecipient == address(0)) revert InvalidReleaseRecipient(releaseRecipient);
        if (durationValue > type(uint64).max) {
            revert InvalidLockDuration(BuybackLocker.LockMode.FIXED_DURATION, durationValue);
        }

        bytes32 modeHash = keccak256(bytes(modeValue));
        if (modeHash == PERMANENT_HASH) {
            mode = BuybackLocker.LockMode.PERMANENT;
            if (durationValue != 0) revert InvalidLockDuration(mode, durationValue);
        } else if (modeHash == FIXED_DURATION_HASH) {
            mode = BuybackLocker.LockMode.FIXED_DURATION;
            if (durationValue == 0) revert InvalidLockDuration(mode, durationValue);
        } else {
            revert InvalidLockMode(modeValue);
        }
        duration = uint64(durationValue);
    }
}
