// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {BuybackLocker} from "pangu2/BuybackLocker.sol";
import {LockDecision} from "pangu2/libraries/LockDecision.sol";

contract LockDecisionHarness {
    function validate(uint256 mode, uint256 duration, address recipient, string calldata decisionId)
        external
        pure
        returns (BuybackLocker.LockMode, uint64)
    {
        return LockDecision.validate(mode, duration, recipient, decisionId);
    }
}

contract LockDecisionTest is Test {
    LockDecisionHarness internal harness = new LockDecisionHarness();
    address internal constant RECIPIENT = address(0xA11CE);
    string internal constant ACTIVE_TEST_DECISION = "DR-P2-0012";
    uint64 internal constant TEST_FIXTURE_LOCK_DURATION = 7 days;

    function testMissingDecisionStopsDeploymentConfiguration() public {
        vm.expectRevert(LockDecision.InvalidDecisionId.selector);
        harness.validate(
            uint256(BuybackLocker.LockMode.FIXED_DURATION),
            TEST_FIXTURE_LOCK_DURATION,
            RECIPIENT,
            ""
        );
    }

    function testFixturePlaceholderCannotBeUsedAsDeploymentDecision() public {
        vm.expectRevert(LockDecision.InvalidDecisionId.selector);
        harness.validate(
            uint256(BuybackLocker.LockMode.FIXED_DURATION),
            TEST_FIXTURE_LOCK_DURATION,
            RECIPIENT,
            "TEST_FIXTURE_ONLY"
        );
    }

    function testArbitraryStringIsNotAValidDecisionRecord() public {
        vm.expectRevert(LockDecision.InvalidDecisionId.selector);
        harness.validate(
            uint256(BuybackLocker.LockMode.FIXED_DURATION),
            TEST_FIXTURE_LOCK_DURATION,
            RECIPIENT,
            "approved-by-operator"
        );
    }

    function testDecisionIdMustUseCanonicalFourDigitRecordFormat() public {
        vm.expectRevert(LockDecision.InvalidDecisionId.selector);
        harness.validate(
            uint256(BuybackLocker.LockMode.FIXED_DURATION),
            TEST_FIXTURE_LOCK_DURATION,
            RECIPIENT,
            "DR-P2-FAKE"
        );

        vm.expectRevert(LockDecision.InvalidDecisionId.selector);
        harness.validate(
            uint256(BuybackLocker.LockMode.FIXED_DURATION),
            TEST_FIXTURE_LOCK_DURATION,
            RECIPIENT,
            "DR-P2-12345"
        );
    }

    function testPermanentModeRequiresZeroDuration() public {
        (BuybackLocker.LockMode mode, uint64 duration) = harness.validate(
            uint256(BuybackLocker.LockMode.PERMANENT), 0, RECIPIENT, ACTIVE_TEST_DECISION
        );
        assertEq(uint256(mode), uint256(BuybackLocker.LockMode.PERMANENT));
        assertEq(duration, 0);

        vm.expectRevert(LockDecision.InvalidLockDuration.selector);
        harness.validate(
            uint256(BuybackLocker.LockMode.PERMANENT), 1, RECIPIENT, ACTIVE_TEST_DECISION
        );
    }

    function testFixedModeRequiresPositiveDuration() public {
        vm.expectRevert(LockDecision.InvalidLockDuration.selector);
        harness.validate(
            uint256(BuybackLocker.LockMode.FIXED_DURATION), 0, RECIPIENT, ACTIVE_TEST_DECISION
        );

        (BuybackLocker.LockMode mode, uint64 duration) = harness.validate(
            uint256(BuybackLocker.LockMode.FIXED_DURATION),
            TEST_FIXTURE_LOCK_DURATION,
            RECIPIENT,
            ACTIVE_TEST_DECISION
        );
        assertEq(uint256(mode), uint256(BuybackLocker.LockMode.FIXED_DURATION));
        assertEq(duration, TEST_FIXTURE_LOCK_DURATION);
    }

    function testInvalidModeRecipientAndOversizedDurationFail() public {
        vm.expectRevert(LockDecision.InvalidLockMode.selector);
        harness.validate(2, 0, RECIPIENT, ACTIVE_TEST_DECISION);

        vm.expectRevert(LockDecision.InvalidReleaseRecipient.selector);
        harness.validate(
            uint256(BuybackLocker.LockMode.PERMANENT), 0, address(0), ACTIVE_TEST_DECISION
        );

        vm.expectRevert(LockDecision.InvalidLockDuration.selector);
        harness.validate(
            uint256(BuybackLocker.LockMode.FIXED_DURATION),
            uint256(type(uint64).max) + 1,
            RECIPIENT,
            ACTIVE_TEST_DECISION
        );
    }
}
