// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    IPancakeV3Factory,
    IPancakeV3Pool,
    IPancakeV3SwapRouter,
    IPancakeV3QuoterV2
} from "../interfaces/IPancakeV3.sol";
import {IPancakeV3Adapter} from "../interfaces/IPancakeV3Adapter.sol";

contract PancakeV3Adapter is AccessControl, ReentrancyGuard, IPancakeV3Adapter {
    using SafeERC20 for IERC20;

    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant CALLER_ROLE = keccak256("CALLER_ROLE");

    address public immutable token;
    address public immutable wbnb;
    IPancakeV3Factory public immutable factory;
    IPancakeV3Pool public immutable pool;
    IPancakeV3SwapRouter public immutable swapRouter;
    IPancakeV3QuoterV2 public immutable quoter;
    uint24 public immutable feeTier;

    error ZeroAddress();
    error AddressHasNoCode(address account);
    error InvalidPool();
    error InvalidPair();
    error InvalidDeadline();
    error QuoteFailed();
    error InvalidAmount();

    event CallerUpdated(address indexed caller, bool enabled);
    event SwapExecuted(
        address indexed caller,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address recipient
    );

    constructor(
        address token_,
        address wbnb_,
        address factory_,
        address pool_,
        address swapRouter_,
        address quoter_,
        uint24 feeTier_,
        address governance
    ) {
        _requireContract(token_);
        _requireContract(wbnb_);
        _requireContract(factory_);
        _requireContract(pool_);
        _requireContract(swapRouter_);
        _requireContract(quoter_);
        if (governance == address(0)) revert ZeroAddress();

        token = token_;
        wbnb = wbnb_;
        factory = IPancakeV3Factory(factory_);
        pool = IPancakeV3Pool(pool_);
        swapRouter = IPancakeV3SwapRouter(swapRouter_);
        quoter = IPancakeV3QuoterV2(quoter_);
        feeTier = feeTier_;

        address poolToken0 = IPancakeV3Pool(pool_).token0();
        address poolToken1 = IPancakeV3Pool(pool_).token1();
        if (!((poolToken0 == token_ && poolToken1 == wbnb_) || (poolToken0 == wbnb_ && poolToken1 == token_))) {
            revert InvalidPool();
        }
        if (IPancakeV3Pool(pool_).fee() != feeTier_) revert InvalidPool();
        if (IPancakeV3Pool(pool_).factory() != factory_) revert InvalidPool();
        if (IPancakeV3Factory(factory_).getPool(token_, wbnb_, feeTier_) != pool_) revert InvalidPool();

        _grantRole(DEFAULT_ADMIN_ROLE, governance);
        _grantRole(GOVERNANCE_ROLE, governance);
        _setRoleAdmin(CALLER_ROLE, GOVERNANCE_ROLE);
    }

    function setCaller(address caller, bool enabled) external onlyRole(GOVERNANCE_ROLE) {
        if (caller == address(0)) revert ZeroAddress();
        if (enabled) _grantRole(CALLER_ROLE, caller);
        else _revokeRole(CALLER_ROLE, caller);
        emit CallerUpdated(caller, enabled);
    }


    function poolAddress() external view override returns (address) {
        return address(pool);
    }

    function quoteExactInput(address tokenIn, address tokenOut, uint256 amountIn)
        external
        override
        returns (uint256 amountOut, uint256 quoteBlock)
    {
        _validatePair(tokenIn, tokenOut);
        if (amountIn == 0) revert InvalidAmount();

        IPancakeV3QuoterV2.QuoteExactInputSingleParams memory params = IPancakeV3QuoterV2
            .QuoteExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            fee: feeTier,
            sqrtPriceLimitX96: 0
        });
        (amountOut,,,) = quoter.quoteExactInputSingle(params);
        quoteBlock = block.number;
    }

    function swapExactInput(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address recipient,
        uint256 deadline
    ) external override onlyRole(CALLER_ROLE) nonReentrant returns (uint256 amountOut) {
        _validatePair(tokenIn, tokenOut);
        if (recipient == address(0)) revert ZeroAddress();
        if (amountIn == 0) revert InvalidAmount();
        if (deadline < block.timestamp) revert InvalidDeadline();

        IERC20 input = IERC20(tokenIn);
        input.safeTransferFrom(msg.sender, address(this), amountIn);
        input.forceApprove(address(swapRouter), amountIn);
        amountOut = swapRouter.exactInputSingle(
            IPancakeV3SwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: feeTier,
                recipient: recipient,
                deadline: deadline,
                amountIn: amountIn,
                amountOutMinimum: amountOutMinimum,
                sqrtPriceLimitX96: 0
            })
        );
        input.forceApprove(address(swapRouter), 0);
        emit SwapExecuted(msg.sender, tokenIn, tokenOut, amountIn, amountOut, recipient);
    }

    function _validatePair(address tokenIn, address tokenOut) private view {
        if (!((tokenIn == token && tokenOut == wbnb) || (tokenIn == wbnb && tokenOut == token))) {
            revert InvalidPair();
        }
    }

    function _requireContract(address account) private view {
        if (account == address(0)) revert ZeroAddress();
        if (account.code.length == 0) revert AddressHasNoCode(account);
    }
}
