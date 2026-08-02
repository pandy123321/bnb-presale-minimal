// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {FullMath} from "./libraries/FullMath.sol";
import {ICostBasisManager} from "./interfaces/ICostBasisManager.sol";
import {IFeeVault} from "./interfaces/IFeeVault.sol";
import {TransferContext} from "./libraries/TransferContext.sol";

contract Pangu2Token is ERC20, AccessControl, Pausable {

    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant SETTLEMENT_ROLE = keccak256("SETTLEMENT_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UNPAUSER_ROLE = keccak256("UNPAUSER_ROLE");

    uint16 public constant BPS_DENOMINATOR = 10_000;
    uint16 public constant BUY_TAX_BPS = 400;
    uint16 public constant NORMAL_SELL_TAX_BPS = 400;
    uint16 public constant PROFIT_SELL_TAX_BPS = 1_000;
    uint16 public constant PROFIT_SUPPORT_BPS = 900;
    uint16 public constant PROFIT_BURN_BPS = 100;
    uint256 public constant MIN_SELL_AMOUNT = 100;
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 ether;

    ICostBasisManager public costBasisManager;
    IFeeVault public feeVault;
    bool public coreConfigured;

    mapping(address => bool) public isPair;
    mapping(address => bool) public isSystemAddress;
    mapping(address => bool) public isLiquidityManager;
    mapping(address => mapping(TransferContext.Kind => bool)) public systemTransferContextAllowed;

    TransferContext.Kind private _activeContext;
    address private _activeContextOperator;

    error ZeroAddress();
    error AddressHasNoCode(address account);
    error CoreAlreadyConfigured();
    error CoreNotConfigured();
    error DirectPairInteractionForbidden(address from, address to, address operator);
    error DirectSystemInteractionForbidden(address from, address to, address operator);
    error UnsupportedTaxRate(uint16 taxBps);
    error InvalidAmount();
    error CoreSystemAddressImmutable(address account);
    error InvalidTransferContext(TransferContext.Kind kind);
    error TransferContextNotAllowed(address operator, TransferContext.Kind kind);
    error TransferContextActive();

    event CoreConfigured(address indexed costBasisManager, address indexed feeVault);
    event PairUpdated(address indexed pair, bool enabled);
    event SystemAddressUpdated(address indexed account, bool enabled);
    event LiquidityManagerUpdated(address indexed account, bool enabled);
    event LiquidityContextsRevoked(address indexed account);
    event SystemTransferContextUpdated(
        address indexed account, TransferContext.Kind indexed kind, bool enabled
    );
    event TokensPurchased(
        address indexed buyer,
        uint256 amountIn,
        uint256 grossTokens,
        uint256 taxTokens,
        uint256 netTokens
    );
    event TokensSold(
        address indexed seller,
        uint256 tokenIn,
        uint16 taxBps,
        uint256 supportTokens,
        uint256 burnTokens,
        uint256 swapTokens,
        uint256 amountOut
    );
    event ProtocolBurn(address indexed operator, uint256 amount);

    constructor(address initialHolder, address governance, address emergencyAccount)
        ERC20("PANGU2", "PANGU2")
    {
        if (initialHolder == address(0) || governance == address(0) || emergencyAccount == address(0)) {
            revert ZeroAddress();
        }
        _mint(initialHolder, INITIAL_SUPPLY);

        _grantRole(DEFAULT_ADMIN_ROLE, governance);
        _grantRole(GOVERNANCE_ROLE, governance);
        _grantRole(PAUSER_ROLE, emergencyAccount);
        _grantRole(UNPAUSER_ROLE, governance);
        _setRoleAdmin(SETTLEMENT_ROLE, GOVERNANCE_ROLE);
        _setRoleAdmin(PAUSER_ROLE, GOVERNANCE_ROLE);
        _setRoleAdmin(UNPAUSER_ROLE, GOVERNANCE_ROLE);
    }

    // ── One-time config ──

    function configureCore(address costBasisManager_, address feeVault_) external onlyRole(GOVERNANCE_ROLE) {
        if (coreConfigured) revert CoreAlreadyConfigured();
        _requireContract(costBasisManager_);
        _requireContract(feeVault_);
        costBasisManager = ICostBasisManager(costBasisManager_);
        feeVault = IFeeVault(feeVault_);
        coreConfigured = true;
        _setSystemAddress(costBasisManager_, true);
        _setSystemAddress(feeVault_, true);
        emit CoreConfigured(costBasisManager_, feeVault_);
    }

    // ── Governance setters ──

    function setPair(address pair, bool enabled) external onlyRole(GOVERNANCE_ROLE) {
        _requireContract(pair);
        isPair[pair] = enabled;
        emit PairUpdated(pair, enabled);
    }

    function setSystemAddress(address account, bool enabled) external onlyRole(GOVERNANCE_ROLE) {
        if (enabled) _requireContract(account);
        else {
            if (account == address(0)) revert ZeroAddress();
            if (coreConfigured && (account == address(costBasisManager) || account == address(feeVault))) {
                revert CoreSystemAddressImmutable(account);
            }
        }
        // Revoke: also clear any stale liquidity manager flag
        if (!enabled && isLiquidityManager[account]) {
            isLiquidityManager[account] = false;
            emit LiquidityManagerUpdated(account, false);
            // Clear all liquidity contexts for this account
            _revokeLiquidityContexts(account);
        }
        _setSystemAddress(account, enabled);
    }

    function setLiquidityManager(address account, bool enabled) external onlyRole(GOVERNANCE_ROLE) {
        if (enabled) _requireContract(account);
        else if (account == address(0)) revert ZeroAddress();
        isLiquidityManager[account] = enabled;
        _setSystemAddress(account, enabled);
        emit LiquidityManagerUpdated(account, enabled);
        // On revocation, clear all liquidity transfer contexts
        if (!enabled) {
            _revokeLiquidityContexts(account);
        }
    }

    function setSystemTransferContext(address account, TransferContext.Kind kind, bool enabled)
        external
        onlyRole(GOVERNANCE_ROLE)
    {
        if (!isSystemAddress[account]) revert DirectSystemInteractionForbidden(account, account, msg.sender);
        if (
            kind != TransferContext.Kind.LIQUIDITY_WITHDRAWAL
                && kind != TransferContext.Kind.LIQUIDITY_FEE_COLLECTION
                && kind != TransferContext.Kind.DIVIDEND_CLAIM
                && kind != TransferContext.Kind.SYSTEM_CREDIT_UNKNOWN
        ) revert InvalidTransferContext(kind);
        if (
            (kind == TransferContext.Kind.LIQUIDITY_WITHDRAWAL
                || kind == TransferContext.Kind.LIQUIDITY_FEE_COLLECTION)
            && !isLiquidityManager[account]
        ) {
            revert TransferContextNotAllowed(account, kind);
        }
        systemTransferContextAllowed[account][kind] = enabled;
        emit SystemTransferContextUpdated(account, kind, enabled);
    }

    // ── System transfer (only callable by system contracts with context permission) ──

    function systemTransfer(address to, uint256 amount, TransferContext.Kind kind)
        external
        whenNotPaused
        returns (bool)
    {
        if (!coreConfigured) revert CoreNotConfigured();
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();

        // Re-check role at execution time, not just at grant time
        if (
            (kind == TransferContext.Kind.LIQUIDITY_WITHDRAWAL
                || kind == TransferContext.Kind.LIQUIDITY_FEE_COLLECTION)
            && !isLiquidityManager[msg.sender]
        ) revert TransferContextNotAllowed(msg.sender, kind);

        if (!isSystemAddress[msg.sender] || !systemTransferContextAllowed[msg.sender][kind]) {
            revert TransferContextNotAllowed(msg.sender, kind);
        }
        if (isSystemAddress[to] || isPair[to]) {
            revert DirectSystemInteractionForbidden(msg.sender, to, msg.sender);
        }
        _beginContext(msg.sender, kind);
        _update(msg.sender, to, amount);
        _endContext();
        return true;
    }

    // ── Tax preview ──

    function previewBuyTax(uint256 grossAmount) public pure returns (uint256 taxAmount, uint256 netAmount) {
        if (grossAmount == 0) revert InvalidAmount();
        taxAmount = _mulBpsRoundingUp(grossAmount, BUY_TAX_BPS);
        if (taxAmount >= grossAmount) revert InvalidAmount();
        netAmount = grossAmount - taxAmount;
    }

    function previewSellTax(uint256 sellAmount, uint16 taxBps)
        public pure returns (uint256 supportAmount, uint256 burnAmount, uint256 swapAmount)
    {
        if (sellAmount < MIN_SELL_AMOUNT) revert InvalidAmount();
        if (taxBps != NORMAL_SELL_TAX_BPS && taxBps != PROFIT_SELL_TAX_BPS) revert UnsupportedTaxRate(taxBps);
        if (taxBps == NORMAL_SELL_TAX_BPS) {
            supportAmount = _mulBpsRoundingUp(sellAmount, NORMAL_SELL_TAX_BPS);
        } else {
            uint256 totalTax = _mulBpsRoundingUp(sellAmount, PROFIT_SELL_TAX_BPS);
            burnAmount = (totalTax * PROFIT_BURN_BPS) / PROFIT_SELL_TAX_BPS;
            if (burnAmount == 0) burnAmount = 1;
            supportAmount = totalTax - burnAmount;
        }
        swapAmount = sellAmount - supportAmount - burnAmount;
    }

    // ── Settlement ──

    function settleBuy(address buyer, uint256 grossAmount, uint256 costWbnbWei)
        external onlyRole(SETTLEMENT_ROLE) whenNotPaused returns (uint256 taxAmount, uint256 netAmount)
    {
        if (!coreConfigured) revert CoreNotConfigured();
        if (buyer == address(0)) revert ZeroAddress();
        if (grossAmount == 0 || costWbnbWei == 0) revert InvalidAmount();
        (taxAmount, netAmount) = previewBuyTax(grossAmount);
        _update(msg.sender, address(feeVault), taxAmount);
        _beginContext(msg.sender, TransferContext.Kind.BUY_SETTLEMENT);
        _update(msg.sender, buyer, netAmount);
        _endContext();
        feeVault.credit(IFeeVault.Bucket.DIVIDEND, taxAmount);
        costBasisManager.recordBuy(buyer, costWbnbWei, netAmount);
        emit TokensPurchased(buyer, costWbnbWei, grossAmount, taxAmount, netAmount);
    }

    function settleSell(address seller, uint256 sellAmount, uint16 taxBps)
        external onlyRole(SETTLEMENT_ROLE) whenNotPaused returns (uint256 supportAmount, uint256 burnAmount, uint256 swapAmount)
    {
        if (!coreConfigured) revert CoreNotConfigured();
        if (seller == address(0)) revert ZeroAddress();
        if (sellAmount == 0) revert InvalidAmount();
        if (taxBps != NORMAL_SELL_TAX_BPS && taxBps != PROFIT_SELL_TAX_BPS) revert UnsupportedTaxRate(taxBps);
        (supportAmount, burnAmount, swapAmount) = previewSellTax(sellAmount, taxBps);
        _update(msg.sender, address(feeVault), supportAmount);
        if (burnAmount != 0) { _burn(msg.sender, burnAmount); emit ProtocolBurn(msg.sender, burnAmount); }
        feeVault.credit(IFeeVault.Bucket.SUPPORT, supportAmount);
    }

    function emitSellSettlementAmountOut(address seller, uint256 tokenIn, uint16 taxBps, uint256 amountOut)
        external onlyRole(SETTLEMENT_ROLE)
    {
        if (seller == address(0)) revert ZeroAddress();
        if (tokenIn == 0) revert InvalidAmount();
        if (taxBps != NORMAL_SELL_TAX_BPS && taxBps != PROFIT_SELL_TAX_BPS) revert UnsupportedTaxRate(taxBps);
        (uint256 supportAmount, uint256 burnAmount, uint256 swapAmount) = previewSellTax(tokenIn, taxBps);
        emit TokensSold(seller, tokenIn, taxBps, supportAmount, burnAmount, swapAmount, amountOut);
    }

    // ── Pause ──

    function pause() external onlyRole(PAUSER_ROLE) { _pause(); }
    function unpause() external onlyRole(UNPAUSER_ROLE) { _unpause(); }

    // ── Transfer hooks ──

    function _update(address from, address to, uint256 value) internal override {
        if (
            paused() && from != address(0) && to != address(0)
                && (isPair[from] || isPair[to] || isSystemAddress[from] || isSystemAddress[to])
        ) revert EnforcedPause();

        bool liquidityDeposit;
        bool sellEntry;
        bool fromUser = _isUser(from);
        bool toUser = _isUser(to);

        if (from != address(0) && to != address(0) && (isPair[from] || isPair[to])) {
            if (fromUser && isPair[to] && isLiquidityManager[msg.sender]) {
                liquidityDeposit = true;
            } else if (isPair[from] && toUser) {
                revert DirectPairInteractionForbidden(from, to, msg.sender);
            } else if (!((isPair[from] && isSystemAddress[to]) || (isPair[to] && isSystemAddress[from]))) {
                revert DirectPairInteractionForbidden(from, to, msg.sender);
            }
        }

        if (fromUser && isSystemAddress[to] && !isPair[to]) {
            if (isLiquidityManager[to] && msg.sender == to) {
                liquidityDeposit = true;
            } else if (hasRole(SETTLEMENT_ROLE, to) && msg.sender == to) {
                sellEntry = true;
            } else {
                revert DirectSystemInteractionForbidden(from, to, msg.sender);
            }
        }

        if (isSystemAddress[from] && toUser) {
            if (_activeContext == TransferContext.Kind.NONE || _activeContextOperator != from || msg.sender != from) {
                revert DirectSystemInteractionForbidden(from, to, msg.sender);
            }
        }

        super._update(from, to, value);

        if (!coreConfigured || value == 0 || from == address(0) || to == address(0)) return;

        if (liquidityDeposit) {
            costBasisManager.onLiquidityDeposit(from, value);
        } else if (_activeContext == TransferContext.Kind.LIQUIDITY_WITHDRAWAL) {
            costBasisManager.onLiquidityWithdrawal(to, value);
        } else if (_activeContext == TransferContext.Kind.LIQUIDITY_FEE_COLLECTION) {
            costBasisManager.onLiquidityFeeCollection(to, value);
        } else if (_activeContext == TransferContext.Kind.SYSTEM_CREDIT_UNKNOWN) {
            costBasisManager.onSystemCreditUnknown(to, value, keccak256("SYSTEM_CREDIT_UNKNOWN"));
        } else if (fromUser && toUser) {
            costBasisManager.onUserTransfer(from, to, value);
        }
    }

    function _isUser(address account) private view returns (bool) {
        return account != address(0) && !isPair[account] && !isSystemAddress[account];
    }

    function _beginContext(address operator, TransferContext.Kind kind) private {
        if (_activeContext != TransferContext.Kind.NONE) revert TransferContextActive();
        _activeContextOperator = operator;
        _activeContext = kind;
    }

    function _endContext() private {
        _activeContext = TransferContext.Kind.NONE;
        _activeContextOperator = address(0);
    }

    function _mulBpsRoundingUp(uint256 amount, uint16 bps) private pure returns (uint256) {
        return FullMath.mulDivRoundingUp(amount, bps, BPS_DENOMINATOR);
    }

    function _setSystemAddress(address account, bool enabled) private {
        isSystemAddress[account] = enabled;
        if (coreConfigured && account != address(costBasisManager)) {
            costBasisManager.setSystemAddress(account, enabled);
        }
        emit SystemAddressUpdated(account, enabled);
    }

    function _revokeLiquidityContexts(address account) private {
        systemTransferContextAllowed[account][TransferContext.Kind.LIQUIDITY_WITHDRAWAL] = false;
        systemTransferContextAllowed[account][TransferContext.Kind.LIQUIDITY_FEE_COLLECTION] = false;
        emit LiquidityContextsRevoked(account);
    }

    function _requireContract(address account) private view {
        if (account == address(0)) revert ZeroAddress();
        if (account.code.length == 0) revert AddressHasNoCode(account);
    }
}
