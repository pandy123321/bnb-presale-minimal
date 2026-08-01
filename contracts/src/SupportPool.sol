// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWBNB} from "./interfaces/IPancakeV3.sol";
import {IPancakeV3Adapter} from "./interfaces/IPancakeV3Adapter.sol";
import {IPangu2TwapOracle} from "./interfaces/IPangu2TwapOracle.sol";
import {IBuybackLocker} from "./interfaces/IBuybackLocker.sol";
import {ISupportPool} from "./interfaces/ISupportPool.sol";

contract SupportPool is AccessControl, Pausable, ReentrancyGuard, ISupportPool {
    using SafeERC20 for IERC20;

    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UNPAUSER_ROLE = keccak256("UNPAUSER_ROLE");

    uint256 public constant override BUYBACK_AMOUNT = 0.01 ether;
    uint256 public constant override MIN_BUYBACK_INTERVAL = 60 seconds;
    uint16 public constant BPS_DENOMINATOR = 10_000;

    IERC20 public immutable token;
    IWBNB public immutable wbnb;
    IPancakeV3Adapter public immutable adapter;
    IPangu2TwapOracle public immutable oracle;
    uint16 public immutable maximumSlippageBps;
    uint32 public immutable quoteDeadlineWindow;

    address public feeVault;
    IBuybackLocker public locker;
    bool public feeVaultConfigured;
    bool public lockerConfigured;
    uint256 public lastSuccessfulBuybackAt;
    uint256 public buybackCount;

    error ZeroAddress();
    error AddressHasNoCode(address account);
    error InvalidConfiguration();
    error ConfigurationAlreadySet();
    error UnauthorizedNativeSender(address sender);
    error InsufficientNativeBalance(uint256 balance, uint256 required);
    error BuybackTooSoon(uint256 nextAllowedAt);
    error LockerNotConfigured();
    error InvalidOracleQuote(uint256 amountOut, uint256 minimumAmountOut);

    event FeeVaultConfigured(address indexed feeVault);
    event LockerConfigured(address indexed locker);
    event BuybackExecuted(
        uint256 indexed buybackId,
        address indexed trigger,
        uint256 bnbAmount,
        uint256 tokenAmount,
        address indexed locker,
        address pool,
        uint256 blockNumber
    );

    constructor(
        address token_,
        address wbnb_,
        address adapter_,
        address oracle_,
        uint16 maximumSlippageBps_,
        uint32 quoteDeadlineWindow_,
        address governance,
        address emergencyAccount
    ) {
        _requireContract(token_);
        _requireContract(wbnb_);
        _requireContract(adapter_);
        _requireContract(oracle_);
        if (
            maximumSlippageBps_ > 1_000 || quoteDeadlineWindow_ == 0 || quoteDeadlineWindow_ > 5 minutes
                || governance == address(0) || emergencyAccount == address(0)
        ) revert InvalidConfiguration();

        token = IERC20(token_);
        wbnb = IWBNB(wbnb_);
        adapter = IPancakeV3Adapter(adapter_);
        oracle = IPangu2TwapOracle(oracle_);
        maximumSlippageBps = maximumSlippageBps_;
        quoteDeadlineWindow = quoteDeadlineWindow_;

        _grantRole(DEFAULT_ADMIN_ROLE, governance);
        _grantRole(GOVERNANCE_ROLE, governance);
        _grantRole(PAUSER_ROLE, emergencyAccount);
        _grantRole(UNPAUSER_ROLE, governance);
        _setRoleAdmin(PAUSER_ROLE, GOVERNANCE_ROLE);
        _setRoleAdmin(UNPAUSER_ROLE, GOVERNANCE_ROLE);
    }

    receive() external payable {
        if (!feeVaultConfigured || msg.sender != feeVault) revert UnauthorizedNativeSender(msg.sender);
    }

    function configureFeeVault(address feeVault_) external onlyRole(GOVERNANCE_ROLE) {
        if (feeVaultConfigured) revert ConfigurationAlreadySet();
        _requireContract(feeVault_);
        feeVault = feeVault_;
        feeVaultConfigured = true;
        emit FeeVaultConfigured(feeVault_);
    }

    function configureLocker(address locker_) external onlyRole(GOVERNANCE_ROLE) {
        if (lockerConfigured) revert ConfigurationAlreadySet();
        _requireContract(locker_);
        locker = IBuybackLocker(locker_);
        lockerConfigured = true;
        emit LockerConfigured(locker_);
    }

    function canExecuteBuyback()
        public
        view
        override
        returns (bool allowed, BuybackBlockReason reason, uint256 poolBalance, uint256 nextAllowedAt)
    {
        poolBalance = address(this).balance;
        nextAllowedAt = lastSuccessfulBuybackAt == 0
            ? 0
            : lastSuccessfulBuybackAt + MIN_BUYBACK_INTERVAL;

        if (paused()) return (false, BuybackBlockReason.PAUSED, poolBalance, nextAllowedAt);
        if (!lockerConfigured) {
            return (false, BuybackBlockReason.LOCKER_NOT_CONFIGURED, poolBalance, nextAllowedAt);
        }
        if (poolBalance < BUYBACK_AMOUNT) {
            return (false, BuybackBlockReason.INSUFFICIENT_BNB, poolBalance, nextAllowedAt);
        }
        if (lastSuccessfulBuybackAt != 0 && block.timestamp < nextAllowedAt) {
            return (false, BuybackBlockReason.COOLDOWN, poolBalance, nextAllowedAt);
        }

        try oracle.validatedQuote(address(wbnb), address(token), uint128(BUYBACK_AMOUNT)) returns (
            IPangu2TwapOracle.Quote memory q
        ) {
            uint256 minTokenOut =
                (q.amountOut * (BPS_DENOMINATOR - maximumSlippageBps)) / BPS_DENOMINATOR;
            if (q.amountOut == 0 || minTokenOut == 0) {
                return (false, BuybackBlockReason.INVALID_QUOTE, poolBalance, nextAllowedAt);
            }
        } catch {
            return (false, BuybackBlockReason.ORACLE_UNAVAILABLE, poolBalance, nextAllowedAt);
        }

        return (true, BuybackBlockReason.NONE, poolBalance, nextAllowedAt);
    }

    function buyback() external override whenNotPaused nonReentrant returns (uint256 tokenOut) {
        if (!lockerConfigured) revert LockerNotConfigured();
        if (address(this).balance < BUYBACK_AMOUNT) {
            revert InsufficientNativeBalance(address(this).balance, BUYBACK_AMOUNT);
        }
        uint256 nextAllowedAt = lastSuccessfulBuybackAt + MIN_BUYBACK_INTERVAL;
        if (lastSuccessfulBuybackAt != 0 && block.timestamp < nextAllowedAt) revert BuybackTooSoon(nextAllowedAt);

        IPangu2TwapOracle.Quote memory q = oracle.validatedQuote(address(wbnb), address(token), uint128(BUYBACK_AMOUNT));
        uint256 minTokenOut = (q.amountOut * (BPS_DENOMINATOR - maximumSlippageBps)) / BPS_DENOMINATOR;
        if (q.amountOut == 0 || minTokenOut == 0) revert InvalidOracleQuote(q.amountOut, minTokenOut);

        wbnb.deposit{value: BUYBACK_AMOUNT}();
        IERC20(address(wbnb)).forceApprove(address(adapter), BUYBACK_AMOUNT);
        tokenOut = adapter.swapExactInput(
            address(wbnb),
            address(token),
            BUYBACK_AMOUNT,
            minTokenOut,
            address(locker),
            block.timestamp + quoteDeadlineWindow
        );
        IERC20(address(wbnb)).forceApprove(address(adapter), 0);

        uint256 buybackId = ++buybackCount;
        locker.registerBuyback(buybackId, tokenOut);
        lastSuccessfulBuybackAt = block.timestamp;
        emit BuybackExecuted(
            buybackId, msg.sender, BUYBACK_AMOUNT, tokenOut, address(locker), adapter.poolAddress(), block.number
        );
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(UNPAUSER_ROLE) {
        _unpause();
    }

    function _requireContract(address account) private view {
        if (account == address(0)) revert ZeroAddress();
        if (account.code.length == 0) revert AddressHasNoCode(account);
    }
}
