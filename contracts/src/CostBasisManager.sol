// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICostBasisManager} from "./interfaces/ICostBasisManager.sol";
import {CostMath} from "./libraries/CostMath.sol";

/// @notice Tracks user token cost in WBNB wei and a separate token-denominated liquidity position.
/// @dev UNKNOWN is fail-closed and never becomes KNOWN through an administrator operation.
contract CostBasisManager is AccessControl, ICostBasisManager {
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    bytes32 public constant REASON_BUY = keccak256("BUY");
    bytes32 public constant REASON_ZERO_COST = keccak256("ZERO_COST");
    bytes32 public constant REASON_SELL = keccak256("SELL");
    bytes32 public constant REASON_TRANSFER = keccak256("TRANSFER");
    bytes32 public constant REASON_LIQUIDITY_DEPOSIT = keccak256("LIQUIDITY_DEPOSIT");
    bytes32 public constant REASON_LIQUIDITY_WITHDRAWAL = keccak256("LIQUIDITY_WITHDRAWAL");

    address public immutable token;
    address public tradeRouter;
    address public dividendDistributor;
    bool public operatorsConfigured;

    mapping(address => Position) private _positions;
    mapping(address => Position) private _liquidityPositions;
    mapping(address => bool) public systemAddress;

    error ZeroAddress();
    error AddressHasNoCode(address account);
    error InvalidAmount();
    error InvalidPositionState();
    error SystemAccount();
    error UnauthorizedHook(address caller);
    error OperatorsAlreadyConfigured();

    event PositionChanged(
        address indexed account,
        uint256 oldCostWbnbWei,
        uint256 newCostWbnbWei,
        uint256 oldTrackedBalance,
        uint256 newTrackedBalance,
        PositionStatus oldStatus,
        PositionStatus newStatus,
        bytes32 indexed reason
    );
    event LiquidityPositionChanged(
        address indexed account,
        uint256 oldCostWbnbWei,
        uint256 newCostWbnbWei,
        uint256 oldTrackedTokens,
        uint256 newTrackedTokens,
        PositionStatus oldStatus,
        PositionStatus newStatus,
        bytes32 indexed reason
    );
    event CostBasisTransferred(
        address indexed from,
        address indexed to,
        uint256 costWbnbWei,
        uint256 tokenAmount,
        PositionStatus sourceStatus,
        PositionStatus destinationStatus
    );
    event SystemAddressUpdated(address indexed account, bool enabled);
    event OperatorsConfigured(address indexed tradeRouter, address indexed dividendDistributor);

    constructor(address token_, address governance) {
        if (token_ == address(0) || governance == address(0)) revert ZeroAddress();
        if (token_.code.length == 0) revert AddressHasNoCode(token_);
        token = token_;
        _grantRole(DEFAULT_ADMIN_ROLE, governance);
        _grantRole(GOVERNANCE_ROLE, governance);
    }

    modifier onlyToken() {
        if (msg.sender != token) revert UnauthorizedHook(msg.sender);
        _;
    }

    modifier onlyTradeRouter() {
        if (msg.sender != tradeRouter) revert UnauthorizedHook(msg.sender);
        _;
    }

    modifier onlyDividendDistributor() {
        if (msg.sender != dividendDistributor) revert UnauthorizedHook(msg.sender);
        _;
    }

    function configureOperators(address tradeRouter_, address dividendDistributor_)
        external
        onlyRole(GOVERNANCE_ROLE)
    {
        if (operatorsConfigured) revert OperatorsAlreadyConfigured();
        _requireContract(tradeRouter_);
        _requireContract(dividendDistributor_);
        tradeRouter = tradeRouter_;
        dividendDistributor = dividendDistributor_;
        operatorsConfigured = true;
        emit OperatorsConfigured(tradeRouter_, dividendDistributor_);
    }

    function positionOf(address account) external view override returns (Position memory) {
        return _effectiveUserPosition(account, _positions[account]);
    }

    function liquidityPositionOf(address account) external view override returns (Position memory) {
        return _liquidityPositions[account];
    }

    function proportionalCost(address account, uint256 tokenAmount)
        external
        view
        override
        returns (uint256 costWbnbWei, PositionStatus status)
    {
        Position memory p = _effectiveUserPosition(account, _positions[account]);
        status = p.status;
        if (tokenAmount == 0 || p.trackedBalance == 0 || status == PositionStatus.NONE) return (0, status);
        if (status == PositionStatus.UNKNOWN || tokenAmount > p.trackedBalance) return (0, PositionStatus.UNKNOWN);
        if (tokenAmount == p.trackedBalance) return (p.costWbnbWei, status);
        return (CostMath.proportionalFloor(p.costWbnbWei, tokenAmount, p.trackedBalance), status);
    }

    function recordBuy(address account, uint256 costWbnbWei, uint256 netTokenAmount)
        external
        override
        onlyToken
    {
        if (account == address(0)) revert ZeroAddress();
        if (systemAddress[account]) revert SystemAccount();
        if (netTokenAmount == 0 || costWbnbWei == 0) revert InvalidAmount();

        Position memory oldP = _positions[account];
        uint256 actualAfter = IERC20(token).balanceOf(account);
        if (actualAfter < netTokenAmount) revert InvalidPositionState();
        uint256 actualBefore = actualAfter - netTokenAmount;

        Position memory newP;
        if (_isKnownAndConsistent(oldP, actualBefore)) {
            newP = Position({
                costWbnbWei: oldP.costWbnbWei + costWbnbWei,
                trackedBalance: actualAfter,
                status: PositionStatus.KNOWN
            });
        } else {
            newP = _unknownAt(actualAfter);
        }
        _storeUser(account, oldP, newP, REASON_BUY);
    }

    function recordZeroCost(address account, uint256 tokenAmount) external override onlyDividendDistributor {
        if (account == address(0)) revert ZeroAddress();
        if (systemAddress[account]) revert SystemAccount();
        if (tokenAmount == 0) revert InvalidAmount();

        Position memory oldP = _positions[account];
        uint256 actualAfter = IERC20(token).balanceOf(account);
        if (actualAfter < tokenAmount) revert InvalidPositionState();
        uint256 actualBefore = actualAfter - tokenAmount;

        Position memory newP;
        if (_isKnownAndConsistent(oldP, actualBefore)) {
            newP = Position({
                costWbnbWei: oldP.costWbnbWei,
                trackedBalance: actualAfter,
                status: PositionStatus.KNOWN
            });
        } else {
            newP = _unknownAt(actualAfter);
        }
        _storeUser(account, oldP, newP, REASON_ZERO_COST);
    }

    function markUnknown(address account, uint256 tokenAmount, bytes32 reason) external override onlyToken {
        if (account == address(0)) revert ZeroAddress();
        if (systemAddress[account]) revert SystemAccount();
        if (tokenAmount == 0) revert InvalidAmount();
        Position memory oldP = _positions[account];
        _storeUser(account, oldP, _unknownAt(IERC20(token).balanceOf(account)), reason);
    }

    function onSystemCreditUnknown(address account, uint256 tokenAmount, bytes32 reason)
        external
        override
        onlyToken
    {
        if (account == address(0)) revert ZeroAddress();
        if (systemAddress[account]) revert SystemAccount();
        if (tokenAmount == 0) revert InvalidAmount();
        Position memory oldP = _positions[account];
        _storeUser(account, oldP, _unknownAt(IERC20(token).balanceOf(account)), reason);
    }

    function consumeSell(address account, uint256 tokenAmount)
        external
        override
        onlyTradeRouter
        returns (uint256 consumedCostWbnbWei, PositionStatus previousStatus)
    {
        if (account == address(0)) revert ZeroAddress();
        if (tokenAmount == 0) revert InvalidAmount();

        Position memory oldP = _positions[account];
        uint256 actualAfter = IERC20(token).balanceOf(account);
        uint256 actualBefore = actualAfter + tokenAmount;

        if (!_isKnownAndConsistent(oldP, actualBefore)) {
            previousStatus = PositionStatus.UNKNOWN;
            _storeUser(account, oldP, _unknownAt(actualAfter), REASON_SELL);
            return (0, previousStatus);
        }

        previousStatus = PositionStatus.KNOWN;
        consumedCostWbnbWei = tokenAmount == oldP.trackedBalance
            ? oldP.costWbnbWei
            : CostMath.proportionalFloor(oldP.costWbnbWei, tokenAmount, oldP.trackedBalance);
        Position memory newP = actualAfter == 0
            ? _none()
            : Position({
                costWbnbWei: oldP.costWbnbWei - consumedCostWbnbWei,
                trackedBalance: actualAfter,
                status: PositionStatus.KNOWN
            });
        _storeUser(account, oldP, newP, REASON_SELL);
    }

    function onUserTransfer(address from, address to, uint256 tokenAmount) external override onlyToken {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (tokenAmount == 0 || from == to) return;
        if (systemAddress[from] || systemAddress[to]) revert SystemAccount();

        Position memory fromOld = _positions[from];
        Position memory toOld = _positions[to];
        uint256 fromAfter = IERC20(token).balanceOf(from);
        uint256 toAfter = IERC20(token).balanceOf(to);
        if (toAfter < tokenAmount) revert InvalidPositionState();
        uint256 fromBefore = fromAfter + tokenAmount;
        uint256 toBefore = toAfter - tokenAmount;

        if (!_isKnownAndConsistent(fromOld, fromBefore) || !_isKnownAndConsistent(toOld, toBefore)) {
            _storeUser(from, fromOld, _unknownAt(fromAfter), REASON_TRANSFER);
            _storeUser(to, toOld, _unknownAt(toAfter), REASON_TRANSFER);
            emit CostBasisTransferred(
                from, to, 0, tokenAmount, PositionStatus.UNKNOWN, PositionStatus.UNKNOWN
            );
            return;
        }

        uint256 movedCost = tokenAmount == fromOld.trackedBalance
            ? fromOld.costWbnbWei
            : CostMath.proportionalFloor(fromOld.costWbnbWei, tokenAmount, fromOld.trackedBalance);
        Position memory fromNew = fromAfter == 0
            ? _none()
            : Position({
                costWbnbWei: fromOld.costWbnbWei - movedCost,
                trackedBalance: fromAfter,
                status: PositionStatus.KNOWN
            });
        Position memory toNew = Position({
            costWbnbWei: toOld.costWbnbWei + movedCost,
            trackedBalance: toAfter,
            status: PositionStatus.KNOWN
        });
        _storeUser(from, fromOld, fromNew, REASON_TRANSFER);
        _storeUser(to, toOld, toNew, REASON_TRANSFER);
        emit CostBasisTransferred(from, to, movedCost, tokenAmount, fromOld.status, toNew.status);
    }

    function onLiquidityDeposit(address account, uint256 tokenAmount) external override onlyToken {
        if (account == address(0)) revert ZeroAddress();
        if (systemAddress[account]) revert SystemAccount();
        if (tokenAmount == 0) revert InvalidAmount();

        Position memory userOld = _positions[account];
        Position memory liquidityOld = _liquidityPositions[account];
        uint256 actualAfter = IERC20(token).balanceOf(account);
        uint256 actualBefore = actualAfter + tokenAmount;

        if (!_isKnownAndConsistent(userOld, actualBefore) || liquidityOld.status == PositionStatus.UNKNOWN) {
            _storeUser(account, userOld, _unknownAt(actualAfter), REASON_LIQUIDITY_DEPOSIT);
            Position memory liquidityUnknown = Position({
                costWbnbWei: 0,
                trackedBalance: liquidityOld.trackedBalance + tokenAmount,
                status: PositionStatus.UNKNOWN
            });
            _storeLiquidity(account, liquidityOld, liquidityUnknown, REASON_LIQUIDITY_DEPOSIT);
            return;
        }

        uint256 movedCost = tokenAmount == userOld.trackedBalance
            ? userOld.costWbnbWei
            : CostMath.proportionalFloor(userOld.costWbnbWei, tokenAmount, userOld.trackedBalance);
        Position memory userNew = actualAfter == 0
            ? _none()
            : Position({
                costWbnbWei: userOld.costWbnbWei - movedCost,
                trackedBalance: actualAfter,
                status: PositionStatus.KNOWN
            });
        Position memory liquidityNew = Position({
            costWbnbWei: liquidityOld.costWbnbWei + movedCost,
            trackedBalance: liquidityOld.trackedBalance + tokenAmount,
            status: PositionStatus.KNOWN
        });
        _storeUser(account, userOld, userNew, REASON_LIQUIDITY_DEPOSIT);
        _storeLiquidity(account, liquidityOld, liquidityNew, REASON_LIQUIDITY_DEPOSIT);
    }

    function onLiquidityWithdrawal(address account, uint256 tokenAmount) external override onlyToken {
        if (account == address(0)) revert ZeroAddress();
        if (systemAddress[account]) revert SystemAccount();
        if (tokenAmount == 0) revert InvalidAmount();

        Position memory userOld = _positions[account];
        Position memory liquidityOld = _liquidityPositions[account];
        uint256 actualAfter = IERC20(token).balanceOf(account);
        if (actualAfter < tokenAmount) revert InvalidPositionState();
        uint256 actualBefore = actualAfter - tokenAmount;

        uint256 returnedTracked = tokenAmount > liquidityOld.trackedBalance
            ? liquidityOld.trackedBalance
            : tokenAmount;
        bool exactKnownPath = _isKnownAndConsistent(userOld, actualBefore)
            && liquidityOld.status != PositionStatus.UNKNOWN
            && returnedTracked == tokenAmount;

        if (!exactKnownPath) {
            Position memory liquidityNewUnknown = _consumeUnknownLiquidity(liquidityOld, returnedTracked);
            _storeUser(account, userOld, _unknownAt(actualAfter), REASON_LIQUIDITY_WITHDRAWAL);
            _storeLiquidity(account, liquidityOld, liquidityNewUnknown, REASON_LIQUIDITY_WITHDRAWAL);
            return;
        }

        uint256 returnedCost = returnedTracked == liquidityOld.trackedBalance
            ? liquidityOld.costWbnbWei
            : CostMath.proportionalFloor(
                liquidityOld.costWbnbWei, returnedTracked, liquidityOld.trackedBalance
            );
        Position memory liquidityNew = liquidityOld.trackedBalance == returnedTracked
            ? _none()
            : Position({
                costWbnbWei: liquidityOld.costWbnbWei - returnedCost,
                trackedBalance: liquidityOld.trackedBalance - returnedTracked,
                status: PositionStatus.KNOWN
            });
        Position memory userNew = Position({
            costWbnbWei: userOld.costWbnbWei + returnedCost,
            trackedBalance: actualAfter,
            status: PositionStatus.KNOWN
        });
        _storeUser(account, userOld, userNew, REASON_LIQUIDITY_WITHDRAWAL);
        _storeLiquidity(account, liquidityOld, liquidityNew, REASON_LIQUIDITY_WITHDRAWAL);
    }

    function setSystemAddress(address account, bool enabled) external override onlyToken {
        if (account == address(0)) revert ZeroAddress();
        if (
            enabled
                && (_positions[account].trackedBalance != 0 || _liquidityPositions[account].trackedBalance != 0)
        ) revert SystemAccount();
        systemAddress[account] = enabled;
        emit SystemAddressUpdated(account, enabled);
    }

    function _effectiveUserPosition(address account, Position memory stored) private view returns (Position memory) {
        uint256 actual = IERC20(token).balanceOf(account);
        if (actual == stored.trackedBalance) return stored;
        return _unknownAt(actual);
    }

    function _isKnownAndConsistent(Position memory p, uint256 actualBalance) private pure returns (bool) {
        if (actualBalance == 0) {
            return p.trackedBalance == 0 && p.costWbnbWei == 0 && p.status == PositionStatus.NONE;
        }
        return p.trackedBalance == actualBalance && p.status == PositionStatus.KNOWN;
    }

    function _consumeUnknownLiquidity(Position memory oldP, uint256 amount)
        private
        pure
        returns (Position memory)
    {
        if (amount >= oldP.trackedBalance) return _none();
        return Position({
            costWbnbWei: 0,
            trackedBalance: oldP.trackedBalance - amount,
            status: PositionStatus.UNKNOWN
        });
    }

    function _unknownAt(uint256 actualBalance) private pure returns (Position memory) {
        if (actualBalance == 0) return _none();
        return Position({costWbnbWei: 0, trackedBalance: actualBalance, status: PositionStatus.UNKNOWN});
    }

    function _none() private pure returns (Position memory) {
        return Position({costWbnbWei: 0, trackedBalance: 0, status: PositionStatus.NONE});
    }

    function _storeUser(address account, Position memory oldP, Position memory newP, bytes32 reason) private {
        _validate(newP);
        _positions[account] = newP;
        emit PositionChanged(
            account,
            oldP.costWbnbWei,
            newP.costWbnbWei,
            oldP.trackedBalance,
            newP.trackedBalance,
            oldP.status,
            newP.status,
            reason
        );
    }

    function _storeLiquidity(address account, Position memory oldP, Position memory newP, bytes32 reason) private {
        _validate(newP);
        _liquidityPositions[account] = newP;
        emit LiquidityPositionChanged(
            account,
            oldP.costWbnbWei,
            newP.costWbnbWei,
            oldP.trackedBalance,
            newP.trackedBalance,
            oldP.status,
            newP.status,
            reason
        );
    }

    function _validate(Position memory p) private pure {
        if (
            (p.trackedBalance == 0 && (p.costWbnbWei != 0 || p.status != PositionStatus.NONE))
                || (p.trackedBalance != 0 && p.status == PositionStatus.NONE)
                || (p.status == PositionStatus.UNKNOWN && p.costWbnbWei != 0)
        ) revert InvalidPositionState();
    }

    function _requireContract(address account) private view {
        if (account == address(0)) revert ZeroAddress();
        if (account.code.length == 0) revert AddressHasNoCode(account);
    }
}
