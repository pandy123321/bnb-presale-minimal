// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IPangu2TwapOracle {
    struct Quote {
        uint256 amountOut;
        int24 arithmeticMeanTick;
        int24 spotTick;
        uint128 harmonicMeanLiquidity;
        uint256 observedAtBlock;
    }

    function validatedQuote(address baseToken, address quoteToken, uint128 baseAmount)
        external
        view
        returns (Quote memory quote);
}
