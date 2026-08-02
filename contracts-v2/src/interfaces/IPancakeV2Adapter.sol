// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IPancakeV2Adapter {
    function quoteExactInput(address tokenIn, address tokenOut, uint256 amountIn)
        external
        returns (uint256 amountOut, uint256 quoteBlock);

    function poolAddress() external view returns (address);

    function swapExactInput(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address recipient,
        uint256 deadline
    ) external returns (uint256 amountOut);
}
