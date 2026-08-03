// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IPancakeFactory, IPancakePair } from "../interfaces/IPancakeV2.sol";
import { IPangu2TwapOracle } from "../interfaces/IPangu2TwapOracle.sol";
import { FullMath } from "../libraries/FullMath.sol";

contract PancakeV2TwapOracle is IPangu2TwapOracle {
    address public immutable token;
    address public immutable wbnb;
    IPancakeFactory public immutable factory;
    IPancakePair public immutable pair;
    uint32 public immutable twapWindow;
    uint16 public immutable maximumSpotTwapDeviationBps;

    uint16 public constant BPS_DENOMINATOR = 10_000;
    uint256 private constant Q112 = 2 ** 112;

    struct Observation {
        uint32 timestamp;
        uint256 price0CumulativeLast;
        uint256 price1CumulativeLast;
    }

    /// Completed window TWAP averages (in Q112). Always available once a window completes.
    /// Even after update() advances to a new window, these remain valid for quoting.
    uint256 public lastTwapPrice0Accumulator; // avg price0 over completed window (Q112)
    uint256 public lastTwapPrice1Accumulator; // avg price1 over completed window (Q112)
    uint256 public lastTwapElapsed; // elapsed seconds of completed window

    Observation public prevObservation; // start of completed window (for computing averages)
    Observation public curObservation; // start of current window (accumulating)
    uint8 public windowStatus; // 0=uninitialized, 1=firstWindowAccumulating, 2=ready, 3=ready+accumulatingNext

    error ZeroAddress();
    error AddressHasNoCode(address account);
    error InvalidPair();
    error InvalidAmount();
    error ZeroQuote();
    error ZeroReserves();
    error ExcessiveSpotTwapDeviation(uint256 spot, uint256 twap, uint256 deviationBps);
    error OracleNotReady(uint256 elapsed, uint32 required);
    error NoAnchor();

    constructor(
        address token_,
        address wbnb_,
        address factory_,
        address pair_,
        uint32 twapWindow_,
        uint16 maximumSpotTwapDeviationBps_
    ) {
        _requireContract(token_);
        _requireContract(wbnb_);
        _requireContract(factory_);
        _requireContract(pair_);
        if (twapWindow_ == 0 || maximumSpotTwapDeviationBps_ > BPS_DENOMINATOR) revert InvalidAmount();
        token = token_;
        wbnb = wbnb_;
        factory = IPancakeFactory(factory_);
        pair = IPancakePair(pair_);
        twapWindow = twapWindow_;
        maximumSpotTwapDeviationBps = maximumSpotTwapDeviationBps_;
        address pairToken0 = IPancakePair(pair_).token0();
        address pairToken1 = IPancakePair(pair_).token1();
        if (!((pairToken0 == token_ && pairToken1 == wbnb_) || (pairToken0 == wbnb_ && pairToken1 == token_))) {
            revert InvalidPair();
        }
        if (IPancakeFactory(factory_).getPair(token_, wbnb_) != pair_) revert InvalidPair();
    }

    // ─── Events ───
    event OracleAnchored(uint32 pairTs, uint256 price0CumulativeLast, uint256 price1CumulativeLast);
    event TwapWindowCompleted(uint256 elapsed, uint256 price0Accumulator, uint256 price1Accumulator);
    event OracleReset();

    function update() external {
        (uint112 r0, uint112 r1, uint32 ts) = pair.getReserves();
        if (r0 == 0 || r1 == 0) {
            if (windowStatus != 0) {
                windowStatus = 0;
                emit OracleReset();
            }
            return;
        }
        uint256 p0 = pair.price0CumulativeLast();
        uint256 p1 = pair.price1CumulativeLast();

        if (windowStatus == 0) {
            // First observation: start current window
            curObservation = Observation({ timestamp: ts, price0CumulativeLast: p0, price1CumulativeLast: p1 });
            windowStatus = 1;
            emit OracleAnchored(ts, p0, p1);
            return;
        }

        // Compute elapsed using uint32 modular arithmetic (Uniswap V2 timestamp semantics)
        uint32 elapsed32;
        unchecked {
            elapsed32 = ts - curObservation.timestamp;
        }
        if (elapsed32 >= twapWindow) {
            uint256 elapsed = uint256(elapsed32);
            lastTwapElapsed = elapsed;
            // unchecked: Uniswap V2 cumulative prices wrap naturally via uint256 overflow
            unchecked {
                lastTwapPrice0Accumulator = (p0 - curObservation.price0CumulativeLast) / elapsed;
                lastTwapPrice1Accumulator = (p1 - curObservation.price1CumulativeLast) / elapsed;
            }
            // The completed window becomes prevObservation; new window starts at current
            prevObservation = curObservation;
            curObservation = Observation({ timestamp: ts, price0CumulativeLast: p0, price1CumulativeLast: p1 });
            windowStatus = windowStatus == 1 ? 2 : 3;
            emit TwapWindowCompleted(elapsed, lastTwapPrice0Accumulator, lastTwapPrice1Accumulator);
        }
    }

    function validatedQuote(address baseToken, address quoteToken, uint128 baseAmount)
        external
        view
        override
        returns (Quote memory quote)
    {
        if (!((baseToken == token && quoteToken == wbnb) || (baseToken == wbnb && quoteToken == token))) {
            revert InvalidPair();
        }
        if (baseAmount == 0) revert InvalidAmount();
        if (windowStatus == 0) revert NoAnchor();

        (uint112 r0, uint112 r1,) = pair.getReserves();
        if (r0 == 0 || r1 == 0) revert ZeroReserves();
        bool tokenIsToken0 = token < wbnb;
        uint256 tRes = tokenIsToken0 ? uint256(r0) : uint256(r1);
        uint256 wRes = tokenIsToken0 ? uint256(r1) : uint256(r0);

        // Spot
        uint256 spotOut = baseToken == token
            ? FullMath.mulDiv(uint256(baseAmount), wRes, tRes)
            : FullMath.mulDiv(uint256(baseAmount), tRes, wRes);
        if (spotOut == 0) revert ZeroQuote();

        uint256 qpb; // quote per base in Q112

        if (windowStatus == 1) {
            // First window: compute TWAP from counterfactual cumulative prices
            // using block.timestamp (avoids deadlock when pair hasn't had a swap)
            uint256 elapsed =
                block.timestamp >= curObservation.timestamp ? block.timestamp - curObservation.timestamp : 0;
            if (elapsed < twapWindow) revert OracleNotReady(elapsed, twapWindow);

            // Counterfactual: reserves × Q112 ÷ counterpart, same as real TWAP avg
            qpb = baseToken == token ? FullMath.mulDiv(wRes, Q112, tRes) : FullMath.mulDiv(tRes, Q112, wRes);
        } else {
            // windowStatus >= 2: use completed window's stored TWAP average
            qpb = tokenIsToken0
                ? (baseToken == token ? lastTwapPrice0Accumulator : lastTwapPrice1Accumulator)
                : (baseToken == token ? lastTwapPrice1Accumulator : lastTwapPrice0Accumulator);
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

        quote = Quote({
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
