// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICostBasisManager} from "./interfaces/ICostBasisManager.sol";
import {CostMath} from "./libraries/CostMath.sol";

contract CostBasisManager is AccessControl, ICostBasisManager {
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    bytes32 public constant REASON_BUY = keccak256("BUY");
    bytes32 public constant REASON_ZERO_COST = keccak256("ZERO_COST");
    bytes32 public constant REASON_SELL = keccak256("SELL");
    bytes32 public constant REASON_TRANSFER = keccak256("TRANSFER");

    address public immutable token;
    address public tradeRouter;
    address public dividendDistributor;
    bool public operatorsConfigured;
    mapping(address => Position) private _positions;
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
        if (tradeRouter_ == address(0) || dividendDistributor_ == address(0)) revert ZeroAddress();
        if (tradeRouter_.code.length == 0) revert AddressHasNoCode(tradeRouter_);
        if (dividendDistributor_.code.length == 0) revert AddressHasNoCode(dividendDistributor_);
        tradeRouter = tradeRouter_;
        dividendDistributor = dividendDistributor_;
        operatorsConfigured = true;
        emit OperatorsConfigured(tradeRouter_, dividendDistributor_);
    }

    function positionOf(address account) external view override returns (Position memory) {
        return _positions[account];
    }

    function proportionalCost(address account, uint256 tokenAmount)
        external
        view
        override
        returns (uint256 costWbnbWei, PositionStatus status)
    {
        Position memory p = _positions[account];
        status = p.status;
        uint256 actualBalance = IERC20(token).balanceOf(account);
        if (actualBalance > p.trackedBalance || tokenAmount > p.trackedBalance) status = PositionStatus.UNKNOWN;
        if (p.status == PositionStatus.NONE || p.trackedBalance == 0 || tokenAmount == 0) return (0, status);
        if (tokenAmount >= p.trackedBalance) return (p.costWbnbWei, status);
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
        Position memory newP = oldP;
        uint256 actualBalance = IERC20(token).balanceOf(account);
        uint256 preexistingBalance = actualBalance > netTokenAmount ? actualBalance - netTokenAmount : 0;
        newP.costWbnbWei += costWbnbWei;
        newP.trackedBalance += netTokenAmount;
        if (preexistingBalance > oldP.trackedBalance) newP.status = PositionStatus.UNKNOWN;
        else if (newP.status == PositionStatus.NONE) newP.status = PositionStatus.KNOWN;
        _store(account, oldP, newP, REASON_BUY);
    }

    function recordZeroCost(address account, uint256 tokenAmount) external override onlyDividendDistributor {
        if (account == address(0)) revert ZeroAddress();
        if (systemAddress[account]) revert SystemAccount();
        if (tokenAmount == 0) revert InvalidAmount();

        Position memory oldP = _positions[account];
        Position memory newP = oldP;
        uint256 actualBalance = IERC20(token).balanceOf(account);
        uint256 preexistingBalance = actualBalance > tokenAmount ? actualBalance - tokenAmount : 0;
        newP.trackedBalance += tokenAmount;
        if (preexistingBalance > oldP.trackedBalance) newP.status = PositionStatus.UNKNOWN;
        else if (newP.status == PositionStatus.NONE) newP.status = PositionStatus.KNOWN;
        _store(account, oldP, newP, REASON_ZERO_COST);
    }

    function markUnknown(address account, uint256 tokenAmount, bytes32 reason) external override onlyToken {
        if (account == address(0)) revert ZeroAddress();
        if (systemAddress[account]) revert SystemAccount();
        if (tokenAmount == 0) revert InvalidAmount();

        Position memory oldP = _positions[account];
        Position memory newP = oldP;
        newP.trackedBalance += tokenAmount;
        newP.status = PositionStatus.UNKNOWN;
        _store(account, oldP, newP, reason);
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
        uint256 actualBalanceAfterTransfer = IERC20(token).balanceOf(account);
        uint256 actualBalanceBeforeTransfer = actualBalanceAfterTransfer + tokenAmount;
        bool hadUntrackedBalance = actualBalanceBeforeTransfer > oldP.trackedBalance;
        previousStatus = hadUntrackedBalance ? PositionStatus.UNKNOWN : oldP.status;
        Position memory newP = oldP;
        if (hadUntrackedBalance && newP.trackedBalance != 0) newP.status = PositionStatus.UNKNOWN;

        if (oldP.trackedBalance == 0 || oldP.status == PositionStatus.NONE) {
            return (0, PositionStatus.UNKNOWN);
        }

        uint256 consumedTracked = tokenAmount >= oldP.trackedBalance ? oldP.trackedBalance : tokenAmount;
        consumedCostWbnbWei = CostMath.proportionalFloor(oldP.costWbnbWei, consumedTracked, oldP.trackedBalance);

        newP.trackedBalance = oldP.trackedBalance - consumedTracked;
        newP.costWbnbWei = oldP.costWbnbWei - consumedCostWbnbWei;
        if (newP.trackedBalance == 0) {
            newP.costWbnbWei = 0;
            newP.status = PositionStatus.NONE;
        }
        _store(account, oldP, newP, REASON_SELL);
    }

    function onUserTransfer(address from, address to, uint256 tokenAmount) external override onlyToken {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (tokenAmount == 0 || from == to) return;
        if (systemAddress[from] || systemAddress[to]) revert SystemAccount();

        Position memory fromOld = _positions[from];
        Position memory toOld = _positions[to];
        Position memory fromNew = fromOld;
        Position memory toNew = toOld;

        uint256 movedTracked = tokenAmount > fromOld.trackedBalance ? fromOld.trackedBalance : tokenAmount;
        uint256 movedCost;
        if (movedTracked > 0) {
            movedCost = CostMath.proportionalFloor(fromOld.costWbnbWei, movedTracked, fromOld.trackedBalance);
            fromNew.trackedBalance = fromOld.trackedBalance - movedTracked;
            fromNew.costWbnbWei = fromOld.costWbnbWei - movedCost;
            if (fromNew.trackedBalance == 0) {
                fromNew.costWbnbWei = 0;
                fromNew.status = PositionStatus.NONE;
            }
        }

        toNew.trackedBalance += tokenAmount;
        toNew.costWbnbWei += movedCost;
        uint256 sourceBalanceBeforeTransfer = IERC20(token).balanceOf(from) + tokenAmount;
        uint256 destinationBalanceAfterTransfer = IERC20(token).balanceOf(to);
        uint256 destinationBalanceBeforeTransfer =
            destinationBalanceAfterTransfer > tokenAmount ? destinationBalanceAfterTransfer - tokenAmount : 0;
        bool untrackedSourcePosition = sourceBalanceBeforeTransfer > fromOld.trackedBalance;
        bool untrackedDestinationPosition = destinationBalanceBeforeTransfer > toOld.trackedBalance;
        bool untrackedSourceAmount = tokenAmount > movedTracked;
        if (untrackedSourcePosition && fromNew.trackedBalance != 0) fromNew.status = PositionStatus.UNKNOWN;
        if (
            untrackedSourcePosition || untrackedDestinationPosition || untrackedSourceAmount
                || fromOld.status == PositionStatus.UNKNOWN || toOld.status == PositionStatus.UNKNOWN
        ) {
            toNew.status = PositionStatus.UNKNOWN;
        } else if (toNew.status == PositionStatus.NONE) {
            toNew.status = PositionStatus.KNOWN;
        }

        _store(from, fromOld, fromNew, REASON_TRANSFER);
        _store(to, toOld, toNew, REASON_TRANSFER);
        emit CostBasisTransferred(from, to, movedCost, tokenAmount, fromOld.status, toNew.status);
    }

    function setSystemAddress(address account, bool enabled) external override onlyToken {
        if (account == address(0)) revert ZeroAddress();
        if (enabled && _positions[account].trackedBalance != 0) revert SystemAccount();
        systemAddress[account] = enabled;
        emit SystemAddressUpdated(account, enabled);
    }

    function _store(address account, Position memory oldP, Position memory newP, bytes32 reason) private {
        if (
            (newP.trackedBalance == 0
                && (newP.costWbnbWei != 0 || newP.status != PositionStatus.NONE))
                || (newP.trackedBalance != 0 && newP.status == PositionStatus.NONE)
        ) revert InvalidPositionState();
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
}
