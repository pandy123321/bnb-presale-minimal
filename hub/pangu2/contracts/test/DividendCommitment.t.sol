// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Pangu2IntegrationTest} from "./Pangu2Integration.t.sol";
import {DividendDistributor} from "pangu2/DividendDistributor.sol";
import {IDividendDistributor} from "pangu2/interfaces/IDividendDistributor.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract DividendCommitmentTest is Pangu2IntegrationTest {
    address internal constant PUBLISHER = address(0xD1A1);

    function setUp() public override {
        super.setUp();
        distributor.grantRole(distributor.ROOT_PUBLISHER_ROLE(), PUBLISHER);
        token.transfer(address(distributor), 100 ether);
    }

    function testUnapprovedCommitmentCannotBePublished() public {
        IDividendDistributor.EpochCommitment memory c = _commitment(1, USER, 1 ether);
        vm.prank(PUBLISHER);
        vm.expectRevert(abi.encodeWithSelector(DividendDistributor.CommitmentNotApproved.selector, 1));
        distributor.publishEpoch(1, c);
    }

    function testEveryCommittedFieldIsBound() public {
        IDividendDistributor.EpochCommitment memory approved = _commitment(2, USER, 1 ether);
        distributor.approveEpochCommitment(2, approved);
        IDividendDistributor.EpochCommitment memory changed = approved;
        changed.merkleRoot = keccak256("other-root");
        _expectMismatch(2, changed);
        changed = approved;
        changed.artifactChecksum = keccak256("other-artifact");
        _expectMismatch(2, changed);
        changed = approved;
        changed.totalAmount += 1;
        _expectMismatch(2, changed);
        changed = approved;
        changed.claimStart += 1;
        changed.claimEnd += 1;
        _expectMismatch(2, changed);
        vm.roll(block.number + 2);
        changed = approved;
        changed.snapshotBlock += 1;
        _expectMismatch(2, changed);
        changed = approved;
        changed.schemaVersion = 2;
        vm.prank(PUBLISHER);
        vm.expectRevert(abi.encodeWithSelector(DividendDistributor.UnsupportedSchema.selector, 2));
        distributor.publishEpoch(2, changed);
    }

    function testCommitmentCanOnlyBeConsumedOnce() public {
        IDividendDistributor.EpochCommitment memory c = _commitment(3, USER, 1 ether);
        distributor.approveEpochCommitment(3, c);
        vm.prank(PUBLISHER);
        distributor.publishEpoch(3, c);
        assertTrue(distributor.commitmentConsumed(3));
        vm.prank(PUBLISHER);
        vm.expectRevert(abi.encodeWithSelector(DividendDistributor.EpochAlreadyExists.selector, 3));
        distributor.publishEpoch(3, c);
    }

    function testClaimWindowMustBeExactlyThirtyDays() public {
        IDividendDistributor.EpochCommitment memory c = _commitment(4, USER, 1 ether);
        c.claimEnd = c.claimStart + 30 days - 1;
        vm.expectRevert(DividendDistributor.InvalidClaimWindow.selector);
        distributor.approveEpochCommitment(4, c);
        c = _commitment(5, USER, 1 ether);
        c.claimEnd = c.claimStart + 30 days + 1;
        vm.expectRevert(DividendDistributor.InvalidClaimWindow.selector);
        distributor.approveEpochCommitment(5, c);
        c = _commitment(6, USER, 1 ether);
        distributor.approveEpochCommitment(6, c);
        vm.prank(PUBLISHER);
        distributor.publishEpoch(6, c);
    }

    function testEmergencyCanPauseButOnlyGovernanceCanUnpause() public {
        IDividendDistributor.EpochCommitment memory c = _commitment(7, USER, 1 ether);
        distributor.approveEpochCommitment(7, c);
        vm.prank(PUBLISHER);
        distributor.publishEpoch(7, c);
        vm.prank(EMERGENCY);
        distributor.pause();
        bytes32[] memory proof = new bytes32[](0);
        vm.prank(USER);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        distributor.claim(7, 1 ether, proof);
        vm.prank(EMERGENCY);
        vm.expectRevert();
        distributor.unpause();
        distributor.unpause();
        vm.prank(USER);
        distributor.claim(7, 1 ether, proof);
        assertEq(token.balanceOf(USER), 1 ether);
    }

    function testPublisherCannotSubstituteApprovedRoot() public {
        IDividendDistributor.EpochCommitment memory c = _commitment(8, USER, 1 ether);
        distributor.approveEpochCommitment(8, c);
        c.merkleRoot = distributor.leafFor(8, PUBLISHER, 1 ether);
        vm.prank(PUBLISHER);
        vm.expectRevert(DividendDistributor.CommitmentMismatch.selector);
        distributor.publishEpoch(8, c);
    }

    function testCommitmentIsDomainSeparatedByChainAndDistributor() public {
        IDividendDistributor.EpochCommitment memory c = _commitment(9, USER, 1 ether);
        bytes32 localHash = distributor.commitmentHash(9, c);
        DividendDistributor other = new DividendDistributor(address(token), address(costBasis), address(this), PUBLISHER, EMERGENCY);
        assertTrue(other.commitmentHash(9, c) != localHash);
        distributor.approveEpochCommitment(9, c);
        uint256 originalChainId = block.chainid;
        vm.chainId(97);
        vm.prank(PUBLISHER);
        vm.expectRevert(DividendDistributor.CommitmentMismatch.selector);
        distributor.publishEpoch(9, c);
        vm.chainId(originalChainId);
    }

    function _commitment(uint256 epochId, address account, uint256 amount) internal view returns (IDividendDistributor.EpochCommitment memory) {
        return IDividendDistributor.EpochCommitment({
            merkleRoot: distributor.leafFor(epochId, account, amount),
            artifactChecksum: keccak256(abi.encode("PANGU2_EPOCH_ARTIFACT", epochId)),
            totalAmount: amount,
            claimStart: uint64(block.timestamp),
            claimEnd: uint64(block.timestamp + 30 days),
            snapshotBlock: uint32(block.number),
            schemaVersion: distributor.LEAF_SCHEMA_VERSION()
        });
    }

    function _expectMismatch(uint256 epochId, IDividendDistributor.EpochCommitment memory c) internal {
        vm.prank(PUBLISHER);
        vm.expectRevert(DividendDistributor.CommitmentMismatch.selector);
        distributor.publishEpoch(epochId, c);
    }
}
