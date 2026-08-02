// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWBNB} from "./interfaces/IPancakeV2.sol";
import {IFeeVault} from "./interfaces/IFeeVault.sol";
import {IPancakeV2Adapter} from "./interfaces/IPancakeV2Adapter.sol";
import {IPangu2TwapOracle} from "./interfaces/IPangu2TwapOracle.sol";

contract FeeVault is AccessControl, Pausable, ReentrancyGuard, IFeeVault {
    using SafeERC20 for IERC20;

    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UNPAUSER_ROLE = keccak256("UNPAUSER_ROLE");

    IERC20 public immutable token;
    IWBNB public immutable wbnb;
    uint16 public constant BPS_DENOMINATOR = 10_000;
    uint32 public constant MAXIMUM_DEADLINE_WINDOW = 5 minutes;

    IPancakeV2Adapter public immutable adapter;
    IPangu2TwapOracle public immutable oracle;
    address payable public immutable supportPool;
    uint256 public immutable maximumConversionAmount;
    uint16 public immutable maximumSlippageBps;

    address public dividendDistributor;
    bool public dividendDistributorConfigured;
    uint256 private _dividendBalance;
    uint256 private _supportBalance;

    error ZeroAddress();
    error AddressHasNoCode(address account);
    error InvalidAmount();
    error InsufficientBucketBalance(Bucket bucket, uint256 requested, uint256 available);
    error AccountingMismatch(uint256 actualBalance, uint256 accountedBalance);
    error DistributorAlreadyConfigured();
    error NativeTransferFailed();
    error UnauthorizedNativeSender();
    error InvalidDeadline(uint256 deadline);
    error UnauthorizedTokenHook(address caller);

    event FeeBucketCredited(Bucket indexed bucket, uint256 tokenAmount, uint256 newBucketBalance);
    event FeesConverted(
        Bucket indexed bucket,
        address indexed tokenIn,
        uint256 tokenAmount,
        uint256 bnbAmount,
        address indexed recipient,
        uint256 quoteBlock
    );
    event DividendDistributorConfigured(address indexed distributor);
    event DividendFunded(address indexed distributor, uint256 amount, uint256 remainingDividendBucket);

    constructor(
        address token_,
        address wbnb_,
        address adapter_,
        address oracle_,
        address payable supportPool_,
        uint256 maximumConversionAmount_,
        uint16 maximumSlippageBps_,
        address governance,
        address keeper,
        address emergencyAccount
    ) {
        _requireContract(token_);
        _requireContract(wbnb_);
        _requireContract(adapter_);
        _requireContract(oracle_);
        _requireContract(supportPool_);
        if (
            maximumConversionAmount_ == 0 || maximumSlippageBps_ > 1_000 || governance == address(0)
                || keeper == address(0)
                || emergencyAccount == address(0)
        ) revert InvalidAmount();

        token = IERC20(token_);
        wbnb = IWBNB(wbnb_);
        adapter = IPancakeV2Adapter(adapter_);
        oracle = IPangu2TwapOracle(oracle_);
        supportPool = supportPool_;
        maximumConversionAmount = maximumConversionAmount_;
        maximumSlippageBps = maximumSlippageBps_;

        _grantRole(DEFAULT_ADMIN_ROLE, governance);
        _grantRole(GOVERNANCE_ROLE, governance);
        _grantRole(KEEPER_ROLE, keeper);
        _grantRole(PAUSER_ROLE, emergencyAccount);
        _grantRole(UNPAUSER_ROLE, governance);
        _setRoleAdmin(KEEPER_ROLE, GOVERNANCE_ROLE);
        _setRoleAdmin(PAUSER_ROLE, GOVERNANCE_ROLE);
        _setRoleAdmin(UNPAUSER_ROLE, GOVERNANCE_ROLE);
    }

    receive() external payable {
        if (msg.sender != address(wbnb)) revert UnauthorizedNativeSender();
    }

    function dividendBalance() external view override returns (uint256) {
        return _dividendBalance;
    }

    function supportBalance() external view override returns (uint256) {
        return _supportBalance;
    }

    function totalAccounted() public view returns (uint256) {
        return _dividendBalance + _supportBalance;
    }

    function surplus() external view returns (uint256) {
        uint256 actual = token.balanceOf(address(this));
        uint256 accounted = totalAccounted();
        return actual > accounted ? actual - accounted : 0;
    }

    function credit(Bucket bucket, uint256 tokenAmount) external override {
        if (msg.sender != address(token)) revert UnauthorizedTokenHook(msg.sender);
        if (tokenAmount == 0) revert InvalidAmount();
        if (bucket == Bucket.DIVIDEND) _dividendBalance += tokenAmount;
        else _supportBalance += tokenAmount;
        _assertSolvent();
        emit FeeBucketCredited(bucket, tokenAmount, bucket == Bucket.DIVIDEND ? _dividendBalance : _supportBalance);
    }

    function configureDividendDistributor(address distributor) external onlyRole(GOVERNANCE_ROLE) {
        if (dividendDistributorConfigured) revert DistributorAlreadyConfigured();
        _requireContract(distributor);
        dividendDistributor = distributor;
        dividendDistributorConfigured = true;
        emit DividendDistributorConfigured(distributor);
    }

    function fundDividendDistributor(uint256 amount)
        external
        onlyRole(GOVERNANCE_ROLE)
        whenNotPaused
        nonReentrant
    {
        if (!dividendDistributorConfigured) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        if (amount > _dividendBalance) {
            revert InsufficientBucketBalance(Bucket.DIVIDEND, amount, _dividendBalance);
        }
        _dividendBalance -= amount;
        token.safeTransfer(dividendDistributor, amount);
        _assertSolvent();
        emit DividendFunded(dividendDistributor, amount, _dividendBalance);
    }

    function convertSupport(uint256 tokenAmount, uint256 minWbnbOut, uint256 deadline)
        external
        override
        onlyRole(KEEPER_ROLE)
        whenNotPaused
        nonReentrant
        returns (uint256 wbnbOut)
    {
        if (tokenAmount == 0 || tokenAmount > maximumConversionAmount) revert InvalidAmount();
        if (deadline < block.timestamp || deadline > block.timestamp + MAXIMUM_DEADLINE_WINDOW) {
            revert InvalidDeadline(deadline);
        }
        if (tokenAmount > _supportBalance) {
            revert InsufficientBucketBalance(Bucket.SUPPORT, tokenAmount, _supportBalance);
        }

        if (tokenAmount > type(uint128).max) revert InvalidAmount();
        IPangu2TwapOracle.Quote memory q =
            oracle.validatedQuote(address(token), address(wbnb), uint128(tokenAmount));
        uint256 protocolMinimumWbnbOut =
            (q.amountOut * (BPS_DENOMINATOR - maximumSlippageBps)) / BPS_DENOMINATOR;
        uint256 effectiveMinimumWbnbOut =
            minWbnbOut > protocolMinimumWbnbOut ? minWbnbOut : protocolMinimumWbnbOut;

        _supportBalance -= tokenAmount;
        token.forceApprove(address(adapter), tokenAmount);
        wbnbOut = adapter.swapExactInput(
            address(token), address(wbnb), tokenAmount, effectiveMinimumWbnbOut, address(this), deadline
        );
        token.forceApprove(address(adapter), 0);

        wbnb.withdraw(wbnbOut);
        (bool ok,) = supportPool.call{value: wbnbOut}("");
        if (!ok) revert NativeTransferFailed();
        _assertSolvent();
        emit FeesConverted(
            Bucket.SUPPORT, address(token), tokenAmount, wbnbOut, supportPool, q.observedAtBlock
        );
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(UNPAUSER_ROLE) {
        _unpause();
    }

    function _assertSolvent() private view {
        uint256 actual = token.balanceOf(address(this));
        uint256 accounted = totalAccounted();
        if (actual < accounted) revert AccountingMismatch(actual, accounted);
    }

    function _requireContract(address account) private view {
        if (account == address(0)) revert ZeroAddress();
        if (account.code.length == 0) revert AddressHasNoCode(account);
    }
}
