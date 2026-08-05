// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice PancakeSwap V2 交易适配器接口
///         统一语义：输出永远是 ERC20 代币，适配器不发送原生 BNB
interface IPancakeV2Adapter {
    /// 查询报价（view 函数）
    function quoteExactInput(address tokenIn, address tokenOut, uint256 amountIn)
        external view returns (uint256 amountOut, uint256 quoteBlock);

    /// 返回交易对地址
    function poolAddress() external view returns (address);

    /// 执行 swap —— 发送方先将 ERC20 转入 Adapter
    /// 输出永远是 ERC20。调用方自行 unwrap WBNB → BNB
    function swapExactInput(
        address tokenIn, address tokenOut, uint256 amountIn,
        uint256 amountOutMinimum, address recipient, uint256 deadline
    ) external returns (uint256 amountOut);
}
