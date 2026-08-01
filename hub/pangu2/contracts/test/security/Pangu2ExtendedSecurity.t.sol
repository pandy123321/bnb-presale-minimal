// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Pangu2IntegrationTest} from "../Pangu2Integration.t.sol";
import {Pangu2Token} from "pangu2/Pangu2Token.sol";
import {PancakeV3TwapOracle} from "pangu2/oracle/PancakeV3TwapOracle.sol";
import {DividendDistributor} from "pangu2/DividendDistributor.sol";
import {ICostBasisManager} from "pangu2/interfaces/ICostBasisManager.sol";
import {IFeeVault} from "pangu2/interfaces/IFeeVault.sol";

contract Pangu2ExtendedSecurityTest is Pangu2IntegrationTest {
    address internal constant RECIPIENT = address(0xD00D);

    function testOfficialBuyAndPreviewShareFailClosedOracle() public {
        pool.setOracleState(0, 1, 1_000_000 ether);
        vm.expectRevert(PancakeV3TwapOracle.InsufficientObservationCardinality.selector);
        tradeRouter.previewBuy(1 ether);
        vm.prank(USER);
        vm.expectRevert(PancakeV3TwapOracle.InsufficientObservationCardinality.selector);
        tradeRouter.buy{value: 1 ether}(0.9 ether, block.timestamp + 5 minutes);
    }

    function testSpotTwapDeviationFailsClosed() public {
        pool.setOracleTicks(1_000, 0);
        vm.expectRevert(PancakeV3TwapOracle.SpotTwapDeviationExceeded.selector);
        tradeRouter.previewSell(USER, 1 ether);
    }

    function testBuyMinOutFailureRollsBackAllState() public {
        swapRouter.setOutputBps(5_000);
        uint256 supplyBefore = token.totalSupply();
        uint256 vaultBefore = token.balanceOf(address(feeVault));
        vm.prank(USER);
        vm.expectRevert();
        tradeRouter.buy{value: 1 ether}(0.9 ether, block.timestamp + 5 minutes);
        assertEq(token.balanceOf(USER), 0);
        assertEq(token.balanceOf(address(feeVault)), vaultBefore);
        assertEq(token.totalSupply(), supplyBefore);
    }

    function testKnownCostMigratesProportionallyOnUserTransfer() public {
        vm.prank(USER);
        tradeRouter.buy{value: 10 ether}(9 ether, block.timestamp + 5 minutes);
        vm.prank(USER);
        token.transfer(RECIPIENT, 4.8 ether);
        ICostBasisManager.Position memory sender = costBasis.positionOf(USER);
        ICostBasisManager.Position memory recipient = costBasis.positionOf(RECIPIENT);
        assertEq(sender.trackedBalance, 4.8 ether);
        assertEq(sender.costWbnbWei, 5 ether);
        assertEq(recipient.trackedBalance, 4.8 ether);
        assertEq(recipient.costWbnbWei, 5 ether);
        assertEq(uint256(sender.status), uint256(ICostBasisManager.PositionStatus.KNOWN));
        assertEq(uint256(recipient.status), uint256(ICostBasisManager.PositionStatus.KNOWN));
    }

    function testCostBasisHooksCannotBeCalledByGovernanceDirectly() public {
        vm.expectRevert();
        costBasis.recordBuy(USER, 1 ether, 1 ether);
        vm.expectRevert();
        costBasis.recordZeroCost(USER, 1 ether);
        vm.expectRevert();
        costBasis.consumeSell(USER, 1 ether);
    }

    function testEmergencyCanPauseButCannotUnpause() public {
        token.transfer(USER, 1 ether);
        vm.prank(EMERGENCY);
        token.pause();
        vm.prank(USER);
        token.transfer(RECIPIENT, 0.5 ether);
        assertEq(token.balanceOf(RECIPIENT), 0.5 ether);
        vm.expectRevert();
        token.transfer(address(pool), 0.5 ether);
        vm.prank(EMERGENCY);
        vm.expectRevert();
        token.unpause();
        token.unpause();
    }

    function testMerkleLeafCannotReplayAcrossAccountOrEpoch() public {
        token.transfer(address(distributor), 1 ether);
        bytes32 leaf = distributor.leafFor(1, USER, 0.1 ether);
        _approveAndPublishEpoch(1, leaf, 0.1 ether, keccak256("security-epoch-1"));
        bytes32[] memory proof = new bytes32[](0);
        vm.prank(RECIPIENT);
        vm.expectRevert(DividendDistributor.InvalidProof.selector);
        distributor.claim(1, 0.1 ether, proof);
        vm.prank(USER);
        distributor.claim(1, 0.1 ether, proof);
        vm.prank(USER);
        vm.expectRevert(DividendDistributor.AlreadyClaimed.selector);
        distributor.claim(1, 0.1 ether, proof);
        _approveAndPublishEpoch(2, leaf, 0.1 ether, keccak256("security-epoch-2"));
        vm.prank(USER);
        vm.expectRevert(DividendDistributor.InvalidProof.selector);
        distributor.claim(2, 0.1 ether, proof);
    }

    function testExpiredDividendRemainderBecomesCarryOnly() public {
        token.transfer(address(distributor), 1 ether);
        bytes32 leaf = distributor.leafFor(2, USER, 0.1 ether);
        uint64 end = uint64(block.timestamp + 30 days);
        _approveAndPublishEpoch(2, leaf, 0.2 ether, keccak256("security-carry"));
        bytes32[] memory proof = new bytes32[](0);
        vm.prank(USER);
        distributor.claim(2, 0.1 ether, proof);
        vm.warp(uint256(end) + 1);
        uint256 carry = distributor.closeEpoch(2);
        assertEq(carry, 0.1 ether);
        assertEq(distributor.nextEpochCarry(), 0.1 ether);
        assertEq(distributor.totalReservedClaims(), 0);
    }

    function testCoreRegistriesAndFeeCreditCannotBeChangedDirectly() public {
        vm.expectRevert();
        costBasis.setSystemAddress(RECIPIENT, true);
        vm.expectRevert(Pangu2Token.CoreSystemAddressImmutable.selector);
        token.setSystemAddress(address(feeVault), false);
        vm.expectRevert(Pangu2Token.CoreSystemAddressImmutable.selector);
        token.setSystemAddress(address(costBasis), false);
        vm.expectRevert();
        feeVault.credit(IFeeVault.Bucket.SUPPORT, 1 ether);
    }

    function testPublishedEpochCannotBeCancelledDuringClaimWindow() public {
        token.transfer(address(distributor), 1 ether);
        bytes32 leaf = distributor.leafFor(77, USER, 0.1 ether);
        _approveAndPublishEpoch(77, leaf, 0.1 ether, keccak256("security-cancel"));
        vm.expectRevert(DividendDistributor.ClaimWindowStillOpen.selector);
        distributor.cancelUnclaimedEpoch(77);
    }
}
