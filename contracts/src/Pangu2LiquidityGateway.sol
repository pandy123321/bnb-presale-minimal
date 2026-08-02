// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ICostBasisManager} from "./interfaces/ICostBasisManager.sol";
import {IPangu2Token} from "./interfaces/IPangu2Token.sol";
import {IPancakeV3NonfungiblePositionManager} from "./interfaces/IPancakeV3.sol";
import {TransferContext} from "./libraries/TransferContext.sol";

contract Pangu2LiquidityGateway is AccessControl, Pausable, ReentrancyGuard, IERC721Receiver {
    using SafeERC20 for IERC20;

    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UNPAUSER_ROLE = keccak256("UNPAUSER_ROLE");

    struct AddLiquidityParams {
        uint256 tokenDesired; uint256 wbnbDesired;
        uint256 tokenMin; uint256 wbnbMin;
        int24 tickLower; int24 tickUpper; uint256 deadline;
    }
    struct RemoveLiquidityParams {
        uint256 tokenId; uint128 liquidity;
        uint256 tokenMin; uint256 wbnbMin; uint256 deadline;
    }
    struct LpTokenInfo { uint256 tokenPrincipal; uint256 wbnbPrincipal; bool active; }

    IPangu2Token public immutable token;
    IERC20 public immutable wbnb;
    IPancakeV3NonfungiblePositionManager public immutable positionManager;
    ICostBasisManager public immutable costBasisManager;
    uint24 public immutable feeTier;
    bool public immutable tokenIsToken0;

    mapping(uint256 => address) public positionOwner;
    mapping(uint256 => LpTokenInfo) public lpInfo;

    error ZeroAddress(); error AddressHasNoCode(address account);
    error InvalidAmount(); error InvalidDeadline(); error InvalidTicks();
    error NotPositionOwner(uint256 tokenId, address caller);
    error UnexpectedNftOperator(address operator);

    event LiquidityAdded(address indexed account, uint256 indexed tokenId, uint128 liquidity, uint256 tokenUsed, uint256 wbnbUsed, uint256 tokenRefunded, uint256 wbnbRefunded);
    event LiquidityRemoved(address indexed account, uint256 indexed tokenId, uint128 liquidity, uint256 tokenReturned, uint256 wbnbReturned);
    event FeesCollected(address indexed account, uint256 indexed tokenId, uint256 tokenFees, uint256 wbnbFees);
    event PositionOwnershipTransferred(uint256 indexed tokenId, address indexed previousOwner, address indexed newOwner);

    constructor(address token_, address wbnb_, address positionManager_, address costBasisManager_, uint24 feeTier_, address governance, address emergencyAccount) {
        _requireContract(token_); _requireContract(wbnb_); _requireContract(positionManager_);
        _requireContract(costBasisManager_);
        if (governance == address(0) || emergencyAccount == address(0)) revert ZeroAddress();
        token = IPangu2Token(token_); wbnb = IERC20(wbnb_);
        positionManager = IPancakeV3NonfungiblePositionManager(positionManager_);
        costBasisManager = ICostBasisManager(costBasisManager_);
        feeTier = feeTier_; tokenIsToken0 = token_ < wbnb_;
        _grantRole(DEFAULT_ADMIN_ROLE, governance); _grantRole(GOVERNANCE_ROLE, governance);
        _grantRole(PAUSER_ROLE, emergencyAccount); _grantRole(UNPAUSER_ROLE, governance);
        _setRoleAdmin(PAUSER_ROLE, GOVERNANCE_ROLE); _setRoleAdmin(UNPAUSER_ROLE, GOVERNANCE_ROLE);
    }

    function pause() external onlyRole(PAUSER_ROLE) { _pause(); }
    function unpause() external onlyRole(UNPAUSER_ROLE) { _unpause(); }

    // ── Add Liquidity ──

    function addLiquidity(AddLiquidityParams calldata p)
        external whenNotPaused nonReentrant returns (uint256 tokenId, uint128 liquidity, uint256 tokenUsed, uint256 wbnbUsed)
    {
        if (p.tokenDesired == 0 || p.wbnbDesired == 0) revert InvalidAmount();
        if (p.deadline < block.timestamp) revert InvalidDeadline();
        if (p.tickLower >= p.tickUpper) revert InvalidTicks();

        IERC20(address(token)).safeTransferFrom(msg.sender, address(this), p.tokenDesired);
        wbnb.safeTransferFrom(msg.sender, address(this), p.wbnbDesired);
        IERC20(address(token)).forceApprove(address(positionManager), p.tokenDesired);
        wbnb.forceApprove(address(positionManager), p.wbnbDesired);

        IPancakeV3NonfungiblePositionManager.MintParams memory mp = IPancakeV3NonfungiblePositionManager.MintParams({
            token0: tokenIsToken0 ? address(token) : address(wbnb),
            token1: tokenIsToken0 ? address(wbnb) : address(token),
            fee: feeTier, tickLower: p.tickLower, tickUpper: p.tickUpper,
            amount0Desired: tokenIsToken0 ? p.tokenDesired : p.wbnbDesired,
            amount1Desired: tokenIsToken0 ? p.wbnbDesired : p.tokenDesired,
            amount0Min: tokenIsToken0 ? p.tokenMin : p.wbnbMin,
            amount1Min: tokenIsToken0 ? p.wbnbMin : p.tokenMin,
            recipient: address(this), deadline: p.deadline
        });

        uint256 a0; uint256 a1;
        (tokenId, liquidity, a0, a1) = positionManager.mint(mp);
        positionOwner[tokenId] = msg.sender;
        tokenUsed = tokenIsToken0 ? a0 : a1;
        wbnbUsed = tokenIsToken0 ? a1 : a0;
        lpInfo[tokenId] = LpTokenInfo({tokenPrincipal: tokenUsed, wbnbPrincipal: wbnbUsed, active: true});

        IERC20(address(token)).forceApprove(address(positionManager), 0);
        wbnb.forceApprove(address(positionManager), 0);

        // Bind per-tokenId LP cost — cost comes from user's PANGU cost (not WBNB)
        costBasisManager.bindLpTokenId(msg.sender, tokenId, tokenUsed, wbnbUsed);

        uint256 tRefund = p.tokenDesired - tokenUsed;
        uint256 wRefund = p.wbnbDesired - wbnbUsed;
        if (tRefund != 0) token.systemTransfer(msg.sender, tRefund, TransferContext.Kind.LIQUIDITY_WITHDRAWAL);
        if (wRefund != 0) wbnb.safeTransfer(msg.sender, wRefund);

        emit LiquidityAdded(msg.sender, tokenId, liquidity, tokenUsed, wbnbUsed, tRefund, wRefund);
    }

    // ── Remove Liquidity (principal) ──

    function removeLiquidity(RemoveLiquidityParams calldata p)
        external whenNotPaused nonReentrant returns (uint256 tokenPrincipal, uint256 wbnbPrincipal)
    {
        address owner = positionOwner[p.tokenId];
        if (owner != msg.sender) revert NotPositionOwner(p.tokenId, msg.sender);
        if (p.liquidity == 0) revert InvalidAmount();
        if (p.deadline < block.timestamp) revert InvalidDeadline();

        // decreaseLiquidity returns (amount0Principal, amount1Principal) — actual principal removed
        (uint256 a0Principal, uint256 a1Principal) = positionManager.decreaseLiquidity(
            IPancakeV3NonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: p.tokenId, liquidity: p.liquidity,
                amount0Min: tokenIsToken0 ? p.tokenMin : p.wbnbMin,
                amount1Min: tokenIsToken0 ? p.wbnbMin : p.tokenMin,
                deadline: p.deadline
            })
        );
        tokenPrincipal = tokenIsToken0 ? a0Principal : a1Principal;
        wbnbPrincipal = tokenIsToken0 ? a1Principal : a0Principal;

        // Collect to this contract — this includes principal + accumulated fees
        uint256 tCollected; uint256 wCollected;
        (tCollected, wCollected) = _collectOnly(p.tokenId);

        // Verify collected >= principal (fail closed on protocol error)
        if (tCollected < tokenPrincipal || wCollected < wbnbPrincipal) revert InvalidAmount();

        // Fees = collected - principal
        uint256 tokenFees = tCollected - tokenPrincipal;
        uint256 wbnbFees = wCollected - wbnbPrincipal;

        // Send PANGU principal with LIQUIDITY_WITHDRAWAL context (moves cost from LP to user)
        if (tokenPrincipal != 0) {
            token.systemTransfer(msg.sender, tokenPrincipal, TransferContext.Kind.LIQUIDITY_WITHDRAWAL);
        }
        // Send PANGU fees with LIQUIDITY_FEE_COLLECTION context (zero cost, never touches LP cost)
        if (tokenFees != 0) {
            token.systemTransfer(msg.sender, tokenFees, TransferContext.Kind.LIQUIDITY_FEE_COLLECTION);
        }
        if (wbnbPrincipal != 0) wbnb.safeTransfer(msg.sender, wbnbPrincipal);
        if (wbnbFees != 0) wbnb.safeTransfer(msg.sender, wbnbFees);

        // Check remaining liquidity — full exit clears per-tokenId tracking
        (,,,,,,, uint128 remainingLiquidity,,,,) = positionManager.positions(p.tokenId);

        if (remainingLiquidity == 0) {
            LpTokenInfo storage info = lpInfo[p.tokenId];
            costBasisManager.consumeLpTokenId(msg.sender, p.tokenId, tokenPrincipal);
            info.active = false;
        }

        emit LiquidityRemoved(msg.sender, p.tokenId, p.liquidity, tokenPrincipal, wbnbPrincipal);
    }

    // ── Collect Fees (P0 FIX: LIQUIDITY_FEE_COLLECTION context — ZERO COST) ──

    function collectFees(uint256 tokenId)
        external whenNotPaused nonReentrant returns (uint256 tokenFees, uint256 wbnbFees)
    {
        address owner = positionOwner[tokenId];
        if (owner != msg.sender) revert NotPositionOwner(tokenId, msg.sender);

        // Collect to this contract (no context yet — we send next)
        (tokenFees, wbnbFees) = _collectOnly(tokenId);

        // Send PANGU2 fees with LIQUIDITY_FEE_COLLECTION context (zero cost, never touches LP principal)
        if (tokenFees != 0) {
            token.systemTransfer(msg.sender, tokenFees, TransferContext.Kind.LIQUIDITY_FEE_COLLECTION);
        }
        if (wbnbFees != 0) wbnb.safeTransfer(msg.sender, wbnbFees);

        emit FeesCollected(msg.sender, tokenId, tokenFees, wbnbFees);
    }

    // ── Transfer Position Ownership ──

    function transferPositionOwnership(uint256 tokenId, address newOwner) external whenNotPaused {
        address oldOwner = positionOwner[tokenId];
        if (oldOwner != msg.sender) revert NotPositionOwner(tokenId, msg.sender);
        if (newOwner == address(0)) revert ZeroAddress();
        positionOwner[tokenId] = newOwner;

        if (lpInfo[tokenId].active) {
            costBasisManager.migrateLpCost(oldOwner, newOwner, tokenId);
        }
        emit PositionOwnershipTransferred(tokenId, oldOwner, newOwner);
    }

    function onERC721Received(address operator, address, uint256, bytes calldata) external view override returns (bytes4) {
        if (msg.sender != address(positionManager) || operator != address(this)) revert UnexpectedNftOperator(operator);
        return IERC721Receiver.onERC721Received.selector;
    }

    // ── Internal ──

    /// @dev Collect tokens+fees to this contract. Does NOT send to user.
    function _collectOnly(uint256 tokenId) private returns (uint256 tokenAmount, uint256 wbnbAmount) {
        uint256 tBefore = token.balanceOf(address(this));
        uint256 wBefore = wbnb.balanceOf(address(this));
        positionManager.collect(IPancakeV3NonfungiblePositionManager.CollectParams({
            tokenId: tokenId, recipient: address(this),
            amount0Max: type(uint128).max, amount1Max: type(uint128).max
        }));
        tokenAmount = token.balanceOf(address(this)) - tBefore;
        wbnbAmount = wbnb.balanceOf(address(this)) - wBefore;
    }

    function _requireContract(address a) private view {
        if (a == address(0)) revert ZeroAddress();
        if (a.code.length == 0) revert AddressHasNoCode(a);
    }
}
