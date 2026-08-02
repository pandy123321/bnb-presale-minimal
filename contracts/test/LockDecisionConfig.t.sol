// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {BuybackLocker} from "pangu2/BuybackLocker.sol";
import {LockDecisionConfig} from "../script/LockDecisionConfig.sol";

contract LockDecisionConfigHarness {
    function validate(
        string memory modeValue,
        uint256 durationValue,
        address releaseRecipient,
        string memory decisionId
    ) external pure returns (BuybackLocker.LockMode mode, uint64 duration) {
        return LockDecisionConfig.validate(modeValue, durationValue, releaseRecipient, decisionId);
    }
}

contract LockDecisionConfigTest is Test {
    uint64 internal constant TEST_FIXTURE_LOCK_DURATION = 7 days;
    address internal constant RECIPIENT = address(0xA11CE);

    LockDecisionConfigHarness internal harness = new LockDecisionConfigHarness();

    function testMissingDecisionStopsDeploymentConfiguration() public {
        vm.expectRevert(LockDecisionConfig.MissingLockDecision.selector);
        harness.validate("FIXED_DURATION", TEST_FIXTURE_LOCK_DURATION, RECIPIENT, "");
    }

    function testInvalidDecisionIdStopsDeploymentConfiguration() public {
        vm.expectRevert(LockDecisionConfig.InvalidLockDecisionId.selector);
        harness.validate("FIXED_DURATION", TEST_FIXTURE_LOCK_DURATION, RECIPIENT, "placeholder");
    }

    function testPermanentModeRequiresZeroDuration() public {
        vm.expectRevert(LockDecisionConfig.InvalidLockDuration.selector);
        harness.validate("PERMANENT", 1, RECIPIENT, "DR-P2-LOCK-PERMANENT");

        (BuybackLocker.LockMode mode, uint64 duration) =
            harness.validate("PERMANENT", 0, RECIPIENT, "DR-P2-LOCK-PERMANENT");
        assertEq(uint256(mode), uint256(BuybackLocker.LockMode.PERMANENT));
        assertEq(duration, 0);
    }

    function testFixedModeRequiresPositiveExplicitDuration() public {
        vm.expectRevert(LockDecisionConfig.InvalidLockDuration.selector);
        harness.validate("FIXED_DURATION", 0, RECIPIENT, "DR-P2-LOCK-FIXED");

        (BuybackLocker.LockMode mode, uint64 duration) = harness.validate(
            "FIXED_DURATION", TEST_FIXTURE_LOCK_DURATION, RECIPIENT, "DR-P2-LOCK-FIXED"
        );
        assertEq(uint256(mode), uint256(BuybackLocker.LockMode.FIXED_DURATION));
        assertEq(duration, TEST_FIXTURE_LOCK_DURATION);
    }

    function testInvalidModeAndRecipientRevert() public {
        vm.expectRevert(LockDecisionConfig.InvalidLockMode.selector);
        harness.validate("SEVEN_DAYS", TEST_FIXTURE_LOCK_DURATION, RECIPIENT, "DR-P2-LOCK-X");

        vm.expectRevert(LockDecisionConfig.InvalidReleaseRecipient.selector);
        harness.validate("FIXED_DURATION", TEST_FIXTURE_LOCK_DURATION, address(0), "DR-P2-LOCK-X");
    }
}
