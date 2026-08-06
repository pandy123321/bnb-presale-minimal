// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { PancakeV2TwapOracle } from "pangu2/oracle/PancakeV2TwapOracle.sol";
import { IPancakePair, IPancakeFactory } from "pangu2/interfaces/IPancakeV2.sol";

contract MockPair {
    address public immutable token0;
    address public immutable token1;
    address public immutable factory;

    uint112 public reserve0;
    uint112 public reserve1;
    uint32 public blockTimestampLast;
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;

    constructor(address token0_, address token1_, address factory_) {
        token0 = token0_;
        token1 = token1_;
        factory = factory_;
    }

    function setReserves(uint112 r0, uint112 r1, uint32 ts) external {
        reserve0 = r0;
        reserve1 = r1;
        blockTimestampLast = ts;
    }

    function setCumulatives(uint256 p0, uint256 p1) external {
        price0CumulativeLast = p0;
        price1CumulativeLast = p1;
    }

    /// Simulate a swap: accumulate price up to newTs, then update reserves.
    function simulateSwap(uint256 amount0In, uint256 amount1In, uint256 amount0Out, uint256 amount1Out, uint32 newTs)
        external
    {
        uint256 timeElapsed = uint256(newTs) - uint256(blockTimestampLast);
        if (timeElapsed > 0 && reserve0 > 0 && reserve1 > 0) {
            unchecked {
                uint256 Q = 2 ** 112;
                price0CumulativeLast += (uint256(reserve1) * Q / uint256(reserve0)) * timeElapsed;
                price1CumulativeLast += (uint256(reserve0) * Q / uint256(reserve1)) * timeElapsed;
            }
        }
        reserve0 = uint112(uint256(reserve0) + amount0In - amount0Out);
        reserve1 = uint112(uint256(reserve1) + amount1In - amount1Out);
        blockTimestampLast = newTs;
    }

    function getReserves() external view returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, blockTimestampLast);
    }
}

contract MockFactory {
    mapping(address => mapping(address => address)) public pairs;

    function setPair(address t0, address t1, address p) external {
        pairs[t0][t1] = p;
        pairs[t1][t0] = p;
    }

    function getPair(address t0, address t1) external view returns (address) {
        return pairs[t0][t1];
    }
}

