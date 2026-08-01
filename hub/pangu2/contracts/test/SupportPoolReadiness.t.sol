// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Pangu2IntegrationTest} from "./Pangu2Integration.t.sol";
import {SupportPool} from "pangu2/SupportPool.sol";
import {ISupportPool} from "pangu2/interfaces/ISupportPool.sol";
import {IPangu2TwapOracle} from "pangu2/interfaces/IPangu2TwapOracle.sol";
import {IBuybackLocker} from "pangu2/interfaces/IBuybackLocker.sol";

contract ZeroQuoteOracle is IPangu2TwapOracle {
    function validatedQuote(address, address, uint128)
        external
        pure
        override
        returns (Quote memory quote)
    {
        quote = Quote({
            amountOut: 0,
            arithmeticMeanTick: 0,
            spotTick: 0,
            harmonicMeanLiquidity: 1,
            observedAtBlock: 1
        });
    }
}

contract ReadinessLockerStub is IBuybackLocker {
    function registerBuyback(uint256, uint256) external pure override returns (uint256 batchId) {
        return 1;
    }

    function outstandingLocked() external pure override returns (uint256) {
        return 0;
    }
}

contract SupportPoolReadinessTest is Pangu2IntegrationTest {
    function testCanExecuteReportsInsufficientAndRecoversWithoutPause() public {
        vm.deal(address(supportPool), 0.009 ether);
        (bool allowed, ISupportPool.BuybackBlockReason reason, uint256 balance, uint256 nextAllowedAt) =
            supportPool.canExecuteBuyback();
        assertFalse(allowed);
        assertEq(uint256(reason), uint256(ISupportPool.BuybackBlockReason.INSUFFICIENT_BNB));
        assertEq(balance, 0.009 ether);
        assertEq(nextAllowedAt, 0);
        assertFalse(supportPool.paused());

        vm.deal(address(supportPool), 0.01 ether);
        (allowed, reason, balance, nextAllowedAt) = supportPool.canExecuteBuyback();
        assertTrue(allowed);
        assertEq(uint256(reason), uint256(ISupportPool.BuybackBlockReason.NONE));
        assertEq(balance, 0.01 ether);
        assertEq(nextAllowedAt, 0);

        vm.deal(address(supportPool), 1 ether);
        (allowed, reason,,) = supportPool.canExecuteBuyback();
        assertTrue(allowed);
        assertEq(uint256(reason), uint256(ISupportPool.BuybackBlockReason.NONE));
    }

    function testCanExecuteReportsPausedAndOracleUnavailable() public {
        vm.deal(address(supportPool), 0.01 ether);
        vm.prank(EMERGENCY);
        supportPool.pause();
        (bool allowed, ISupportPool.BuybackBlockReason reason,,) = supportPool.canExecuteBuyback();
        assertFalse(allowed);
        assertEq(uint256(reason), uint256(ISupportPool.BuybackBlockReason.PAUSED));

        supportPool.unpause();
        pool.setOracleState(0, 1, 1_000_000 ether);
        (allowed, reason,,) = supportPool.canExecuteBuyback();
        assertFalse(allowed);
        assertEq(uint256(reason), uint256(ISupportPool.BuybackBlockReason.ORACLE_UNAVAILABLE));
    }

    function testCanExecuteReportsInvalidQuote() public {
        ZeroQuoteOracle zeroOracle = new ZeroQuoteOracle();
        SupportPool candidate = new SupportPool(
            address(token),
            address(wbnb),
            address(adapter),
            address(zeroOracle),
            300,
            5 minutes,
            address(this),
            EMERGENCY
        );
        ReadinessLockerStub stub = new ReadinessLockerStub();
        candidate.configureLocker(address(stub));
        vm.deal(address(candidate), 0.01 ether);

        (bool allowed, ISupportPool.BuybackBlockReason reason,,) = candidate.canExecuteBuyback();
        assertFalse(allowed);
        assertEq(uint256(reason), uint256(ISupportPool.BuybackBlockReason.INVALID_QUOTE));
    }

    function testCooldownBoundaryAndPermissionlessCallers() public {
        vm.deal(address(supportPool), 0.02 ether);
        vm.prank(USER);
        supportPool.buyback();
        uint256 firstSuccess = supportPool.lastSuccessfulBuybackAt();

        vm.warp(firstSuccess + 59 seconds);
        (bool allowed, ISupportPool.BuybackBlockReason reason,, uint256 nextAllowedAt) =
            supportPool.canExecuteBuyback();
        assertFalse(allowed);
        assertEq(uint256(reason), uint256(ISupportPool.BuybackBlockReason.COOLDOWN));
        assertEq(nextAllowedAt, firstSuccess + 60 seconds);

        vm.warp(firstSuccess + 60 seconds);
        (allowed, reason,, nextAllowedAt) = supportPool.canExecuteBuyback();
        assertTrue(allowed);
        assertEq(uint256(reason), uint256(ISupportPool.BuybackBlockReason.NONE));
        assertEq(nextAllowedAt, firstSuccess + 60 seconds);

        vm.prank(KEEPER);
        supportPool.buyback();
        assertEq(supportPool.buybackCount(), 2);
        assertEq(locker.outstandingLocked(), 0.02 ether);
    }

    function testOracleDexAndSlippageFailuresDoNotAdvanceTimestamp() public {
        vm.deal(address(supportPool), 0.03 ether);

        pool.setOracleState(0, 1, 1_000_000 ether);
        vm.expectRevert();
        supportPool.buyback();
        assertEq(supportPool.lastSuccessfulBuybackAt(), 0);

        pool.setOracleState(0, 16, 1_000_000 ether);
        swapRouter.setOutputBps(5_000);
        vm.expectRevert();
        supportPool.buyback();
        assertEq(supportPool.lastSuccessfulBuybackAt(), 0);
        assertEq(address(supportPool).balance, 0.03 ether);

        swapRouter.setOutputBps(10_000);
        supportPool.buyback();
        assertGt(supportPool.lastSuccessfulBuybackAt(), 0);
        assertEq(address(supportPool).balance, 0.02 ether);
        assertEq(token.balanceOf(address(locker)), 0.01 ether);
    }
}
