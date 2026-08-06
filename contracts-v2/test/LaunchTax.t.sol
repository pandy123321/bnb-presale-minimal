// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { Pangu2Token } from "pangu2/Pangu2Token.sol";

contract LaunchTaxTest is Test {
    Pangu2Token internal token;

    address internal constant GOVERNANCE = address(0x6000);
    address internal constant EMERGENCY = address(0x7000);
    address internal constant HOLDER = address(0x8000);
    address internal constant BUYER = address(0x9000);

    uint256 internal constant TOTAL_SUPPLY = 1_000_000_000 ether;

    function setUp() public {
        token = new Pangu2Token(HOLDER, GOVERNANCE, EMERGENCY);
        // Open trading at t=0
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        assertEq(block.timestamp, 1); // forge starts at t=1
    }

    // ═══════════════════════════════════════════════════════
    // T1: t=0 (immediate) — buy tax = 30%
    // ═══════════════════════════════════════════════════════
    function testBuyTaxAtT0_30Percent() public {
        // block.timestamp == 1, tradingOpenAt == 1 → in launch protection
        assertTrue(token.isInLaunchProtection());

        (uint256 tax, uint256 net) = token.previewBuyTax(1 ether);
        // 30% of 1 ether = 0.3 ether
        assertEq(tax, 300_000_000_000_000_000, "tax should be 30%");
        assertEq(net, 700_000_000_000_000_000, "net should be 70%");
        assertEq(tax + net, 1 ether, "buy invariant: tax+net == gross");
    }

    // ═══════════════════════════════════════════════════════
    // T2: t=0 (immediate) — sell tax = 30% (29% support, 1% burn)
    // ═══════════════════════════════════════════════════════
    function testSellTaxAtT0_30Percent() public {
        assertTrue(token.isInLaunchProtection());

        (uint256 support, uint256 burn, uint256 swap) = token.previewSellTax(1 ether, 400); // taxBps is ignored during launch

        uint256 expectedTotalTax = 300_000_000_000_000_000; // 30%
        uint256 expectedBurn = expectedTotalTax / 30; // 1/30 of tax = 1% of sell
        uint256 expectedSupport = expectedTotalTax - expectedBurn;

        assertEq(support, expectedSupport, "support should be 29%");
        assertEq(burn, expectedBurn, "burn should be 1%");
        assertEq(swap, 700_000_000_000_000_000, "swap should be 70%");
        assertEq(support + burn + swap, 1 ether, "sell invariant");
    }

    // ═══════════════════════════════════════════════════════
    // T3: t=14:59 — buy tax still 30%
    // ═══════════════════════════════════════════════════════
    function testBuyTaxAt14m59s_Still30Percent() public {
        // Warp to 14:59 (899 seconds after trading opened)
        vm.warp(block.timestamp + 15 minutes - 1);
        assertTrue(token.isInLaunchProtection());

        (uint256 tax, uint256 net) = token.previewBuyTax(1 ether);
        assertEq(tax, 300_000_000_000_000_000);
        assertEq(net, 700_000_000_000_000_000);
    }

    // ═══════════════════════════════════════════════════════
    // T4: t=14:59 — sell tax still 30%
    // ═══════════════════════════════════════════════════════
    function testSellTaxAt14m59s_Still30Percent() public {
        vm.warp(block.timestamp + 15 minutes - 1);
        assertTrue(token.isInLaunchProtection());

        (uint256 support, uint256 burn, uint256 swap) = token.previewSellTax(1 ether, 1000); // taxBps ignored

        assertEq(burn, 10_000_000_000_000_000, "burn 1% at 14:59");
        assertEq(support + burn + swap, 1 ether);
    }

    // ═══════════════════════════════════════════════════════
    // T5: t=15:00 — buy tax returns to normal 4%
    // ═══════════════════════════════════════════════════════
    function testBuyTaxAt15m00s_Normal4Percent() public {
        vm.warp(block.timestamp + 15 minutes);
        assertFalse(token.isInLaunchProtection());

        (uint256 tax, uint256 net) = token.previewBuyTax(1 ether);
        assertEq(tax, 40_000_000_000_000_000, "normal buy tax 4%");
        assertEq(net, 960_000_000_000_000_000, "normal net 96%");
        assertEq(tax + net, 1 ether);
    }

    // ═══════════════════════════════════════════════════════
    // T6: t=15:01 — buy tax still normal
    // ═══════════════════════════════════════════════════════
    function testBuyTaxAt15m01s_StaysNormal() public {
        vm.warp(block.timestamp + 15 minutes + 1);
        assertFalse(token.isInLaunchProtection());

        (uint256 tax, uint256 net) = token.previewBuyTax(1 ether);
        assertEq(tax, 40_000_000_000_000_000);
        assertEq(net, 960_000_000_000_000_000);
    }

    // ═══════════════════════════════════════════════════════
    // T7: Invariant — buy: tax + net == gross
    // ═══════════════════════════════════════════════════════
    function testBuyInvariantTaxPlusNetEqualsGross() public {
        uint256[] memory amounts = _testAmounts();

        for (uint256 i = 0; i < amounts.length; i++) {
            // Launch period
            vm.warp(1);
            (uint256 t1, uint256 n1) = token.previewBuyTax(amounts[i]);
            assertEq(t1 + n1, amounts[i], "launch buy invariant");

            // Normal period
            vm.warp(block.timestamp + 15 minutes);
            (uint256 t2, uint256 n2) = token.previewBuyTax(amounts[i]);
            assertEq(t2 + n2, amounts[i], "normal buy invariant");

            vm.warp(1); // reset for next iteration
        }
    }

    // ═══════════════════════════════════════════════════════
    // T8: Invariant — sell: support + burn + swap == sellAmount
    // ═══════════════════════════════════════════════════════
    function testSellInvariantSupportPlusBurnPlusSwap() public {
        uint256[] memory amounts = _testAmounts();

        for (uint256 i = 0; i < amounts.length; i++) {
            if (amounts[i] < token.MIN_SELL_AMOUNT()) continue;

            // Launch period
            vm.warp(1);
            (uint256 s1, uint256 b1, uint256 sw1) = token.previewSellTax(amounts[i], 400);
            assertEq(s1 + b1 + sw1, amounts[i], "launch sell invariant");

            // Normal NORMAL
            vm.warp(block.timestamp + 15 minutes);
            (uint256 s2, uint256 b2, uint256 sw2) = token.previewSellTax(amounts[i], 400);
            assertEq(s2 + b2 + sw2, amounts[i], "normal sell invariant 4%");

            // Normal PROFIT
            (uint256 s3, uint256 b3, uint256 sw3) = token.previewSellTax(amounts[i], 1000);
            assertEq(s3 + b3 + sw3, amounts[i], "profit sell invariant 10%");

            vm.warp(1); // reset
        }
    }

    // ═══════════════════════════════════════════════════════
    // T9: 29% support + 1% burn = 30% total (launch sell)
    // ═══════════════════════════════════════════════════════
    function testLaunchSell29Support1Burn() public {
        assertTrue(token.isInLaunchProtection());

        for (uint256 i = 0; i < _testAmounts().length; i++) {
            uint256 amount = _testAmounts()[i];
            if (amount < token.MIN_SELL_AMOUNT()) continue;

            (uint256 support, uint256 burn, uint256 _swap) = token.previewSellTax(amount, 400);

            uint256 totalTax = support + burn;
            // totalTax should be ~30% of amount
            uint256 expectedTax = (amount * 3000) / 10_000;
            // Allow ±1 wei rounding difference
            assertApproxEqAbs(totalTax, expectedTax, 1, "total tax ~30%");

            // burn should be ~1% of amount
            uint256 expectedBurn = (amount * 100) / 10_000;
            assertApproxEqAbs(burn, expectedBurn, 1, "burn ~1%");

            // support should be ~29% of amount
            uint256 expectedSupport = (amount * 2900) / 10_000;
            assertApproxEqAbs(support, expectedSupport, 1, "support ~29%");
        }
    }

    // ═══════════════════════════════════════════════════════
    // T10: 1% burn accuracy on launch sell
    // ═══════════════════════════════════════════════════════
    function testLaunchSellBurnIs1Percent() public {
        assertTrue(token.isInLaunchProtection());

        // Use a clean amount to avoid rounding noise
        uint256 sellAmount = 10_000 ether; // divisible by 10000

        (uint256 sup, uint256 burn, uint256 swp) = token.previewSellTax(sellAmount, 400);

        // 1% of 10000 ether = 100 ether
        // burn = (totalTax * 100) / 3000 = (3e21 * 100) / 3000 = 1e20 = 100 ether
        assertEq(burn, 100 ether, "burn should be exactly 1% of 10000 ether");
    }

    // ═══════════════════════════════════════════════════════
    // T11: Preview and Settlement produce same values
    // ═══════════════════════════════════════════════════════
    function testPreviewMatchesSettlementBuy() public {
        assertTrue(token.isInLaunchProtection());

        // previewBuyTax and settleBuy (which calls previewBuyTax internally)
        // must produce identical results.
        (uint256 pTax, uint256 pNet) = token.previewBuyTax(1 ether);

        // settleBuy can't be called directly in test (needs SETTLEMENT_ROLE + coreConfigured)
        // but it calls the same previewBuyTax internally. We verify the preview values
        // match the expected constants.
        assertEq(pTax, (1 ether * 3000) / 10_000, "preview buy tax 30%");
        assertEq(pNet, 1 ether - pTax, "preview buy net");
    }

    function testPreviewMatchesSettlementSell() public {
        assertTrue(token.isInLaunchProtection());

        (uint256 pSupport, uint256 pBurn, uint256 pSwap) = token.previewSellTax(1 ether, 1000);

        // previewSellTax is called internally by settleSell
        uint256 expectedTax = (1 ether * 3000) / 10_000;
        uint256 expectedBurn = expectedTax / 30;
        assertEq(pBurn, expectedBurn, "preview sell burn");
        assertEq(pSupport + pBurn + pSwap, 1 ether);
    }

    // ═══════════════════════════════════════════════════════
    // T12: Tiny amounts don't revert and preserve invariants
    // ═══════════════════════════════════════════════════════
    function testTinyBuyAmount1WeiReverts() public {
        assertTrue(token.isInLaunchProtection());
        // 1 wei: 30% of 1 = 0.3 rounds up to 1, and 1 >= 1 → InvalidAmount
        vm.expectRevert(Pangu2Token.InvalidAmount.selector);
        token.previewBuyTax(1);
    }

    function testTinyBuyAmount2WeiOk() public {
        assertTrue(token.isInLaunchProtection());
        // 2 wei: 30% of 2 = 0.6 rounds up to 1, tax=1, net=1
        (uint256 tax, uint256 net) = token.previewBuyTax(2);
        assertEq(tax, 1, "tax on 2 wei");
        assertEq(net, 1, "net on 2 wei");
        assertEq(tax + net, 2);
    }

    function testTinySellAmount() public {
        assertTrue(token.isInLaunchProtection());

        // MIN_SELL_AMOUNT = 100
        uint256 min = token.MIN_SELL_AMOUNT();
        (uint256 s, uint256 b, uint256 sw) = token.previewSellTax(min, 400);

        // 30% of 100 = 30, burn = 30/30 = 1
        assertEq(b, 1, "burn minimum 1 wei");
        assertEq(s + b + sw, min, "sell invariant at minimum");
    }

    // ═══════════════════════════════════════════════════════
    // T13: Large amounts (1B tokens) don't overflow
    // ═══════════════════════════════════════════════════════
    function testMaxBuyAmount() public {
        assertTrue(token.isInLaunchProtection());

        uint256 largeAmount = 1_000_000_000 ether; // 1B tokens
        (uint256 tax, uint256 net) = token.previewBuyTax(largeAmount);

        assertEq(tax, (largeAmount * 3000) / 10_000, "large buy tax 30%");
        assertEq(net, largeAmount - tax, "large buy net");
        assertEq(tax + net, largeAmount);
    }

    function testMaxSellAmount() public {
        assertTrue(token.isInLaunchProtection());

        uint256 largeAmount = 1_000_000_000 ether;
        (uint256 support, uint256 burn, uint256 swap) = token.previewSellTax(largeAmount, 400);

        assertEq(support + burn + swap, largeAmount, "large sell invariant");
    }

    // ═══════════════════════════════════════════════════════
    // T14: Fuzz — random amounts in launch period
    // ═══════════════════════════════════════════════════════
    function testFuzzBuyLaunchTax(uint256 amount) public {
        amount = bound(amount, 2, 1_000_000_000 ether);
        vm.warp(1);

        (uint256 tax, uint256 net) = token.previewBuyTax(amount);

        assertEq(tax + net, amount, "fuzz buy invariant");
        assertTrue(tax > 0, "tax must be positive");
        assertTrue(net > 0, "net must be positive");
    }

    function testFuzzSellLaunchTax(uint256 amount) public {
        amount = bound(amount, token.MIN_SELL_AMOUNT(), 1_000_000_000 ether);
        vm.warp(1);

        (uint256 support, uint256 burn, uint256 swap) = token.previewSellTax(amount, 400);

        assertEq(support + burn + swap, amount, "fuzz sell invariant");
        assertTrue(burn > 0, "burn must be positive");
        assertTrue(support > 0, "support must be positive");
        assertTrue(swap > 0, "swap must be positive");
    }

    // ═══════════════════════════════════════════════════════
    // T15: Fuzz — random amounts in normal period
    // ═══════════════════════════════════════════════════════
    function testFuzzBuyNormalTax(uint256 amount) public {
        amount = bound(amount, 2, 1_000_000_000 ether);
        vm.warp(1 + 15 minutes + 1);

        (uint256 tax, uint256 net) = token.previewBuyTax(amount);

        assertEq(tax + net, amount, "fuzz normal buy invariant");
        // Tax should be ~4%
        uint256 expectedTax = (amount * 400) / 10_000;
        assertApproxEqAbs(tax, expectedTax, 1);
    }

    function testFuzzSellNormalTax(uint256 amount) public {
        amount = bound(amount, token.MIN_SELL_AMOUNT(), 1_000_000_000 ether);
        vm.warp(1 + 15 minutes + 1);

        (uint256 support, uint256 burn, uint256 swap) = token.previewSellTax(amount, 400);

        assertEq(support + burn + swap, amount, "fuzz normal sell invariant");
    }

    function testFuzzSellProfitTax(uint256 amount) public {
        amount = bound(amount, token.MIN_SELL_AMOUNT(), 1_000_000_000 ether);
        vm.warp(1 + 15 minutes + 1);

        (uint256 support, uint256 burn, uint256 swap) = token.previewSellTax(amount, 1000);

        assertEq(support + burn + swap, amount, "fuzz profit sell invariant");
        assertTrue(burn > 0, "profit burn must be positive");
    }

    // ═══════════════════════════════════════════════════════
    // T16: Before trading is opened, normal tax applies
    // ═══════════════════════════════════════════════════════
    function testBeforeTradingOpenNormalTax() public {
        // Deploy fresh token without calling setTradingOpenAt
        Pangu2Token freshToken = new Pangu2Token(HOLDER, GOVERNANCE, EMERGENCY);

        assertFalse(freshToken.isInLaunchProtection());
        assertEq(freshToken.tradingOpenAt(), 0);

        (uint256 tax, uint256 net) = freshToken.previewBuyTax(1 ether);
        assertEq(tax, 40_000_000_000_000_000, "before open: normal buy tax 4%");
        assertEq(net, 960_000_000_000_000_000);
    }

    // ═══════════════════════════════════════════════════════
    // T17: Cannot set trading open twice
    // ═══════════════════════════════════════════════════════
    function testCannotSetTradingOpenTwice() public {
        vm.warp(1 + 15 minutes + 1); // after launch window

        vm.prank(GOVERNANCE);
        vm.expectRevert(Pangu2Token.TradingAlreadyOpen.selector);
        token.setTradingOpenAt();
    }

    // ═══════════════════════════════════════════════════════
    // T18: Non-governance cannot set trading open
    // ═══════════════════════════════════════════════════════
    function testNonGovernanceCannotOpenTrading() public {
        Pangu2Token freshToken = new Pangu2Token(HOLDER, GOVERNANCE, EMERGENCY);
        vm.prank(BUYER);
        vm.expectRevert();
        freshToken.setTradingOpenAt();
    }

    // ═══════════════════════════════════════════════════════
    // T19: t=15:00 sell normal tax 4% / profit tax 10%
    // ═══════════════════════════════════════════════════════
    function testSellNormalAfter15Minutes() public {
        vm.warp(1 + 15 minutes);
        assertFalse(token.isInLaunchProtection());

        (uint256 s, uint256 b, uint256 sw) = token.previewSellTax(1 ether, 400);
        // Normal sell: 4% tax all to support, 0 burn
        assertEq(s, 40_000_000_000_000_000, "normal sell 4%");
        assertEq(b, 0, "normal sell no burn");
        assertEq(sw, 960_000_000_000_000_000, "normal sell swap 96%");
        assertEq(s + b + sw, 1 ether);
    }

    function testSellProfitAfter15Minutes() public {
        vm.warp(1 + 15 minutes);
        assertFalse(token.isInLaunchProtection());

        (uint256 s, uint256 b, uint256 sw) = token.previewSellTax(1 ether, 1000);
        // Profit sell: 10% total, 1% burn
        uint256 expectedTotal = 100_000_000_000_000_000; // 10%
        uint256 expectedBurn = expectedTotal / 10; // 1%
        assertEq(b, expectedBurn, "profit sell burn 1%");
        assertEq(s, expectedTotal - expectedBurn, "profit sell support 9%");
        assertEq(sw, 900_000_000_000_000_000, "profit sell swap 90%");
        assertEq(s + b + sw, 1 ether);
    }

    // ═══════════════════════════════════════════════════════
    // T20: Invariant — no underflow for any amount in range
    // ═══════════════════════════════════════════════════════
    function testInvariantNoUnderflow(uint256 amount) public {
        amount = bound(amount, 2, 1_000_000_000 ether);

        // Launch: buy
        vm.warp(1);
        (uint256 tax, uint256 net) = token.previewBuyTax(amount);
        assertTrue(tax < amount, "launch buy: tax must not reach amount");
        assertEq(tax + net, amount);

        // Launch: sell (only if >= MIN_SELL)
        if (amount >= token.MIN_SELL_AMOUNT()) {
            (uint256 s, uint256 b, uint256 sw) = token.previewSellTax(amount, 400);
            assertTrue(s + b < amount, "launch sell: total tax must not reach amount");
            assertEq(s + b + sw, amount);
        }

        // Normal: buy
        vm.warp(1 + 15 minutes);
        (uint256 tax2, uint256 net2) = token.previewBuyTax(amount);
        assertTrue(tax2 < amount, "normal buy: tax must not reach amount");
        assertEq(tax2 + net2, amount);

        // Normal: sell (NORMAL)
        if (amount >= token.MIN_SELL_AMOUNT()) {
            (uint256 s2, uint256 b2, uint256 sw2) = token.previewSellTax(amount, 400);
            assertEq(s2 + b2 + sw2, amount, "normal sell invariant");
        }
    }

    // ═══════════════════════════════════════════════════════
    // Helpers
    // ═══════════════════════════════════════════════════════

    function _testAmounts() private pure returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](10);
        amounts[0] = 100; // MIN_SELL_AMOUNT
        amounts[1] = 1000;
        amounts[2] = 10_000;
        amounts[3] = 100_000;
        amounts[4] = 1 ether;
        amounts[5] = 10 ether;
        amounts[6] = 100 ether;
        amounts[7] = 1000 ether;
        amounts[8] = 1_000_000 ether;
        amounts[9] = 1_000_000_000 ether;
        return amounts;
    }
}
