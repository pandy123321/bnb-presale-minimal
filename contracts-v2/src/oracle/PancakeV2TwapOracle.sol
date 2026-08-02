// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IPancakeFactory, IPancakePair, IUniswapV2Pair} from "../interfaces/IPancakeV2.sol";
import {IPangu2TwapOracle} from "../interfaces/IPangu2TwapOracle.sol";
import {FullMath} from "../libraries/FullMath.sol";

contract PancakeV2TwapOracle is IPangu2TwapOracle {
    address public immutable token;
    address public immutable wbnb;
    IPancakeFactory public immutable factory;
    IPancakePair public immutable pair;
    uint32 public immutable twapWindow;
    uint16 public immutable maximumSpotTwapDeviationBps;

    uint16 public constant BPS_DENOMINATOR = 10_000;

    Observation public lastObservation;

    error ZeroAddress();
    error AddressHasNoCode(address account);
    error InvalidPair();
    error InvalidAmount();
    error ZeroQuote();
    error ExcessiveSpotTwapDeviation(uint256 spot, uint256 twap, uint16 deviationBps);
    error ObservationWindowTooShort(uint256 elapsed, uint32 required);

    constructor(
        address token_, address wbnb_, address factory_, address pair_, uint32 twapWindow_,
        uint16 maximumSpotTwapDeviationBps_
    ) {
        _requireContract(token_); _requireContract(wbnb_); _requireContract(factory_); _requireContract(pair_);
        if (twapWindow_ == 0 || maximumSpotTwapDeviationBps_ > BPS_DENOMINATOR) revert InvalidAmount();
        token = token_; wbnb = wbnb_; factory = IPancakeFactory(factory_); pair = IPancakePair(pair_);
        twapWindow = twapWindow_; maximumSpotTwapDeviationBps = maximumSpotTwapDeviationBps_;
        address pairToken0 = IPancakePair(pair_).token0();
        address pairToken1 = IPancakePair(pair_).token1();
        if (!((pairToken0 == token_ && pairToken1 == wbnb_) || (pairToken0 == wbnb_ && pairToken1 == token_))) {
            revert InvalidPair();
        }
        if (IPancakeFactory(factory_).getPair(token_, wbnb_) != pair_) revert InvalidPair();
        // Seed first observation
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = pair.getReserves();
        lastObservation = Observation({
            timestamp: blockTimestampLast,
            price0CumulativeLast: IUniswapV2Pair(address(pair)).price0CumulativeLast(),
            price1CumulativeLast: IUniswapV2Pair(address(pair)).price1CumulativeLast()
        });
    }

    function update() external override {
        (,, uint32 ts) = pair.getReserves();
        uint p0 = IUniswapV2Pair(address(pair)).price0CumulativeLast();
        uint p1 = IUniswapV2Pair(address(pair)).price1CumulativeLast();
        if (ts > lastObservation.timestamp) {
            lastObservation = Observation({timestamp: ts, price0CumulativeLast: p0, price1CumulativeLast: p1});
        }
    }

    function validatedQuote(address baseToken, address quoteToken, uint128 baseAmount)
        external view override returns (Quote memory quote)
    {
        if (!((baseToken == token && quoteToken == wbnb) || (baseToken == wbnb && quoteToken == token)))
            revert InvalidPair();
        if (baseAmount == 0) revert InvalidAmount();

        (uint112 r0, uint112 r1,) = pair.getReserves();
        bool t0 = token < wbnb;
        uint256 tRes = t0 ? uint256(r0) : uint256(r1);
        uint256 wRes = t0 ? uint256(r1) : uint256(r0);
        if (tRes == 0 || wRes == 0) revert ZeroQuote();

        // Spot
        uint256 spotOut = baseToken == token
            ? FullMath.mulDiv(uint256(baseAmount), wRes, tRes)
            : FullMath.mulDiv(uint256(baseAmount), tRes, wRes);
        if (spotOut == 0) revert ZeroQuote();

        // TWAP from cumulative deltas
        uint256 twapOut = spotOut;
        (,, uint32 ts) = pair.getReserves();
        uint p0c = IUniswapV2Pair(address(pair)).price0CumulativeLast();
        uint p1c = IUniswapV2Pair(address(pair)).price1CumulativeLast();
        uint256 elapsed = ts >= lastObservation.timestamp ? ts - lastObservation.timestamp : 0;

        if (elapsed >= twapWindow && lastObservation.price0CumulativeLast > 0 && p0c > lastObservation.price0CumulativeLast) {
            uint256 avgR0 = (p0c - lastObservation.price0CumulativeLast) / elapsed;
            uint256 avgR1 = (p1c - lastObservation.price1CumulativeLast) / elapsed;
            if (avgR0 > 0 && avgR1 > 0) {
                twapOut = baseToken == token
                    ? FullMath.mulDiv(uint256(baseAmount), avgR1, avgR0)
                    : FullMath.mulDiv(uint256(baseAmount), avgR0, avgR1);
            }
            // Validate deviation
            if (maximumSpotTwapDeviationBps < BPS_DENOMINATOR) {
                uint256 dev;
                if (spotOut > twapOut) {
                    dev = ((spotOut - twapOut) * BPS_DENOMINATOR) / twapOut;
                } else {
                    dev = ((twapOut - spotOut) * BPS_DENOMINATOR) / spotOut;
                }
                if (dev > maximumSpotTwapDeviationBps)
                    revert ExcessiveSpotTwapDeviation(spotOut, twapOut, uint16(dev));
            }
        } else if (maximumSpotTwapDeviationBps == 0 && elapsed < twapWindow) {
            revert ObservationWindowTooShort(elapsed, twapWindow);
        }

        quote = Quote({amountOut: twapOut, arithmeticMeanTick: 0, spotTick: 0, harmonicMeanLiquidity: 0, observedAtBlock: uint40(block.number)});
    }

    function _requireContract(address account) private view {
        if (account == address(0)) revert ZeroAddress();
        if (account.code.length == 0) revert AddressHasNoCode(account);
    }
}
