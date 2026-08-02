// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IPancakeFactory, IPancakePair} from "../interfaces/IPancakeV2.sol";
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

    error ZeroAddress();
    error AddressHasNoCode(address account);
    error InvalidPair();
    error InvalidAmount();
    error ZeroQuote();

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

    function validatedQuote(address baseToken, address quoteToken, uint128 baseAmount)
        external view override returns (Quote memory quote)
    {
        if (!((baseToken == token && quoteToken == wbnb) || (baseToken == wbnb && quoteToken == token))) {
            revert InvalidPair();
        }
        if (baseAmount == 0) revert InvalidAmount();

        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        bool tokenIsToken0 = token < wbnb;
        uint256 tokenReserve = tokenIsToken0 ? uint256(reserve0) : uint256(reserve1);
        uint256 wbnbReserve = tokenIsToken0 ? uint256(reserve1) : uint256(reserve0);

        if (tokenReserve == 0 || wbnbReserve == 0) revert ZeroQuote();

        uint256 amountOut;
        if (baseToken == token) {
            amountOut = FullMath.mulDiv(uint256(baseAmount), wbnbReserve, tokenReserve);
        } else {
            amountOut = FullMath.mulDiv(uint256(baseAmount), tokenReserve, wbnbReserve);
        }
        if (amountOut == 0) revert ZeroQuote();

        quote = Quote({
            amountOut: amountOut,
            arithmeticMeanTick: 0,
            spotTick: 0,
            harmonicMeanLiquidity: 0,
            observedAtBlock: block.number
        });
    }

    function _requireContract(address account) private view {
        if (account == address(0)) revert ZeroAddress();
        if (account.code.length == 0) revert AddressHasNoCode(account);
    }
}
