// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWBNB} from "./interfaces/IPancakeV2.sol";
import {IPangu2Token} from "./interfaces/IPangu2Token.sol";
import {ICostBasisManager} from "./interfaces/ICostBasisManager.sol";
import {IPancakeV2Adapter} from "./interfaces/IPancakeV2Adapter.sol";
import {IPangu2TwapOracle} from "./interfaces/IPangu2TwapOracle.sol";
import {FullMath} from "./libraries/FullMath.sol";

contract Pangu2TradeRouter is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UNPAUSER_ROLE = keccak256("UNPAUSER_ROLE");

    uint16 public constant BPS_DENOMINATOR = 10_000;
    uint32 public constant MAXIMUM_DEADLINE_WINDOW = 5 minutes;

    IPangu2Token public immutable token;
    IWBNB public immutable wbnb;
    ICostBasisManager public immutable costBasisManager;
    IPancakeV2Adapter public immutable adapter;
    IPangu2TwapOracle public immutable oracle;

    struct BuyPreview {
        uint256 amountIn;
        uint256 grossTokens;
        uint256 taxTokens;
        uint256 netTokens;
        uint256 quoteBlock;
        uint256 expiresAt;
    }

    struct SellPreview {
        uint256 tokenIn;
        uint256 proportionalCostWbnbWei;
        uint256 preTaxTwapValueWbnbWei;
        uint16 taxBps;
        uint256 supportTokens;
        uint256 burnTokens;
        uint256 swapTokens;
        uint256 estimatedWbnbOut;
        ICostBasisManager.PositionStatus costStatus;
        int24 arithmeticMeanTick;
        int24 spotTick;
        uint128 harmonicMeanLiquidity;
        uint256 quoteBlock;
        uint256 expiresAt;
    }

    error ZeroAddress();
    error AddressHasNoCode(address account);
    error InvalidAmount();
    error InvalidDeadline(uint256 deadline);
    error NativeTransferFailed();
    error UnauthorizedNativeSender(address sender);
    error AmountExceedsUint128();

    event BuyExecuted(
        address indexed buyer,
        uint256 bnbIn,
        uint256 grossTokens,
        uint256 taxTokens,
        uint256 netTokens,
        uint256 quoteBlock
    );
    event SellExecuted(
        address indexed seller,
        uint256 tokenIn,
        uint16 taxBps,
        uint256 supportTokens,
        uint256 burnTokens,
        uint256 swapTokens,
        uint256 bnbOut,
        uint256 quoteBlock
    );

    constructor(
        address token_,
        address wbnb_,
        address costBasisManager_,
        address adapter_,
        address oracle_,
        address governance,
        address emergencyAccount
    ) {
        _requireContract(token_);
        _requireContract(wbnb_);
        _requireContract(costBasisManager_);
        _requireContract(adapter_);
        _requireContract(oracle_);
        if (governance == address(0) || emergencyAccount == address(0)) revert ZeroAddress();

        token = IPangu2Token(token_);
        wbnb = IWBNB(wbnb_);
        costBasisManager = ICostBasisManager(costBasisManager_);
        adapter = IPancakeV2Adapter(adapter_);
        oracle = IPangu2TwapOracle(oracle_);

        _grantRole(DEFAULT_ADMIN_ROLE, governance);
        _grantRole(GOVERNANCE_ROLE, governance);
        _grantRole(PAUSER_ROLE, emergencyAccount);
        _grantRole(UNPAUSER_ROLE, governance);
        _setRoleAdmin(PAUSER_ROLE, GOVERNANCE_ROLE);
        _setRoleAdmin(UNPAUSER_ROLE, GOVERNANCE_ROLE);
    }

    receive() external payable {
        if (msg.sender != address(wbnb)) revert UnauthorizedNativeSender(msg.sender);
    }

    function previewBuy(uint256 bnbAmount) external view returns (BuyPreview memory preview) {
        return _previewBuy(address(0), bnbAmount);
    }

    function previewSell(address seller, uint256 tokenAmount) external view returns (SellPreview memory) {
        return _previewSell(seller, tokenAmount);
    }

    function buy(uint256 minimumNetTokens, uint256 deadline)
        external
        payable
        whenNotPaused
        nonReentrant
        returns (uint256 netTokens)
    {
        if (msg.value == 0 || minimumNetTokens == 0) revert InvalidAmount();
        _validateDeadline(deadline);

        BuyPreview memory p = _previewBuy(msg.sender, msg.value);
        uint256 minimumGrossTokens = FullMath.mulDivRoundingUp(
            minimumNetTokens, BPS_DENOMINATOR, BPS_DENOMINATOR - token.BUY_TAX_BPS()
        );

        wbnb.deposit{value: msg.value}();
        IERC20(address(wbnb)).forceApprove(address(adapter), msg.value);
        uint256 grossTokens = adapter.swapExactInput(
            address(wbnb), address(token), msg.value, minimumGrossTokens, address(this), deadline
        );
        IERC20(address(wbnb)).forceApprove(address(adapter), 0);

        (uint256 taxTokens, uint256 settledNetTokens) = token.settleBuy(msg.sender, grossTokens, msg.value);
        if (settledNetTokens < minimumNetTokens) revert InvalidAmount();
        netTokens = settledNetTokens;
        emit BuyExecuted(msg.sender, msg.value, grossTokens, taxTokens, netTokens, p.quoteBlock);
    }

    function sell(uint256 tokenAmount, uint256 minimumBnbOut, uint256 deadline)
        external
        whenNotPaused
        nonReentrant
        returns (uint256 bnbOut)
    {
        if (tokenAmount == 0 || minimumBnbOut == 0) revert InvalidAmount();
        _validateDeadline(deadline);

        SellPreview memory p = _previewSell(msg.sender, tokenAmount);
        IERC20(address(token)).safeTransferFrom(msg.sender, address(this), tokenAmount);
        costBasisManager.consumeSell(msg.sender, tokenAmount);
        (uint256 supportTokens, uint256 burnTokens, uint256 swapTokens) =
            token.settleSell(msg.sender, tokenAmount, p.taxBps);

        if (swapTokens > type(uint128).max) revert AmountExceedsUint128();
        IERC20(address(token)).forceApprove(address(adapter), swapTokens);
        uint256 wbnbOut = adapter.swapExactInput(
            address(token), address(wbnb), swapTokens, minimumBnbOut, address(this), deadline
        );
        IERC20(address(token)).forceApprove(address(adapter), 0);

        wbnb.withdraw(wbnbOut);
        (bool ok,) = payable(msg.sender).call{value: wbnbOut}("");
        if (!ok) revert NativeTransferFailed();
        bnbOut = wbnbOut;
        token.emitSellSettlementAmountOut(msg.sender, tokenAmount, p.taxBps, bnbOut);
        emit SellExecuted(
            msg.sender,
            tokenAmount,
            p.taxBps,
            supportTokens,
            burnTokens,
            swapTokens,
            bnbOut,
            p.quoteBlock
        );
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(UNPAUSER_ROLE) {
        _unpause();
    }


    function _previewBuy(address buyer, uint256 bnbAmount) private view returns (BuyPreview memory preview) {
        if (bnbAmount == 0) revert InvalidAmount();
        if (bnbAmount > type(uint128).max) revert AmountExceedsUint128();
        IPangu2TwapOracle.Quote memory q =
            oracle.validatedQuote(address(wbnb), address(token), uint128(bnbAmount));
        uint256 grossTokens = q.amountOut;
        (uint256 taxTokens, uint256 netTokens) = buyer != address(0)
            ? token.previewBuyTaxFor(buyer, grossTokens)
            : token.previewBuyTax(grossTokens);
        preview = BuyPreview({
            amountIn: bnbAmount,
            grossTokens: grossTokens,
            taxTokens: taxTokens,
            netTokens: netTokens,
            quoteBlock: q.observedAtBlock,
            expiresAt: block.timestamp + MAXIMUM_DEADLINE_WINDOW
        });
    }

    function _previewSell(address seller, uint256 tokenAmount) private view returns (SellPreview memory p) {
        if (seller == address(0)) revert ZeroAddress();
        if (tokenAmount == 0) revert InvalidAmount();
        if (tokenAmount > type(uint128).max) revert AmountExceedsUint128();

        (uint256 proportionalCost, ICostBasisManager.PositionStatus status) =
            costBasisManager.proportionalCost(seller, tokenAmount);
        IPangu2TwapOracle.Quote memory twap =
            oracle.validatedQuote(address(token), address(wbnb), uint128(tokenAmount));

        uint16 taxBps = status == ICostBasisManager.PositionStatus.KNOWN && twap.amountOut <= proportionalCost
            ? token.NORMAL_SELL_TAX_BPS()
            : token.PROFIT_SELL_TAX_BPS();
        (uint256 supportTokens, uint256 burnTokens, uint256 swapTokens) =
            token.previewSellTaxFor(seller, tokenAmount, taxBps);
        if (swapTokens > type(uint128).max) revert AmountExceedsUint128();
        IPangu2TwapOracle.Quote memory postTaxQuote =
            oracle.validatedQuote(address(token), address(wbnb), uint128(swapTokens));

        p = SellPreview({
            tokenIn: tokenAmount,
            proportionalCostWbnbWei: proportionalCost,
            preTaxTwapValueWbnbWei: twap.amountOut,
            taxBps: taxBps,
            supportTokens: supportTokens,
            burnTokens: burnTokens,
            swapTokens: swapTokens,
            estimatedWbnbOut: postTaxQuote.amountOut,
            costStatus: status,
            arithmeticMeanTick: twap.arithmeticMeanTick,
            spotTick: twap.spotTick,
            harmonicMeanLiquidity: twap.harmonicMeanLiquidity,
            quoteBlock: twap.observedAtBlock,
            expiresAt: block.timestamp + MAXIMUM_DEADLINE_WINDOW
        });
    }

    function _validateDeadline(uint256 deadline) private view {
        if (deadline < block.timestamp || deadline > block.timestamp + MAXIMUM_DEADLINE_WINDOW) {
            revert InvalidDeadline(deadline);
        }
    }

    function _requireContract(address account) private view {
        if (account == address(0)) revert ZeroAddress();
        if (account.code.length == 0) revert AddressHasNoCode(account);
    }
}
