// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {FullMath} from "./FullMath.sol";
import {TickMathLite} from "./TickMathLite.sol";

library OracleQuote {
    function getQuoteAtTick(int24 tick, uint128 baseAmount, address baseToken, address quoteToken)
        internal
        pure
        returns (uint256 quoteAmount)
    {
        uint160 sqrtRatioX96 = TickMathLite.getSqrtRatioAtTick(tick);
        if (sqrtRatioX96 <= type(uint128).max) {
            uint256 ratioX192 = uint256(sqrtRatioX96) * sqrtRatioX96;
            quoteAmount = baseToken < quoteToken
                ? FullMath.mulDiv(ratioX192, baseAmount, 1 << 192)
                : FullMath.mulDiv(1 << 192, baseAmount, ratioX192);
        } else {
            uint256 ratioX128 = FullMath.mulDiv(sqrtRatioX96, sqrtRatioX96, 1 << 64);
            quoteAmount = baseToken < quoteToken
                ? FullMath.mulDiv(ratioX128, baseAmount, 1 << 128)
                : FullMath.mulDiv(1 << 128, baseAmount, ratioX128);
        }
    }
}
