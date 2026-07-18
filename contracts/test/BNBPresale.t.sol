// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { BNBPresale } from "../src/BNBPresale.sol";
import { MockSaleToken } from "../src/MockSaleToken.sol";
import { FalseReturnToken } from "../src/mocks/FalseReturnToken.sol";
import { ReentrantSaleToken } from "../src/mocks/ReentrantSaleToken.sol";
import { ReentrantTreasury, RejectBNBTreasury } from "../src/mocks/ReentrantTreasury.sol";
import { BNBPresaleHarness } from "../src/mocks/BNBPresaleHarness.sol";
import { FeeOnTransferToken } from "../src/mocks/FeeOnTransferToken.sol";
import { TrueNoTransferToken } from "../src/mocks/TrueNoTransferToken.sol";
import { NoReturnToken } from "../src/mocks/NoReturnToken.sol";
import { TestBase, Vm } from "./utils/TestBase.sol";

contract BNBPresaleTest is TestBase {
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

    uint256 internal constant ONE_TOKEN = 1e18;
    uint256 internal constant TOTAL_SUPPLY = 1_000_000_000 * ONE_TOKEN;
    uint256 internal constant INVENTORY = 100_000_000 * ONE_TOKEN;
    uint256 internal constant PRICE = 100_000 * ONE_TOKEN;
    uint256 internal constant MIN_PURCHASE = 0.01 ether;
    uint256 internal constant MAX_PURCHASE = 10 ether;
    uint256 internal constant WALLET_MAX = 50 ether;

    address internal owner = address(0xA11CE);
    address internal treasury = address(0xBEEF);
    address internal buyer = address(0xB0B);
    address internal secondBuyer = address(0xCAFE);
    address internal outsider = address(0xBAD);

    MockSaleToken internal token;
    BNBPresale internal presale;

    bytes32 internal constant PURCHASE_COMPLETED_TOPIC =
        keccak256("PurchaseCompleted(address,uint256,uint256,uint256,uint256,uint256,uint256)");

    struct PurchaseEventData {
        uint256 bnbAmount;
        uint256 tokenAmount;
        uint256 tokenPerBNB;
        uint256 walletPurchaseCount;
        uint256 totalBNBRaised;
        uint256 totalTokensSold;
    }

    struct PurchaseEventExpectation {
        address buyer;
        PurchaseEventData data;
    }

    struct PurchaseState {
        uint256 totalBNBRaised;
        uint256 totalTokensSold;
        uint256 walletBNBSpent;
        uint256 walletTokensReceived;
        uint256 walletPurchaseCount;
        uint256 presaleBNBBalance;
        uint256 buyerBNBBalance;
        uint256 presaleTokenBalance;
        uint256 buyerTokenBalance;
    }

    function setUp() public {
        token = new MockSaleToken(address(this), TOTAL_SUPPLY);
        presale = _deployPresale(
            address(token), owner, treasury, PRICE, MIN_PURCHASE, MAX_PURCHASE, WALLET_MAX, true, INVENTORY
        );
        assertTrue(token.transfer(address(presale), INVENTORY), "inventory transfer failed");
        vm.prank(owner);
        presale.unpause();
        vm.deal(buyer, 100 ether);
        vm.deal(secondBuyer, 100 ether);
        vm.deal(owner, 100 ether);
        vm.deal(outsider, 100 ether);
    }

    // ---------------------------------------------------------------------
    // 部署和初始化审核。
    // ---------------------------------------------------------------------

    function test_DeploymentStoresConfigurationAndStartsPaused() public {
        BNBPresale deployed = _deployPresale(
            address(token), owner, treasury, PRICE, MIN_PURCHASE, MAX_PURCHASE, WALLET_MAX, true, INVENTORY
        );

        assertEq(address(deployed.saleToken()), address(token), unicode"项目代币地址错误");
        assertEq(deployed.owner(), owner, unicode"Owner 错误");
        assertEq(deployed.treasuryAddress(), treasury, unicode"Treasury 错误");
        assertEq(deployed.tokenPerBNB(), PRICE, unicode"价格错误");
        assertEq(deployed.minPurchaseBNB(), MIN_PURCHASE, unicode"最低额度错误");
        assertEq(deployed.maxPurchaseBNB(), MAX_PURCHASE, unicode"最高额度错误");
        assertEq(deployed.maxPurchasePerWallet(), WALLET_MAX, unicode"钱包上限错误");
        assertEq(deployed.maxTokensSold(), INVENTORY, unicode"销售上限错误");
        assertTrue(deployed.allowRepeatPurchase(), unicode"重复认购配置错误");
        assertTrue(deployed.paused(), unicode"部署后必须暂停");
        assertFalse(deployed.saleFinalized(), unicode"部署后不应结束");
    }

    function test_RevertDeploymentWithZeroOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        _deployPresale(
            address(token), address(0), treasury, PRICE, MIN_PURCHASE, MAX_PURCHASE, WALLET_MAX, true, INVENTORY
        );
    }

    function test_RevertDeploymentWithZeroToken() public {
        vm.expectRevert(BNBPresale.ZeroAddress.selector);
        _deployPresale(address(0), owner, treasury, PRICE, MIN_PURCHASE, MAX_PURCHASE, WALLET_MAX, true, INVENTORY);
    }

    function test_RevertDeploymentWithEOAAsSaleToken() public {
        vm.expectRevert(BNBPresale.InvalidSaleTokenContract.selector);
        _deployPresale(address(0x1234), owner, treasury, PRICE, MIN_PURCHASE, MAX_PURCHASE, WALLET_MAX, true, INVENTORY);
    }

    function test_RevertDeploymentWithZeroTreasury() public {
        vm.expectRevert(BNBPresale.ZeroAddress.selector);
        _deployPresale(
            address(token), owner, address(0), PRICE, MIN_PURCHASE, MAX_PURCHASE, WALLET_MAX, true, INVENTORY
        );
    }

    function test_RevertDeploymentWithZeroPrice() public {
        vm.expectRevert(BNBPresale.InvalidPrice.selector);
        _deployPresale(address(token), owner, treasury, 0, MIN_PURCHASE, MAX_PURCHASE, WALLET_MAX, true, INVENTORY);
    }

    function test_RevertDeploymentWithZeroMaxTokensSold() public {
        vm.expectRevert(BNBPresale.InvalidMaxTokensSold.selector);
        _deployPresale(address(token), owner, treasury, PRICE, MIN_PURCHASE, MAX_PURCHASE, WALLET_MAX, true, 0);
    }

    function test_RevertDeploymentWhenMaximumBelowMinimum() public {
        vm.expectRevert(BNBPresale.InvalidPurchaseLimits.selector);
        _deployPresale(address(token), owner, treasury, PRICE, 2 ether, 1 ether, WALLET_MAX, true, INVENTORY);
    }

    function test_RevertDeploymentWhenWalletMaximumBelowMinimum() public {
        vm.expectRevert(BNBPresale.InvalidPurchaseLimits.selector);
        _deployPresale(address(token), owner, treasury, PRICE, 2 ether, 10 ether, 1 ether, true, INVENTORY);
    }

    // ---------------------------------------------------------------------
    // receive() 与 buy() 正常认购。
    // ---------------------------------------------------------------------

    function test_ReceivePurchaseTransfersExactTokensAndUpdatesState() public {
        uint256 bnbAmount = 1 ether;
        uint256 tokenAmount = 100_000 * ONE_TOKEN;

        vm.recordLogs();
        vm.prank(buyer);
        (bool success,) = address(presale).call{ value: bnbAmount }("");
        assertTrue(success, unicode"receive 认购失败");
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(_countPurchaseEvents(logs, address(presale)), 1, unicode"receive 必须只发出一个购买事件");
        _assertPurchaseEvent(
            logs,
            address(presale),
            PurchaseEventExpectation(buyer, PurchaseEventData(bnbAmount, tokenAmount, PRICE, 1, bnbAmount, tokenAmount))
        );
        assertEq(token.balanceOf(buyer), tokenAmount, unicode"用户 TOKEN 数量错误");
        assertEq(address(presale).balance, bnbAmount, unicode"合约 BNB 余额错误");
        assertEq(presale.totalBNBRaised(), bnbAmount, unicode"累计 BNB 错误");
        assertEq(presale.totalTokensSold(), tokenAmount, unicode"累计 TOKEN 错误");
        assertEq(presale.walletBNBSpent(buyer), bnbAmount, unicode"钱包累计 BNB 错误");
        assertEq(presale.walletTokensReceived(buyer), tokenAmount, unicode"钱包累计 TOKEN 错误");
        assertEq(presale.walletPurchaseCount(buyer), 1, unicode"钱包次数错误");
    }

    function test_BuyPurchaseUsesSameBusinessLogic() public {
        vm.recordLogs();
        vm.prank(buyer);
        presale.buy{ value: 2 ether }();
        Vm.Log[] memory logs = vm.getRecordedLogs();

        uint256 expected = 200_000 * ONE_TOKEN;
        assertEq(_countPurchaseEvents(logs, address(presale)), 1, unicode"buy 必须只发出一个购买事件");
        _assertPurchaseEvent(
            logs,
            address(presale),
            PurchaseEventExpectation(buyer, PurchaseEventData(2 ether, expected, PRICE, 1, 2 ether, expected))
        );
        assertEq(token.balanceOf(buyer), expected, unicode"buy 发币错误");
        assertEq(presale.totalBNBRaised(), 2 ether, unicode"buy 累计 BNB 错误");
        assertEq(presale.totalTokensSold(), expected, unicode"buy 累计 TOKEN 错误");
        assertEq(presale.walletPurchaseCount(buyer), 1, unicode"buy 次数错误");
    }

    function test_RepeatPurchaseAccumulatesCorrectlyWhenAllowed() public {
        vm.startPrank(buyer);
        presale.buy{ value: 1 ether }();
        presale.buy{ value: 2 ether }();
        vm.stopPrank();

        assertEq(presale.walletBNBSpent(buyer), 3 ether, unicode"重复认购累计 BNB 错误");
        assertEq(presale.walletTokensReceived(buyer), 300_000 * ONE_TOKEN, unicode"重复认购累计 TOKEN 错误");
        assertEq(presale.walletPurchaseCount(buyer), 2, unicode"重复认购次数错误");
    }

    function test_RemainingCapacityAndInventoryViews() public {
        vm.prank(buyer);
        presale.buy{ value: 1 ether }();
        assertEq(presale.remainingSaleCapacity(), INVENTORY - 100_000 * ONE_TOKEN, unicode"剩余销售容量错误");
        assertEq(presale.tokenInventory(), INVENTORY - 100_000 * ONE_TOKEN, unicode"实际库存错误");
    }

    // ---------------------------------------------------------------------
    // 认购失败条件和边界。
    // ---------------------------------------------------------------------

    function test_RevertPurchaseWhilePaused() public {
        vm.prank(owner);
        presale.pause();
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(buyer);
        presale.buy{ value: 1 ether }();
    }

    function test_RevertZeroPayment() public {
        vm.expectRevert(BNBPresale.ZeroPayment.selector);
        vm.prank(buyer);
        presale.buy();
    }

    function test_DefensiveZeroBuyerAndZeroPriceChecks() public {
        BNBPresaleHarness harness =
            new BNBPresaleHarness(owner, address(token), treasury, PRICE, 0, 0, 0, true, INVENTORY);
        assertTrue(token.transfer(address(harness), INVENTORY), "harness inventory transfer failed");
        vm.prank(owner);
        harness.unpause();

        vm.expectRevert(BNBPresale.ZeroAddress.selector);
        harness.exposedPurchase{ value: 1 ether }(address(0));

        harness.forceSetTokenPerBNB(0);
        vm.expectRevert(BNBPresale.InvalidPrice.selector);
        vm.prank(buyer);
        harness.buy{ value: 1 ether }();
    }

    function test_RevertBelowMinimumPurchase() public {
        vm.expectRevert(BNBPresale.BelowMinimumPurchase.selector);
        vm.prank(buyer);
        presale.buy{ value: MIN_PURCHASE - 1 }();
    }

    function test_ExactMinimumPurchaseSucceeds() public {
        vm.prank(buyer);
        presale.buy{ value: MIN_PURCHASE }();
        assertEq(presale.walletBNBSpent(buyer), MIN_PURCHASE, unicode"最低边界应成功");
    }

    function test_RevertAboveMaximumPurchase() public {
        vm.expectRevert(BNBPresale.AboveMaximumPurchase.selector);
        vm.prank(buyer);
        presale.buy{ value: MAX_PURCHASE + 1 }();
    }

    function test_ExactMaximumPurchaseSucceeds() public {
        vm.prank(buyer);
        presale.buy{ value: MAX_PURCHASE }();
        assertEq(presale.walletBNBSpent(buyer), MAX_PURCHASE, unicode"最高边界应成功");
    }

    function test_RevertRepeatPurchaseWhenDisabled() public {
        vm.prank(owner);
        presale.setAllowRepeatPurchase(false);

        vm.startPrank(buyer);
        presale.buy{ value: 1 ether }();
        vm.expectRevert(BNBPresale.RepeatPurchaseNotAllowed.selector);
        presale.buy{ value: 1 ether }();
        vm.stopPrank();
    }

    function test_RevertWhenWalletCumulativeLimitExceeded() public {
        vm.prank(owner);
        presale.setPurchaseLimits(MIN_PURCHASE, MAX_PURCHASE, 2 ether);

        vm.startPrank(buyer);
        presale.buy{ value: 1 ether }();
        presale.buy{ value: 1 ether }();
        vm.expectRevert(BNBPresale.WalletLimitExceeded.selector);
        presale.buy{ value: MIN_PURCHASE }();
        vm.stopPrank();
    }

    function test_ExactWalletCumulativeLimitSucceeds() public {
        vm.prank(owner);
        presale.setPurchaseLimits(MIN_PURCHASE, MAX_PURCHASE, 2 ether);
        vm.startPrank(buyer);
        presale.buy{ value: 1 ether }();
        presale.buy{ value: 1 ether }();
        vm.stopPrank();
        assertEq(presale.walletBNBSpent(buyer), 2 ether, unicode"钱包累计边界应成功");
    }

    function test_RevertWhenTokenOutputRoundsToZero() public {
        vm.prank(owner);
        presale.setPurchaseLimits(0, 0, 0);
        vm.prank(owner);
        presale.setTokenPerBNB(1);

        vm.expectRevert(BNBPresale.ZeroTokenOutput.selector);
        vm.prank(buyer);
        presale.buy{ value: 1 wei }();
    }

    function test_RevertWhenSaleCapExceeded() public {
        vm.prank(owner);
        presale.setMaxTokensSold(100_000 * ONE_TOKEN);
        vm.prank(buyer);
        presale.buy{ value: 1 ether }();

        vm.expectRevert(BNBPresale.SaleCapExceeded.selector);
        vm.prank(secondBuyer);
        presale.buy{ value: MIN_PURCHASE }();
    }

    function test_ExactRemainingSaleCapSucceeds() public {
        vm.prank(owner);
        presale.setMaxTokensSold(100_000 * ONE_TOKEN);
        vm.prank(buyer);
        presale.buy{ value: 1 ether }();
        assertEq(presale.totalTokensSold(), presale.maxTokensSold(), unicode"销售上限边界错误");
    }

    function test_RevertWhenInventoryInsufficient() public {
        MockSaleToken smallToken = new MockSaleToken(address(this), 10 * ONE_TOKEN);
        BNBPresale smallPresale = _deployPresale(address(smallToken), owner, treasury, PRICE, 0, 0, 0, true, INVENTORY);
        assertTrue(smallToken.transfer(address(smallPresale), 10 * ONE_TOKEN), "small inventory transfer failed");
        vm.prank(owner);
        smallPresale.unpause();

        vm.expectRevert(BNBPresale.InsufficientTokenInventory.selector);
        vm.prank(buyer);
        smallPresale.buy{ value: 1 ether }();
    }

    function test_RevertAndRollbackWhenTokenReturnsFalse() public {
        FalseReturnToken badToken = new FalseReturnToken();
        BNBPresale badPresale = _deployPresale(address(badToken), owner, treasury, PRICE, 0, 0, 0, true, INVENTORY);
        badToken.mint(address(badPresale), INVENTORY);
        vm.prank(owner);
        badPresale.unpause();

        _assertBuyRevertsAndRollsBack(badPresale, buyer, 1 ether, SafeERC20.SafeERC20FailedOperation.selector);
    }

    function test_ReceiveAndBuyProduceEquivalentStateAndSingleEvents() public {
        MockSaleToken receiveToken = new MockSaleToken(address(this), INVENTORY);
        MockSaleToken buyToken = new MockSaleToken(address(this), INVENTORY);
        BNBPresale receivePresale =
            _deployPresale(address(receiveToken), owner, treasury, PRICE, 0, 0, 0, true, INVENTORY);
        BNBPresale buyPresale = _deployPresale(address(buyToken), owner, treasury, PRICE, 0, 0, 0, true, INVENTORY);
        assertTrue(receiveToken.transfer(address(receivePresale), INVENTORY), "receive inventory transfer failed");
        assertTrue(buyToken.transfer(address(buyPresale), INVENTORY), "buy inventory transfer failed");
        vm.startPrank(owner);
        receivePresale.unpause();
        buyPresale.unpause();
        vm.stopPrank();

        uint256 amount = 3 ether;
        vm.deal(buyer, 10 ether);
        vm.recordLogs();
        vm.prank(buyer);
        (bool success,) = address(receivePresale).call{ value: amount }("");
        assertTrue(success, unicode"receive 对照认购失败");
        Vm.Log[] memory receiveLogs = vm.getRecordedLogs();

        vm.recordLogs();
        vm.prank(buyer);
        buyPresale.buy{ value: amount }();
        Vm.Log[] memory buyLogs = vm.getRecordedLogs();

        assertEq(_countPurchaseEvents(receiveLogs, address(receivePresale)), 1, unicode"receive 事件数量错误");
        assertEq(_countPurchaseEvents(buyLogs, address(buyPresale)), 1, unicode"buy 事件数量错误");
        assertEq(receivePresale.totalBNBRaised(), buyPresale.totalBNBRaised(), unicode"入口累计 BNB 不一致");
        assertEq(receivePresale.totalTokensSold(), buyPresale.totalTokensSold(), unicode"入口累计 TOKEN 不一致");
        assertEq(
            receivePresale.walletBNBSpent(buyer), buyPresale.walletBNBSpent(buyer), unicode"入口钱包 BNB 不一致"
        );
        assertEq(
            receivePresale.walletTokensReceived(buyer),
            buyPresale.walletTokensReceived(buyer),
            unicode"入口钱包 TOKEN 不一致"
        );
        assertEq(
            receivePresale.walletPurchaseCount(buyer),
            buyPresale.walletPurchaseCount(buyer),
            unicode"入口钱包次数不一致"
        );
        assertEq(receiveToken.balanceOf(buyer), buyToken.balanceOf(buyer), unicode"入口实际到账不一致");
    }

    function test_RevertedLimitPurchasesEmitNoEventAndFullyRollback() public {
        _assertBuyRevertsAndRollsBack(presale, buyer, MIN_PURCHASE - 1, BNBPresale.BelowMinimumPurchase.selector);
        _assertBuyRevertsAndRollsBack(presale, buyer, MAX_PURCHASE + 1, BNBPresale.AboveMaximumPurchase.selector);

        vm.prank(owner);
        presale.setAllowRepeatPurchase(false);
        vm.prank(buyer);
        presale.buy{ value: 1 ether }();
        _assertBuyRevertsAndRollsBack(presale, buyer, 1 ether, BNBPresale.RepeatPurchaseNotAllowed.selector);

        vm.prank(owner);
        presale.setAllowRepeatPurchase(true);
        vm.prank(owner);
        presale.setPurchaseLimits(0, 0, 1 ether);
        _assertBuyRevertsAndRollsBack(presale, buyer, 1 wei, BNBPresale.WalletLimitExceeded.selector);
    }

    function test_RevertedCalculationAndInventoryPurchasesEmitNoEventAndFullyRollback() public {
        vm.prank(owner);
        presale.setPurchaseLimits(0, 0, 0);
        vm.prank(owner);
        presale.setTokenPerBNB(1);
        _assertBuyRevertsAndRollsBack(presale, buyer, 1 wei, BNBPresale.ZeroTokenOutput.selector);

        MockSaleToken capToken = new MockSaleToken(address(this), INVENTORY);
        BNBPresale capPresale =
            _deployPresale(address(capToken), owner, treasury, PRICE, 0, 0, 0, true, 100_000 * ONE_TOKEN);
        assertTrue(capToken.transfer(address(capPresale), INVENTORY), "cap inventory transfer failed");
        vm.prank(owner);
        capPresale.unpause();
        vm.prank(buyer);
        capPresale.buy{ value: 1 ether }();
        _assertBuyRevertsAndRollsBack(capPresale, secondBuyer, 1 wei, BNBPresale.SaleCapExceeded.selector);

        MockSaleToken inventoryToken = new MockSaleToken(address(this), 10 * ONE_TOKEN);
        BNBPresale inventoryPresale =
            _deployPresale(address(inventoryToken), owner, treasury, PRICE, 0, 0, 0, true, INVENTORY);
        assertTrue(
            inventoryToken.transfer(address(inventoryPresale), 10 * ONE_TOKEN), "small inventory transfer failed"
        );
        vm.prank(owner);
        inventoryPresale.unpause();
        _assertBuyRevertsAndRollsBack(
            inventoryPresale, secondBuyer, 1 ether, BNBPresale.InsufficientTokenInventory.selector
        );
    }

    function test_FeeOnTransferTokenPurchaseRevertsAndFullyRollsBack() public {
        FeeOnTransferToken feeToken = new FeeOnTransferToken();
        BNBPresale feePresale = _deployPresale(address(feeToken), owner, treasury, PRICE, 0, 0, 0, true, INVENTORY);
        feeToken.mint(address(feePresale), INVENTORY);
        vm.prank(owner);
        feePresale.unpause();

        _assertBuyRevertsAndRollsBack(feePresale, buyer, 1 ether, BNBPresale.InexactTokenTransfer.selector);
    }

    function test_TrueNoTransferTokenPurchaseRevertsAndFullyRollsBack() public {
        TrueNoTransferToken noTransferToken = new TrueNoTransferToken();
        BNBPresale noTransferPresale =
            _deployPresale(address(noTransferToken), owner, treasury, PRICE, 0, 0, 0, true, INVENTORY);
        noTransferToken.mint(address(noTransferPresale), INVENTORY);
        vm.prank(owner);
        noTransferPresale.unpause();

        _assertBuyRevertsAndRollsBack(noTransferPresale, buyer, 1 ether, BNBPresale.InexactTokenTransfer.selector);
    }

    function test_NoReturnTokenPurchaseTransfersExactAmount() public {
        NoReturnToken noReturnToken = new NoReturnToken();
        BNBPresale noReturnPresale =
            _deployPresale(address(noReturnToken), owner, treasury, PRICE, 0, 0, 0, true, INVENTORY);
        noReturnToken.mint(address(noReturnPresale), INVENTORY);
        vm.prank(owner);
        noReturnPresale.unpause();

        vm.recordLogs();
        vm.prank(buyer);
        noReturnPresale.buy{ value: 1 ether }();
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(
            _countPurchaseEvents(logs, address(noReturnPresale)), 1, unicode"无返回值代币购买事件数量错误"
        );
        assertEq(noReturnToken.balanceOf(buyer), 100_000 * ONE_TOKEN, unicode"无返回值代币实际到账错误");
    }

    function test_RevertedPreconditionPurchasesEmitNoEventAndFullyRollback() public {
        vm.prank(owner);
        presale.pause();
        _assertBuyRevertsAndRollsBack(presale, buyer, 1 ether, Pausable.EnforcedPause.selector);
        vm.prank(owner);
        presale.unpause();

        _assertBuyRevertsAndRollsBack(presale, buyer, 0, BNBPresale.ZeroPayment.selector);

        BNBPresaleHarness harness =
            new BNBPresaleHarness(owner, address(token), treasury, PRICE, 0, 0, 0, true, INVENTORY);
        assertTrue(token.transfer(address(harness), INVENTORY), "harness inventory transfer failed");
        vm.prank(owner);
        harness.unpause();
        harness.forceSetTokenPerBNB(0);
        _assertBuyRevertsAndRollsBack(harness, buyer, 1 ether, BNBPresale.InvalidPrice.selector);
    }

    // ---------------------------------------------------------------------
    // 管理函数、权限和事件。
    // ---------------------------------------------------------------------

    function test_OwnerUpdatesPriceAndEmitsEvent() public {
        uint256 newPrice = 120_000 * ONE_TOKEN;
        vm.expectEmit(false, false, false, true, address(presale));
        emit TokenPerBNBUpdated(PRICE, newPrice);
        vm.prank(owner);
        presale.setTokenPerBNB(newPrice);
        assertEq(presale.tokenPerBNB(), newPrice, unicode"价格更新失败");
    }

    function test_RevertSetZeroPrice() public {
        vm.expectRevert(BNBPresale.InvalidPrice.selector);
        vm.prank(owner);
        presale.setTokenPerBNB(0);
    }

    function test_RevertNonOwnerAdministrativeWrites() public {
        bytes memory unauthorized = abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, outsider);

        vm.startPrank(outsider);
        vm.expectRevert(unauthorized);
        presale.setTokenPerBNB(PRICE + 1);
        vm.expectRevert(unauthorized);
        presale.setPurchaseLimits(0, 0, 0);
        vm.expectRevert(unauthorized);
        presale.setAllowRepeatPurchase(false);
        vm.expectRevert(unauthorized);
        presale.setMaxTokensSold(INVENTORY + 1);
        vm.expectRevert(unauthorized);
        presale.setTreasuryAddress(address(1));
        vm.expectRevert(unauthorized);
        presale.pause();
        vm.expectRevert(unauthorized);
        presale.unpause();
        vm.expectRevert(unauthorized);
        presale.finalizeSale();
        vm.expectRevert(unauthorized);
        presale.sweepBNB(1);
        vm.expectRevert(unauthorized);
        presale.withdrawUnsoldTokens(outsider, 1);
        vm.expectRevert(unauthorized);
        presale.transferOwnership(outsider);
        vm.expectRevert(unauthorized);
        presale.renounceOwnership();
        vm.stopPrank();
    }

    function test_OwnerUpdatesPurchaseLimitsAndEvent() public {
        vm.expectEmit(false, false, false, true, address(presale));
        emit PurchaseLimitsUpdated(0.1 ether, 5 ether, 20 ether);
        vm.prank(owner);
        presale.setPurchaseLimits(0.1 ether, 5 ether, 20 ether);

        assertEq(presale.minPurchaseBNB(), 0.1 ether, unicode"最低额度更新错误");
        assertEq(presale.maxPurchaseBNB(), 5 ether, unicode"最高额度更新错误");
        assertEq(presale.maxPurchasePerWallet(), 20 ether, unicode"钱包额度更新错误");
    }

    function test_RevertInvalidUpdatedLimits() public {
        vm.expectRevert(BNBPresale.InvalidPurchaseLimits.selector);
        vm.prank(owner);
        presale.setPurchaseLimits(2 ether, 1 ether, 5 ether);

        vm.expectRevert(BNBPresale.InvalidPurchaseLimits.selector);
        vm.prank(owner);
        presale.setPurchaseLimits(2 ether, 10 ether, 1 ether);
    }

    function test_SetWalletMaximumBelowHistoricalTotalBlocksFuturePurchase() public {
        vm.prank(buyer);
        presale.buy{ value: 2 ether }();

        vm.prank(owner);
        presale.setPurchaseLimits(0, 0, 1 ether);

        vm.expectRevert(BNBPresale.WalletLimitExceeded.selector);
        vm.prank(buyer);
        presale.buy{ value: 1 wei }();
        assertEq(presale.walletBNBSpent(buyer), 2 ether, unicode"历史累计不能被修改");
    }

    function test_OwnerUpdatesRepeatRuleAndEvent() public {
        vm.expectEmit(false, false, false, true, address(presale));
        emit RepeatPurchaseRuleUpdated(false);
        vm.prank(owner);
        presale.setAllowRepeatPurchase(false);
        assertFalse(presale.allowRepeatPurchase(), unicode"重复认购规则更新失败");
    }

    function test_OwnerUpdatesMaximumSaleAndEvent() public {
        uint256 newMaximum = INVENTORY + 1;
        vm.expectEmit(false, false, false, true, address(presale));
        emit MaxTokensSoldUpdated(INVENTORY, newMaximum);
        vm.prank(owner);
        presale.setMaxTokensSold(newMaximum);
        assertEq(presale.maxTokensSold(), newMaximum, unicode"最大销售量更新失败");
    }

    function test_RevertMaximumSaleZeroOrBelowSold() public {
        vm.expectRevert(BNBPresale.InvalidMaxTokensSold.selector);
        vm.prank(owner);
        presale.setMaxTokensSold(0);

        vm.prank(buyer);
        presale.buy{ value: 1 ether }();
        uint256 soldAmount = presale.totalTokensSold();
        vm.expectRevert(BNBPresale.InvalidMaxTokensSold.selector);
        vm.prank(owner);
        presale.setMaxTokensSold(soldAmount - 1);
    }

    function test_OwnerUpdatesTreasuryAndEvent() public {
        address newTreasury = address(0x1234);
        vm.expectEmit(true, true, false, true, address(presale));
        emit TreasuryAddressUpdated(treasury, newTreasury);
        vm.prank(owner);
        presale.setTreasuryAddress(newTreasury);
        assertEq(presale.treasuryAddress(), newTreasury, unicode"Treasury 更新失败");
    }

    function test_RevertZeroTreasury() public {
        vm.expectRevert(BNBPresale.ZeroAddress.selector);
        vm.prank(owner);
        presale.setTreasuryAddress(address(0));
    }

    // ---------------------------------------------------------------------
    // 暂停、最终结束和所有权安全。
    // ---------------------------------------------------------------------

    function test_PauseUnpauseAndFinalizeLifecycle() public {
        vm.prank(owner);
        presale.pause();
        assertTrue(presale.paused(), unicode"暂停失败");

        vm.prank(owner);
        presale.unpause();
        assertFalse(presale.paused(), unicode"恢复失败");

        vm.prank(owner);
        presale.pause();
        vm.expectEmit(true, false, false, true, address(presale));
        emit SaleFinalized(owner);
        vm.prank(owner);
        presale.finalizeSale();

        assertTrue(presale.saleFinalized(), unicode"最终结束失败");
        assertTrue(presale.paused(), unicode"结束后必须保持暂停");

        vm.expectRevert(BNBPresale.SaleAlreadyFinalized.selector);
        vm.prank(owner);
        presale.unpause();
    }

    function test_RevertFinalizeWhileActive() public {
        vm.expectRevert(Pausable.ExpectedPause.selector);
        vm.prank(owner);
        presale.finalizeSale();
    }

    function test_RevertFinalizeTwice() public {
        vm.prank(owner);
        presale.pause();
        vm.prank(owner);
        presale.finalizeSale();
        vm.expectRevert(BNBPresale.SaleAlreadyFinalized.selector);
        vm.prank(owner);
        presale.finalizeSale();
    }

    function test_RevertSaleConfigurationChangesAfterFinalization() public {
        vm.prank(owner);
        presale.pause();
        vm.prank(owner);
        presale.finalizeSale();

        vm.startPrank(owner);
        vm.expectRevert(BNBPresale.SaleAlreadyFinalized.selector);
        presale.setTokenPerBNB(PRICE + 1);
        vm.expectRevert(BNBPresale.SaleAlreadyFinalized.selector);
        presale.setPurchaseLimits(0, 0, 0);
        vm.expectRevert(BNBPresale.SaleAlreadyFinalized.selector);
        presale.setAllowRepeatPurchase(false);
        vm.expectRevert(BNBPresale.SaleAlreadyFinalized.selector);
        presale.setMaxTokensSold(INVENTORY + 1);
        vm.stopPrank();
    }

    function test_TreasuryCanStillChangeAfterFinalization() public {
        vm.prank(owner);
        presale.pause();
        vm.prank(owner);
        presale.finalizeSale();
        vm.prank(owner);
        presale.setTreasuryAddress(address(0x7777));
        assertEq(presale.treasuryAddress(), address(0x7777), unicode"结束后应允许修改 Treasury");
    }

    function test_RevertRenounceOwnership() public {
        vm.expectRevert(BNBPresale.OwnershipRenounceDisabled.selector);
        vm.prank(owner);
        presale.renounceOwnership();
        assertEq(presale.owner(), owner, unicode"Owner 不应丢失");
    }

    function test_Ownable2StepRequiresPendingOwnerAcceptance() public {
        address newOwner = address(0xD00D);
        vm.prank(owner);
        presale.transferOwnership(newOwner);

        assertEq(presale.owner(), owner, unicode"接受前 Owner 不应变化");
        assertEq(presale.pendingOwner(), newOwner, unicode"Pending Owner 错误");

        vm.prank(newOwner);
        presale.acceptOwnership();
        assertEq(presale.owner(), newOwner, unicode"接受后 Owner 错误");
        assertEq(presale.pendingOwner(), address(0), unicode"Pending Owner 应清空");
    }

    function test_Ownable2StepRejectsWrongAcceptorAndSupportsPendingReplacementAndCancellation() public {
        address firstPending = address(0xD001);
        address secondPending = address(0xD002);

        vm.prank(owner);
        presale.transferOwnership(firstPending);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, outsider));
        vm.prank(outsider);
        presale.acceptOwnership();

        vm.prank(owner);
        presale.transferOwnership(secondPending);
        assertEq(presale.pendingOwner(), secondPending, unicode"Pending Owner 替换失败");

        vm.prank(owner);
        presale.transferOwnership(address(0));
        assertEq(presale.pendingOwner(), address(0), unicode"Pending Owner 取消失败");
        assertEq(presale.owner(), owner, unicode"取消 Pending 不得改变 Owner");
    }

    function test_PriceUpdateAndResumeAreAppliedToSubsequentPurchase() public {
        uint256 newPrice = 123_456 * ONE_TOKEN;
        vm.prank(owner);
        presale.pause();
        vm.prank(owner);
        presale.setTokenPerBNB(newPrice);
        vm.prank(owner);
        presale.unpause();

        vm.prank(buyer);
        presale.buy{ value: 1 ether }();
        assertEq(token.balanceOf(buyer), newPrice, unicode"恢复后购买未使用新价格");
    }

    function test_FinalizedPurchaseEmitsNoEventAndFullyRollsBack() public {
        vm.prank(owner);
        presale.pause();
        vm.prank(owner);
        presale.finalizeSale();
        _assertBuyRevertsAndRollsBack(presale, buyer, 1 ether, Pausable.EnforcedPause.selector);
    }

    // ---------------------------------------------------------------------
    // BNB 归集和 TOKEN 提取。
    // ---------------------------------------------------------------------

    function test_SweepBNBSendsOnlyToTreasuryAndEmitsEvent() public {
        vm.prank(buyer);
        presale.buy{ value: 2 ether }();
        uint256 beforeBalance = treasury.balance;

        vm.expectEmit(true, false, false, true, address(presale));
        emit BNBSwept(treasury, 1.5 ether);
        vm.prank(owner);
        presale.sweepBNB(1.5 ether);

        assertEq(treasury.balance, beforeBalance + 1.5 ether, unicode"Treasury 到账错误");
        assertEq(address(presale).balance, 0.5 ether, unicode"合约保留余额错误");
        assertEq(presale.totalBNBRaised(), 2 ether, unicode"归集不得减少累计收入");
    }

    function test_RevertSweepZeroOrAboveBalance() public {
        vm.expectRevert(BNBPresale.InvalidAmount.selector);
        vm.prank(owner);
        presale.sweepBNB(0);

        vm.expectRevert(BNBPresale.InvalidAmount.selector);
        vm.prank(owner);
        presale.sweepBNB(1);
    }

    function test_RevertSweepWhenTreasuryRejectsBNB() public {
        RejectBNBTreasury rejecting = new RejectBNBTreasury();
        vm.prank(owner);
        presale.setTreasuryAddress(address(rejecting));
        vm.prank(buyer);
        presale.buy{ value: 1 ether }();

        vm.expectRevert(BNBPresale.BNBTransferFailed.selector);
        vm.prank(owner);
        presale.sweepBNB(1 ether);
        assertEq(address(presale).balance, 1 ether, unicode"失败归集应完整回滚");
    }

    function test_SweepReentrancyIsBlockedWhileOuterSweepSucceeds() public {
        ReentrantTreasury attacker = new ReentrantTreasury(address(presale));
        vm.prank(owner);
        presale.setTreasuryAddress(address(attacker));
        vm.prank(owner);
        presale.transferOwnership(address(attacker));
        attacker.acceptPresaleOwnership();

        vm.prank(buyer);
        presale.buy{ value: 2 ether }();
        uint256 beforeBalance = address(attacker).balance;
        attacker.attackSweep(1 ether);

        assertTrue(attacker.reentryBlocked(), unicode"归集重入未被阻止");
        assertEq(address(attacker).balance, beforeBalance + 1 ether, unicode"外层归集应成功");
        assertEq(address(presale).balance, 1 ether, unicode"重入不得额外转出 BNB");
    }

    function test_PurchaseReentrancyFromTokenIsBlockedWhilePurchaseSucceeds() public {
        uint256 supply = 1_000_000 * ONE_TOKEN;
        ReentrantSaleToken attackToken = new ReentrantSaleToken(address(this), supply);
        BNBPresale attackPresale = _deployPresale(address(attackToken), owner, treasury, PRICE, 0, 0, 0, true, supply);
        assertTrue(attackToken.transfer(address(attackPresale), supply), "attack inventory transfer failed");
        attackToken.setAttack(address(attackPresale), true);
        vm.deal(address(attackToken), 1 ether);
        vm.prank(owner);
        attackPresale.unpause();

        vm.prank(buyer);
        attackPresale.buy{ value: 1 ether }();

        assertTrue(attackToken.reentryBlocked(), unicode"TOKEN 回调重入未被阻止");
        assertEq(attackPresale.walletPurchaseCount(buyer), 1, unicode"外层购买应成功一次");
        assertEq(attackPresale.walletPurchaseCount(address(attackToken)), 0, unicode"重入购买不得成功");
    }

    function test_RevertWithdrawBeforeFinalizationEvenIfPaused() public {
        vm.prank(owner);
        presale.pause();
        vm.expectRevert(BNBPresale.SaleNotFinalized.selector);
        vm.prank(owner);
        presale.withdrawUnsoldTokens(owner, ONE_TOKEN);
    }

    function test_WithdrawUnsoldTokensAfterFinalization() public {
        vm.prank(owner);
        presale.pause();
        vm.prank(owner);
        presale.finalizeSale();

        uint256 amount = 1000 * ONE_TOKEN;
        uint256 ownerBefore = token.balanceOf(owner);
        vm.expectEmit(true, false, false, true, address(presale));
        emit UnsoldTokensWithdrawn(owner, amount);
        vm.prank(owner);
        presale.withdrawUnsoldTokens(owner, amount);

        assertEq(token.balanceOf(owner), ownerBefore + amount, unicode"未售 TOKEN 提取错误");
        assertEq(presale.tokenInventory(), INVENTORY - amount, unicode"提取后库存错误");
    }

    function test_RevertWithdrawWithZeroRecipientZeroAmountOrExcessAmount() public {
        vm.prank(owner);
        presale.pause();
        vm.prank(owner);
        presale.finalizeSale();

        vm.expectRevert(BNBPresale.ZeroAddress.selector);
        vm.prank(owner);
        presale.withdrawUnsoldTokens(address(0), ONE_TOKEN);

        vm.expectRevert(BNBPresale.InvalidAmount.selector);
        vm.prank(owner);
        presale.withdrawUnsoldTokens(owner, 0);

        vm.expectRevert(BNBPresale.InvalidAmount.selector);
        vm.prank(owner);
        presale.withdrawUnsoldTokens(owner, INVENTORY + 1);
    }

    // ---------------------------------------------------------------------
    // 模糊测试：验证大数乘除、金额边界和统计一致性。
    // ---------------------------------------------------------------------

    function test_MulDivHandles512BitIntermediateProduct() public {
        uint256 bnbAmount = uint256(1) << 200;
        uint256 highPrice = uint256(1) << 100;
        uint256 hugeInventory = type(uint256).max;
        assertTrue(bnbAmount > type(uint256).max / highPrice, unicode"测试必须进入 512 位中间乘积路径");

        MockSaleToken highToken = new MockSaleToken(address(this), hugeInventory);
        BNBPresale highPresale =
            _deployPresale(address(highToken), owner, treasury, highPrice, 0, 0, 0, true, hugeInventory);
        assertTrue(highToken.transfer(address(highPresale), hugeInventory), "high inventory transfer failed");
        vm.prank(owner);
        highPresale.unpause();
        vm.deal(buyer, bnbAmount);

        uint256 expected = Math.mulDiv(bnbAmount, highPrice, 1 ether);
        vm.prank(buyer);
        highPresale.buy{ value: bnbAmount }();

        assertEq(highToken.balanceOf(buyer), expected, unicode"512 位路径实际到账错误");
        assertEq(highPresale.totalTokensSold(), expected, unicode"512 位路径累计 TOKEN 错误");
    }

    function testFuzz_PurchaseCalculationMatchesMathMulDiv(uint192 rawBnb, uint128 rawPrice) public {
        uint256 bnbMinimum = uint256(1) << 160;
        uint256 bnbRange = (uint256(1) << 180) - bnbMinimum;
        uint256 bnbAmount = (uint256(rawBnb) % bnbRange) + bnbMinimum;
        uint256 priceMinimum = uint256(1) << 100;
        uint256 priceRange = (uint256(1) << 110) - priceMinimum;
        uint256 fuzzPrice = (uint256(rawPrice) % priceRange) + priceMinimum;
        uint256 hugeInventory = type(uint256).max;
        assertTrue(bnbAmount > type(uint256).max / fuzzPrice, unicode"fuzz 必须进入 512 位中间乘积路径");

        MockSaleToken fuzzToken = new MockSaleToken(address(this), hugeInventory);
        BNBPresale fuzzPresale =
            _deployPresale(address(fuzzToken), owner, treasury, fuzzPrice, 0, 0, 0, true, hugeInventory);
        assertTrue(fuzzToken.transfer(address(fuzzPresale), hugeInventory), "fuzz inventory transfer failed");
        vm.prank(owner);
        fuzzPresale.unpause();
        vm.deal(buyer, bnbAmount);

        uint256 expected = Math.mulDiv(bnbAmount, fuzzPrice, 1 ether);
        vm.prank(buyer);
        fuzzPresale.buy{ value: bnbAmount }();

        assertEq(fuzzToken.balanceOf(buyer), expected, unicode"模糊计算结果不一致");
        assertEq(fuzzPresale.totalTokensSold(), expected, unicode"模糊累计 TOKEN 不一致");
        assertEq(fuzzPresale.totalBNBRaised(), bnbAmount, unicode"模糊累计 BNB 不一致");
    }

    function testFuzz_ValidPurchaseLimitsCanBeStored(uint96 minimumRaw, uint96 extraMaxRaw, uint96 extraWalletRaw)
        public
    {
        uint256 minimum = uint256(minimumRaw) % (100 ether + 1);
        uint256 maximum = minimum + (uint256(extraMaxRaw) % (100 ether + 1));
        uint256 walletMaximum = minimum + (uint256(extraWalletRaw) % (200 ether + 1));

        vm.prank(owner);
        presale.setPurchaseLimits(minimum, maximum, walletMaximum);

        assertEq(presale.minPurchaseBNB(), minimum, unicode"模糊最低额度错误");
        assertEq(presale.maxPurchaseBNB(), maximum, unicode"模糊最高额度错误");
        assertEq(presale.maxPurchasePerWallet(), walletMaximum, unicode"模糊钱包额度错误");
    }

    function _snapshotPurchaseState(BNBPresale target, address purchaser)
        internal
        view
        returns (PurchaseState memory state)
    {
        state.totalBNBRaised = target.totalBNBRaised();
        state.totalTokensSold = target.totalTokensSold();
        state.walletBNBSpent = target.walletBNBSpent(purchaser);
        state.walletTokensReceived = target.walletTokensReceived(purchaser);
        state.walletPurchaseCount = target.walletPurchaseCount(purchaser);
        state.presaleBNBBalance = address(target).balance;
        state.buyerBNBBalance = purchaser.balance;
        state.presaleTokenBalance = target.saleToken().balanceOf(address(target));
        state.buyerTokenBalance = target.saleToken().balanceOf(purchaser);
    }

    function _assertPurchaseStateEq(PurchaseState memory actual, PurchaseState memory expected) internal pure {
        assertEq(actual.totalBNBRaised, expected.totalBNBRaised, unicode"失败后累计 BNB 改变");
        assertEq(actual.totalTokensSold, expected.totalTokensSold, unicode"失败后累计 TOKEN 改变");
        assertEq(actual.walletBNBSpent, expected.walletBNBSpent, unicode"失败后钱包 BNB 改变");
        assertEq(actual.walletTokensReceived, expected.walletTokensReceived, unicode"失败后钱包 TOKEN 改变");
        assertEq(actual.walletPurchaseCount, expected.walletPurchaseCount, unicode"失败后钱包次数改变");
        assertEq(actual.presaleBNBBalance, expected.presaleBNBBalance, unicode"失败后合约 BNB 改变");
        assertEq(actual.buyerBNBBalance, expected.buyerBNBBalance, unicode"失败后买方 BNB 改变");
        assertEq(actual.presaleTokenBalance, expected.presaleTokenBalance, unicode"失败后库存改变");
        assertEq(actual.buyerTokenBalance, expected.buyerTokenBalance, unicode"失败后买方 TOKEN 改变");
    }

    function _assertBuyRevertsAndRollsBack(
        BNBPresale target,
        address purchaser,
        uint256 amount,
        bytes4 expectedSelector
    ) internal {
        PurchaseState memory beforeState = _snapshotPurchaseState(target, purchaser);
        vm.recordLogs();
        vm.prank(purchaser);
        (bool success, bytes memory revertData) =
            address(target).call{ value: amount }(abi.encodeWithSelector(BNBPresale.buy.selector));
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertFalse(success, unicode"预期失败的认购却成功");
        assertEq(
            bytes32(_selectorFromRevertData(revertData)),
            bytes32(expectedSelector),
            unicode"认购失败选择器不一致"
        );
        assertEq(_countPurchaseEvents(logs, address(target)), 0, unicode"失败认购不得发出 PurchaseCompleted");
        PurchaseState memory afterState = _snapshotPurchaseState(target, purchaser);
        _assertPurchaseStateEq(afterState, beforeState);
    }

    function _selectorFromRevertData(bytes memory revertData) internal pure returns (bytes4 selector) {
        if (revertData.length < 4) return bytes4(0);
        assembly {
            selector := mload(add(revertData, 32))
        }
    }

    function _countPurchaseEvents(Vm.Log[] memory logs, address emitter) internal pure returns (uint256 count) {
        for (uint256 i = 0; i < logs.length; ++i) {
            if (
                logs[i].emitter == emitter && logs[i].topics.length > 0 && logs[i].topics[0] == PURCHASE_COMPLETED_TOPIC
            ) {
                ++count;
            }
        }
    }

    function _assertPurchaseEvent(Vm.Log[] memory logs, address emitter, PurchaseEventExpectation memory expected)
        internal
        pure
    {
        for (uint256 i = 0; i < logs.length; ++i) {
            if (
                logs[i].emitter != emitter || logs[i].topics.length < 2 || logs[i].topics[0] != PURCHASE_COMPLETED_TOPIC
            ) {
                continue;
            }
            address loggedBuyer = address(uint160(uint256(logs[i].topics[1])));
            PurchaseEventData memory actual = abi.decode(logs[i].data, (PurchaseEventData));
            assertEq(loggedBuyer, expected.buyer, unicode"购买事件 buyer 错误");
            assertEq(actual.bnbAmount, expected.data.bnbAmount, unicode"购买事件 BNB 错误");
            assertEq(actual.tokenAmount, expected.data.tokenAmount, unicode"购买事件 TOKEN 错误");
            assertEq(actual.tokenPerBNB, expected.data.tokenPerBNB, unicode"购买事件价格错误");
            assertEq(actual.walletPurchaseCount, expected.data.walletPurchaseCount, unicode"购买事件次数错误");
            assertEq(actual.totalBNBRaised, expected.data.totalBNBRaised, unicode"购买事件累计 BNB 错误");
            assertEq(actual.totalTokensSold, expected.data.totalTokensSold, unicode"购买事件累计 TOKEN 错误");
            return;
        }
        revert AssertionFailed(unicode"未找到 PurchaseCompleted 事件");
    }

    function _deployPresale(
        address tokenAddress,
        address initialOwner,
        address initialTreasury,
        uint256 initialPrice,
        uint256 minimum,
        uint256 maximum,
        uint256 walletMaximum,
        bool repeatAllowed,
        uint256 maximumTokens
    ) internal returns (BNBPresale deployed) {
        deployed = new BNBPresale(
            initialOwner,
            tokenAddress,
            initialTreasury,
            initialPrice,
            minimum,
            maximum,
            walletMaximum,
            repeatAllowed,
            maximumTokens
        );
    }
}