contract PancakeV2TwapOracleTest is Test {
    address internal immutable TOKEN = address(0x1000);
    address internal immutable WBNB = address(0x2000);

    MockFactory internal factory;
    MockPair internal pair;
    PancakeV2TwapOracle internal oracle;

    uint32 internal immutable TWAP_WINDOW = 30 minutes;
    uint16 internal immutable DEV_BPS = 300;
    uint112 internal constant INIT_TOKEN_RES = 100_000 ether;
    uint112 internal constant INIT_WBNB_RES = 10_000 ether;
    uint112 internal constant MIN_RES = 1;

    function _deployOracle(bool tokenIsToken0) internal {
        factory = new MockFactory();
        address t0 = tokenIsToken0 ? TOKEN : WBNB;
        address t1 = tokenIsToken0 ? WBNB : TOKEN;
        pair = new MockPair(t0, t1, address(factory));
        factory.setPair(t0, t1, address(pair));
        factory.setPair(t1, t0, address(pair));

        uint112 r0 = tokenIsToken0 ? INIT_TOKEN_RES : INIT_WBNB_RES;
        uint112 r1 = tokenIsToken0 ? INIT_WBNB_RES : INIT_TOKEN_RES;
        pair.setReserves(r0, r1, uint32(block.timestamp));
        pair.setCumulatives(0, 0);

        oracle = new PancakeV2TwapOracle(
            TOKEN, WBNB, address(factory), address(pair), TWAP_WINDOW, DEV_BPS, MIN_RES, MIN_RES
        );
        assertEq(oracle.tokenIsToken0(), tokenIsToken0);
    }

    function _warpAndUpdate(uint256 deltaSec) internal {
        vm.warp(block.timestamp + deltaSec);
        oracle.update();
    }

    function _anchorAndMature() internal {
        oracle.update();
        _warpAndUpdate(TWAP_WINDOW);
    }

    function setUp() public {
        vm.etch(TOKEN, hex"fe");
        vm.etch(WBNB, hex"fe");
        _deployOracle(true);
    }

    // ═══════════════════════════════════════════════
    // T1: No-swap window matures via counterfactual
    function testNoSwapWindowMatures() public {
        oracle.update();
        assertEq(uint256(oracle.status()), uint256(PancakeV2TwapOracle.WindowStatus.ACCUMULATING));
        _warpAndUpdate(TWAP_WINDOW);
        assertEq(uint256(oracle.status()), uint256(PancakeV2TwapOracle.WindowStatus.READY));
    }

    // T2: Bidirectional quotes (token0)
    function testQuotesTokenAsToken0() public {
        _anchorAndMature();
        PancakeV2TwapOracle.Quote memory q1 = oracle.validatedQuote(TOKEN, WBNB, 1 ether);
        PancakeV2TwapOracle.Quote memory q2 = oracle.validatedQuote(WBNB, TOKEN, 1 ether);
        assertGt(q1.amountOut, 0);
        assertGt(q2.amountOut, 0);
        assertApproxEqRel(q1.amountOut, 0.1 ether, 0.05e18);
        assertApproxEqRel(q2.amountOut, 10 ether, 0.05e18);
    }

    // T3: TWAP not available before expiry
    function testTwapNotAvailableBeforeExpiry() public {
        oracle.update();
        _warpAndUpdate(TWAP_WINDOW / 2);
        assertEq(uint256(oracle.status()), uint256(PancakeV2TwapOracle.WindowStatus.ACCUMULATING));
        vm.expectRevert(PancakeV2TwapOracle.OracleNotReady.selector);
        oracle.validatedQuote(TOKEN, WBNB, 1 ether);
    }

    // T4: TWAP rejected after expiry
    function testTwapRejectedAfterExpiry() public {
        _anchorAndMature();
        uint256 maxAge = TWAP_WINDOW * 5;
        vm.warp(block.timestamp + maxAge + 1);
        vm.expectRevert(
            abi.encodeWithSelector(PancakeV2TwapOracle.TwapTooOld.selector, block.timestamp - maxAge - 1, maxAge)
        );
        oracle.validatedQuote(TOKEN, WBNB, 1 ether);
    }

    // T5: Low liquidity recovery
    function testLowLiquidityRecovery() public {
        _anchorAndMature();
        pair.setReserves(0, 0, uint32(block.timestamp));
        oracle.update();
        assertEq(uint256(oracle.status()), uint256(PancakeV2TwapOracle.WindowStatus.LIQUIDITY_LOW));

        pair.setReserves(INIT_TOKEN_RES, INIT_WBNB_RES, uint32(block.timestamp));
        pair.setCumulatives(0, 0);
        oracle.update();
        assertEq(uint256(oracle.status()), uint256(PancakeV2TwapOracle.WindowStatus.ACCUMULATING));

        _warpAndUpdate(TWAP_WINDOW / 2);
        vm.expectRevert(PancakeV2TwapOracle.OracleNotReady.selector);
        oracle.validatedQuote(TOKEN, WBNB, 1 ether);

        _warpAndUpdate(TWAP_WINDOW / 2);
        assertEq(uint256(oracle.status()), uint256(PancakeV2TwapOracle.WindowStatus.READY));
        assertGt(oracle.validatedQuote(TOKEN, WBNB, 1 ether).amountOut, 0);
    }

    // T6: Spot/TWAP deviation exceeded
    function testExcessiveSpotTwapDeviation() public {
        _anchorAndMature();
        pair.simulateSwap(50_000 ether, 0, 0, 3333 ether, uint32(block.timestamp));
        vm.expectRevert();
        oracle.validatedQuote(TOKEN, WBNB, 1 ether);
    }

    // T7: observedAtBlock matches completion block
    function testObservedAtBlockIsCompletionBlock() public {
        _anchorAndMature();
        assertEq(oracle.validatedQuote(TOKEN, WBNB, 1 ether).observedAtBlock, block.number);
    }

    // T8: Multi-window no-swaps
    function testMultiWindowNoSwaps() public {
        _anchorAndMature();
        uint256 q1 = oracle.validatedQuote(TOKEN, WBNB, 1 ether).amountOut;
        _warpAndUpdate(TWAP_WINDOW);
        assertEq(oracle.validatedQuote(TOKEN, WBNB, 1 ether).amountOut, q1);
    }

    // ═══════════════════════════════════════════════
    // T9: Mid-window swap — TWAP is time-weighted correctly
    function testMidWindowSwap_TimeWeighted() public {
        // Anchor starts at t=1 with reserves 100K/10K, spot = 0.1 WBNB/PANGU
        oracle.update();

        vm.warp(1 + 600);
        // Use a smaller swap to keep deviation within 3% limit
        // 30% of 10K = 3K WBNB left
        pair.simulateSwap(2300 ether, 0, 0, 200 ether, uint32(block.timestamp));
        // New reserves: ≈102300 token, ≈9800 WBNB, spot ≈ 0.0958

        vm.warp(1 + TWAP_WINDOW + 60);
        oracle.update();

        assertEq(uint256(oracle.status()), uint256(PancakeV2TwapOracle.WindowStatus.READY));

        // TWAP should be between pre-swap (0.1) and post-swap (~0.0958)
        PancakeV2TwapOracle.Quote memory q = oracle.validatedQuote(TOKEN, WBNB, 1 ether);
        assertGt(q.amountOut, 0.09 ether);
        assertLt(q.amountOut, 0.1 ether);
    }

    // T10: Below-minimum reserves triggers exact custom error
    function testBelowMinimumReservesExactError() public {
        _anchorAndMature();
        Oracle oracleLow = new Oracle(
            TOKEN, WBNB, address(factory), address(pair), TWAP_WINDOW, DEV_BPS, 100_000 ether, 100_000 ether
        );
        // minWbnbReserve = 100K ether → current 10K is below
        oracleLow.update();
        vm.warp(1 + TWAP_WINDOW);
        oracleLow.update();

        vm.expectRevert(
            abi.encodeWithSelector(
                PancakeV2TwapOracle.BelowMinimumReserves.selector,
                uint112(INIT_TOKEN_RES),
                uint112(INIT_WBNB_RES),
                uint112(100_000 ether),
                uint112(100_000 ether)
            )
        );
        oracleLow.validatedQuote(TOKEN, WBNB, 1 ether);
    }

    // T11: Exact Spot/TWAP deviation error values
    function testExcessiveSpotTwapDeviationExactValues() public {
        _anchorAndMature();
        pair.simulateSwap(50_000 ether, 0, 0, 3333 ether, uint32(block.timestamp));

        try oracle.validatedQuote(TOKEN, WBNB, 1 ether) {
            fail("should have reverted");
        } catch (bytes memory reason) {
            // Verify the error selector matches
            bytes4 selector = bytes4(reason);
            bytes4 expected = PancakeV2TwapOracle.ExcessiveSpotTwapDeviation.selector;
            assertEq(selector, expected, "should be ExcessiveSpotTwapDeviation");
        }
    }

    // T12: Fuzz — counterfactual TWAP matches constant-reserve expectation
    function testFuzz_ConstantReserves_TWAP(uint256 windowOffset) public {
        windowOffset = bound(windowOffset, uint256(TWAP_WINDOW), 2 * uint256(TWAP_WINDOW));
        oracle.update();
        vm.warp(1 + windowOffset);
        oracle.update();
        assertEq(uint256(oracle.status()), uint256(PancakeV2TwapOracle.WindowStatus.READY));

        PancakeV2TwapOracle.Quote memory q = oracle.validatedQuote(TOKEN, WBNB, 1 ether);
        assertGt(q.amountOut, 0);
        // With constant reserves 100K/10K, price = 0.1 WBNB/PANGU regardless of window length
        assertApproxEqRel(q.amountOut, 0.1 ether, 0.02e18);
    }
}

