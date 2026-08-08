// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TransferContext } from "../libraries/TransferContext.sol";

interface IPangu2Token is IERC20 {
    function BUY_TAX_BPS() external view returns (uint16);
    function NORMAL_SELL_TAX_BPS() external view returns (uint16);
    function PROFIT_SELL_TAX_BPS() external view returns (uint16);
    function MIN_SELL_AMOUNT() external view returns (uint256);

    function previewBuyTax(uint256 grossAmount) external view returns (uint256 taxAmount, uint256 netAmount);
    function previewBuyTaxFor(address buyer, uint256 grossAmount)
        external
        view
        returns (uint256 taxAmount, uint256 netAmount);
    function previewSellTax(uint256 sellAmount, uint16 taxBps)
        external
        view
        returns (uint256 supportAmount, uint256 burnAmount, uint256 swapAmount);
    function previewSellTaxFor(address seller, uint256 sellAmount, uint16 taxBps)
        external
        view
        returns (uint256 supportAmount, uint256 burnAmount, uint256 swapAmount);

    /// @notice Authoritative buy tax rate — single source of truth.
    function resolveBuyTaxBps(address buyer) external view returns (uint16);

    /// @notice Authoritative sell tax rate — single source of truth.
    function resolveSellTaxBps(address seller, uint16 baseTaxBps) external view returns (uint16);

    function settleBuy(address buyer, uint256 grossAmount, uint256 costWbnbWei)
        external
        returns (uint256 taxAmount, uint256 netAmount);

    function settleSell(address seller, uint256 sellAmount, uint16 taxBps)
        external
        returns (uint256 supportAmount, uint256 burnAmount, uint256 swapAmount);

    function settleSellExact(address seller, uint256 sellAmount, uint256 supportAmount, uint256 burnAmount)
        external
        returns (uint256 swapAmount);

    function systemTransfer(address to, uint256 amount, TransferContext.Kind kind) external returns (bool);
    function stakingDeposit(address from, uint256 amount) external returns (bool);
    function emitSellSettlementAmountOut(address seller, uint256 tokenIn, uint16 taxBps, uint256 amountOut) external;

    function isPair(address account) external view returns (bool);
    function isSystemAddress(address account) external view returns (bool);
    function isLiquidityManager(address account) external view returns (bool);
}
