// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { FullMath } from "./libraries/FullMath.sol";
import { ICostBasisManager } from "./interfaces/ICostBasisManager.sol";
import { IFeeVault } from "./interfaces/IFeeVault.sol";
import { TransferContext } from "./libraries/TransferContext.sol";

contract Pangu2Token is ERC20, AccessControl, Pausable {
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant SETTLEMENT_ROLE = keccak256("SETTLEMENT_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UNPAUSER_ROLE = keccak256("UNPAUSER_ROLE");

    uint16 public constant BPS_DENOMINATOR = 10_000;
    uint16 public constant BUY_TAX_BPS = 400;
    uint16 public constant NORMAL_SELL_TAX_BPS = 400;
    uint16 public constant PROFIT_SELL_TAX_BPS = 1000;
    uint16 public constant PROFIT_SUPPORT_BPS = 900;
    uint16 public constant PROFIT_BURN_BPS = 100;
    uint256 public constant MIN_SELL_AMOUNT = 100;
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 ether;

    // ── Launch Protection (immutable — never modifiable by governance) ──
    uint32 public constant LAUNCH_PROTECTION_DURATION = 15 minutes;
    uint16 public constant LAUNCH_BUY_TAX_BPS = 3000;
    uint16 public constant LAUNCH_SELL_TAX_BPS = 3000;
    uint16 public constant LAUNCH_SUPPORT_BPS = 2900;
    uint16 public constant LAUNCH_BURN_BPS = 100;

    /// @notice Timestamp when trading was opened by governance.
    ///         Zero means trading has never been opened.
    uint40 public tradingOpenAt;

    ICostBasisManager public costBasisManager;
    IFeeVault public feeVault;
    bool public coreConfigured;

    mapping(address => bool) public isPair;
    mapping(address => bool) public isSystemAddress;
    mapping(address => bool) public isLiquidityManager;

    /// @notice Fee whitelist — addresses that pay 0% buy and sell tax.
    ///         Only real user addresses. NEVER add Router, Adapter, Pair,
    ///         or any system contract to this mapping.
    mapping(address => bool) public feeWhitelist;
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
    error TradingNotOpen();
    error TradingAlreadyOpen();
    error BatchTooLarge(uint256 count, uint256 max);
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
    event SystemTransferContextUpdated(address indexed account, TransferContext.Kind indexed kind, bool enabled);
    event TokensPurchased(
        address indexed buyer, uint256 amountIn, uint256 grossTokens, uint256 taxTokens, uint256 netTokens
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
    event TradingOpened(uint40 openedAt);
    event FeeWhitelistUpdated(address indexed account, bool enabled);

    constructor(address initialHolder, address governance, address emergencyAccount) ERC20("PANGU2", "PANGU2") {
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

    /// @notice Open trading — irreversibly sets the timestamp from which
    ///         the 15-minute launch protection window is measured.
    ///         Can only be called once while trading is not yet open.
    function setTradingOpenAt() external onlyRole(GOVERNANCE_ROLE) {
        if (tradingOpenAt != 0) revert TradingAlreadyOpen();
        tradingOpenAt = uint40(block.timestamp);
        emit TradingOpened(tradingOpenAt);
    }

    /// @notice True during the 15-minute high-tax launch protection window.
    function isInLaunchProtection() public view returns (bool) {
        uint40 opened = tradingOpenAt;
        return opened != 0 && block.timestamp < uint256(opened) + LAUNCH_PROTECTION_DURATION;
    }

    // ── Fee Whitelist ──

    uint256 public constant MAX_BATCH_WHITELIST = 50;

    function setFeeWhitelist(address account, bool enabled) external onlyRole(GOVERNANCE_ROLE) {
        if (account == address(0)) revert ZeroAddress();
        feeWhitelist[account] = enabled;
        emit FeeWhitelistUpdated(account, enabled);
    }

    function setFeeWhitelistBatch(address[] calldata accounts, bool enabled) external onlyRole(GOVERNANCE_ROLE) {
        uint256 len = accounts.length;
        if (len > MAX_BATCH_WHITELIST) revert BatchTooLarge(len, MAX_BATCH_WHITELIST);
        for (uint256 i = 0; i < len; ++i) {
            address account = accounts[i];
            if (account == address(0)) revert ZeroAddress();
            feeWhitelist[account] = enabled;
            emit FeeWhitelistUpdated(account, enabled);
        }
    }

    function setPair(address pair, bool enabled) external onlyRole(GOVERNANCE_ROLE) {
        _requireContract(pair);
        isPair[pair] = enabled;
        emit PairUpdated(pair, enabled);
    }

    function setSystemAddress(address account, bool enabled) external onlyRole(GOVERNANCE_ROLE) {
        if (enabled) {
            _requireContract(account);
        } else {
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
            kind != TransferContext.Kind.LIQUIDITY_WITHDRAWAL && kind != TransferContext.Kind.LIQUIDITY_FEE_COLLECTION
                && kind != TransferContext.Kind.DIVIDEND_CLAIM && kind != TransferContext.Kind.SYSTEM_CREDIT_UNKNOWN
                && kind != TransferContext.Kind.STAKING_DEPOSIT && kind != TransferContext.Kind.STAKING_PRINCIPAL_RETURN
                && kind != TransferContext.Kind.STAKING_REWARD
        ) revert InvalidTransferContext(kind);
        if (
            (kind == TransferContext.Kind.LIQUIDITY_WITHDRAWAL || kind == TransferContext.Kind.LIQUIDITY_FEE_COLLECTION)
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
            (kind == TransferContext.Kind.LIQUIDITY_WITHDRAWAL || kind == TransferContext.Kind.LIQUIDITY_FEE_COLLECTION)
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

    function previewBuyTax(uint256 grossAmount) public view returns (uint256 taxAmount, uint256 netAmount) {
        if (grossAmount == 0) revert InvalidAmount();
        uint16 rate = isInLaunchProtection() ? LAUNCH_BUY_TAX_BPS : BUY_TAX_BPS;
        taxAmount = _mulBpsRoundingUp(grossAmount, rate);
        if (taxAmount >= grossAmount) revert InvalidAmount();
        netAmount = grossAmount - taxAmount;
    }

    /// @notice Preview buy tax for a specific buyer — 0% if whitelisted.
    function previewBuyTaxFor(address buyer, uint256 grossAmount)
        public
        view
        returns (uint256 taxAmount, uint256 netAmount)
    {
        if (feeWhitelist[buyer]) return (0, grossAmount);
        return previewBuyTax(grossAmount);
    }

    /// @notice Authoritative buy tax rate for a buyer — single source of truth.
    ///         Reverts if trading has not yet been opened.
    function resolveBuyTaxBps(address buyer) public view returns (uint16) {
        if (tradingOpenAt == 0) revert TradingNotOpen();
        if (feeWhitelist[buyer]) return 0;
        if (isInLaunchProtection()) return LAUNCH_BUY_TAX_BPS;
        return BUY_TAX_BPS;
    }

    /// @notice Authoritative sell tax rate for a seller — single source of truth.
    ///         baseTaxBps is the cost-basis-derived rate (400 or 1000).
    ///         Reverts if trading has not yet been opened.
    function resolveSellTaxBps(address seller, uint16 baseTaxBps) public view returns (uint16) {
        if (tradingOpenAt == 0) revert TradingNotOpen();
        if (feeWhitelist[seller]) return 0;
        if (isInLaunchProtection()) return LAUNCH_SELL_TAX_BPS;
        return baseTaxBps;
    }

    function previewSellTax(uint256 sellAmount, uint16 taxBps)
        public
        view
        returns (uint256 supportAmount, uint256 burnAmount, uint256 swapAmount)
    {
        if (sellAmount < MIN_SELL_AMOUNT) revert InvalidAmount();

        // During launch protection: 29% support + 1% burn, caller's taxBps is ignored
        if (isInLaunchProtection()) {
            uint256 totalTax = _mulBpsRoundingUp(sellAmount, LAUNCH_SELL_TAX_BPS); // 30%
            burnAmount = (totalTax * LAUNCH_BURN_BPS) / LAUNCH_SELL_TAX_BPS; // 1/30 of tax = 1% of sell
            if (burnAmount == 0) burnAmount = 1;
            supportAmount = totalTax - burnAmount; // 29% of sell
            swapAmount = sellAmount - totalTax; // 70% of sell
            return (supportAmount, burnAmount, swapAmount);
        }

        // Normal period
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

    /// @notice Preview sell tax for a specific seller — 0% if whitelisted.
    function previewSellTaxFor(address seller, uint256 sellAmount, uint16 taxBps)
        public
        view
        returns (uint256 supportAmount, uint256 burnAmount, uint256 swapAmount)
    {
        if (feeWhitelist[seller]) return (0, 0, sellAmount);
        return previewSellTax(sellAmount, taxBps);
    }

    // ── Settlement ──

    function settleBuy(address buyer, uint256 grossAmount, uint256 costWbnbWei)
        external
        onlyRole(SETTLEMENT_ROLE)
        whenNotPaused
        returns (uint256 taxAmount, uint256 netAmount)
    {
        if (!coreConfigured) revert CoreNotConfigured();
        if (buyer == address(0)) revert ZeroAddress();
        if (grossAmount == 0 || costWbnbWei == 0) revert InvalidAmount();
        if (tradingOpenAt == 0) revert TradingNotOpen();
        (taxAmount, netAmount) = previewBuyTaxFor(buyer, grossAmount);
        _update(msg.sender, address(feeVault), taxAmount);
        _beginContext(msg.sender, TransferContext.Kind.BUY_SETTLEMENT);
        _update(msg.sender, buyer, netAmount);
        _endContext();
        feeVault.credit(IFeeVault.Bucket.DIVIDEND, taxAmount);
        costBasisManager.recordBuy(buyer, costWbnbWei, netAmount);
        emit TokensPurchased(buyer, costWbnbWei, grossAmount, taxAmount, netAmount);
    }

    function settleSell(address seller, uint256 sellAmount, uint16 taxBps)
        external
        onlyRole(SETTLEMENT_ROLE)
        whenNotPaused
        returns (uint256 supportAmount, uint256 burnAmount, uint256 swapAmount)
    {
        if (!coreConfigured) {
            revert CoreNotConfigured();
        }
        if (seller == address(0)) revert ZeroAddress();
        if (sellAmount == 0) revert InvalidAmount();
        if (tradingOpenAt == 0) revert TradingNotOpen();
        (supportAmount, burnAmount, swapAmount) = previewSellTaxFor(seller, sellAmount, taxBps);
        _update(msg.sender, address(feeVault), supportAmount);
        if (burnAmount != 0) {
            _burn(msg.sender, burnAmount);
            emit ProtocolBurn(msg.sender, burnAmount);
        }
        feeVault.credit(IFeeVault.Bucket.SUPPORT, supportAmount);
    }

    function emitSellSettlementAmountOut(address seller, uint256 tokenIn, uint16 taxBps, uint256 amountOut)
        external
        onlyRole(SETTLEMENT_ROLE)
    {
        if (seller == address(0)) revert ZeroAddress();
        if (tokenIn == 0) revert InvalidAmount();
        // taxBps validation happens inside previewSellTaxFor → previewSellTax
        (uint256 supportAmount, uint256 burnAmount, uint256 swapAmount) = previewSellTaxFor(seller, tokenIn, taxBps);
        emit TokensSold(seller, tokenIn, taxBps, supportAmount, burnAmount, swapAmount, amountOut);
    }

    // ── Staking Deposit ──

    /// Controlled staking deposit: pulls tokens from user to Staking contract.
    /// Only callable by a system address with STAKING_DEPOSIT context permission.
    function stakingDeposit(address from, uint256 amount) external whenNotPaused returns (bool) {
        if (!coreConfigured) revert CoreNotConfigured();
        if (from == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        if (
            !isSystemAddress[msg.sender]
                || !systemTransferContextAllowed[msg.sender][TransferContext.Kind.STAKING_DEPOSIT]
        ) {
            revert TransferContextNotAllowed(msg.sender, TransferContext.Kind.STAKING_DEPOSIT);
        }
        if (isSystemAddress[from] || isPair[from]) {
            revert DirectSystemInteractionForbidden(from, msg.sender, msg.sender);
        }
        _update(from, msg.sender, amount);
        return true;
    }

    // ── Pause ──

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(UNPAUSER_ROLE) {
        _unpause();
    }

    // ── Transfer hooks ──

    function _update(address from, address to, uint256 value) internal override {
        if (
            paused() && from != address(0) && to != address(0)
                && (isPair[from] || isPair[to] || isSystemAddress[from] || isSystemAddress[to])
        ) revert EnforcedPause();

        // Block unregistered contracts — prevents AMM pairs from being treated as
        // users and bypassing tax, burn, fee vault, and cost basis settlement.
        if (from != address(0) && from.code.length > 0 && !isSystemAddress[from] && !isPair[from]) {
            revert("unregistered contract sender");
        }
        if (to != address(0) && to.code.length > 0 && !isSystemAddress[to] && !isPair[to]) {
            revert("unregistered contract receiver");
        }

        bool liquidityDeposit;
        bool sellEntry;
        bool isStakingDeposit;
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
            } else if (msg.sender == to && systemTransferContextAllowed[to][TransferContext.Kind.STAKING_DEPOSIT]) {
                isStakingDeposit = true;
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
        } else if (isStakingDeposit) {
            costBasisManager.onStakingDeposit(from, value);
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