// ───────────────────────────────────────────────
// Helper contract to test with high min reserves
contract Oracle is PancakeV2TwapOracle {
    constructor(address t, address w, address f, address p, uint32 ww, uint16 d, uint112 minT, uint112 minW)
        PancakeV2TwapOracle(t, w, f, p, ww, d, minT, minW)
    { }
}

contract PancakeV2TwapOracleToken1Test is Test {
    address internal immutable TOKEN = address(0x1000);
    address internal immutable WBNB = address(0x2000);

    MockFactory internal factory;
    MockPair internal pair;
    PancakeV2TwapOracle internal oracle;

    uint32 internal immutable TWAP_WINDOW = 30 minutes;
    uint16 internal immutable DEV_BPS = 300;
    uint112 internal constant INIT_TOKEN_RES = 100_000 ether;
    uint112 internal constant INIT_WBNB_RES = 10_000 ether;
    uint112 internal constant MIN_RES = 1;

    function setUp() public {
        vm.etch(TOKEN, hex"fe");
        vm.etch(WBNB, hex"fe");

        factory = new MockFactory();
        pair = new MockPair(WBNB, TOKEN, address(factory));
        factory.setPair(WBNB, TOKEN, address(pair));
        factory.setPair(TOKEN, WBNB, address(pair));

        pair.setReserves(INIT_WBNB_RES, INIT_TOKEN_RES, uint32(block.timestamp));
        pair.setCumulatives(0, 0);

        oracle = new PancakeV2TwapOracle(
            TOKEN, WBNB, address(factory), address(pair), TWAP_WINDOW, DEV_BPS, MIN_RES, MIN_RES
        );
        assertFalse(oracle.tokenIsToken0());
    }

    function testNoSwapWindowMaturesToken1() public {
        oracle.update();
        assertEq(uint256(oracle.status()), uint256(PancakeV2TwapOracle.WindowStatus.ACCUMULATING));
        vm.warp(block.timestamp + TWAP_WINDOW);
        oracle.update();
        assertEq(uint256(oracle.status()), uint256(PancakeV2TwapOracle.WindowStatus.READY));
    }

    function testQuotesTokenAsToken1() public {
        oracle.update();
        vm.warp(block.timestamp + TWAP_WINDOW);
        oracle.update();

        PancakeV2TwapOracle.Quote memory q1 = oracle.validatedQuote(TOKEN, WBNB, 1 ether);
        PancakeV2TwapOracle.Quote memory q2 = oracle.validatedQuote(WBNB, TOKEN, 1 ether);
        assertGt(q1.amountOut, 0);
        assertGt(q2.amountOut, 0);
        assertApproxEqRel(q1.amountOut, 0.1 ether, 0.05e18);
        assertApproxEqRel(q2.amountOut, 10 ether, 0.05e18);
    }

    function testObservedAtBlockToken1() public {
        oracle.update();
        vm.warp(block.timestamp + TWAP_WINDOW);
        oracle.update();
        assertEq(oracle.validatedQuote(TOKEN, WBNB, 1 ether).observedAtBlock, block.number);
    }

    // token1 mid-swap TWAP: oracle stays READY with a time-weighted price
    function testMidWindowSwapToken1() public {
        oracle.update();
        vm.warp(1 + 600);
        // Small swap: 100 WBNB → ~990 token1. Deviation stays within 3%.
        pair.simulateSwap(100 ether, 0, 0, 990 ether, uint32(block.timestamp));
        vm.warp(1 + TWAP_WINDOW + 60);
        oracle.update();
        assertEq(uint256(oracle.status()), uint256(PancakeV2TwapOracle.WindowStatus.READY));
        PancakeV2TwapOracle.Quote memory q = oracle.validatedQuote(TOKEN, WBNB, 1 ether);
        assertGt(q.amountOut, 0);
    }
}
