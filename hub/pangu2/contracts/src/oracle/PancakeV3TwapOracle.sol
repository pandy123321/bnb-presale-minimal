// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IPancakeV3Factory, IPancakeV3Pool} from "../interfaces/IPancakeV3.sol";
import {IPangu2TwapOracle} from "../interfaces/IPangu2TwapOracle.sol";
import {OracleQuote} from "../libraries/OracleQuote.sol";
import {FullMath} from "../libraries/FullMath.sol";

contract PancakeV3TwapOracle is IPangu2TwapOracle {
    address public immutable token;
    address public immutable wbnb;
    IPancakeV3Factory public immutable factory;
    IPancakeV3Pool public immutable pool;
    uint24 public immutable feeTier;
    uint32 public immutable twapWindow;
    uint16 public immutable minimumObservationCardinality;
    uint16 public immutable maximumSpotTwapDeviationBps;
    uint128 public immutable minimumHarmonicLiquidity;

    uint16 public constant BPS_DENOMINATOR = 10_000;

    error ZeroAddress();
    error AddressHasNoCode(address account);
    error InvalidPool();
    error InvalidPair();
    error InvalidAmount();
    error InsufficientObservationCardinality(uint16 actual, uint16 required);
    error InsufficientLiquidity(uint128 actual, uint128 required);
    error OracleObservationFailed();
    error SpotTwapDeviationExceeded(uint256 deviationBps, uint256 maximumBps);
    error ZeroQuote();

    constructor(
        address token_,
        address wbnb_,
        address factory_,
        address pool_,
        uint24 feeTier_,
        uint32 twapWindow_,
        uint16 minimumObservationCardinality_,
        uint16 maximumSpotTwapDeviationBps_,
        uint128 minimumHarmonicLiquidity_
    ) {
        _requireContract(token_);
        _requireContract(wbnb_);
        _requireContract(factory_);
        _requireContract(pool_);
        if (
            twapWindow_ == 0 || minimumObservationCardinality_ == 0
                || maximumSpotTwapDeviationBps_ > BPS_DENOMINATOR || minimumHarmonicLiquidity_ == 0
        ) revert InvalidAmount();

        token = token_;
        wbnb = wbnb_;
        factory = IPancakeV3Factory(factory_);
        pool = IPancakeV3Pool(pool_);
        feeTier = feeTier_;
        twapWindow = twapWindow_;
        minimumObservationCardinality = minimumObservationCardinality_;
        maximumSpotTwapDeviationBps = maximumSpotTwapDeviationBps_;
        minimumHarmonicLiquidity = minimumHarmonicLiquidity_;

        address poolToken0 = IPancakeV3Pool(pool_).token0();
        address poolToken1 = IPancakeV3Pool(pool_).token1();
        if (!((poolToken0 == token_ && poolToken1 == wbnb_) || (poolToken0 == wbnb_ && poolToken1 == token_))) {
            revert InvalidPool();
        }
        if (IPancakeV3Pool(pool_).fee() != feeTier_) revert InvalidPool();
        if (IPancakeV3Pool(pool_).factory() != factory_) revert InvalidPool();
        if (IPancakeV3Factory(factory_).getPool(token_, wbnb_, feeTier_) != pool_) revert InvalidPool();
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

        (, int24 spotTick,, uint16 observationCardinality,,,) = pool.slot0();
        if (observationCardinality < minimumObservationCardinality) {
            revert InsufficientObservationCardinality(observationCardinality, minimumObservationCardinality);
        }

        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = twapWindow;
        secondsAgos[1] = 0;

        int56[] memory tickCumulatives;
        uint160[] memory secondsPerLiquidityCumulativeX128s;
        try pool.observe(secondsAgos) returns (int56[] memory ticks, uint160[] memory secondsPerLiquidity) {
            tickCumulatives = ticks;
            secondsPerLiquidityCumulativeX128s = secondsPerLiquidity;
        } catch {
            revert OracleObservationFailed();
        }
        if (tickCumulatives.length != 2 || secondsPerLiquidityCumulativeX128s.length != 2) {
            revert OracleObservationFailed();
        }

        int56 tickDelta;
        uint160 splDelta;
        unchecked {
            tickDelta = tickCumulatives[1] - tickCumulatives[0];
            splDelta = secondsPerLiquidityCumulativeX128s[1] - secondsPerLiquidityCumulativeX128s[0];
        }
        int56 window = int56(uint56(twapWindow));
        int24 arithmeticMeanTick = int24(tickDelta / window);
        if (tickDelta < 0 && (tickDelta % window != 0)) arithmeticMeanTick--;

        if (splDelta == 0) revert OracleObservationFailed();
        uint256 harmonic = FullMath.mulDiv(uint256(twapWindow), 1 << 128, uint256(splDelta));
        uint128 harmonicLiquidity = harmonic > type(uint128).max ? type(uint128).max : uint128(harmonic);
        if (harmonicLiquidity < minimumHarmonicLiquidity) {
            revert InsufficientLiquidity(harmonicLiquidity, minimumHarmonicLiquidity);
        }

        uint256 twapUnitQuote = OracleQuote.getQuoteAtTick(arithmeticMeanTick, 1 ether, baseToken, quoteToken);
        uint256 spotUnitQuote = OracleQuote.getQuoteAtTick(spotTick, 1 ether, baseToken, quoteToken);
        uint256 difference = spotUnitQuote > twapUnitQuote
            ? spotUnitQuote - twapUnitQuote
            : twapUnitQuote - spotUnitQuote;
        uint256 deviationBps = twapUnitQuote == 0
            ? type(uint256).max
            : FullMath.mulDiv(difference, BPS_DENOMINATOR, twapUnitQuote);
        if (deviationBps > maximumSpotTwapDeviationBps) {
            revert SpotTwapDeviationExceeded(deviationBps, maximumSpotTwapDeviationBps);
        }

        uint256 amountOut = OracleQuote.getQuoteAtTick(arithmeticMeanTick, baseAmount, baseToken, quoteToken);
        if (amountOut == 0) revert ZeroQuote();
        quote = Quote({
            amountOut: amountOut,
            arithmeticMeanTick: arithmeticMeanTick,
            spotTick: spotTick,
            harmonicMeanLiquidity: harmonicLiquidity,
            observedAtBlock: block.number
        });
    }

    function _requireContract(address account) private view {
        if (account == address(0)) revert ZeroAddress();
        if (account.code.length == 0) revert AddressHasNoCode(account);
    }
}
