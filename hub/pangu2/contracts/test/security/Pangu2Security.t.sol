// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Pangu2IntegrationTest} from "../Pangu2Integration.t.sol";
import {Pangu2Token} from "pangu2/Pangu2Token.sol";
import {Pangu2TradeRouter} from "pangu2/Pangu2TradeRouter.sol";
import {ICostBasisManager} from "pangu2/interfaces/ICostBasisManager.sol";

contract Pangu2SecurityTest is Pangu2IntegrationTest {
    function testDustSellCannotBypassTax() public {
        vm.expectRevert(Pangu2Token.InvalidAmount.selector);
        token.previewSellTax(token.MIN_SELL_AMOUNT() - 1, token.NORMAL_SELL_TAX_BPS());

        (uint256 normalSupport, uint256 normalBurn, uint256 normalSwap) =
            token.previewSellTax(101, token.NORMAL_SELL_TAX_BPS());
        assertEq(normalSupport, 5);
        assertEq(normalBurn, 0);
        assertEq(normalSupport + normalBurn + normalSwap, 101);

        (uint256 profitSupport, uint256 profitBurn, uint256 profitSwap) =
            token.previewSellTax(101, token.PROFIT_SELL_TAX_BPS());
        assertEq(profitSupport, 10);
        assertEq(profitBurn, 1);
        assertEq(profitSupport + profitBurn + profitSwap, 101);
    }

    function testFuzz_TaxSplitConserves(uint128 rawAmount, bool profitable) public view {
        uint256 amount = bound(uint256(rawAmount), token.MIN_SELL_AMOUNT(), 1_000_000_000 ether);
        uint16 taxBps = profitable ? token.PROFIT_SELL_TAX_BPS() : token.NORMAL_SELL_TAX_BPS();
        (uint256 support, uint256 burn, uint256 swapAmount) = token.previewSellTax(amount, taxBps);
        assertEq(support + burn + swapAmount, amount);
        if (profitable) assertGt(burn, 0);
        else assertEq(burn, 0);
    }

    function testFuzz_BuyTaxConserves(uint128 rawAmount) public view {
        uint256 gross = bound(uint256(rawAmount), 2, 1_000_000_000 ether);
        (uint256 taxAmount, uint256 netAmount) = token.previewBuyTax(gross);
        assertEq(taxAmount + netAmount, gross);
        assertGt(taxAmount, 0);
        assertGt(netAmount, 0);
    }

    function testProfitTaxUsesGrossSellAmountNotSequentialRemainder() public view {
        uint256 sellAmount = 10_000;
        (uint256 support, uint256 burn, uint256 swapAmount) =
            token.previewSellTax(sellAmount, token.PROFIT_SELL_TAX_BPS());
        assertEq(support, 900);
        assertEq(burn, 100);
        assertEq(swapAmount, 9_000);
        assertEq(support + burn + swapAmount, sellAmount);
        uint256 sequentialTax = 400 + ((sellAmount - 400) * 600) / 10_000;
        assertEq(sequentialTax, 976);
        assertTrue(support + burn != sequentialTax);
    }

    function testProfitSellUsesTenPercentAndBurnsOnePercent() public {
        swapRouter.setOutputBps(20_000);
        vm.prank(USER);
        tradeRouter.buy{value: 1 ether}(1.8 ether, block.timestamp + 5 minutes);
        swapRouter.setOutputBps(10_000);

        Pangu2TradeRouter.SellPreview memory preview = tradeRouter.previewSell(USER, 1 ether);
        assertEq(preview.taxBps, 1_000);
        assertEq(preview.supportTokens, 0.09 ether);
        assertEq(preview.burnTokens, 0.01 ether);
        assertEq(preview.swapTokens, 0.9 ether);

        uint256 supplyBefore = token.totalSupply();
        vm.startPrank(USER);
        token.approve(address(tradeRouter), 1 ether);
        uint256 amountOut = tradeRouter.sell(1 ether, 0.8 ether, block.timestamp + 5 minutes);
        vm.stopPrank();
        assertEq(amountOut, 0.9 ether);
        assertEq(token.totalSupply(), supplyBefore - 0.01 ether);
        assertEq(feeVault.supportBalance(), 0.09 ether);
    }

    function testSellRecomputesTaxAfterCostStatusChangesFromPriorPreview() public {
        vm.prank(USER);
        tradeRouter.buy{value: 10 ether}(9 ether, block.timestamp + 5 minutes);
        Pangu2TradeRouter.SellPreview memory beforeChange = tradeRouter.previewSell(USER, 1 ether);
        assertEq(beforeChange.taxBps, token.NORMAL_SELL_TAX_BPS());

        token.transfer(USER, 1 ether);
        Pangu2TradeRouter.SellPreview memory afterChange = tradeRouter.previewSell(USER, 1 ether);
        assertEq(afterChange.taxBps, token.PROFIT_SELL_TAX_BPS());
        assertEq(uint256(afterChange.costStatus), uint256(ICostBasisManager.PositionStatus.UNKNOWN));

        uint256 supportBefore = feeVault.supportBalance();
        uint256 supplyBefore = token.totalSupply();
        vm.startPrank(USER);
        token.approve(address(tradeRouter), 1 ether);
        tradeRouter.sell(1 ether, 0.8 ether, block.timestamp + 5 minutes);
        vm.stopPrank();
        assertEq(feeVault.supportBalance() - supportBefore, 0.09 ether);
        assertEq(supplyBefore - token.totalSupply(), 0.01 ether);
    }

    function testDirectPairBypassCannotForgeSettlementContext() public {
        token.transfer(USER, 1 ether);
        vm.startPrank(USER);
        vm.expectRevert(Pangu2Token.DirectPairInteractionForbidden.selector);
        token.transfer(address(pool), 1 ether);
        vm.stopPrank();
    }

    function testBuybackFailureDoesNotAdvanceTimestamp() public {
        assertEq(supportPool.lastSuccessfulBuybackAt(), 0);
        vm.expectRevert();
        supportPool.buyback();
        assertEq(supportPool.lastSuccessfulBuybackAt(), 0);
    }
}
