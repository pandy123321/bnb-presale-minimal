// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ICostBasisManager } from "./interfaces/ICostBasisManager.sol";
import { CostMath } from "./libraries/CostMath.sol";

/// @notice 用户代币成本跟踪合约，以 WBNB wei 为单位记录用户持仓成本
///         并管理 LP 流动性头寸。
///
///         三种持仓状态：
///         - NONE：    无持仓
///         - KNOWN：   成本已知（通过 TradeRouter 买入）→ 可计算盈亏税率
///         - UNKNOWN： 成本未知（来源不明）→ 固定 10% 最高税率
///
///         核心安全规则：
///         UNKNOWN 是 fail-closed 的 —— 永远不能通过管理员操作变为 KNOWN。
///         V2 分支说明：保留了 V3 风格的 tokenId 型 LP 头寸追踪。
contract CostBasisManager is AccessControl, ICostBasisManager {
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    // 仓位变更原因常数
    bytes32 public constant REASON_BUY = keccak256("BUY"); // 买入
    bytes32 public constant REASON_ZERO_COST = keccak256("ZERO_COST"); // 零成本接收（分红领取）
    bytes32 public constant REASON_SELL = keccak256("SELL"); // 卖出
    bytes32 public constant REASON_TRANSFER = keccak256("TRANSFER"); // 用户间转账
    bytes32 public constant REASON_LIQUIDITY_DEPOSIT = keccak256("LIQUIDITY_DEPOSIT"); // LP 存入
    bytes32 public constant REASON_LIQUIDITY_WITHDRAWAL = keccak256("LIQUIDITY_WITHDRAWAL"); // LP 取回
    bytes32 public constant REASON_LIQUIDITY_FEE = keccak256("LIQUIDITY_FEE"); // LP 手续费
    bytes32 public constant REASON_LP_LOSS = keccak256("LP_LOSS"); // LP 损失
    bytes32 public constant REASON_STAKING_DEPOSIT = keccak256("STAKING_DEPOSIT"); // Staking 存入

    address public immutable token; // PANGU2 token 地址
    address public tradeRouter; // TradeRouter 地址（一次性配置）
    address public dividendDistributor; // DividendDistributor 地址（一次性配置）
    address public liquidityGateway; // 流动性网关地址（一次性配置）
    bool public operatorsConfigured; // 运营商是否已配置
    bool public liquidityGatewayConfigured; // 流动性网关是否已配置

    // 用户持仓头寸（聚合）
    mapping(address => Position) private _positions;
    // 按 tokenId 的 LP 头寸（保留 V3 模型用于 V2 最小可行产品）
    mapping(address => mapping(uint256 => Position)) private _lpPositions;
    // 按用户追踪 LP 总额
    mapping(address => uint256) public lpTrackedTotal;
    mapping(address => uint256) public lpCostTotal;
    // 待定 LP 存入值 —— 由 onLiquidityDeposit 填充，由 bindLpTokenId 消费
    mapping(address => uint256) private _pendingLpTokens;
    mapping(address => uint256) private _pendingLpCost;
    mapping(address => bool) public systemAddress; // 系统地址（不参与成本追踪）

    // ─────────────────── 错误定义 ───────────────────
    error ZeroAddress();
    error AddressHasNoCode(address account);
    error InvalidAmount();
    error InvalidPositionState();
    error SystemAccount();
    error UnauthorizedHook(address caller);
    error OperatorsAlreadyConfigured();
    error LiquidityGatewayAlreadyConfigured();
    error UnauthorizedLiquidityGateway(address caller);

    // ─────────────────── 事件 ───────────────────
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
    event LpPositionChanged(
        address indexed account,
        uint256 indexed tokenId,
        uint256 oldCostWbnbWei,
        uint256 newCostWbnbWei,
        uint256 oldTrackedTokens,
        uint256 newTrackedTokens,
        PositionStatus oldStatus,
        PositionStatus newStatus,
        bytes32 indexed reason
    );
    event LpLossRecorded(
        address indexed account, uint256 indexed tokenId, uint256 lostTrackedTokens, uint256 lostCostWbnbWei
    );
    event CostBasisTransferred(
        address indexed from,
        address indexed to,
        uint256 costWbnbWei,
        uint256 tokenAmount,
        PositionStatus sourceStatus,
        PositionStatus destinationStatus
    );
    event LpCostMigrated(
        address indexed from, address indexed to, uint256 indexed tokenId, uint256 costWbnbWei, uint256 trackedTokens
    );
    event SystemAddressUpdated(address indexed account, bool enabled);
    event OperatorsConfigured(address indexed tradeRouter, address indexed dividendDistributor);
    event LiquidityGatewayConfigured(address indexed liquidityGateway);

    constructor(address token_, address governance) {
        if (token_ == address(0) || governance == address(0)) revert ZeroAddress();
        if (token_.code.length == 0) revert AddressHasNoCode(token_);
        token = token_;
        _grantRole(DEFAULT_ADMIN_ROLE, governance);
        _grantRole(GOVERNANCE_ROLE, governance);
    }

    // ─────────────────── 权限修饰器 ───────────────────
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
    modifier onlyLiquidityGateway() {
        if (msg.sender != liquidityGateway) revert UnauthorizedLiquidityGateway(msg.sender);
        _;
    }

    // ─────────────────── 一次性配置 ───────────────────
    function configureOperators(address tradeRouter_, address dividendDistributor_) external onlyRole(GOVERNANCE_ROLE) {
        if (operatorsConfigured) revert OperatorsAlreadyConfigured();
        _requireContract(tradeRouter_);
        _requireContract(dividendDistributor_);
        tradeRouter = tradeRouter_;
        dividendDistributor = dividendDistributor_;
        operatorsConfigured = true;
        emit OperatorsConfigured(tradeRouter_, dividendDistributor_);
    }

    function configureLiquidityGateway(address gateway_) external onlyRole(GOVERNANCE_ROLE) {
        if (liquidityGatewayConfigured) revert LiquidityGatewayAlreadyConfigured();
        if (gateway_ == address(0)) revert ZeroAddress();
        if (gateway_.code.length == 0) revert AddressHasNoCode(gateway_);
        liquidityGateway = gateway_;
        liquidityGatewayConfigured = true;
        emit LiquidityGatewayConfigured(gateway_);
    }

    // ─────────────────── 查询函数 ───────────────────
    function positionOf(address account) external view override returns (Position memory) {
        return _effectiveUserPosition(account, _positions[account]);
    }

    function liquidityPositionOf(address account) external view override returns (Position memory) {
        uint256 tracked = lpTrackedTotal[account];
        uint256 cost = lpCostTotal[account];
        if (tracked == 0 && cost == 0) {
            return Position({ costWbnbWei: 0, trackedBalance: 0, status: PositionStatus.NONE });
        }
        return Position({ costWbnbWei: cost, trackedBalance: tracked, status: PositionStatus.KNOWN });
    }

    function lpPositionFor(address account, uint256 tokenId) external view returns (Position memory) {
        return _lpPositions[account][tokenId];
    }

    /// 按比例计算卖出的成本。UNKNOWN 状态返回 (0, UNKNOWN)，Router 会固定使用 10% 税率。
    /// floor 版本——用于实际成本扣除（不会多扣）。
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

    /// ceil 版本——用于利润判断（防止 floor 导致的错误 4%/10% 分类 P1-TAX-02）
    function proportionalCostCeil(address account, uint256 tokenAmount)
        external
        view
        returns (uint256 costWbnbWei, PositionStatus status)
    {
        Position memory p = _effectiveUserPosition(account, _positions[account]);
        status = p.status;
        if (tokenAmount == 0 || p.trackedBalance == 0 || status == PositionStatus.NONE) return (0, status);
        if (status == PositionStatus.UNKNOWN || tokenAmount > p.trackedBalance) return (0, PositionStatus.UNKNOWN);
        if (tokenAmount == p.trackedBalance) return (p.costWbnbWei, status);
        return (CostMath.proportionalCeil(p.costWbnbWei, tokenAmount, p.trackedBalance), status);
    }

    // ─────────────────── 用户仓位钩子 ───────────────────

    /// 记录买入：只能由 Token 合约调用
    /// 如果买入前仓位与链上余额一致且为 KNOWN → 累加成本
    /// 如果不一致 → 标记为 UNKNOWN（保护机制：状态漂移时 fail-closed）
    function recordBuy(address account, uint256 costWbnbWei, uint256 netTokenAmount) external override onlyToken {
        if (account == address(0)) revert ZeroAddress();
        if (systemAddress[account]) revert SystemAccount();
        if (netTokenAmount == 0 || costWbnbWei == 0) revert InvalidAmount();
        Position memory oldP = _positions[account];
        uint256 actualAfter = IERC20(token).balanceOf(account);
        if (actualAfter < netTokenAmount) revert InvalidPositionState();
        uint256 actualBefore = actualAfter - netTokenAmount;
        Position memory newP;
        if (_isKnownAndConsistent(oldP, actualBefore)) {
            // 仓位一致 → 正常累加成本
            newP = Position({
                costWbnbWei: oldP.costWbnbWei + costWbnbWei, trackedBalance: actualAfter, status: PositionStatus.KNOWN
            });
        } else {
            // 仓位不一致 → 标记 UNKNOWN
            newP = _unknownAt(actualAfter);
        }
        _storeUser(account, oldP, newP, REASON_BUY);
    }

    /// 记录零成本接收（分红领取）：只能由 DividendDistributor 调用
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
            // 零成本增加余额，成本不变
            newP =
                Position({ costWbnbWei: oldP.costWbnbWei, trackedBalance: actualAfter, status: PositionStatus.KNOWN });
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

    /// 系统信用未知（BuybackLocker release 等场景）→ 强制标记 UNKNOWN
    function onSystemCreditUnknown(address account, uint256 tokenAmount, bytes32 reason) external override onlyToken {
        if (account == address(0)) revert ZeroAddress();
        if (systemAddress[account]) revert SystemAccount();
        if (tokenAmount == 0) revert InvalidAmount();
        Position memory oldP = _positions[account];
        _storeUser(account, oldP, _unknownAt(IERC20(token).balanceOf(account)), reason);
    }

    /// 消费卖出仓位：只能由 TradeRouter 调用
    /// 返回已消费的成本和卖出前的状态，Router 据此选择 4% 或 10% 税率
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
            // 仓位不一致 → UNKNOWN → 固定 10% 税率
            previousStatus = PositionStatus.UNKNOWN;
            _storeUser(account, oldP, _unknownAt(actualAfter), REASON_SELL);
            return (0, previousStatus);
        }
        previousStatus = PositionStatus.KNOWN;
        // 按比例扣除成本
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

    // ──────────────────────────────────────────────
    // 用户间转账 —— UNKNOWN 污染规则（P0 安全修复）
    // ──────────────────────────────────────────────

    /// 核心修复：UNKNOWN 来源的代币永远污染接收方 —— 无 KNOWN 绕过
    ///
    /// 攻击场景（已修复）：
    ///   A 有 100 PANGU，成本 100 BNB，当前价值 50 BNB，状态 KNOWN
    ///   B 转入 100 个 UNKNOWN PANGU 给 A
    ///   旧逻辑：A 保持 KNOWN，成本不变 → 打折后按 4% 卖出（逃过了 10% 税率）
    ///   新逻辑：A 被迫变为 UNKNOWN → 按 10% 卖出（无法逃税）
    ///
    /// 三种情况：
    ///   情况 1（KNOWN → KNOWN）：按比例迁移成本
    ///   情况 2（UNKNOWN → 任何）：接收方永远强制变为 UNKNOWN
    ///   情况 3（KNOWN → UNKNOWN/NONE）：发送方扣除成本，接收方 UNKNOWN
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

        bool fromKnown = _isKnownAndConsistent(fromOld, fromBefore);
        bool toKnown = _isKnownAndConsistent(toOld, toBefore);

        // 情况 1：双方都是 KNOWN → 按比例迁移成本
        if (fromKnown && toKnown) {
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
                costWbnbWei: toOld.costWbnbWei + movedCost, trackedBalance: toAfter, status: PositionStatus.KNOWN
            });
            _storeUser(from, fromOld, fromNew, REASON_TRANSFER);
            _storeUser(to, toOld, toNew, REASON_TRANSFER);
            emit CostBasisTransferred(from, to, movedCost, tokenAmount, fromOld.status, toNew.status);
            return;
        }

        // 情况 2：发送方是 UNKNOWN → 接收方永远强制变为 UNKNOWN
        // 这是核心安全规则：攻击者不能用 UNKNOWN 代币稀释 KNOWN 仓位来逃税
        if (!fromKnown) {
            _storeUser(from, fromOld, _unknownAt(fromAfter), REASON_TRANSFER);
            _storeUser(to, toOld, _unknownAt(toAfter), REASON_TRANSFER);
            emit CostBasisTransferred(from, to, 0, tokenAmount, PositionStatus.UNKNOWN, PositionStatus.UNKNOWN);
            return;
        }

        // 情况 3：KNOWN → UNKNOWN（或 NONE）
        // 发送方按比例扣除成本，接收方保持 UNKNOWN
        {
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
            _storeUser(from, fromOld, fromNew, REASON_TRANSFER);
            _storeUser(to, toOld, _unknownAt(toAfter), REASON_TRANSFER);
            emit CostBasisTransferred(from, to, 0, tokenAmount, PositionStatus.KNOWN, PositionStatus.UNKNOWN);
        }
    }

    // ─────────────────── LP 交互 ───────────────────

    /// 流动性存入：从用户仓位中扣除对应成本和代币，标记为待定 LP
    function onLiquidityDeposit(address account, uint256 tokenAmount) external override onlyToken {
        if (account == address(0)) revert ZeroAddress();
        if (systemAddress[account]) revert SystemAccount();
        if (tokenAmount == 0) revert InvalidAmount();

        Position memory userOld = _positions[account];
        uint256 actualAfter = IERC20(token).balanceOf(account);
        uint256 actualBefore = actualAfter + tokenAmount;

        if (_isKnownAndConsistent(userOld, actualBefore)) {
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
            _storeUser(account, userOld, userNew, REASON_LIQUIDITY_DEPOSIT);
            _pendingLpTokens[account] = tokenAmount;
            _pendingLpCost[account] = movedCost;
            lpTrackedTotal[account] += tokenAmount;
            lpCostTotal[account] += movedCost;
        } else {
            _storeUser(account, userOld, _unknownAt(actualAfter), REASON_LIQUIDITY_DEPOSIT);
            _pendingLpTokens[account] = 0;
            _pendingLpCost[account] = 0;
        }
    }

    /// Staking 存入：按比例从用户仓位扣除成本，不跟踪 LP
    function onStakingDeposit(address account, uint256 tokenAmount) external override onlyToken {
        if (account == address(0)) revert ZeroAddress();
        if (systemAddress[account]) revert SystemAccount();
        if (tokenAmount == 0) revert InvalidAmount();

        Position memory userOld = _positions[account];
        uint256 actualAfter = IERC20(token).balanceOf(account);
        uint256 actualBefore = actualAfter + tokenAmount;

        if (_isKnownAndConsistent(userOld, actualBefore)) {
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
            _storeUser(account, userOld, userNew, REASON_STAKING_DEPOSIT);
        } else {
            _storeUser(account, userOld, _unknownAt(actualAfter), REASON_STAKING_DEPOSIT);
        }
    }

    /// 绑定 LP tokenId（由流动性网关在 mint 后调用）
    function bindLpTokenId(address account, uint256 tokenId, uint256 tokenUsed, uint256 wbnbUsed)
        external
        onlyLiquidityGateway
    {
        if (account == address(0) || tokenId == 0) revert ZeroAddress();
        if (tokenUsed == 0) revert InvalidAmount();
        if (_lpPositions[account][tokenId].trackedBalance != 0) revert InvalidPositionState();

        uint256 totalDeposited = _pendingLpTokens[account];
        uint256 totalPendingCost = _pendingLpCost[account];
        delete _pendingLpTokens[account];
        delete _pendingLpCost[account];

        if (totalDeposited == 0 || totalPendingCost == 0) return;

        uint256 lpCost = tokenUsed == totalDeposited
            ? totalPendingCost
            : CostMath.proportionalFloor(totalPendingCost, tokenUsed, totalDeposited);

        Position memory lpPos =
            Position({ costWbnbWei: lpCost, trackedBalance: tokenUsed, status: PositionStatus.KNOWN });
        _lpPositions[account][tokenId] = lpPos;
        emit LpPositionChanged(
            account,
            tokenId,
            0,
            lpCost,
            0,
            tokenUsed,
            PositionStatus.NONE,
            PositionStatus.KNOWN,
            REASON_LIQUIDITY_DEPOSIT
        );
    }

    /// 流动性取回
    function onLiquidityWithdrawal(address account, uint256 tokenAmount) external override onlyToken {
        if (account == address(0)) revert ZeroAddress();
        if (systemAddress[account]) revert SystemAccount();
        if (tokenAmount == 0) revert InvalidAmount();

        Position memory userOld = _positions[account];
        uint256 actualAfter = IERC20(token).balanceOf(account);
        if (actualAfter < tokenAmount) revert InvalidPositionState();
        uint256 actualBefore = actualAfter - tokenAmount;

        bool knownUser = _isKnownAndConsistent(userOld, actualBefore);
        if (!knownUser) {
            _storeUser(account, userOld, _unknownAt(actualAfter), REASON_LIQUIDITY_WITHDRAWAL);
            return;
        }

        uint256 returnedTracked = tokenAmount;
        if (returnedTracked > lpTrackedTotal[account]) returnedTracked = lpTrackedTotal[account];

        if (returnedTracked > 0) {
            uint256 returnedCost = returnedTracked == lpTrackedTotal[account]
                ? lpCostTotal[account]
                : CostMath.proportionalFloor(lpCostTotal[account], returnedTracked, lpTrackedTotal[account]);
            lpTrackedTotal[account] -= returnedTracked;
            lpCostTotal[account] -= returnedCost;
            Position memory userNew = actualAfter == 0
                ? _none()
                : Position({
                    costWbnbWei: userOld.costWbnbWei + returnedCost,
                    trackedBalance: actualAfter,
                    status: PositionStatus.KNOWN
                });
            _storeUser(account, userOld, userNew, REASON_LIQUIDITY_WITHDRAWAL);
        } else {
            Position memory userNew = Position({
                costWbnbWei: userOld.costWbnbWei, trackedBalance: actualAfter, status: PositionStatus.KNOWN
            });
            _storeUser(account, userOld, userNew, REASON_LIQUIDITY_WITHDRAWAL);
        }
    }

    /// 消费特定 tokenId 的 LP 头寸（完全退出并清除）
    function consumeLpTokenId(address account, uint256 tokenId, uint256 actualTokenReturned)
        external
        onlyLiquidityGateway
        returns (uint256 clearedTracked, uint256 clearedCost)
    {
        Position memory lpPos = _lpPositions[account][tokenId];
        if (lpPos.trackedBalance == 0) return (0, 0);
        clearedTracked = lpPos.trackedBalance;
        clearedCost = lpPos.costWbnbWei;

        if (actualTokenReturned < clearedTracked) {
            uint256 lost = clearedTracked - actualTokenReturned;
            uint256 lostCost = CostMath.proportionalFloor(clearedCost, lost, clearedTracked);
            emit LpLossRecorded(account, tokenId, lost, lostCost);
            clearedTracked = actualTokenReturned;
            clearedCost = clearedCost > lostCost ? clearedCost - lostCost : 0;
        }

        delete _lpPositions[account][tokenId];
        if (lpTrackedTotal[account] >= clearedTracked) lpTrackedTotal[account] -= clearedTracked;
        if (lpCostTotal[account] >= clearedCost) lpCostTotal[account] -= clearedCost;

        emit LpPositionChanged(
            account,
            tokenId,
            lpPos.costWbnbWei,
            0,
            lpPos.trackedBalance,
            0,
            lpPos.status,
            PositionStatus.NONE,
            REASON_LIQUIDITY_WITHDRAWAL
        );
    }

    /// LP 成本迁移（NFT 所有权转移时）
    function migrateLpCost(address from, address to, uint256 tokenId)
        external
        onlyLiquidityGateway
        returns (uint256 costWbnbWei, uint256 trackedTokens)
    {
        Position memory lpPos = _lpPositions[from][tokenId];
        costWbnbWei = lpPos.costWbnbWei;
        trackedTokens = lpPos.trackedBalance;
        if (trackedTokens == 0) return (0, 0);

        delete _lpPositions[from][tokenId];
        _lpPositions[to][tokenId] = lpPos;

        if (lpTrackedTotal[from] >= trackedTokens) lpTrackedTotal[from] -= trackedTokens;
        if (lpCostTotal[from] >= costWbnbWei) lpCostTotal[from] -= costWbnbWei;
        lpTrackedTotal[to] += trackedTokens;
        lpCostTotal[to] += costWbnbWei;
        emit LpCostMigrated(from, to, tokenId, costWbnbWei, trackedTokens);
    }

    /// 手续费领取：零成本 —— 永不移动 LP 本金或成本
    function onLiquidityFeeCollection(address account, uint256 tokenAmount) external override onlyToken {
        if (account == address(0)) revert ZeroAddress();
        if (tokenAmount == 0) return;
        Position memory userOld = _positions[account];
        uint256 actualAfter = IERC20(token).balanceOf(account);
        if (actualAfter < tokenAmount) revert InvalidPositionState();
        uint256 actualBefore = actualAfter - tokenAmount;
        if (_isKnownAndConsistent(userOld, actualBefore)) {
            Position memory userNew = Position({
                costWbnbWei: userOld.costWbnbWei, trackedBalance: actualAfter, status: PositionStatus.KNOWN
            });
            _storeUser(account, userOld, userNew, REASON_LIQUIDITY_FEE);
        } else {
            _storeUser(account, userOld, _unknownAt(actualAfter), REASON_LIQUIDITY_FEE);
        }
    }

    function setSystemAddress(address account, bool enabled) external override onlyToken {
        if (account == address(0)) revert ZeroAddress();
        if (enabled && (_positions[account].trackedBalance != 0 || lpTrackedTotal[account] != 0)) {
            revert SystemAccount();
        }
        systemAddress[account] = enabled;
        emit SystemAddressUpdated(account, enabled);
    }

    // ─────────────────── 内部辅助函数 ───────────────────

    /// 获取用户有效仓位（与链上余额对比，不一致则标记 UNKNOWN）
    function _effectiveUserPosition(address account, Position memory stored) private view returns (Position memory) {
        uint256 actual = IERC20(token).balanceOf(account);
        if (actual == stored.trackedBalance) return stored;
        return _unknownAt(actual);
    }

    /// 检查仓位是否与链上余额一致且为 KNOWN
    function _isKnownAndConsistent(Position memory p, uint256 actualBalance) private pure returns (bool) {
        if (actualBalance == 0) return p.trackedBalance == 0 && p.costWbnbWei == 0 && p.status == PositionStatus.NONE;
        return p.trackedBalance == actualBalance && p.status == PositionStatus.KNOWN;
    }

    function _unknownAt(uint256 actualBalance) private pure returns (Position memory) {
        if (actualBalance == 0) return _none();
        return Position({ costWbnbWei: 0, trackedBalance: actualBalance, status: PositionStatus.UNKNOWN });
    }

    function _none() private pure returns (Position memory) {
        return Position({ costWbnbWei: 0, trackedBalance: 0, status: PositionStatus.NONE });
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

    /// 仓位校验：确保状态一致性
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
