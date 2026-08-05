// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IPancakeFactory, IPancakePair, IPancakeRouter01 } from "../interfaces/IPancakeV2.sol";
import { IPancakeV2Adapter } from "../interfaces/IPancakeV2Adapter.sol";

/// @notice PancakeSwap V2 交易适配器
///         统一语义：输出永远是 ERC20 代币（WBNB 或 PANGU2），永不发送原生 BNB。
///         TradeRouter/FeeVault/SupportPool 自行处理 WBNB → BNB 的 unwrap。
///         只有持有 CALLER_ROLE 的合约可以发起 swap。
contract PancakeV2Adapter is AccessControl, ReentrancyGuard, IPancakeV2Adapter {
    using SafeERC20 for IERC20;

    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant CALLER_ROLE = keccak256("CALLER_ROLE"); // 允许调用 swap 的角色

    address public immutable token;      // PANGU2 token
    address public immutable wbnb;       // WBNB
    IPancakeFactory public immutable factory;
    IPancakePair public immutable pair;  // PANGU2/WBNB 交易对
    IPancakeRouter01 public immutable router;

    error ZeroAddress();
    error AddressHasNoCode(address account);
    error InvalidPair();
    error InvalidDeadline();
    error InvalidAmount();

    event CallerUpdated(address indexed caller, bool enabled);
    event SwapExecuted(address indexed caller, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut, address recipient);

    constructor(address token_, address wbnb_, address factory_, address pair_, address router_, address governance) {
        _requireContract(token_);
        _requireContract(wbnb_);
        _requireContract(factory_);
        _requireContract(pair_);
        _requireContract(router_);
        if (governance == address(0)) revert ZeroAddress();
        token = token_;
        wbnb = wbnb_;
        factory = IPancakeFactory(factory_);
        pair = IPancakePair(pair_);
        router = IPancakeRouter01(router_);
        address pairToken0 = IPancakePair(pair_).token0();
        address pairToken1 = IPancakePair(pair_).token1();
        if (!((pairToken0 == token_ && pairToken1 == wbnb_) || (pairToken0 == wbnb_ && pairToken1 == token_))) revert InvalidPair();
        if (IPancakeFactory(factory_).getPair(token_, wbnb_) != pair_) revert InvalidPair();
        _grantRole(DEFAULT_ADMIN_ROLE, governance);
        _grantRole(GOVERNANCE_ROLE, governance);
        _setRoleAdmin(CALLER_ROLE, GOVERNANCE_ROLE);
    }

    /// 设置调用者权限（只能由治理调用）
    function setCaller(address caller, bool enabled) external onlyRole(GOVERNANCE_ROLE) {
        if (caller == address(0)) revert ZeroAddress();
        if (enabled) _grantRole(CALLER_ROLE, caller);
        else _revokeRole(CALLER_ROLE, caller);
        emit CallerUpdated(caller, enabled);
    }

    function poolAddress() external view override returns (address) { return address(pair); }

    /// 报价查询（view 函数，不消耗 gas）
    function quoteExactInput(address tokenIn, address tokenOut, uint256 amountIn)
        external view override returns (uint256 amountOut, uint256 quoteBlock)
    {
        _validatePair(tokenIn, tokenOut);
        if (amountIn == 0) revert InvalidAmount();
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        amountOut = router.getAmountsOut(amountIn, path)[1];
        quoteBlock = block.number;
    }

    /// 执行 swap —— 统一使用 swapExactTokensForTokens
    /// 输入 ERC20 必须先转入 Adapter，再由 Adapter approve PancakeRouter 执行 swap
    /// swap 完成后 allowance 清零
    /// 输出永远是 ERC20 —— Adapter 永不发送原生 BNB，调用方自行 unwrap
    function swapExactInput(
        address tokenIn, address tokenOut, uint256 amountIn,
        uint256 amountOutMinimum, address recipient, uint256 deadline
    ) external override onlyRole(CALLER_ROLE) nonReentrant returns (uint256 amountOut) {
        _validatePair(tokenIn, tokenOut);
        if (recipient == address(0)) revert ZeroAddress();
        if (amountIn == 0 || amountOutMinimum == 0) revert InvalidAmount();
        if (deadline < block.timestamp) revert InvalidDeadline();

        // 从调用方接收输入代币
        IERC20 input = IERC20(tokenIn);
        input.safeTransferFrom(msg.sender, address(this), amountIn);
        input.forceApprove(address(router), amountIn);

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        // 两个方向都使用 swapExactTokensForTokens：输出永远是 ERC20
        uint256[] memory amounts = router.swapExactTokensForTokens(amountIn, amountOutMinimum, path, recipient, deadline);
        amountOut = amounts[1];

        // 清零 allowance 防止残留授权
        input.forceApprove(address(router), 0);
        emit SwapExecuted(msg.sender, tokenIn, tokenOut, amountIn, amountOut, recipient);
    }

    function _validatePair(address tokenIn, address tokenOut) private view {
        if (!((tokenIn == token && tokenOut == wbnb) || (tokenIn == wbnb && tokenOut == token))) revert InvalidPair();
    }

    function _requireContract(address account) private view {
        if (account == address(0)) revert ZeroAddress();
        if (account.code.length == 0) revert AddressHasNoCode(account);
    }
}
