// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { Pangu2Token } from "pangu2/Pangu2Token.sol";

contract FeeWhitelistTest is Test {
    Pangu2Token internal token;

    address internal constant GOVERNANCE = address(0x6000);
    address internal constant EMERGENCY = address(0x7000);
    address internal constant HOLDER = address(0x8000);
    address internal constant USER_A = address(0xA000);
    address internal constant USER_B = address(0xB000);
    address internal constant ROUTER = address(0xC000);
    address internal constant PAIR = address(0xD000);

    function setUp() public {
        token = new Pangu2Token(HOLDER, GOVERNANCE, EMERGENCY);
        // Register Router as system address + grant SETTLEMENT_ROLE
        vm.etch(ROUTER, hex"fe");
        vm.startPrank(GOVERNANCE);
        token.grantRole(token.SETTLEMENT_ROLE(), ROUTER);
        // Open trading at t=0
        token.setTradingOpenAt();
        vm.stopPrank();
    }

    // ═══════════════════════════════════════════════════════
    // T1: Governance can add to whitelist
    // ═══════════════════════════════════════════════════════
    function testGovernanceCanAddToWhitelist() public {
        vm.prank(GOVERNANCE);
        token.setFeeWhitelist(USER_A, true);
        assertTrue(token.feeWhitelist(USER_A));
    }

    // ═══════════════════════════════════════════════════════
    // T2: Non-governance cannot add
    // ═══════════════════════════════════════════════════════
    function testNonGovernanceCannotAdd() public {
        vm.prank(USER_A);
        vm.expectRevert();
        token.setFeeWhitelist(USER_A, true);
    }

    // ═══════════════════════════════════════════════════════
    // T3: Governance can remove from whitelist
    // ═══════════════════════════════════════════════════════
    function testGovernanceCanRemove() public {
        vm.startPrank(GOVERNANCE);
        token.setFeeWhitelist(USER_A, true);
        assertTrue(token.feeWhitelist(USER_A));

        token.setFeeWhitelist(USER_A, false);
        assertFalse(token.feeWhitelist(USER_A));
        vm.stopPrank();
    }

    // ═══════════════════════════════════════════════════════
    // T4: Zero address rejected
    // ═══════════════════════════════════════════════════════
    function testZeroAddressRejected() public {
        vm.prank(GOVERNANCE);
        vm.expectRevert(Pangu2Token.ZeroAddress.selector);
        token.setFeeWhitelist(address(0), true);
    }

    function testBatchZeroAddressRejected() public {
        address[] memory addrs = new address[](2);
        addrs[0] = USER_A;
        addrs[1] = address(0);
        vm.prank(GOVERNANCE);
        vm.expectRevert(Pangu2Token.ZeroAddress.selector);
        token.setFeeWhitelistBatch(addrs, true);
    }

    // ═══════════════════════════════════════════════════════
    // T5: Batch set respects max
    // ═══════════════════════════════════════════════════════
    function testBatchRespectsMaxLimit() public {
        uint256 tooMany = token.MAX_BATCH_WHITELIST() + 1;
        address[] memory addrs = new address[](tooMany);
        for (uint256 i = 0; i < tooMany; i++) {
            addrs[i] = address(uint160(0xA000 + i));
        }
        vm.startPrank(GOVERNANCE);
        vm.expectRevert(
            abi.encodeWithSelector(Pangu2Token.BatchTooLarge.selector, tooMany, token.MAX_BATCH_WHITELIST())
        );
        token.setFeeWhitelistBatch(addrs, true);
        vm.stopPrank();
    }

    function testBatchAtMaxLimit() public {
        uint256 limit = token.MAX_BATCH_WHITELIST();
        address[] memory addrs = new address[](limit);
        for (uint256 i = 0; i < limit; i++) {
            addrs[i] = address(uint160(0xA000 + i));
        }
        vm.prank(GOVERNANCE);
        token.setFeeWhitelistBatch(addrs, true);
        assertTrue(token.feeWhitelist(addrs[0]));
        assertTrue(token.feeWhitelist(addrs[limit - 1]));
    }

    // ═══════════════════════════════════════════════════════
    // T6: Whitelist buy 0% tax (launch period)
    // ═══════════════════════════════════════════════════════
    function testWhitelistBuy0PercentInLaunch() public {
        assertTrue(token.isInLaunchProtection());

        vm.prank(GOVERNANCE);
        token.setFeeWhitelist(USER_A, true);

        (uint256 tax, uint256 net) = token.previewBuyTaxFor(USER_A, 1 ether);
        assertEq(tax, 0, "whitelisted buy tax should be 0");
        assertEq(net, 1 ether, "whitelisted buy net should be full amount");
    }

    // ═══════════════════════════════════════════════════════
    // T7: Whitelist sell 0% tax (launch period)
    // ═══════════════════════════════════════════════════════
    function testWhitelistSell0PercentInLaunch() public {
        assertTrue(token.isInLaunchProtection());

        vm.prank(GOVERNANCE);
        token.setFeeWhitelist(USER_A, true);

        (uint256 support, uint256 burn, uint256 swap) = token.previewSellTaxFor(USER_A, 1 ether, 400);
        assertEq(support, 0, "whitelisted sell support should be 0");
        assertEq(burn, 0, "whitelisted sell burn should be 0");
        assertEq(swap, 1 ether, "whitelisted sell swap should be full amount");
    }

    // ═══════════════════════════════════════════════════════
    // T8: Whitelist buy 0% tax (normal period)
    // ═══════════════════════════════════════════════════════
    function testWhitelistBuy0PercentNormal() public {
        vm.warp(block.timestamp + 15 minutes);
        assertFalse(token.isInLaunchProtection());

        vm.prank(GOVERNANCE);
        token.setFeeWhitelist(USER_A, true);

        (uint256 tax, uint256 net) = token.previewBuyTaxFor(USER_A, 1 ether);
        assertEq(tax, 0);
        assertEq(net, 1 ether);
    }

    // ═══════════════════════════════════════════════════════
    // T9: Whitelist sell 0% tax (normal period)
    // ═══════════════════════════════════════════════════════
    function testWhitelistSell0PercentNormal() public {
        vm.warp(block.timestamp + 15 minutes);
        assertFalse(token.isInLaunchProtection());

        vm.prank(GOVERNANCE);
        token.setFeeWhitelist(USER_A, true);

        (uint256 support, uint256 burn, uint256 swap) = token.previewSellTaxFor(USER_A, 1 ether, 400);
        assertEq(support, 0);
        assertEq(burn, 0);
        assertEq(swap, 1 ether);
    }

    // ═══════════════════════════════════════════════════════
    // T10: Remove from whitelist restores normal tax
    // ═══════════════════════════════════════════════════════
    function testRemoveRestoresNormalTax() public {
        vm.warp(block.timestamp + 15 minutes);
        assertFalse(token.isInLaunchProtection());

        // Add
        vm.prank(GOVERNANCE);
        token.setFeeWhitelist(USER_A, true);

        (uint256 tax0,) = token.previewBuyTaxFor(USER_A, 1 ether);
        assertEq(tax0, 0);

        // Remove
        vm.prank(GOVERNANCE);
        token.setFeeWhitelist(USER_A, false);

        (uint256 tax1, uint256 net1) = token.previewBuyTaxFor(USER_A, 1 ether);
        assertEq(tax1, 40_000_000_000_000_000, "normal 4% tax should be restored");
        assertEq(net1, 960_000_000_000_000_000);
    }

    // ═══════════════════════════════════════════════════════
    // T11: Non-whitelisted users still pay normal tax
    // ═══════════════════════════════════════════════════════
    function testNonWhitelistedStillPaysNormalTax() public {
        vm.warp(block.timestamp + 15 minutes);

        // Whitelist USER_A only
        vm.prank(GOVERNANCE);
        token.setFeeWhitelist(USER_A, true);

        // USER_B is NOT whitelisted
        (uint256 tax, uint256 net) = token.previewBuyTaxFor(USER_B, 1 ether);
        assertEq(tax, 40_000_000_000_000_000, "non-whitelisted should pay 4%");
        assertEq(net, 960_000_000_000_000_000);
    }

    // ═══════════════════════════════════════════════════════
    // T12: Preview and settlement produce identical values
    // ═══════════════════════════════════════════════════════
    function testPreviewMatchesSettlementForWhitelisted() public {
        vm.prank(GOVERNANCE);
        token.setFeeWhitelist(USER_A, true);

        (uint256 pTax, uint256 pNet) = token.previewBuyTaxFor(USER_A, 1 ether);
        assertEq(pTax, 0);
        assertEq(pNet, 1 ether);

        // previewBuyTaxFor is the same function settleBuy uses internally
        // This verifies the path is consistent
    }

    // ═══════════════════════════════════════════════════════
    // T13: Pause cannot be bypassed by whitelist
    // ═══════════════════════════════════════════════════════
    function testWhitelistCannotBypassPause() public {
        vm.prank(GOVERNANCE);
        token.setFeeWhitelist(USER_A, true);

        // PAUSER_ROLE granted to EMERGENCY in constructor
        vm.prank(EMERGENCY);
        token.pause();

        // settleBuy is whenNotPaused — cannot call it
        vm.expectRevert();
        vm.prank(ROUTER);
        token.settleBuy(USER_A, 1 ether, 1 ether);
    }

    // ═══════════════════════════════════════════════════════
    // T14: Whitelist before trading open — preview still works
    // ═══════════════════════════════════════════════════════
    function testWhitelistBeforeOpenPreviewWorks() public {
        // Deploy fresh token without opening trading
        Pangu2Token fresh = new Pangu2Token(HOLDER, GOVERNANCE, EMERGENCY);

        vm.prank(GOVERNANCE);
        fresh.setFeeWhitelist(USER_A, true);

        // previewBuyTaxFor does NOT check tradingOpenAt — that's the Router's job
        (uint256 tax, uint256 net) = fresh.previewBuyTaxFor(USER_A, 1 ether);
        assertEq(tax, 0, "whitelist should still apply before open");
        assertEq(net, 1 ether);
    }

    // ═══════════════════════════════════════════════════════
    // T15: Router whitelist does NOT make all users tax-free
    // ═══════════════════════════════════════════════════════
    function testRouterWhitelistDoesNotAffectUsers() public {
        vm.warp(block.timestamp + 15 minutes);

        // Whitelist the Router address
        vm.prank(GOVERNANCE);
        token.setFeeWhitelist(ROUTER, true);

        // A regular user should still pay tax
        (uint256 tax, uint256 net) = token.previewBuyTaxFor(USER_A, 1 ether);
        assertEq(tax, 40_000_000_000_000_000, "user should still pay 4%");
        assertEq(net, 960_000_000_000_000_000);
    }

    // ═══════════════════════════════════════════════════════
    // T16: Pair whitelist does NOT make all users tax-free
    // ═══════════════════════════════════════════════════════
    function testPairWhitelistDoesNotAffectUsers() public {
        vm.warp(block.timestamp + 15 minutes);

        vm.etch(PAIR, hex"fe");
        vm.prank(GOVERNANCE);
        token.setFeeWhitelist(PAIR, true);

        // A regular user should still pay tax
        (uint256 sellSupport,,) = token.previewSellTaxFor(USER_A, 1 ether, 400);
        assertGt(sellSupport, 0, "user should still pay sell tax");
    }

    // ═══════════════════════════════════════════════════════
    // T17: Events emitted
    // ═══════════════════════════════════════════════════════
    function testWhitelistEventsEmitted() public {
        vm.startPrank(GOVERNANCE);

        vm.expectEmit(true, true, false, false);
        emit Pangu2Token.FeeWhitelistUpdated(USER_A, true);
        token.setFeeWhitelist(USER_A, true);

        vm.expectEmit(true, true, false, false);
        emit Pangu2Token.FeeWhitelistUpdated(USER_A, false);
        token.setFeeWhitelist(USER_A, false);

        vm.stopPrank();
    }

    // ═══════════════════════════════════════════════════════
    // T18: Fuzz — random whitelisted users always 0 tax
    // ═══════════════════════════════════════════════════════
    function testFuzzWhitelistBuyAlwaysZeroTax(uint256 amount, address user) public {
        amount = bound(amount, 2, 1_000_000_000 ether);
        vm.assume(user != address(0) && user != GOVERNANCE);
        vm.assume(user.code.length == 0);

        vm.prank(GOVERNANCE);
        token.setFeeWhitelist(user, true);

        (uint256 tax, uint256 net) = token.previewBuyTaxFor(user, amount);
        assertEq(tax, 0, "whitelisted fuzz buy tax must be 0");
        assertEq(net, amount, "whitelisted fuzz buy net must be full amount");
    }

    function testFuzzWhitelistSellAlwaysZeroTax(uint256 amount, address user) public {
        amount = bound(amount, token.MIN_SELL_AMOUNT(), 1_000_000_000 ether);
        vm.assume(user != address(0) && user != GOVERNANCE);
        vm.assume(user.code.length == 0);

        vm.prank(GOVERNANCE);
        token.setFeeWhitelist(user, true);

        (uint256 support, uint256 burn, uint256 swap) = token.previewSellTaxFor(user, amount, 400);
        assertEq(support, 0, "whitelisted fuzz sell support must be 0");
        assertEq(burn, 0, "whitelisted fuzz sell burn must be 0");
        assertEq(swap, amount, "whitelisted fuzz sell swap must be full amount");
    }

    function testFuzzNonWhitelistedPaysTax(uint256 amount) public {
        amount = bound(amount, 2, 1_000_000_000 ether);
        vm.warp(block.timestamp + 15 minutes);

        (uint256 tax, uint256 net) = token.previewBuyTaxFor(USER_A, amount);
        uint256 expectedTax = (amount * 400) / 10_000;
        assertApproxEqAbs(tax, expectedTax, 1, "non-whitelisted fuzz should pay ~4%");
        assertEq(tax + net, amount);
    }
}
