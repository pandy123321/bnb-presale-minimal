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
    uint256 private constant Q112 = 2**112;

    struct Observation { uint32 timestamp; uint256 price0CumulativeLast; uint256 price1CumulativeLast; }

    Observation public anchor;
    bool public anchored;

    error ZeroAddress();
    error AddressHasNoCode(address account);
    error InvalidPair();
    error InvalidAmount();
    error ZeroQuote();
    error ZeroReserves();
    error ExcessiveSpotTwapDeviation(uint256 spot, uint256 twap, uint16 deviationBps);
    error OracleNotReady(uint256 elapsed, uint32 required);
    error NoAnchor();

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
    }

    function update() external override {
        (uint112 r0, uint112 r1, uint32 ts) = pair.getReserves();
        if (r0 == 0 || r1 == 0) { anchored = false; return; }
        uint256 p0 = IUniswapV2Pair(address(pair)).price0CumulativeLast();
        uint256 p1 = IUniswapV2Pair(address(pair)).price1CumulativeLast();
        if (!anchored) {
            anchor = Observation({timestamp: ts, price0CumulativeLast: p0, price1CumulativeLast: p1});
            anchored = true;
            return;
        }
        // Only advance anchor after full twapWindow; prevents frequent resets
        if (ts >= anchor.timestamp && ts - anchor.timestamp >= twapWindow) {
            anchor = Observation({timestamp: ts, price0CumulativeLast: p0, price1CumulativeLast: p1});
        }
    }

    function validatedQuote(address baseToken, address quoteToken, uint128 baseAmount)
        external view override returns (Quote memory quote)
    {
        if (!((baseToken == token && quoteToken == wbnb) || (baseToken == wbnb && quoteToken == token)))
            revert InvalidPair();
        if (baseAmount == 0) revert InvalidAmount();
        if (!anchored) revert NoAnchor();

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

        // Counterfactual cumulative (extrapolate to current block)
        uint256 p0c = _cfPrice0(); uint256 p1c = _cfPrice1();
        uint256 elapsed = block.timestamp >= anchor.timestamp ? block.timestamp - anchor.timestamp : 0;
        if (elapsed < twapWindow) revert OracleNotReady(elapsed, twapWindow);

        // avg price0 = (reserve1/reserve0) in Q112; avg price1 = (reserve0/reserve1) in Q112
        uint256 p0Delta = p0c - anchor.price0CumulativeLast;
        uint256 p1Delta = p1c - anchor.price1CumulativeLast;

        // quotePerBaseQ112 = TWAP of quoteToken per baseToken in Q112
        // tokenIsToken0: price0 = wbnb/token, price1 = token/wbnb
        uint256 qpb = tokenIsToken0
            ? (baseToken == token ? p0Delta / elapsed : p1Delta / elapsed)
            : (baseToken == token ? p1Delta / elapsed : p0Delta / elapsed);

        uint256 twapOut = FullMath.mulDiv(uint256(baseAmount), qpb, Q112);
        if (twapOut == 0) revert ZeroQuote();

        if (maximumSpotTwapDeviationBps < BPS_DENOMINATOR) {
            uint256 dev = spotOut > twapOut
                ? ((spotOut - twapOut) * BPS_DENOMINATOR) / twapOut
                : ((twapOut - spotOut) * BPS_DENOMINATOR) / spotOut;
            if (dev > maximumSpotTwapDeviationBps)
                revert ExcessiveSpotTwapDeviation(spotOut, twapOut, uint16(dev));
        }

        quote = Quote({amountOut: twapOut, arithmeticMeanTick: 0, spotTick: 0, harmonicMeanLiquidity: 0, observedAtBlock: uint40(block.number)});
    }

    function _cfPrice0() private view returns (uint256) {
        (uint112 r0, uint112 r1, uint32 lastTs) = pair.getReserves();
        uint256 s = IUniswapV2Pair(address(pair)).price0CumulativeLast();
        if (lastTs >= block.timestamp) return s;
        return s + FullMath.mulDiv(uint256(r1) * (block.timestamp - lastTs), Q112, uint256(r0));
    }

    function _cfPrice1() private view returns (uint256) {
        (uint112 r0, uint112 r1, uint32 lastTs) = pair.getReserves();
        uint256 s = IUniswapV2Pair(address(pair)).price1CumulativeLast();
        if (lastTs >= block.timestamp) return s;
        return s + FullMath.mulDiv(uint256(r0) * (block.timestamp - lastTs), Q112, uint256(r1));
    }

    function _requireContract(address account) private view {
        if (account == address(0)) revert ZeroAddress();
        if (account.code.length == 0) revert AddressHasNoCode(account);
    }
}
