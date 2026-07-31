// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title BNBPresale
/// @notice 单项目、仅接收原生 BNB、支付成功后立即发放项目代币的内部测试私募合约。
/// @dev
/// 业务边界：
/// 1. 项目代币地址部署后不可修改；
/// 2. 不支持 USDT、退款、锁仓、Claim、多项目和自动定价；
/// 3. 合约部署后默认暂停，正式结束后进入不可逆 FINALIZED 状态；
/// 4. BNB 只能由 Owner 主动归集至单一 Treasury 地址。
contract BNBPresale is Ownable2Step, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------------
    // 自定义错误：使用错误选择器降低 Gas，并让测试和后台更容易识别失败原因。
    // ---------------------------------------------------------------------

    error ZeroAddress();
    error InvalidSaleTokenContract();
    error ZeroPayment();
    error InvalidPrice();
    error BelowMinimumPurchase();
    error AboveMaximumPurchase();
    error RepeatPurchaseNotAllowed();
    error WalletLimitExceeded();
    error ZeroTokenOutput();
    error SaleCapExceeded();
    error InsufficientTokenInventory();
    error InexactTokenTransfer(uint256 expectedAmount, uint256 actualAmount);
    error InvalidPurchaseLimits();
    error InvalidMaxTokensSold();
    error InvalidAmount();
    error BNBTransferFailed();
    error SaleAlreadyFinalized();
    error SaleNotFinalized();
    error OwnershipRenounceDisabled();

    // ---------------------------------------------------------------------
    // 事件：后台必须以这些事件作为链上配置和资金行为的权威证据。
    // ---------------------------------------------------------------------

    event PurchaseCompleted(
        address indexed buyer,
        uint256 bnbAmount,
        uint256 tokenAmount,
        uint256 tokenPerBNB,
        uint256 walletPurchaseCount,
        uint256 totalBNBRaised,
        uint256 totalTokensSold
    );

    event TokenPerBNBUpdated(uint256 previousValue, uint256 newValue);

    event PurchaseLimitsUpdated(uint256 minPurchaseBNB, uint256 maxPurchaseBNB, uint256 maxPurchasePerWallet);

    event RepeatPurchaseRuleUpdated(bool allowed);
    event MaxTokensSoldUpdated(uint256 previousValue, uint256 newValue);
    event TreasuryAddressUpdated(address indexed previousAddress, address indexed newAddress);
    event BNBSwept(address indexed treasuryAddress, uint256 amount);
    event UnsoldTokensWithdrawn(address indexed recipient, uint256 amount);
    event SaleFinalized(address indexed operator);

    // ---------------------------------------------------------------------
    // 不可修改配置。
    // ---------------------------------------------------------------------

    /// @notice 项目代币，部署后永久不可修改。
    IERC20 public immutable saleToken;

    // ---------------------------------------------------------------------
    // 可修改的销售配置和累计统计。
    // ---------------------------------------------------------------------

    /// @notice BNB 归集接收地址。该地址不自动拥有合约管理权限。
    address public treasuryAddress;

    /// @notice 每 1 个完整 BNB 可获得的项目代币最小单位数量。
    uint256 public tokenPerBNB;

    /// @notice 单笔最低认购金额，单位 wei；0 表示不限制。
    uint256 public minPurchaseBNB;

    /// @notice 单笔最高认购金额，单位 wei；0 表示不限制。
    uint256 public maxPurchaseBNB;

    /// @notice 单钱包累计最高认购金额，单位 wei；0 表示不限制。
    uint256 public maxPurchasePerWallet;

    /// @notice 本合约允许售出的 TOKEN 最大数量，单位为项目代币最小单位，必须大于 0。
    uint256 public maxTokensSold;

    /// @notice 历史累计收到的 BNB，单位 wei。归集不会减少该统计值。
    uint256 public totalBNBRaised;

    /// @notice 历史累计成功发放的 TOKEN，单位为项目代币最小单位。
    uint256 public totalTokensSold;

    /// @notice 是否允许同一钱包重复认购。
    bool public allowRepeatPurchase;

    /// @notice 是否已经永久结束私募。该状态不可逆。
    bool public saleFinalized;

    /// @notice 钱包累计支付 BNB，单位 wei。
    mapping(address buyer => uint256 amount) public walletBNBSpent;

    /// @notice 钱包累计获得 TOKEN，单位为项目代币最小单位。
    mapping(address buyer => uint256 amount) public walletTokensReceived;

    /// @notice 钱包成功认购次数。
    mapping(address buyer => uint256 count) public walletPurchaseCount;

    /// @param initialOwner 初始合约 Owner，第一期应与后台 Chain Operator 地址一致。
    /// @param saleTokenAddress 项目代币地址，部署后不可修改。
    /// @param initialTreasuryAddress 初始 BNB 归集地址。
    /// @param initialTokenPerBNB 初始兑换比例，单位为每 1 BNB 对应的 TOKEN 最小单位。
    /// @param initialMinPurchaseBNB 初始单笔最低 BNB，单位 wei；0 表示关闭限制。
    /// @param initialMaxPurchaseBNB 初始单笔最高 BNB，单位 wei；0 表示关闭限制。
    /// @param initialMaxPurchasePerWallet 初始单钱包累计 BNB 上限，单位 wei；0 表示关闭限制。
    /// @param initialAllowRepeatPurchase 是否允许重复认购。
    /// @param initialMaxTokensSold 初始最大 TOKEN 销售量，必须大于 0。
    constructor(
        address initialOwner,
        address saleTokenAddress,
        address initialTreasuryAddress,
        uint256 initialTokenPerBNB,
        uint256 initialMinPurchaseBNB,
        uint256 initialMaxPurchaseBNB,
        uint256 initialMaxPurchasePerWallet,
        bool initialAllowRepeatPurchase,
        uint256 initialMaxTokensSold
    ) Ownable(initialOwner) {
        if (saleTokenAddress == address(0) || initialTreasuryAddress == address(0)) {
            revert ZeroAddress();
        }
        // 项目代币必须是已经部署的合约，避免误填 EOA 后导致私募永久不可用。
        if (saleTokenAddress.code.length == 0) revert InvalidSaleTokenContract();
        if (initialTokenPerBNB == 0) revert InvalidPrice();
        if (initialMaxTokensSold == 0) revert InvalidMaxTokensSold();
        _validatePurchaseLimits(initialMinPurchaseBNB, initialMaxPurchaseBNB, initialMaxPurchasePerWallet);

        saleToken = IERC20(saleTokenAddress);
        treasuryAddress = initialTreasuryAddress;
        tokenPerBNB = initialTokenPerBNB;
        minPurchaseBNB = initialMinPurchaseBNB;
        maxPurchaseBNB = initialMaxPurchaseBNB;
        maxPurchasePerWallet = initialMaxPurchasePerWallet;
        allowRepeatPurchase = initialAllowRepeatPurchase;
        maxTokensSold = initialMaxTokensSold;

        // 安全部署原则：库存和配置未检查完成前，合约不能接收认购。
        _pause();
    }

    /// @notice 用户直接向合约发送原生 BNB 时执行认购。
    receive() external payable whenNotPaused nonReentrant {
        _purchase(msg.sender, msg.value);
    }

    /// @notice 用户显式调用该方法并附带原生 BNB 执行认购。
    function buy() external payable whenNotPaused nonReentrant {
        _purchase(msg.sender, msg.value);
    }

    /// @notice Owner 更新兑换比例。
    /// @param newTokenPerBNB 每 1 BNB 对应的 TOKEN 最小单位数量。
    function setTokenPerBNB(uint256 newTokenPerBNB) external onlyOwner {
        _requireSaleNotFinalized();
        if (newTokenPerBNB == 0) revert InvalidPrice();

        uint256 previousValue = tokenPerBNB;
        tokenPerBNB = newTokenPerBNB;
        emit TokenPerBNBUpdated(previousValue, newTokenPerBNB);
    }

    /// @notice Owner 一次性更新三项认购额度限制。
    function setPurchaseLimits(uint256 newMinPurchaseBNB, uint256 newMaxPurchaseBNB, uint256 newMaxPurchasePerWallet)
        external
        onlyOwner
    {
        _requireSaleNotFinalized();
        _validatePurchaseLimits(newMinPurchaseBNB, newMaxPurchaseBNB, newMaxPurchasePerWallet);

        minPurchaseBNB = newMinPurchaseBNB;
        maxPurchaseBNB = newMaxPurchaseBNB;
        maxPurchasePerWallet = newMaxPurchasePerWallet;

        emit PurchaseLimitsUpdated(newMinPurchaseBNB, newMaxPurchaseBNB, newMaxPurchasePerWallet);
    }

    /// @notice Owner 修改是否允许同一钱包重复认购。
    function setAllowRepeatPurchase(bool allowed) external onlyOwner {
        _requireSaleNotFinalized();
        allowRepeatPurchase = allowed;
        emit RepeatPurchaseRuleUpdated(allowed);
    }

    /// @notice Owner 修改最大 TOKEN 销售量。
    function setMaxTokensSold(uint256 newMaxTokensSold) external onlyOwner {
        _requireSaleNotFinalized();
        if (newMaxTokensSold == 0 || newMaxTokensSold < totalTokensSold) revert InvalidMaxTokensSold();

        uint256 previousValue = maxTokensSold;
        maxTokensSold = newMaxTokensSold;
        emit MaxTokensSoldUpdated(previousValue, newMaxTokensSold);
    }

    /// @notice Owner 修改唯一 BNB 归集地址。
    /// @dev 即使销售已经结束，也允许更新 Treasury，以便安全归集剩余 BNB。
    function setTreasuryAddress(address newTreasuryAddress) external onlyOwner {
        if (newTreasuryAddress == address(0)) revert ZeroAddress();

        address previousAddress = treasuryAddress;
        treasuryAddress = newTreasuryAddress;
        emit TreasuryAddressUpdated(previousAddress, newTreasuryAddress);
    }

    /// @notice Owner 临时暂停认购。
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Owner 在未永久结束时恢复认购。
    function unpause() external onlyOwner {
        _requireSaleNotFinalized();
        _unpause();
    }

    /// @notice Owner 在暂停状态永久结束私募。
    /// @dev FINALIZED 不可逆，之后不能恢复认购，也不能再修改销售参数。
    function finalizeSale() external onlyOwner whenPaused {
        if (saleFinalized) revert SaleAlreadyFinalized();
        saleFinalized = true;
        emit SaleFinalized(msg.sender);
    }

    /// @notice Owner 将指定数量 BNB 归集到当前 Treasury。
    /// @param amount 归集数量，单位 wei。
    function sweepBNB(uint256 amount) external onlyOwner nonReentrant {
        if (amount == 0 || amount > address(this).balance) revert InvalidAmount();

        (bool success,) = payable(treasuryAddress).call{ value: amount }("");
        if (!success) revert BNBTransferFailed();

        emit BNBSwept(treasuryAddress, amount);
    }

    /// @notice 在私募永久结束后提取未售项目代币。
    /// @param recipient 接收代币的地址。
    /// @param amount 提取数量，单位为项目代币最小单位。
    function withdrawUnsoldTokens(address recipient, uint256 amount) external onlyOwner whenPaused nonReentrant {
        if (!saleFinalized) revert SaleNotFinalized();
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0 || amount > saleToken.balanceOf(address(this))) revert InvalidAmount();

        saleToken.safeTransfer(recipient, amount);
        emit UnsoldTokensWithdrawn(recipient, amount);
    }

    /// @notice 禁止放弃所有权，避免私募合约永久失去管理能力。
    function renounceOwnership() public view override onlyOwner {
        revert OwnershipRenounceDisabled();
    }

    /// @notice 返回当前仍可按销售上限售出的 TOKEN 数量。
    /// @dev 该值不代表实际库存；实际可售数量还受 saleToken.balanceOf 限制。
    function remainingSaleCapacity() external view returns (uint256) {
        return maxTokensSold - totalTokensSold;
    }

    /// @notice 返回当前合约 TOKEN 实际库存。
    function tokenInventory() external view returns (uint256) {
        return saleToken.balanceOf(address(this));
    }

    /// @dev receive() 和 buy() 共用的唯一认购实现。
    function _purchase(address buyer, uint256 bnbAmount) internal {
        // FINALIZED 状态理论上始终保持暂停，此处额外防御，避免未来修改破坏生命周期。
        _requireSaleNotFinalized();
        if (buyer == address(0)) revert ZeroAddress();
        if (bnbAmount == 0) revert ZeroPayment();

        uint256 currentTokenPerBNB = tokenPerBNB;
        if (currentTokenPerBNB == 0) revert InvalidPrice();

        uint256 currentMinPurchase = minPurchaseBNB;
        if (currentMinPurchase != 0 && bnbAmount < currentMinPurchase) revert BelowMinimumPurchase();

        uint256 currentMaxPurchase = maxPurchaseBNB;
        if (currentMaxPurchase != 0 && bnbAmount > currentMaxPurchase) revert AboveMaximumPurchase();

        uint256 currentPurchaseCount = walletPurchaseCount[buyer];
        if (!allowRepeatPurchase && currentPurchaseCount != 0) revert RepeatPurchaseNotAllowed();

        uint256 newWalletBNBSpent = walletBNBSpent[buyer] + bnbAmount;
        uint256 currentWalletMaximum = maxPurchasePerWallet;
        if (currentWalletMaximum != 0 && newWalletBNBSpent > currentWalletMaximum) revert WalletLimitExceeded();

        uint256 tokenAmount = Math.mulDiv(bnbAmount, currentTokenPerBNB, 1 ether);
        if (tokenAmount == 0) revert ZeroTokenOutput();

        uint256 newTotalTokensSold = totalTokensSold + tokenAmount;
        if (newTotalTokensSold > maxTokensSold) revert SaleCapExceeded();
        if (saleToken.balanceOf(address(this)) < tokenAmount) revert InsufficientTokenInventory();

        // Checks-Effects-Interactions：先完成全部状态更新，再执行外部代币调用。
        uint256 newPurchaseCount = currentPurchaseCount + 1;
        totalBNBRaised += bnbAmount;
        totalTokensSold = newTotalTokensSold;
        walletBNBSpent[buyer] = newWalletBNBSpent;
        walletTokensReceived[buyer] += tokenAmount;
        walletPurchaseCount[buyer] = newPurchaseCount;

        uint256 buyerBalanceBefore = saleToken.balanceOf(buyer);
        saleToken.safeTransfer(buyer, tokenAmount);
        uint256 buyerBalanceAfter = saleToken.balanceOf(buyer);
        uint256 actualReceived = buyerBalanceAfter >= buyerBalanceBefore ? buyerBalanceAfter - buyerBalanceBefore : 0;
        if (actualReceived != tokenAmount) revert InexactTokenTransfer(tokenAmount, actualReceived);

        emit PurchaseCompleted(
            buyer, bnbAmount, tokenAmount, currentTokenPerBNB, newPurchaseCount, totalBNBRaised, newTotalTokensSold
        );
    }

    /// @dev 统一校验最低、单笔最高和钱包累计上限之间的逻辑关系。
    function _validatePurchaseLimits(uint256 minimum, uint256 maximum, uint256 walletMaximum) internal pure {
        if (maximum != 0 && maximum < minimum) revert InvalidPurchaseLimits();
        if (walletMaximum != 0 && minimum != 0 && walletMaximum < minimum) revert InvalidPurchaseLimits();
    }

    /// @dev 阻止 FINALIZED 后继续认购或修改销售参数。
    function _requireSaleNotFinalized() internal view {
        if (saleFinalized) revert SaleAlreadyFinalized();
    }
}
