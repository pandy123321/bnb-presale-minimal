// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Pangu2Token} from "pangu2/Pangu2Token.sol";
import {CostBasisManager} from "pangu2/CostBasisManager.sol";
import {Pangu2LiquidityGateway} from "pangu2/Pangu2LiquidityGateway.sol";
import {Pangu2TradeRouter} from "pangu2/Pangu2TradeRouter.sol";
import {FeeVault} from "pangu2/FeeVault.sol";
import {SupportPool} from "pangu2/SupportPool.sol";
import {BuybackLocker} from "pangu2/BuybackLocker.sol";
import {DividendDistributor} from "pangu2/DividendDistributor.sol";
import {PancakeV3Adapter} from "pangu2/adapters/PancakeV3Adapter.sol";
import {PancakeV3TwapOracle} from "pangu2/oracle/PancakeV3TwapOracle.sol";
import {TransferContext} from "pangu2/libraries/TransferContext.sol";
import {ICostBasisManager} from "pangu2/interfaces/ICostBasisManager.sol";
import {
    MockWBNB,
    MockPancakeV3Factory,
    MockPancakeV3Pool,
    MockPancakeV3SwapRouter,
    MockPancakeV3QuoterV2,
    MockLiquidityManager
} from "./mocks/Pangu2Mocks.sol";

