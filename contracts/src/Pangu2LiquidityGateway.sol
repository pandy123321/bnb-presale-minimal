// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IPangu2Token} from "./interfaces/IPangu2Token.sol";
import {IPancakeV3NonfungiblePositionManager} from "./interfaces/IPancakeV3.sol";
import {TransferContext} from "./libraries/TransferContext.sol";

/// @notice Protocol liquidity entry that keeps Pancake V3 NFTs in custody while preserving user cost basis.
/// @dev Users cannot bypass this gateway because direct PANGU2/Pair interaction is rejected by Pangu2Token.
contract Pangu2LiquidityGateway is ReentrancyGuard, IERC721Receiver {
    using SafeERC20 for IERC20;

    struct AddLiquidityParams {
        uint256 tokenDesired;
        uint256 wbnbDesired;
        uint256 tokenMin;
        uint256 wbnbMin;
        int24 tickLower;
        int24 tickUpper;
        uint256 deadline;
    }

    struct RemoveLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 tokenMin;
        uint256 wbnbMin;
        uint256 deadline;
    }

    IPangu2Token public immutable token;
    IERC20 public immutable wbnb;
    IPancakeV3NonfungiblePositionManager public immutable positionManager;
    uint24 public immutable feeTier;
    bool public immutable tokenIsToken0;

    mapping(uint256 => address) public positionOwner;

    error ZeroAddress();
    error AddressHasNoCode(address account);
    error InvalidAmount();
    error InvalidDeadline();
    error InvalidTicks();
    error NotPositionOwner(uint256 tokenId, address caller);
    error UnexpectedNftOperator(address operator);

    event LiquidityAdded(
        address indexed account,
        uint256 indexed tokenId,
        uint128 liquidity,
        uint256 tokenUsed,
        uint256 wbnbUsed,
        uint256 tokenRefunded,
        uint256 wbnbRefunded
    );
    event LiquidityRemoved(
        address indexed account,
        uint256 indexed tokenId,
        uint128 liquidity,
        uint256 tokenReturned,
        uint256 wbnbReturned
    );
    event PositionOwnershipTransferred(
        uint256 indexed tokenId, address indexed previousOwner, address indexed newOwner
    );

    constructor(address token_, address wbnb_, address positionManager_, uint24 feeTier_) {
        _requireContract(token_);
        _requireContract(wbnb_);
        _requireContract(positionManager_);
        token = IPangu2Token(token_);
        wbnb = IERC20(wbnb_);
        positionManager = IPancakeV3NonfungiblePositionManager(positionManager_);
        feeTier = feeTier_;
        tokenIsToken0 = token_ < wbnb_;
    }

    function addLiquidity(AddLiquidityParams calldata params)
        external
        nonReentrant
        returns (uint256 tokenId, uint128 liquidity, uint256 tokenUsed, uint256 wbnbUsed)
    {
        if (params.tokenDesired == 0 || params.wbnbDesired == 0) revert InvalidAmount();
        if (params.deadline < block.timestamp) revert InvalidDeadline();
        if (params.tickLower >= params.tickUpper) revert InvalidTicks();

        IERC20(address(token)).safeTransferFrom(msg.sender, address(this), params.tokenDesired);
        wbnb.safeTransferFrom(msg.sender, address(this), params.wbnbDesired);
        IERC20(address(token)).forceApprove(address(positionManager), params.tokenDesired);
        wbnb.forceApprove(address(positionManager), params.wbnbDesired);

        IPancakeV3NonfungiblePositionManager.MintParams memory mintParams =
            IPancakeV3NonfungiblePositionManager.MintParams({
                token0: tokenIsToken0 ? address(token) : address(wbnb),
                token1: tokenIsToken0 ? address(wbnb) : address(token),
                fee: feeTier,
                tickLower: params.tickLower,
                tickUpper: params.tickUpper,
                amount0Desired: tokenIsToken0 ? params.tokenDesired : params.wbnbDesired,
                amount1Desired: tokenIsToken0 ? params.wbnbDesired : params.tokenDesired,
                amount0Min: tokenIsToken0 ? params.tokenMin : params.wbnbMin,
                amount1Min: tokenIsToken0 ? params.wbnbMin : params.tokenMin,
                recipient: address(this),
                deadline: params.deadline
            });

        uint256 amount0;
        uint256 amount1;
        (tokenId, liquidity, amount0, amount1) = positionManager.mint(mintParams);
        positionOwner[tokenId] = msg.sender;
        tokenUsed = tokenIsToken0 ? amount0 : amount1;
        wbnbUsed = tokenIsToken0 ? amount1 : amount0;

        IERC20(address(token)).forceApprove(address(positionManager), 0);
        wbnb.forceApprove(address(positionManager), 0);

        uint256 tokenRefund = params.tokenDesired - tokenUsed;
        uint256 wbnbRefund = params.wbnbDesired - wbnbUsed;
        if (tokenRefund != 0) {
            token.systemTransfer(msg.sender, tokenRefund, TransferContext.Kind.LIQUIDITY_WITHDRAWAL);
        }
        if (wbnbRefund != 0) wbnb.safeTransfer(msg.sender, wbnbRefund);

        emit LiquidityAdded(
            msg.sender, tokenId, liquidity, tokenUsed, wbnbUsed, tokenRefund, wbnbRefund
        );
    }

    function removeLiquidity(RemoveLiquidityParams calldata params)
        external
        nonReentrant
        returns (uint256 tokenReturned, uint256 wbnbReturned)
    {
        address owner = positionOwner[params.tokenId];
        if (owner != msg.sender) revert NotPositionOwner(params.tokenId, msg.sender);
        if (params.liquidity == 0) revert InvalidAmount();
        if (params.deadline < block.timestamp) revert InvalidDeadline();

        IPancakeV3NonfungiblePositionManager.DecreaseLiquidityParams memory decreaseParams =
            IPancakeV3NonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: params.tokenId,
                liquidity: params.liquidity,
                amount0Min: tokenIsToken0 ? params.tokenMin : params.wbnbMin,
                amount1Min: tokenIsToken0 ? params.wbnbMin : params.tokenMin,
                deadline: params.deadline
            });
        positionManager.decreaseLiquidity(decreaseParams);
        (tokenReturned, wbnbReturned) = _collectAndReturn(params.tokenId, msg.sender);
        emit LiquidityRemoved(
            msg.sender, params.tokenId, params.liquidity, tokenReturned, wbnbReturned
        );
    }

    function collectFees(uint256 tokenId)
        external
        nonReentrant
        returns (uint256 tokenReturned, uint256 wbnbReturned)
    {
        address owner = positionOwner[tokenId];
        if (owner != msg.sender) revert NotPositionOwner(tokenId, msg.sender);
        (tokenReturned, wbnbReturned) = _collectAndReturn(tokenId, msg.sender);
        emit LiquidityRemoved(msg.sender, tokenId, 0, tokenReturned, wbnbReturned);
    }

    function transferPositionOwnership(uint256 tokenId, address newOwner) external {
        address oldOwner = positionOwner[tokenId];
        if (oldOwner != msg.sender) revert NotPositionOwner(tokenId, msg.sender);
        if (newOwner == address(0)) revert ZeroAddress();
        positionOwner[tokenId] = newOwner;
        emit PositionOwnershipTransferred(tokenId, oldOwner, newOwner);
    }

    function onERC721Received(address operator, address, uint256, bytes calldata)
        external
        view
        override
        returns (bytes4)
    {
        if (msg.sender != address(positionManager) || operator != address(this)) {
            revert UnexpectedNftOperator(operator);
        }
        return IERC721Receiver.onERC721Received.selector;
    }

    function _collectAndReturn(uint256 tokenId, address account)
        private
        returns (uint256 tokenReturned, uint256 wbnbReturned)
    {
        uint256 tokenBefore = token.balanceOf(address(this));
        uint256 wbnbBefore = wbnb.balanceOf(address(this));
        positionManager.collect(
            IPancakeV3NonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );
        tokenReturned = token.balanceOf(address(this)) - tokenBefore;
        wbnbReturned = wbnb.balanceOf(address(this)) - wbnbBefore;
        if (tokenReturned != 0) {
            token.systemTransfer(account, tokenReturned, TransferContext.Kind.LIQUIDITY_WITHDRAWAL);
        }
        if (wbnbReturned != 0) wbnb.safeTransfer(account, wbnbReturned);
    }

    function _requireContract(address account) private view {
        if (account == address(0)) revert ZeroAddress();
        if (account.code.length == 0) revert AddressHasNoCode(account);
    }
}
