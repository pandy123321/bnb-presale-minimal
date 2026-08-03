// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Pangu2Token} from "pangu2/Pangu2Token.sol";
import {Pangu2TradeRouter} from "pangu2/Pangu2TradeRouter.sol";
import {CostBasisManager} from "pangu2/CostBasisManager.sol";
import {FeeVault} from "pangu2/FeeVault.sol";
import {SupportPool} from "pangu2/SupportPool.sol";
import {BuybackLocker} from "pangu2/BuybackLocker.sol";
import {DividendDistributor} from "pangu2/DividendDistributor.sol";
import {PancakeV2Adapter} from "pangu2/adapters/PancakeV2Adapter.sol";
import {PancakeV2TwapOracle} from "pangu2/oracle/PancakeV2TwapOracle.sol";
import {IPancakeFactory, IPancakePair, IPancakeRouter01, IWBNB} from "pangu2/interfaces/IPancakeV2.sol";
import {ICostBasisManager} from "pangu2/interfaces/ICostBasisManager.sol";
import {IDividendDistributor} from "pangu2/interfaces/IDividendDistributor.sol";
import {TransferContext} from "pangu2/libraries/TransferContext.sol";

contract PancakeV2BscTestnetForkTest is Test {
    uint64 internal constant TEST_FIXTURE_LOCK_DURATION = 7 days;
    address internal constant WBNB = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;
    address internal constant FACTORY = 0x6725F303b657a9451d8BA641348b6761A6CC7a17;
    address internal constant ROUTER = 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3;

    address internal constant USER = address(0xBEEF);
    address internal constant EMERGENCY = address(0xE911);
    address internal constant KEEPER = address(0xCAFE);
    address internal constant RELEASE_RECIPIENT = address(0xA11CE);

    Pangu2Token internal token;
    CostBasisManager internal costBasis;
    PancakeV2Adapter internal adapter;
    PancakeV2TwapOracle internal oracle;
    SupportPool internal supportPool;
    FeeVault internal feeVault;
    BuybackLocker internal locker;
    DividendDistributor internal distributor;
    Pangu2TradeRouter internal tradeRouter;
    address internal pair;

    function setUp() public {
        string memory rpc = vm.envString("BSC_TESTNET_RPC_URL");
        uint256 forkBlock = vm.envUint("BSC_TESTNET_FORK_BLOCK");
        vm.createSelectFork(rpc, forkBlock);
        assertEq(block.chainid, 97);
        assertGt(WBNB.code.length, 0);
        assertGt(FACTORY.code.length, 0);
        assertGt(ROUTER.code.length, 0);

        vm.deal(address(this), 5_000 ether);
        vm.deal(USER, 100 ether);

        token = new Pangu2Token(address(this), address(this), EMERGENCY);
        costBasis = new CostBasisManager(address(token), address(this));

        // Create V2 pair via factory
        pair = IPancakeFactory(FACTORY).createPair(address(token), WBNB);

        adapter = new PancakeV2Adapter(address(token), WBNB, FACTORY, pair, ROUTER, address(this));
        oracle = new PancakeV2TwapOracle(address(token), WBNB, FACTORY, pair, 30 minutes, 300, 1, 1);
        supportPool = new SupportPool(address(token), WBNB, address(adapter), address(oracle), 300, 5 minutes, address(this), EMERGENCY);
        feeVault = new FeeVault(address(token), WBNB, address(adapter), address(oracle), payable(address(supportPool)), 1_000_000 ether, 300, address(this), KEEPER, EMERGENCY);
        locker = new BuybackLocker(address(token), address(supportPool), BuybackLocker.LockMode.FIXED_DURATION, TEST_FIXTURE_LOCK_DURATION, RELEASE_RECIPIENT);
        distributor = new DividendDistributor(address(token), address(costBasis), address(this), address(this), EMERGENCY);
        tradeRouter = new Pangu2TradeRouter(address(token), WBNB, address(costBasis), address(adapter), address(oracle), address(this), EMERGENCY);

        token.configureCore(address(costBasis), address(feeVault));
        token.setPair(pair, true);
        token.setSystemAddress(address(tradeRouter), true);
        token.setSystemAddress(address(adapter), true);
        token.setSystemAddress(address(supportPool), true);
        token.setSystemAddress(address(locker), true);
        token.setSystemAddress(address(distributor), true);
        token.setSystemTransferContext(address(distributor), TransferContext.Kind.DIVIDEND_CLAIM, true);
        token.setSystemTransferContext(address(locker), TransferContext.Kind.SYSTEM_CREDIT_UNKNOWN, true);
        token.grantRole(token.SETTLEMENT_ROLE(), address(tradeRouter));
        costBasis.configureOperators(address(tradeRouter), address(distributor));
        costBasis.configureLiquidityGateway(address(adapter));
        adapter.setCaller(address(tradeRouter), true);
        adapter.setCaller(address(feeVault), true);
        adapter.setCaller(address(supportPool), true);
        adapter.setCaller(address(this), true);
        supportPool.configureFeeVault(address(feeVault));
        supportPool.configureLocker(address(locker));
        feeVault.configureDividendDistributor(address(distributor));

        // Add initial liquidity to V2 pair
        IWBNB(WBNB).deposit{value: 2_000 ether}();
        token.approve(address(ROUTER), 1_000 ether);
        IERC20(WBNB).approve(address(ROUTER), 1_000 ether);
        IPancakeRouter01(ROUTER).addLiquidity(address(token), WBNB, 1_000 ether, 1_000 ether, 900 ether, 900 ether, address(this), block.timestamp + 5 minutes);
    }

    function testRealPancakeV2BuyAndSell() public {
        vm.prank(USER);
        tradeRouter.buy{value: 10 ether}(1, block.timestamp + 5 minutes);

        Pangu2TradeRouter.SellPreview memory preview = tradeRouter.previewSell(USER, 1 ether);
        assertEq(preview.taxBps, token.NORMAL_SELL_TAX_BPS());

        vm.startPrank(USER);
        token.approve(address(tradeRouter), 1 ether);
        tradeRouter.sell(1 ether, 1, block.timestamp + 5 minutes);
        vm.stopPrank();
    }

    function testRealPancakeV2DividendAndBuyback() public {
        vm.prank(USER);
        tradeRouter.buy{value: 5 ether}(1, block.timestamp + 5 minutes);
        vm.startPrank(USER);
        token.approve(address(tradeRouter), 1 ether);
        tradeRouter.sell(1 ether, 1, block.timestamp + 5 minutes);
        vm.stopPrank();

        uint256 supportTokens = feeVault.supportBalance();
        vm.prank(KEEPER);
        feeVault.convertSupport(supportTokens, 1, block.timestamp + 5 minutes);
        assertGe(address(supportPool).balance, supportPool.BUYBACK_AMOUNT());
        uint256 boughtBack = supportPool.buyback();
        assertGt(boughtBack, 0);
        assertEq(locker.outstandingLocked(), boughtBack);

        uint256 epochTotal = feeVault.dividendBalance() / 2;
        feeVault.fundDividendDistributor(epochTotal);
        uint256 claimAmount = epochTotal / 2;
        bytes32 root = distributor.leafFor(1, USER, claimAmount);
        IDividendDistributor.EpochCommitment memory c = IDividendDistributor.EpochCommitment({
            merkleRoot: root,
            artifactChecksum: keccak256("BSC_TESTNET_V2_EPOCH_1"),
            totalAmount: epochTotal,
            claimStart: uint64(block.timestamp),
            claimEnd: uint64(block.timestamp + 30 days),
            snapshotBlock: uint32(block.number),
            schemaVersion: 1
        });
        distributor.approveEpochCommitment(1, c);
        distributor.publishEpoch(1, c);
        bytes32[] memory proof = new bytes32[](0);
        vm.prank(USER);
        distributor.claim(1, claimAmount, proof);
    }
}