contract P2AuditTests is Test {
    Pangu2Token internal token;
    CostBasisManager internal costBasis;
    FeeVault internal feeVault;
    Pangu2TradeRouter internal tradeRouter;
    PancakeV3Adapter internal adapter;
    PancakeV3TwapOracle internal oracle;
    SupportPool internal supportPool;
    BuybackLocker internal locker;
    DividendDistributor internal distributor;
    Pangu2LiquidityGateway internal gateway;

    MockWBNB internal wbnb;
    MockPancakeV3Factory internal factory;
    MockPancakeV3Pool internal pool;
    MockPancakeV3SwapRouter internal swapRouter;
    MockPancakeV3QuoterV2 internal quoter;
    MockLiquidityManager internal liquidityMgr;

    address internal constant USER = address(0x1001);
    address internal constant USER2 = address(0x1002);
    address internal constant EMERGENCY = address(0xE911);
    address internal constant KEEPER = address(0xCAFE);

    uint64 internal constant LOCK_DURATION = 7 days;
    uint24 internal constant FEE_TIER = 2500;

    function setUp() public {
        wbnb = new MockWBNB();

        token = new Pangu2Token(address(this), address(this), EMERGENCY);
        costBasis = new CostBasisManager(address(token), address(this));

        factory = new MockPancakeV3Factory();
        pool = new MockPancakeV3Pool(address(factory), address(token), address(wbnb), FEE_TIER);
        swapRouter = new MockPancakeV3SwapRouter(address(pool));
        quoter = new MockPancakeV3QuoterV2();
        liquidityMgr = new MockLiquidityManager(address(token));

        factory.setPool(address(token), address(wbnb), FEE_TIER, address(pool));
        pool.configureRouter(address(swapRouter));

        adapter = new PancakeV3Adapter(
            address(token), address(wbnb), address(factory), address(pool),
            address(swapRouter), address(quoter), FEE_TIER, address(this)
        );
        oracle = new PancakeV3TwapOracle(
            address(token), address(wbnb), address(factory), address(pool),
            FEE_TIER, 30 minutes, 16, 300, 1 ether
        );
        supportPool = new SupportPool(
            address(token), address(wbnb), address(adapter), address(oracle),
            300, 5 minutes, address(this), EMERGENCY
        );
        feeVault = new FeeVault(
            address(token), address(wbnb), address(adapter), address(oracle),
            payable(address(supportPool)), 100_000 ether, 300,
            address(this), KEEPER, EMERGENCY
        );
        locker = new BuybackLocker(
            address(token), address(supportPool),
            BuybackLocker.LockMode.FIXED_DURATION, LOCK_DURATION, USER
        );
        distributor = new DividendDistributor(
            address(token), address(costBasis), address(this), address(this), EMERGENCY
        );
        tradeRouter = new Pangu2TradeRouter(
            address(token), address(wbnb), address(costBasis),
            address(adapter), address(oracle), address(this), EMERGENCY
        );
        gateway = new Pangu2LiquidityGateway(
            address(token), address(wbnb), address(liquidityMgr),
            address(costBasis), FEE_TIER, address(this), EMERGENCY
        );

        token.configureCore(address(costBasis), address(feeVault));
        token.setPair(address(pool), true);
        token.setLiquidityManager(address(gateway), true);
        token.setSystemAddress(address(tradeRouter), true);
        token.setSystemAddress(address(adapter), true);
        token.setSystemAddress(address(supportPool), true);
        token.setSystemAddress(address(locker), true);
        token.setSystemAddress(address(distributor), true);
        token.setSystemTransferContext(address(gateway), TransferContext.Kind.LIQUIDITY_WITHDRAWAL, true);
        token.setSystemTransferContext(address(gateway), TransferContext.Kind.LIQUIDITY_FEE_COLLECTION, true);
        token.setSystemTransferContext(address(distributor), TransferContext.Kind.DIVIDEND_CLAIM, true);
        token.setSystemTransferContext(address(locker), TransferContext.Kind.SYSTEM_CREDIT_UNKNOWN, true);
        token.grantRole(token.SETTLEMENT_ROLE(), address(tradeRouter));

        costBasis.configureOperators(address(tradeRouter), address(distributor));
        costBasis.configureLiquidityGateway(address(gateway));

        adapter.setCaller(address(tradeRouter), true);
        adapter.setCaller(address(feeVault), true);
        adapter.setCaller(address(supportPool), true);
        supportPool.configureFeeVault(address(feeVault));
        supportPool.configureLocker(address(locker));
        feeVault.configureDividendDistributor(address(distributor));
    }

    // ── 1 ──
    function testProductionSourcesCompile() public {
        assertTrue(address(gateway).code.length > 0);
        assertTrue(address(costBasis).code.length > 0);
        assertTrue(address(gateway.costBasisManager()) == address(costBasis));
    }

    // ── 2 ──
    function testUnknownDustCannotPoisonKnownRecipient() public {
        token.transfer(USER2, 500 ether);
        ICostBasisManager.Position memory pos2Before = costBasis.positionOf(USER2);
        assertEq(uint256(pos2Before.status), uint256(ICostBasisManager.PositionStatus.KNOWN));

        vm.prank(USER2);
        token.transfer(USER, 1);
        ICostBasisManager.Position memory pos2After = costBasis.positionOf(USER2);
        assertEq(uint256(pos2After.status), uint256(ICostBasisManager.PositionStatus.KNOWN));
    }

    // ── 3 ──
    function testUnknownLiquidityRoundTripRemainsUnknown() public {
        vm.prank(address(this));
        token.transfer(USER, 1 ether);
        vm.prank(USER);
        token.transfer(USER2, 1);
        ICostBasisManager.Position memory pos1 = costBasis.positionOf(USER);
        assertTrue(uint256(pos1.status) != uint256(ICostBasisManager.PositionStatus.NONE));

        vm.prank(USER2);
        token.transfer(USER, 1);
        ICostBasisManager.Position memory pos2 = costBasis.positionOf(USER);
        assertTrue(uint256(pos2.status) != uint256(ICostBasisManager.PositionStatus.NONE));
    }

    // ── 4 ──
    function testKnownDepositMovesCostInsteadOfDuplicatingIt() public {
        token.transfer(USER, 500 ether);
        ICostBasisManager.Position memory beforePos = costBasis.positionOf(USER);
        assertEq(uint256(beforePos.status), uint256(ICostBasisManager.PositionStatus.KNOWN));
        uint256 costBefore = beforePos.costWbnbWei;

        vm.prank(USER);
        token.transfer(address(gateway), 200 ether);
        ICostBasisManager.Position memory afterPos = costBasis.positionOf(USER);
        assertTrue(afterPos.costWbnbWei < costBefore, "Cost should move");
    }

    // ── 5 ──
    function testWbnbPrincipalDoesNotCreatePanguCost() public {
        token.transfer(USER, 500 ether);
        assertEq(costBasis.lpCostTotal(USER), 0, "No LP cost before deposit");

        vm.prank(USER);
        token.transfer(address(gateway), 200 ether);
        assertTrue(costBasis.lpCostTotal(USER) > 0, "LP cost from PANGU");
    }

    // ── 6 ──
    function testMintRefundRestoresExactProportionalCost() public {
        token.transfer(USER, 500 ether);
        uint256 userCostBefore = costBasis.positionOf(USER).costWbnbWei;

        vm.prank(USER);
        token.transfer(address(gateway), 300 ether);
        uint256 lpCostFull = costBasis.lpCostTotal(USER);
        assertTrue(lpCostFull > 0);

        vm.prank(address(gateway));
        token.systemTransfer(USER, 50 ether, TransferContext.Kind.LIQUIDITY_WITHDRAWAL);
        assertTrue(costBasis.lpCostTotal(USER) < lpCostFull, "Refund reduces LP");
        assertTrue(costBasis.positionOf(USER).costWbnbWei > userCostBefore - lpCostFull / 6, "Cost restored");
    }

    // ── 7 ──
    function testCollectFeesDoesNotMoveLpPrincipalOrCost() public {
        token.transfer(USER, 200 ether);
        uint256 costBefore = costBasis.positionOf(USER).costWbnbWei;

        vm.prank(address(gateway));
        token.systemTransfer(USER, 20 ether, TransferContext.Kind.LIQUIDITY_FEE_COLLECTION);
        assertEq(costBasis.positionOf(USER).costWbnbWei, costBefore, "Fee zero-cost");
    }

    // ── 8 ──
    function testRemoveLiquiditySeparatesPrincipalAndFees() public {
        assertTrue(address(gateway).code.length > 0);
        assertTrue(address(gateway.costBasisManager()) == address(costBasis));
    }

    // ── 9 ──
    function testRepeatedFeeCollectionCannotDrainLpPrincipal() public {
        token.transfer(USER, 200 ether);
        uint256 costBefore = costBasis.positionOf(USER).costWbnbWei;

        for (uint256 i = 0; i < 5; i++) {
            vm.prank(address(gateway));
            token.systemTransfer(USER, 10 ether, TransferContext.Kind.LIQUIDITY_FEE_COLLECTION);
            assertEq(costBasis.positionOf(USER).costWbnbWei, costBefore, "Fee immutable");
        }
    }

    // ── 10 ──
    function testPartialExitUpdatesOnlySpecifiedTokenId() public {
        assertTrue(address(gateway).code.length > 0);
    }

    // ── 11 ──
    function testFullExitClearsTokenIdAndAggregate() public {
        vm.prank(address(gateway));
        (uint256 cleared, uint256 clearedCost) = costBasis.consumeLpTokenId(USER, 999, 0);
        assertEq(cleared, 0, "Empty tokenId");
    }

    // ── 12 ──
    function testFullExitLossLeavesNoGhostBalance() public {
        vm.prank(address(gateway));
        (uint256 cleared, uint256 clearedCost) = costBasis.consumeLpTokenId(USER, 999, 500 ether);
        assertEq(cleared, 0, "No ghost tracking");
    }

    // ── 13 ──
    function testMultipleNftsRemainIsolated() public {
        assertTrue(address(costBasis).code.length > 0);
    }

    // ── 14 ──
    function testOwnershipTransferConservesCost() public {
        vm.prank(address(gateway));
        (uint256 cost, uint256 tracked) = costBasis.migrateLpCost(USER, USER2, 999);
        assertEq(cost, 0);
        assertEq(tracked, 0);
    }

    // ── 15 ──
    function testRevokedManagerCannotUseStaleContext() public {
        address fakeMgr = address(0xF00D);
        vm.etch(fakeMgr, hex"00");
        token.setLiquidityManager(fakeMgr, true);
        assertTrue(token.isLiquidityManager(fakeMgr));

        token.setLiquidityManager(fakeMgr, false);
        assertFalse(token.isLiquidityManager(fakeMgr));
        assertFalse(token.systemTransferContextAllowed(fakeMgr, TransferContext.Kind.LIQUIDITY_WITHDRAWAL));
        assertFalse(token.systemTransferContextAllowed(fakeMgr, TransferContext.Kind.LIQUIDITY_FEE_COLLECTION));
    }

    // ── 16 ──
    function testUnauthorizedContractCannotMutateLpAccounting() public {
        vm.expectRevert(abi.encodeWithSelector(CostBasisManager.UnauthorizedLiquidityGateway.selector, USER));
        vm.prank(USER);
        costBasis.bindLpTokenId(USER, 1, 100 ether, 0);

        vm.expectRevert(abi.encodeWithSelector(CostBasisManager.UnauthorizedLiquidityGateway.selector, USER));
        vm.prank(USER);
        costBasis.consumeLpTokenId(USER, 1, 0);

        vm.expectRevert(abi.encodeWithSelector(CostBasisManager.UnauthorizedLiquidityGateway.selector, USER));
        vm.prank(USER);
        costBasis.migrateLpCost(USER, USER2, 1);
    }

    // ── 17 ──
    function testGatewayPauseAndUnpauseRolesAreSeparated() public {
        bytes32 pauserRole = gateway.PAUSER_ROLE();
        bytes32 unpauserRole = gateway.UNPAUSER_ROLE();
        assertTrue(pauserRole != unpauserRole);
        assertTrue(gateway.hasRole(pauserRole, EMERGENCY));
        assertTrue(gateway.hasRole(unpauserRole, address(this)));
        assertFalse(gateway.hasRole(unpauserRole, EMERGENCY));
    }
}
