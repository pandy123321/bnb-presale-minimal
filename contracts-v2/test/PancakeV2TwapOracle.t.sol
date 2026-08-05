// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { PancakeV2TwapOracle } from "pangu2/oracle/PancakeV2TwapOracle.sol";
import { IPancakePair, IPancakeFactory } from "pangu2/interfaces/IPancakeV2.sol";

// ── Mock PancakeV2 Pair ──
contract MockPancakePair {
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
            // real Pancake V2 uses Q112 fixed point
            unchecked {
                price0CumulativeLast += (uint256(reserve1) * (2 ** 112) / uint256(reserve0)) * timeElapsed;
                price1CumulativeLast += (uint256(reserve0) * (2 ** 112) / uint256(reserve1)) * timeElapsed;
            }
        }
        reserve0 = uint112(uint256(reserve0) + amount0In - amount0Out);
        reserve1 = uint112(uint256(reserve1) + amount1In - amount1Out);
        blockTimestampLast = newTs;
    }

    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        return (reserve0, reserve1, blockTimestampLast);
    }
}

/// Simple factory mock that just stores the pair address.
contract MockPancakeFactory {
    mapping(address => mapping(address => address)) public pairs;

    function setPair(address t0, address t1, address p) external {
        pairs[t0][t1] = p;
    }

    function getPair(address t0, address t1) external view returns (address) {
        return pairs[t0][t1];
    }
}

