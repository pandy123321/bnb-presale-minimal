// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IPancakeFactory, IPancakePair } from "../interfaces/IPancakeV2.sol";
import { IPangu2TwapOracle } from "../interfaces/IPangu2TwapOracle.sol";
import { FullMath } from "../libraries/FullMath.sol";

contract PancakeV2TwapOracle is IPangu2TwapOracle {
    enum WindowStatus {
        UNINITIALIZED, // 0: no anchor yet
        ACCUMULATING, // 1: anchor set, waiting for full twapWindow
        READY, // 2: at least one completed window, TWAP available
        LIQUIDITY_LOW // 3: reserves below minimum — fail-closed
    }

    bool public immutable tokenIsToken0; // cached: token == pair.token0()

    address public immutable token;
    address public immutable wbnb;
    IPancakeFactory public immutable factory;
    IPancakePair public immutable pair;
    uint32 public immutable twapWindow;
    uint16 public immutable maximumSpotTwapDeviationBps;

    uint112 public immutable minTokenReserve;
    uint112 public immutable minWbnbReserve;

    uint16 public constant BPS_DENOMINATOR = 10_000;
    uint256 private constant Q112 = 2 ** 112;

    struct Observation {
        uint32 timestamp;
        uint256 price0CumulativeLast;
        uint256 price1CumulativeLast;
    }

    uint256 public lastTwapPrice0Accumulator;
    uint256 public lastTwapPrice1Accumulator;
    uint256 public lastTwapElapsed;

    Observation public anchor;
    WindowStatus public status;

    error ZeroAddress();
    error AddressHasNoCode(address account);
    error InvalidPair();
    error InvalidAmount();
    error ZeroQuote();
    error ZeroReserves();
    error OracleNotReady();
    error NoAnchor();
    error ExcessiveSpotTwapDeviation(uint256 spot, uint256 twap, uint256 deviationBps);
    error BelowMinimumReserves(uint112 tokenReserve, uint112 wbnbReserve, uint112 minToken, uint112 minWbnb);

    event OracleAnchored(uint32 pairTs, uint256 price0CumulativeLast, uint256 price1CumulativeLast);
    event TwapWindowCompleted(uint256 elapsed, uint256 price0Accumulator, uint256 price1Accumulator);
    event OracleReset();
    event OracleLowLiquidity();
    event OracleRecovered();

    constructor(
        address token_,
        address wbnb_,
        address factory_,
        address pair_,
        uint32 twapWindow_,
        uint16 maximumSpotTwapDeviationBps_,
        uint112 minTokenReserve_,
        uint112 minWbnbReserve_
    ) {
        _requireContract(token_);
        _requireContract(wbnb_);
        _requireContract(factory_);
        _requireContract(pair_);
        if (twapWindow_ == 0 || maximumSpotTwapDeviationBps_ > BPS_DENOMINATOR) revert InvalidAmount();
        if (minTokenReserve_ == 0 || minWbnbReserve_ == 0) revert InvalidAmount();
        token = token_;
        wbnb = wbnb_;
        factory = IPancakeFactory(factory_);
        pair = IPancakePair(pair_);
        twapWindow = twapWindow_;
        maximumSpotTwapDeviationBps = maximumSpotTwapDeviationBps_;
        minTokenReserve = minTokenReserve_;
        minWbnbReserve = minWbnbReserve_;

        address pairToken0 = IPancakePair(pair_).token0();
        address pairToken1 = IPancakePair(pair_).token1();
        if (!((pairToken0 == token_ && pairToken1 == wbnb_) || (pairToken0 == wbnb_ && pairToken1 == token_))) {
            revert InvalidPair();
        }
        if (IPancakeFactory(factory_).getPair(token_, wbnb_) != pair_) revert InvalidPair();
        tokenIsToken0 = pairToken0 == token_;
    }

    function _getMappedReserves(uint112 r0, uint112 r1) private view returns (uint112 tokenRes, uint112 wbnbRes) {
        if (tokenIsToken0) {
            tokenRes = r0;
            wbnbRes = r1;
        } else {
            tokenRes = r1;
            wbnbRes = r0;
        }
    }

    function _reservesAboveMinimum(uint112 tokenRes, uint112 wbnbRes) private view returns (bool) {
        return tokenRes >= minTokenReserve && wbnbRes >= minWbnbReserve;
    }

    function update() external {
        (uint112 r0, uint112 r1, uint32 ts) = pair.getReserves();
        (uint112 tokenRes, uint112 wbnbRes) = _getMappedReserves(r0, r1);

        if (r0 == 0 || r1 == 0 || !_reservesAboveMinimum(tokenRes, wbnbRes)) {
            // Low liquidity — fail closed. Record the low state but do NOT
            // reset anchor/anchor data, so recovery is possible after
            // a single new full window (not forced restart from scratch).
            if (status != WindowStatus.LIQUIDITY_LOW && status != WindowStatus.UNINITIALIZED) {
                status = WindowStatus.LIQUIDITY_LOW;
                emit OracleLowLiquidity();
            }
            return;
        }

        uint256 p0 = pair.price0CumulativeLast();
        uint256 p1 = pair.price1CumulativeLast();

        // Liquidity recovered from LOW_LIQUIDITY — discard old anchor and start fresh
        if (status == WindowStatus.LIQUIDITY_LOW) {
            // The old anchor may include prices from the low-liquidity (manipulated)
            // period. Start a fresh anchor at the recovery point so a full new
            // twapWindow must complete before becoming READY.
            anchor = Observation({ timestamp: ts, price0CumulativeLast: p0, price1CumulativeLast: p1 });
            status = WindowStatus.ACCUMULATING;
            emit OracleRecovered();
            emit OracleAnchored(ts, p0, p1);
            return;
        }

        if (status == WindowStatus.UNINITIALIZED) {
            anchor = Observation({ timestamp: ts, price0CumulativeLast: p0, price1CumulativeLast: p1 });
            status = WindowStatus.ACCUMULATING;
            emit OracleAnchored(ts, p0, p1);
            return;
        }

        // Compute elapsed using uint32 modular arithmetic
        uint32 elapsed32;
        unchecked {
            elapsed32 = ts - anchor.timestamp;
        }
        if (elapsed32 >= twapWindow) {
            uint256 elapsed = uint256(elapsed32);
            lastTwapElapsed = elapsed;
            // Cumulative price delta — steady reserves during window
            // produce valid TWAP (constant price). Only actions that
            // advance the pair timestamp (swap/mint/burn/sync) allow
            // window completion; if no such action occurs the window
            // doesn't mature, which is the correct behavior.
            uint256 p0Delta;
            uint256 p1Delta;
            unchecked {
                p0Delta = p0 - anchor.price0CumulativeLast;
                p1Delta = p1 - anchor.price1CumulativeLast;
            }
            if (p0Delta == 0 || p1Delta == 0) {
                // No price movement — still compute valid zero-change TWAP
                // (constant price observation). Slide anchor forward.
                lastTwapPrice0Accumulator = 0;
                lastTwapPrice1Accumulator = 0;
            } else {
                lastTwapPrice0Accumulator = p0Delta / elapsed;
                lastTwapPrice1Accumulator = p1Delta / elapsed;
            }
            anchor = Observation({ timestamp: ts, price0CumulativeLast: p0, price1CumulativeLast: p1 });
            status = WindowStatus.READY;
            emit TwapWindowCompleted(elapsed, lastTwapPrice0Accumulator, lastTwapPrice1Accumulator);
        }
    }

    function validatedQuote(address baseToken, address quoteToken, uint128 baseAmount)
        external
        view
        override
        returns (Quote memory q)
    {
        if (!((baseToken == token && quoteToken == wbnb) || (baseToken == wbnb && quoteToken == token))) {
            revert InvalidPair();
        }
        if (baseAmount == 0) revert InvalidAmount();

        (uint112 r0, uint112 r1,) = pair.getReserves();
        (uint112 tokenRes, uint112 wbnbRes) = _getMappedReserves(r0, r1);

        if (r0 == 0 || r1 == 0) revert ZeroReserves();
        if (!_reservesAboveMinimum(tokenRes, wbnbRes)) {
            revert BelowMinimumReserves(tokenRes, wbnbRes, minTokenReserve, minWbnbReserve);
        }

        // Only READY state returns quotes
        if (status == WindowStatus.UNINITIALIZED) revert NoAnchor();
        if (status != WindowStatus.READY) revert OracleNotReady();

        uint256 tRes = uint256(tokenRes);
        uint256 wRes = uint256(wbnbRes);

        // Spot price from current reserves (deviation check only, NOT for quote)
        uint256 spotOut = baseToken == token
            ? FullMath.mulDiv(uint256(baseAmount), wRes, tRes)
            : FullMath.mulDiv(uint256(baseAmount), tRes, wRes);
        if (spotOut == 0) revert ZeroQuote();

        // TWAP from completed window (Q112)
        uint256 qpb;
        if (tokenIsToken0) {
            qpb = baseToken == token ? lastTwapPrice0Accumulator : lastTwapPrice1Accumulator;
        } else {
            qpb = baseToken == token ? lastTwapPrice1Accumulator : lastTwapPrice0Accumulator;
        }
        if (qpb == 0) {
            // Zero cumulative delta case: compute price from current reserves
            // (this IS valid when the pair had constant reserves for the full window)
            qpb = baseToken == token ? FullMath.mulDiv(wRes, Q112, tRes) : FullMath.mulDiv(tRes, Q112, wRes);
        }
        if (qpb == 0) revert ZeroQuote();

        uint256 twapOut = FullMath.mulDiv(uint256(baseAmount), qpb, Q112);
        if (twapOut == 0) revert ZeroQuote();

        if (maximumSpotTwapDeviationBps < BPS_DENOMINATOR) {
            uint256 dev = spotOut > twapOut
                ? FullMath.mulDiv(spotOut - twapOut, BPS_DENOMINATOR, twapOut)
                : FullMath.mulDiv(twapOut - spotOut, BPS_DENOMINATOR, spotOut);
            if (dev > maximumSpotTwapDeviationBps) {
                revert ExcessiveSpotTwapDeviation(spotOut, twapOut, dev);
            }
        }

        q = Quote({
            amountOut: twapOut,
            arithmeticMeanTick: 0,
            spotTick: 0,
            harmonicMeanLiquidity: 0,
            observedAtBlock: uint40(block.number)
        });
    }

    function _requireContract(address account) private view {
        if (account == address(0)) revert ZeroAddress();
        if (account.code.length == 0) revert AddressHasNoCode(account);
    }
}
