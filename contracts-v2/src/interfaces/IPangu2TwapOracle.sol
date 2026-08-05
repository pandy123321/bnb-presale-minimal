// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice TWAP 预言机接口
///         V2 实现使用 PancakeSwap V2 累计价格差值计算时间加权均价。
///         V3 字段 (arithmeticMeanTick, spotTick, harmonicMeanLiquidity) 在 V2 中恒为 0。
interface IPangu2TwapOracle {
    struct Quote {
        uint256 amountOut;              // TWAP 报价的 output 数量
        int24 arithmeticMeanTick;      // V3 算术平均 tick（V2 恒为 0）
        int24 spotTick;                // V3 现货 tick（V2 恒为 0）
        uint128 harmonicMeanLiquidity; // V3 调和平均流动性（V2 恒为 0）
        uint256 observedAtBlock;       // 报价时区块号
    }

    /// 返回经过 TWAP 验证和偏差校验的报价
    function validatedQuote(address baseToken, address quoteToken, uint128 baseAmount)
        external view returns (Quote memory quote);

    /// 更新预言机状态（permissionless）
    function update() external;
}
