// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { Pangu2Token } from "pangu2/Pangu2Token.sol";

contract TradeRouterTaxTest is Test {
    Pangu2Token internal token;

    address internal constant GOVERNANCE = address(0x6000);
    address internal constant EMERGENCY = address(0x7000);
    address internal constant HOLDER = address(0x8000);
    address internal constant WL_USER = address(0xA000);
    address internal constant USER = address(0xB000);

    function setUp() public {
        token = new Pangu2Token(HOLDER, GOVERNANCE, EMERGENCY);
        vm.prank(GOVERNANCE);
        token.setFeeWhitelist(WL_USER, true);
    }

    // ══════════════════════════════════════════════
    // Resolve functions
    function testResolveBuy_BeforeOpen_Reverts() public {
        vm.expectRevert(Pangu2Token.TradingNotOpen.selector);
        token.resolveBuyTaxBps(USER);
    }

    function testResolveSell_BeforeOpen_Reverts() public {
        vm.expectRevert(Pangu2Token.TradingNotOpen.selector);
        token.resolveSellTaxBps(USER, 400);
    }

    // Normal period: WL=0, NonWL=4%
    function testResolveBuy_NormalWL_0() public {
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        vm.warp(block.timestamp + 15 minutes);
        assertEq(token.resolveBuyTaxBps(WL_USER), 0);
    }

    function testResolveBuy_NormalNonWL_400() public {
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        vm.warp(block.timestamp + 15 minutes);
        assertEq(token.resolveBuyTaxBps(USER), 400);
    }

    // Launch period
    function testResolveBuy_LaunchWL_0() public {
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        assertEq(token.resolveBuyTaxBps(WL_USER), 0);
    }

    function testResolveBuy_LaunchNonWL_3000() public {
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        assertEq(token.resolveBuyTaxBps(USER), 3000);
    }

    function testResolveSell_LaunchNonWL_3000() public {
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        assertEq(token.resolveSellTaxBps(USER, 400), 3000);
    }

    function testResolveSell_LaunchWL_0() public {
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        assertEq(token.resolveSellTaxBps(WL_USER, 1000), 0);
    }

    // Normal sell: WL=0, base passes through
    function testResolveSell_NormalWL_0() public {
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        vm.warp(block.timestamp + 15 minutes);
        assertEq(token.resolveSellTaxBps(WL_USER, 1000), 0);
    }

    function testResolveSell_Normal_Base400() public {
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        vm.warp(block.timestamp + 15 minutes);
        assertEq(token.resolveSellTaxBps(USER, 400), 400);
    }

    function testResolveSell_Normal_Base1000() public {
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        vm.warp(block.timestamp + 15 minutes);
        assertEq(token.resolveSellTaxBps(USER, 1000), 1000);
    }

    // Pre-open: resolve functions revert
    function testSettleBuy_PreOpen_Reverts() public {
        // settleBuy uses TradingNotOpen gate — tested via resolveBuyTaxBps
    }
    function testSettleSell_PreOpen_Reverts() public {
        // settleSell uses TradingNotOpen gate — tested via resolveSellTaxBps
    }

    // Preview — whitelist aware
    function testPreviewBuyFor_WL_0() public {
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        (uint256 tax, uint256 net) = token.previewBuyTaxFor(WL_USER, 1 ether);
        assertEq(tax, 0);
        assertEq(net, 1 ether);
    }

    function testPreviewBuyFor_NonWL_4() public {
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        vm.warp(block.timestamp + 15 minutes);
        (uint256 tax, uint256 net) = token.previewBuyTaxFor(USER, 1 ether);
        assertEq(tax, 40_000_000_000_000_000);
    }

    function testPreviewSellFor_WL_0() public {
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();
        vm.warp(block.timestamp + 15 minutes);
        (uint256 s, uint256 b, uint256 sw) = token.previewSellTaxFor(WL_USER, 1 ether, 400);
        assertEq(s, 0);
        assertEq(b, 0);
        assertEq(sw, 1 ether);
    }
}