contract PancakeV2TwapOracleTest is Test {
    address internal immutable TOKEN = address(0x1000);
    address internal immutable WBNB = address(0x2000);

    MockPancakeFactory internal factory;
    MockPancakePair internal pair;
    PancakeV2TwapOracle internal oracle;

    uint32 internal immutable TWAP_WINDOW = 30 minutes;
    uint16 internal immutable DEV_BPS = 300; // 3% deviation
    uint112 internal constant INIT_TOKEN_RES = 100_000 ether;
    uint112 internal constant INIT_WBNB_RES = 10_000 ether;
    uint112 internal constant MIN_RES = 1;

    function _deployOracle(bool tokenIsToken0) internal {
        factory = new MockPancakeFactory();

        address t0 = tokenIsToken0 ? TOKEN : WBNB;
        address t1 = tokenIsToken0 ? WBNB : TOKEN;

        pair = new MockPancakePair(t0, t1, address(factory));
        factory.setPair(t0, t1, address(pair));
        factory.setPair(t1, t0, address(pair)); // bidirectional like real factory

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

    /// Convenience: anchor + warp a full window in one call.
    function _anchorAndMature() internal {
        oracle.update(); // UNINITIALIZED → ACCUMULATING
        _warpAndUpdate(TWAP_WINDOW); // ACCUMULATING → READY
    }

    function setUp() public {
        vm.etch(TOKEN, hex"fe");
        vm.etch(WBNB, hex"fe");
        _deployOracle(true); // PANGU2 = token0
    }

    // ───────────────────────────────────────────────────────
    // T1: No-swap window matures via counterfactual
    // ───────────────────────────────────────────────────────
    function testNoSwapWindowMatures() public {
        oracle.update();
        assertEq(uint256(oracle.status()), uint256(PancakeV2TwapOracle.WindowStatus.ACCUMULATING));

        _warpAndUpdate(TWAP_WINDOW);

        assertEq(uint256(oracle.status()), uint256(PancakeV2TwapOracle.WindowStatus.READY));
    }

    // ───────────────────────────────────────────────────────
    // T2: PANGU2=token0 — bidirectional quotes
    // ───────────────────────────────────────────────────────
    function testQuotesTokenAsToken0() public {
        _anchorAndMature();

        // Token → WBNB (base=TOKEN, quote=WBNB)
        PancakeV2TwapOracle.Quote memory q1 = oracle.validatedQuote(TOKEN, WBNB, 1 ether);
        assertGt(q1.amountOut, 0);

        // WBNB → Token (base=WBNB, quote=TOKEN)
        PancakeV2TwapOracle.Quote memory q2 = oracle.validatedQuote(WBNB, TOKEN, 1 ether);
        assertGt(q2.amountOut, 0);

        // Spot: 1 PANGU ≈ 0.1 WBNB (ratio: 10K/100K)
        assertApproxEqRel(q1.amountOut, 0.1 ether, 0.05e18);
        // Spot: 1 WBNB ≈ 10 PANGU
        assertApproxEqRel(q2.amountOut, 10 ether, 0.05e18);
    }

    // ───────────────────────────────────────────────────────
    // T3: TWAP not available before window expiry
    // ───────────────────────────────────────────────────────
    function testTwapNotAvailableBeforeExpiry() public {
        oracle.update();
        _warpAndUpdate(TWAP_WINDOW / 2);

        assertEq(uint256(oracle.status()), uint256(PancakeV2TwapOracle.WindowStatus.ACCUMULATING));

        vm.expectRevert(PancakeV2TwapOracle.OracleNotReady.selector);
        oracle.validatedQuote(TOKEN, WBNB, 1 ether);
    }

    // ───────────────────────────────────────────────────────
    // T4: TWAP rejected after expiry (maxAge = 5 × twapWindow)
    // ───────────────────────────────────────────────────────
    function testTwapRejectedAfterExpiry() public {
        _anchorAndMature(); // ready

        uint256 maxAge = TWAP_WINDOW * 5;
        vm.warp(block.timestamp + maxAge + 1);

        vm.expectRevert();
        oracle.validatedQuote(TOKEN, WBNB, 1 ether);
    }

    // ───────────────────────────────────────────────────────
    // T5: Low liquidity recovery — re-anchors, waits full window
    // ───────────────────────────────────────────────────────
    function testLowLiquidityRecovery() public {
        _anchorAndMature(); // READY

        // Drop below minimum
        pair.setReserves(0, 0, uint32(block.timestamp));
        oracle.update();
        assertEq(uint256(oracle.status()), uint256(PancakeV2TwapOracle.WindowStatus.LIQUIDITY_LOW));

        // Restore liquidity
        pair.setReserves(INIT_TOKEN_RES, INIT_WBNB_RES, uint32(block.timestamp));
        pair.setCumulatives(0, 0);
        oracle.update();

        assertEq(uint256(oracle.status()), uint256(PancakeV2TwapOracle.WindowStatus.ACCUMULATING));

        // Half window — still not ready
        _warpAndUpdate(TWAP_WINDOW / 2);
        vm.expectRevert(PancakeV2TwapOracle.OracleNotReady.selector);
        oracle.validatedQuote(TOKEN, WBNB, 1 ether);

        // Full window — ready
        _warpAndUpdate(TWAP_WINDOW / 2);
        assertEq(uint256(oracle.status()), uint256(PancakeV2TwapOracle.WindowStatus.READY));
        PancakeV2TwapOracle.Quote memory q = oracle.validatedQuote(TOKEN, WBNB, 1 ether);
        assertGt(q.amountOut, 0);
    }

    // ───────────────────────────────────────────────────────
    // T6: Spot/TWAP deviation exceeded
    // ───────────────────────────────────────────────────────
    function testExcessiveSpotTwapDeviation() public {
        // First establish a stable TWAP: 0.1 WBNB/PANGU
        _anchorAndMature();

        // Sell 50K PANGU → pair receives token0, sends ~3333 WBNB (CFMM)
        //  r0'=150K, r1'=6667 → spot = 0.0444, TWAP=0.1 → deviation ≈125%
        pair.simulateSwap(50_000 ether, 0, 0, 3333 ether, uint32(block.timestamp));

        vm.expectRevert();
        oracle.validatedQuote(TOKEN, WBNB, 1 ether);
    }

    // ───────────────────────────────────────────────────────
    // T7: observedAtBlock matches real TWAP completion block
    // ───────────────────────────────────────────────────────
    function testObservedAtBlockIsCompletionBlock() public {
        _anchorAndMature();

        PancakeV2TwapOracle.Quote memory q = oracle.validatedQuote(TOKEN, WBNB, 1 ether);
        assertEq(q.observedAtBlock, block.number, "observedAtBlock should equal completion block number");
    }

    // ───────────────────────────────────────────────────────
    // T8: TWAP survives multiple windows without swaps
    // ───────────────────────────────────────────────────────
    function testMultiWindowNoSwaps() public {
        _anchorAndMature();
        PancakeV2TwapOracle.Quote memory q1 = oracle.validatedQuote(TOKEN, WBNB, 1 ether);

        _warpAndUpdate(TWAP_WINDOW);
        PancakeV2TwapOracle.Quote memory q2 = oracle.validatedQuote(TOKEN, WBNB, 1 ether);

        assertEq(q1.amountOut, q2.amountOut, "TWAP should be stable with constant reserves");
    }
}

// ───────────────────────────────────────────────────────────
// Token-as-token1 test contract
// ───────────────────────────────────────────────────────────
contract PancakeV2TwapOracleToken1Test is Test {
    address internal immutable TOKEN = address(0x1000);
    address internal immutable WBNB = address(0x2000);

    MockPancakeFactory internal factory;
    MockPancakePair internal pair;
    PancakeV2TwapOracle internal oracle;

    uint32 internal immutable TWAP_WINDOW = 30 minutes;
    uint16 internal immutable DEV_BPS = 300;
    uint112 internal constant INIT_TOKEN_RES = 100_000 ether;
    uint112 internal constant INIT_WBNB_RES = 10_000 ether;
    uint112 internal constant MIN_RES = 1;

    function setUp() public {
        vm.etch(TOKEN, hex"fe");
        vm.etch(WBNB, hex"fe");

        factory = new MockPancakeFactory();
        address t0 = WBNB;
        address t1 = TOKEN;
        pair = new MockPancakePair(t0, t1, address(factory));
        factory.setPair(t0, t1, address(pair));
        factory.setPair(t1, t0, address(pair)); // bidirectional like real factory

        pair.setReserves(INIT_WBNB_RES, INIT_TOKEN_RES, uint32(block.timestamp));
        pair.setCumulatives(0, 0);

        oracle = new PancakeV2TwapOracle(
            TOKEN, WBNB, address(factory), address(pair), TWAP_WINDOW, DEV_BPS, MIN_RES, MIN_RES
        );
        assertFalse(oracle.tokenIsToken0());
    }

    // ───────────────────────────────────────────────────────
    // T9: PANGU2=token1 — no-swap window matures
    // ───────────────────────────────────────────────────────
    function testNoSwapWindowMaturesToken1() public {
        oracle.update();
        assertEq(uint256(oracle.status()), uint256(PancakeV2TwapOracle.WindowStatus.ACCUMULATING));

        vm.warp(block.timestamp + TWAP_WINDOW);
        oracle.update();
        assertEq(uint256(oracle.status()), uint256(PancakeV2TwapOracle.WindowStatus.READY));
    }

    // ───────────────────────────────────────────────────────
    // T10: PANGU2=token1 — bidirectional quotes
    // ───────────────────────────────────────────────────────
    function testQuotesTokenAsToken1() public {
        oracle.update(); // anchor
        vm.warp(block.timestamp + TWAP_WINDOW);
        oracle.update(); // mature

        // Token → WBNB
        PancakeV2TwapOracle.Quote memory q1 = oracle.validatedQuote(TOKEN, WBNB, 1 ether);
        assertGt(q1.amountOut, 0);

        // WBNB → Token
        PancakeV2TwapOracle.Quote memory q2 = oracle.validatedQuote(WBNB, TOKEN, 1 ether);
        assertGt(q2.amountOut, 0);

        assertApproxEqRel(q1.amountOut, 0.1 ether, 0.05e18);
        assertApproxEqRel(q2.amountOut, 10 ether, 0.05e18);
    }

    // T11: token1 — observedAtBlock correct
    function testObservedAtBlockToken1() public {
        oracle.update(); // anchor
        vm.warp(block.timestamp + TWAP_WINDOW);
        oracle.update(); // mature
        PancakeV2TwapOracle.Quote memory q = oracle.validatedQuote(TOKEN, WBNB, 1 ether);
        assertEq(q.observedAtBlock, block.number);
    }
}
