// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Pangu2IntegrationTest} from "./Pangu2Integration.t.sol";
import {Pangu2Token} from "pangu2/Pangu2Token.sol";
import {Pangu2TradeRouter} from "pangu2/Pangu2TradeRouter.sol";
import {ICostBasisManager} from "pangu2/interfaces/ICostBasisManager.sol";

contract CostBasisTransferContextTest is Pangu2IntegrationTest {
    address internal constant SECOND_USER = address(0xB0B);

    function setUp() public override {
        super.setUp();
        vm.deal(SECOND_USER, 100 ether);
    }

    function testUserCannotTransferDirectlyToNonDepositSystemAddresses() public {
        token.transfer(USER, 7 ether);
        address[7] memory forbidden = [
            address(tradeRouter),
            address(feeVault),
            address(supportPool),
            address(locker),
            address(distributor),
            address(adapter),
            address(liquidityManager)
        ];

        for (uint256 i; i < forbidden.length; ++i) {
            vm.prank(USER);
            vm.expectRevert(Pangu2Token.DirectSystemInteractionForbidden.selector);
            token.transfer(forbidden[i], 1 ether);
        }
    }

    function testSystemCannotCreditUserWithoutExplicitContext() public {
        _buy(USER, 10 ether);
        vm.startPrank(USER);
        token.approve(address(liquidityManager), 2 ether);
        liquidityManager.depositToSelf(USER, 2 ether);
        vm.stopPrank();

        vm.expectRevert(Pangu2Token.DirectSystemInteractionForbidden.selector);
        liquidityManager.rawTransfer(USER, 1 ether);

        liquidityManager.unknownCredit(USER, 1 ether);
        ICostBasisManager.Position memory p = costBasis.positionOf(USER);
        assertEq(uint256(p.status), uint256(ICostBasisManager.PositionStatus.UNKNOWN));
        assertEq(p.trackedBalance, token.balanceOf(USER));
        assertEq(p.costWbnbWei, 0);
    }

    function testExactLiquidityReturnPreservesKnownCost() public {
        _buy(USER, 10 ether);
        _deposit(USER, 6 ether);
        liquidityManager.withdrawTo(USER, 6 ether);

        ICostBasisManager.Position memory userP = costBasis.positionOf(USER);
        ICostBasisManager.Position memory lpP = costBasis.liquidityPositionOf(USER);
        assertEq(uint256(userP.status), uint256(ICostBasisManager.PositionStatus.KNOWN));
        assertEq(userP.trackedBalance, token.balanceOf(USER));
        assertEq(userP.costWbnbWei, 10 ether);
        assertEq(uint256(lpP.status), uint256(ICostBasisManager.PositionStatus.NONE));
    }

    function testPartialLiquidityReturnPreservesSeparateKnownPositions() public {
        _buy(USER, 10 ether);
        _deposit(USER, 6 ether);
        liquidityManager.withdrawTo(USER, 3 ether);

        ICostBasisManager.Position memory userP = costBasis.positionOf(USER);
        ICostBasisManager.Position memory lpP = costBasis.liquidityPositionOf(USER);
        assertEq(uint256(userP.status), uint256(ICostBasisManager.PositionStatus.KNOWN));
        assertEq(userP.trackedBalance, token.balanceOf(USER));
        assertEq(uint256(lpP.status), uint256(ICostBasisManager.PositionStatus.KNOWN));
        assertEq(lpP.trackedBalance, 3 ether);
        assertEq(userP.costWbnbWei + lpP.costWbnbWei, 10 ether);
    }

    function testLiquidityReturnAboveTrackedAmountFailsClosedToUnknown() public {
        _buy(USER, 10 ether);
        _buy(SECOND_USER, 10 ether);
        _deposit(USER, 6 ether);
        _deposit(SECOND_USER, 6 ether);

        liquidityManager.withdrawTo(USER, 7 ether);
        ICostBasisManager.Position memory userP = costBasis.positionOf(USER);
        ICostBasisManager.Position memory lpP = costBasis.liquidityPositionOf(USER);
        assertEq(uint256(userP.status), uint256(ICostBasisManager.PositionStatus.UNKNOWN));
        assertEq(userP.trackedBalance, token.balanceOf(USER));
        assertEq(userP.costWbnbWei, 0);
        assertEq(uint256(lpP.status), uint256(ICostBasisManager.PositionStatus.NONE));
    }

    function testUnknownDoesNotBecomeKnownThroughLiquidityRoundTrip() public {
        token.transfer(USER, 10 ether);
        _deposit(USER, 4 ether);
        liquidityManager.withdrawTo(USER, 4 ether);
        ICostBasisManager.Position memory p = costBasis.positionOf(USER);
        assertEq(uint256(p.status), uint256(ICostBasisManager.PositionStatus.UNKNOWN));
        assertEq(p.costWbnbWei, 0);
    }

    function testPreviewAndExecutionUseSameTaxAfterExactLiquidityRoundTrip() public {
        _buy(USER, 10 ether);
        _deposit(USER, 6 ether);
        liquidityManager.withdrawTo(USER, 6 ether);

        Pangu2TradeRouter.SellPreview memory preview = tradeRouter.previewSell(USER, 1 ether);
        uint256 supportBefore = feeVault.supportBalance();
        vm.startPrank(USER);
        token.approve(address(tradeRouter), 1 ether);
        tradeRouter.sell(1 ether, 0.8 ether, block.timestamp + 5 minutes);
        vm.stopPrank();

        (uint256 expectedSupport,,) = token.previewSellTax(1 ether, preview.taxBps);
        assertEq(feeVault.supportBalance() - supportBefore, expectedSupport);
        assertEq(preview.taxBps, token.NORMAL_SELL_TAX_BPS());
    }

    function testFuzz_KnownPositionAlwaysMatchesActualBalanceAfterLiquidityRoundTrip(
        uint96 rawDeposit,
        uint96 rawReturn
    ) public {
        _buy(USER, 10 ether);
        uint256 deposit = bound(uint256(rawDeposit), 1, 9.6 ether);
        _deposit(USER, deposit);
        uint256 returned = bound(uint256(rawReturn), 1, deposit);
        liquidityManager.withdrawTo(USER, returned);

        ICostBasisManager.Position memory p = costBasis.positionOf(USER);
        if (p.status == ICostBasisManager.PositionStatus.KNOWN) {
            assertEq(p.trackedBalance, token.balanceOf(USER));
        }
    }

    function _buy(address account, uint256 amount) internal {
        vm.prank(account);
        tradeRouter.buy{value: amount}(amount * 9 / 10, block.timestamp + 5 minutes);
    }

    function _deposit(address account, uint256 amount) internal {
        vm.startPrank(account);
        token.approve(address(liquidityManager), amount);
        liquidityManager.depositToSelf(account, amount);
        vm.stopPrank();
    }
}
