// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Pangu2IntegrationTest} from "./Pangu2Integration.t.sol";
import {SupportPool} from "pangu2/SupportPool.sol";
import {ISupportPool} from "pangu2/interfaces/ISupportPool.sol";
import {IPangu2TwapOracle} from "pangu2/interfaces/IPangu2TwapOracle.sol";

contract ConfigurableBuybackOracle is IPangu2TwapOracle {
    uint256 public amountOut;
    bool public shouldRevert;

    constructor(uint256 amountOut_) {
        amountOut = amountOut_;
    }

    function configure(uint256 amountOut_, bool shouldRevert_) external {
        amountOut = amountOut_;
        shouldRevert = shouldRevert_;
    }

    function validatedQuote(address, address, uint128)
        external
        view
        returns (Quote memory quote)
    {
        if (shouldRevert) revert("ORACLE_UNAVAILABLE");
        quote = Quote({
            amountOut: amountOut,
            arithmeticMeanTick: 0,
            spotTick: 0,
            harmonicMeanLiquidity: 1,
            observedAtBlock: block.number
        });
    }
}

contract LockerConfigurationStub {}

contract SupportPoolStatusTest is Pangu2IntegrationTest {
    function testCanExecuteBuybackReportsInsufficientAndAutomaticallyRecovers() public {
        vm.deal(address(supportPool), supportPool.BUYBACK_AMOUNT() - 1);
        (bool allowed, ISupportPool.BuybackBlockReason reason, uint256 balance, uint256 nextAllowedAt) =
            supportPool.canExecuteBuyback();
        assertFalse(allowed);
        assertEq(uint256(reason), uint256(ISupportPool.BuybackBlockReason.INSUFFICIENT_BNB));
        assertEq(balance, supportPool.BUYBACK_AMOUNT() - 1);
        assertEq(nextAllowedAt, 0);

        vm.deal(address(supportPool), supportPool.BUYBACK_AMOUNT());
        (allowed, reason, balance, nextAllowedAt) = supportPool.canExecuteBuyback();
        assertTrue(allowed);
        assertEq(uint256(reason), uint256(ISupportPool.BuybackBlockReason.NONE));
        assertEq(balance, supportPool.BUYBACK_AMOUNT());
        assertEq(nextAllowedAt, 0);

        vm.deal(address(supportPool), supportPool.BUYBACK_AMOUNT() * 3);
        uint256 ignoredNextAllowedAt;
        (allowed, reason, balance, ignoredNextAllowedAt) = supportPool.canExecuteBuyback();
        assertTrue(allowed);
        assertEq(uint256(reason), uint256(ISupportPool.BuybackBlockReason.NONE));
        assertEq(balance, supportPool.BUYBACK_AMOUNT() * 3);
    }

    function testCanExecuteBuybackReasonPrecedence() public {
        SupportPool unconfigured = new SupportPool(
            address(token),
            address(wbnb),
            address(adapter),
            address(oracle),
            300,
            5 minutes,
            address(this),
            EMERGENCY
        );
        vm.deal(address(unconfigured), unconfigured.BUYBACK_AMOUNT());
        (
            bool allowed,
            ISupportPool.BuybackBlockReason reason,
            uint256 ignoredBalance,
            uint256 ignoredNextAllowedAt
        ) = unconfigured.canExecuteBuyback();
        assertFalse(allowed);
        assertEq(uint256(reason), uint256(ISupportPool.BuybackBlockReason.LOCKER_NOT_CONFIGURED));

        vm.prank(EMERGENCY);
        supportPool.pause();
        (allowed, reason, ignoredBalance, ignoredNextAllowedAt) = supportPool.canExecuteBuyback();
        assertFalse(allowed);
        assertEq(uint256(reason), uint256(ISupportPool.BuybackBlockReason.PAUSED));
    }

    function testCanExecuteBuybackReportsOracleUnavailableAndInvalidQuote() public {
        vm.deal(address(supportPool), supportPool.BUYBACK_AMOUNT());
        pool.setOracleState(0, 1, 1_000_000 ether);
        (
            bool allowed,
            ISupportPool.BuybackBlockReason reason,
            uint256 ignoredBalance,
            uint256 ignoredNextAllowedAt
        ) = supportPool.canExecuteBuyback();
        assertFalse(allowed);
        assertEq(uint256(reason), uint256(ISupportPool.BuybackBlockReason.ORACLE_UNAVAILABLE));

        ConfigurableBuybackOracle zeroOracle = new ConfigurableBuybackOracle(0);
        SupportPool zeroQuotePool = new SupportPool(
            address(token),
            address(wbnb),
            address(adapter),
            address(zeroOracle),
            300,
            5 minutes,
            address(this),
            EMERGENCY
        );
        LockerConfigurationStub lockerStub = new LockerConfigurationStub();
        zeroQuotePool.configureLocker(address(lockerStub));
        vm.deal(address(zeroQuotePool), zeroQuotePool.BUYBACK_AMOUNT());
        (allowed, reason, ignoredBalance, ignoredNextAllowedAt) = zeroQuotePool.canExecuteBuyback();
        assertFalse(allowed);
        assertEq(uint256(reason), uint256(ISupportPool.BuybackBlockReason.INVALID_QUOTE));
    }

    function testInvalidQuoteCannotBeExecuted() public {
        ConfigurableBuybackOracle zeroOracle = new ConfigurableBuybackOracle(0);
        SupportPool zeroQuotePool = new SupportPool(
            address(token),
            address(wbnb),
            address(adapter),
            address(zeroOracle),
            300,
            5 minutes,
            address(this),
            EMERGENCY
        );
        LockerConfigurationStub lockerStub = new LockerConfigurationStub();
        zeroQuotePool.configureLocker(address(lockerStub));
        adapter.setCaller(address(zeroQuotePool), true);
        vm.deal(address(zeroQuotePool), zeroQuotePool.BUYBACK_AMOUNT());

        vm.expectRevert(SupportPool.InvalidOracleQuote.selector);
        zeroQuotePool.buyback();
        assertEq(zeroQuotePool.lastSuccessfulBuybackAt(), 0);
    }

    function testCooldownBoundaryManualAndKeeperCalls() public {
        vm.deal(address(supportPool), supportPool.BUYBACK_AMOUNT() * 3);
        uint256 beforeBalance = address(supportPool).balance;

        vm.prank(USER);
        uint256 firstOut = supportPool.buyback();
        assertGt(firstOut, 0);
        assertEq(beforeBalance - address(supportPool).balance, supportPool.BUYBACK_AMOUNT());
        assertEq(token.balanceOf(address(locker)), firstOut);

        uint256 last = supportPool.lastSuccessfulBuybackAt();
        vm.warp(last + 59 seconds);
        (
            bool allowed,
            ISupportPool.BuybackBlockReason reason,
            uint256 ignoredBalance,
            uint256 nextAllowedAt
        ) = supportPool.canExecuteBuyback();
        assertFalse(allowed);
        assertEq(uint256(reason), uint256(ISupportPool.BuybackBlockReason.COOLDOWN));
        assertEq(nextAllowedAt, last + 60 seconds);

        vm.warp(last + 60 seconds);
        (allowed, reason, ignoredBalance, nextAllowedAt) = supportPool.canExecuteBuyback();
        assertTrue(allowed);
        assertEq(uint256(reason), uint256(ISupportPool.BuybackBlockReason.NONE));
        assertEq(nextAllowedAt, last + 60 seconds);

        vm.prank(KEEPER);
        uint256 secondOut = supportPool.buyback();
        assertGt(secondOut, 0);
        assertEq(supportPool.buybackCount(), 2);
    }

    function testOracleSlippageAndDexFailuresDoNotAdvanceSuccessTimestamp() public {
        vm.deal(address(supportPool), supportPool.BUYBACK_AMOUNT() * 3);
        uint256 initialTimestamp = supportPool.lastSuccessfulBuybackAt();

        pool.setOracleState(0, 1, 1_000_000 ether);
        vm.expectRevert();
        supportPool.buyback();
        assertEq(supportPool.lastSuccessfulBuybackAt(), initialTimestamp);

        pool.setOracleState(0, 16, 1_000_000 ether);
        swapRouter.setOutputBps(9_600);
        vm.expectRevert();
        supportPool.buyback();
        assertEq(supportPool.lastSuccessfulBuybackAt(), initialTimestamp);

        swapRouter.setOutputBps(0);
        vm.expectRevert();
        supportPool.buyback();
        assertEq(supportPool.lastSuccessfulBuybackAt(), initialTimestamp);
    }

    function testCallerCannotChangeLockerRecipientOrConfiguredLocker() public {
        assertEq(locker.releaseRecipient(), RELEASE_RECIPIENT);
        LockerConfigurationStub otherLocker = new LockerConfigurationStub();
        vm.expectRevert(SupportPool.ConfigurationAlreadySet.selector);
        supportPool.configureLocker(address(otherLocker));
        assertEq(address(supportPool.locker()), address(locker));
    }
}
