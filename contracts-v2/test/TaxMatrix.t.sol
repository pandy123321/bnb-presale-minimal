// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { Pangu2Token } from "pangu2/Pangu2Token.sol";

contract TaxMatrixTest is Test {
    Pangu2Token internal token;

    address internal constant GOVERNANCE = address(0x6000);
    address internal constant EMERGENCY = address(0x7000);
    address internal constant HOLDER = address(0x8000);
    address internal constant WL_USER = address(0xA000);
    address internal constant USER_B = address(0xB000);

    function setUp() public {
        token = new Pangu2Token(HOLDER, GOVERNANCE, EMERGENCY);
        vm.prank(GOVERNANCE);
        token.setFeeWhitelist(WL_USER, true);
    }

    // ═══════════════════════════════════════════════════════
    // Cell [Launch  WL  Buy] → 0%
    // ═══════════════════════════════════════════════════════
    function testLaunch_WL_Buy_0() public {
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        (uint256 tax, uint256 net) = token.previewBuyTaxFor(WL_USER, 1 ether);
        assertEq(tax, 0);
        assertEq(net, 1 ether);
    }

    // Cell [Launch  WL  Sell] → 0%
    function testLaunch_WL_Sell_0() public {
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        (uint256 s, uint256 b, uint256 sw) = token.previewSellTaxFor(WL_USER, 1 ether, 400);
        assertEq(s, 0);
        assertEq(b, 0);
        assertEq(sw, 1 ether);
    }

    // Cell [Launch  NonWL  Buy] → 30%
    function testLaunch_NonWL_Buy_30() public {
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        (uint256 tax, uint256 net) = token.previewBuyTaxFor(USER_B, 1 ether);
        assertEq(tax + net, 1 ether);
        assertApproxEqAbs(tax, 300_000_000_000_000_000, 1);
    }

    // Cell [Launch  NonWL  Sell] → 30%
    function testLaunch_NonWL_Sell_30() public {
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        (uint256 s, uint256 b, uint256 sw) = token.previewSellTaxFor(USER_B, 1 ether, 400);
        assertEq(s + b + sw, 1 ether);
        assertApproxEqAbs(s + b, 300_000_000_000_000_000, 1);
    }

    // Cell [Normal  WL  Buy] → 0%
    function testNormal_WL_Buy_0() public {
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        vm.warp(block.timestamp + 15 minutes);
        (uint256 tax, uint256 net) = token.previewBuyTaxFor(WL_USER, 1 ether);
        assertEq(tax, 0);
        assertEq(net, 1 ether);
    }

    // Cell [Normal  WL  Sell] → 0%
    function testNormal_WL_Sell_0() public {
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        vm.warp(block.timestamp + 15 minutes);
        (uint256 s, uint256 b, uint256 sw) = token.previewSellTaxFor(WL_USER, 1 ether, 400);
        assertEq(s, 0);
        assertEq(b, 0);
        assertEq(sw, 1 ether);
    }

    // Cell [Normal  NonWL  Buy] → 4%
    function testNormal_NonWL_Buy_4() public {
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        vm.warp(block.timestamp + 15 minutes);
        (uint256 tax, uint256 net) = token.previewBuyTaxFor(USER_B, 1 ether);
        assertEq(tax + net, 1 ether);
        assertApproxEqAbs(tax, 40_000_000_000_000_000, 1);
    }

    // Cell [Normal  NonWL  Sell 4%] → 4%
    function testNormal_NonWL_Sell_4() public {
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        vm.warp(block.timestamp + 15 minutes);
        (uint256 s, uint256 b, uint256 sw) = token.previewSellTaxFor(USER_B, 1 ether, 400);
        assertEq(s + b + sw, 1 ether);
        assertEq(b, 0);
        assertApproxEqAbs(s, 40_000_000_000_000_000, 1);
    }

    // Cell [Normal  NonWL  Sell 10%] → 10%
    function testNormal_NonWL_Sell_10() public {
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        vm.warp(block.timestamp + 15 minutes);
        (uint256 s, uint256 b, uint256 sw) = token.previewSellTaxFor(USER_B, 1 ether, 1000);
        assertEq(s + b + sw, 1 ether);
        assertTrue(b > 0);
        assertApproxEqAbs(s + b, 100_000_000_000_000_000, 1);
    }

    // ═══════════════════════════════════════════════════════
    // Multi-user, partial sell, boundary edges
    // ═══════════════════════════════════════════════════════
    function testMultiUser_WhitelistIsPerAddress() public {
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        vm.warp(block.timestamp + 15 minutes);
        (uint256 t1,) = token.previewBuyTaxFor(WL_USER, 1 ether);
        (uint256 t2,) = token.previewBuyTaxFor(USER_B, 1 ether);
        assertEq(t1, 0);
        assertEq(t2, 40_000_000_000_000_000);
    }

    function testPartialSell_Invariant(uint256 fraction) public {
        fraction = bound(fraction, 1, 100);
        uint256 amount = (1 ether * fraction) / 100;
        vm.assume(amount >= token.MIN_SELL_AMOUNT());
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        vm.warp(block.timestamp + 15 minutes);
        (uint256 s, uint256 b, uint256 sw) = token.previewSellTaxFor(USER_B, amount, 400);
        assertEq(s + b + sw, amount);
    }

    function testBoundary_14m59vs15m00() public {
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        vm.warp(1 + 15 minutes - 1);
        assertTrue(token.isInLaunchProtection());
        vm.warp(1 + 15 minutes);
        assertFalse(token.isInLaunchProtection());
    }

    function testTaxConservation_Buy() public {
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 100;
        amounts[1] = 1 ether;
        amounts[2] = 100 ether;
        amounts[3] = 1_000_000 ether;
        for (uint256 i = 0; i < amounts.length; i++) {
            (uint256 tax, uint256 net) = token.previewBuyTaxFor(USER_B, amounts[i]);
            assertEq(tax + net, amounts[i]);
        }
    }

    function testTaxConservation_Sell() public {
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = uint256(token.MIN_SELL_AMOUNT());
        amounts[1] = 1 ether;
        amounts[2] = 100 ether;
        amounts[3] = 1_000_000 ether;
        for (uint256 i = 0; i < amounts.length; i++) {
            (uint256 s, uint256 b, uint256 sw) = token.previewSellTaxFor(USER_B, amounts[i], 400);
            assertEq(s + b + sw, amounts[i]);
        }
    }

    function testPreviewExecution_SameFunction() public {
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        (uint256 pTax, uint256 pNet) = token.previewBuyTaxFor(WL_USER, 1 ether);
        (uint256 pTax2, uint256 pNet2) = token.previewBuyTaxFor(USER_B, 1 ether);
        assertEq(pTax, 0);
        assertEq(pNet, 1 ether);
        assertTrue(pTax2 > 0);
    }

    // ═══════════════════════════════════════════════════════
    // Fuzz — all 6 cells with random amounts
    // ═══════════════════════════════════════════════════════
    function testFuzz_LaunchWL_Buy(uint256 amount) public {
        amount = bound(amount, 2, 1_000_000_000 ether);
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        (uint256 t,) = token.previewBuyTaxFor(WL_USER, amount);
        assertEq(t, 0);
    }

    function testFuzz_LaunchWL_Sell(uint256 amount) public {
        amount = bound(amount, token.MIN_SELL_AMOUNT(), 1_000_000_000 ether);
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        (uint256 s, uint256 b, uint256 sw) = token.previewSellTaxFor(WL_USER, amount, 400);
        assertEq(s, 0);
        assertEq(b, 0);
        assertEq(sw, amount);
    }

    function testFuzz_LaunchNonWL_Buy(uint256 amount) public {
        amount = bound(amount, 2, 1_000_000_000 ether);
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        (uint256 tax, uint256 net) = token.previewBuyTaxFor(USER_B, amount);
        assertEq(tax + net, amount);
        assertTrue(tax > 0);
    }

    function testFuzz_NormalNonWL_Buy(uint256 amount) public {
        amount = bound(amount, 2, 1_000_000_000 ether);
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        vm.warp(block.timestamp + 15 minutes);
        (uint256 tax, uint256 net) = token.previewBuyTaxFor(USER_B, amount);
        assertEq(tax + net, amount);
        assertApproxEqAbs(tax, (amount * 400) / 10_000, 1);
    }

    function testFuzz_NormalNonWL_Sell4(uint256 amount) public {
        amount = bound(amount, token.MIN_SELL_AMOUNT(), 1_000_000_000 ether);
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        vm.warp(block.timestamp + 15 minutes);
        (uint256 s, uint256 b, uint256 sw) = token.previewSellTaxFor(USER_B, amount, 400);
        assertEq(s + b + sw, amount);
        assertEq(b, 0);
    }

    function testFuzz_NormalNonWL_Sell10(uint256 amount) public {
        amount = bound(amount, token.MIN_SELL_AMOUNT(), 1_000_000_000 ether);
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        vm.warp(block.timestamp + 15 minutes);
        (uint256 s, uint256 b, uint256 sw) = token.previewSellTaxFor(USER_B, amount, 1000);
        assertEq(s + b + sw, amount);
        assertTrue(b > 0);
    }
}
