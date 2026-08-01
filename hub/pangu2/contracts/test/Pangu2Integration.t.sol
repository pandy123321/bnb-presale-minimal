// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Pangu2Token} from "pangu2/Pangu2Token.sol";
import {Pangu2TradeRouter} from "pangu2/Pangu2TradeRouter.sol";
import {CostBasisManager} from "pangu2/CostBasisManager.sol";
import {FeeVault} from "pangu2/FeeVault.sol";
import {SupportPool} from "pangu2/SupportPool.sol";
import {BuybackLocker} from "pangu2/BuybackLocker.sol";
import {DividendDistributor} from "pangu2/DividendDistributor.sol";
import {GovernanceAdapter} from "pangu2/GovernanceAdapter.sol";
import {PancakeV3Adapter} from "pangu2/adapters/PancakeV3Adapter.sol";
import {PancakeV3TwapOracle} from "pangu2/oracle/PancakeV3TwapOracle.sol";
import {ICostBasisManager} from "pangu2/interfaces/ICostBasisManager.sol";
import {IDividendDistributor} from "pangu2/interfaces/IDividendDistributor.sol";
import {TransferContext} from "pangu2/libraries/TransferContext.sol";
import {
    MockWBNB,
    MockPancakeV3Factory,
    MockPancakeV3Pool,
    MockPancakeV3SwapRouter,
    MockPancakeV3QuoterV2,
    MockGovernedTarget,
    MockLiquidityManager
} from "./mocks/Pangu2Mocks.sol";

contract Pangu2IntegrationTest is Test {
    uint24 internal constant FEE_TIER = 2500;
    address internal constant USER = address(0xBEEF);
    address internal constant EMERGENCY = address(0xE911);
    address internal constant KEEPER = address(0xCAFE);
    address internal constant RELEASE_RECIPIENT = address(0xA11CE);

    Pangu2Token internal token;
    MockWBNB internal wbnb;
    MockPancakeV3Factory internal factory;
    MockPancakeV3Pool internal pool;
    MockPancakeV3SwapRouter internal swapRouter;
    MockPancakeV3QuoterV2 internal quoter;
    CostBasisManager internal costBasis;
    PancakeV3Adapter internal adapter;
    PancakeV3TwapOracle internal oracle;
    SupportPool internal supportPool;
    FeeVault internal feeVault;
    BuybackLocker internal locker;
    DividendDistributor internal distributor;
    Pangu2TradeRouter internal tradeRouter;
    MockLiquidityManager internal liquidityManager;

    function setUp() public virtual {
        vm.deal(address(this), 1_000 ether);
        vm.deal(USER, 100 ether);
        token = new Pangu2Token(address(this), address(this), EMERGENCY);
        wbnb = new MockWBNB();
        factory = new MockPancakeV3Factory();
        pool = new MockPancakeV3Pool(address(factory), address(token), address(wbnb), FEE_TIER);
        factory.setPool(address(token), address(wbnb), FEE_TIER, address(pool));
        swapRouter = new MockPancakeV3SwapRouter(address(pool));
        quoter = new MockPancakeV3QuoterV2();
        pool.configureRouter(address(swapRouter));
        costBasis = new CostBasisManager(address(token), address(this));
        adapter = new PancakeV3Adapter(address(token), address(wbnb), address(factory), address(pool), address(swapRouter), address(quoter), FEE_TIER, address(this));
        oracle = new PancakeV3TwapOracle(address(token), address(wbnb), address(factory), address(pool), FEE_TIER, 30 minutes, 16, 300, 1);
        supportPool = new SupportPool(address(token), address(wbnb), address(adapter), address(oracle), 300, 5 minutes, address(this), EMERGENCY);
        feeVault = new FeeVault(address(token), address(wbnb), address(adapter), address(oracle), payable(address(supportPool)), 1_000_000 ether, 300, address(this), KEEPER, EMERGENCY);
        // TEST_FIXTURE_ONLY: 7 days is not a frozen deployment parameter.
        locker = new BuybackLocker(address(token), address(supportPool), BuybackLocker.LockMode.FIXED_DURATION, 7 days, RELEASE_RECIPIENT);
        distributor = new DividendDistributor(address(token), address(costBasis), address(this), address(this), EMERGENCY);
        tradeRouter = new Pangu2TradeRouter(address(token), address(wbnb), address(costBasis), address(adapter), address(oracle), address(this), EMERGENCY);
        liquidityManager = new MockLiquidityManager(address(token));

        token.configureCore(address(costBasis), address(feeVault));
        token.setPair(address(pool), true);
        token.setLiquidityManager(address(liquidityManager), true);
        token.setSystemAddress(address(tradeRouter), true);
        token.setSystemAddress(address(adapter), true);
        token.setSystemAddress(address(supportPool), true);
        token.setSystemAddress(address(locker), true);
        token.setSystemAddress(address(distributor), true);
        token.setSystemTransferContext(address(liquidityManager), TransferContext.Kind.LIQUIDITY_WITHDRAWAL, true);
        token.setSystemTransferContext(address(liquidityManager), TransferContext.Kind.SYSTEM_CREDIT_UNKNOWN, true);
        token.setSystemTransferContext(address(distributor), TransferContext.Kind.DIVIDEND_CLAIM, true);
        token.setSystemTransferContext(address(locker), TransferContext.Kind.SYSTEM_CREDIT_UNKNOWN, true);
        token.grantRole(token.SETTLEMENT_ROLE(), address(tradeRouter));
        costBasis.configureOperators(address(tradeRouter), address(distributor));
        adapter.setCaller(address(tradeRouter), true);
        adapter.setCaller(address(feeVault), true);
        adapter.setCaller(address(supportPool), true);
        supportPool.configureFeeVault(address(feeVault));
        supportPool.configureLocker(address(locker));
        feeVault.configureDividendDistributor(address(distributor));

        token.approve(address(liquidityManager), 10_000_000 ether);
        liquidityManager.depositToPair(address(this), address(pool), 10_000_000 ether);
        wbnb.deposit{value: 500 ether}();
        wbnb.transfer(address(pool), 400 ether);
    }

    function testFixedSupplyAndNoPublicMint() public view {
        assertEq(token.totalSupply(), 1_000_000_000 ether);
        assertEq(token.decimals(), 18);
    }

    function testDirectUserPairInteractionIsRejected() public {
        token.transfer(USER, 10 ether);
        vm.prank(USER);
        vm.expectRevert(Pangu2Token.DirectPairInteractionForbidden.selector);
        token.transfer(address(pool), 1 ether);
    }

    function testUnknownCostUsesTenPercentSellTax() public {
        token.transfer(USER, 10 ether);
        Pangu2TradeRouter.SellPreview memory preview = tradeRouter.previewSell(USER, 1 ether);
        assertEq(preview.taxBps, 1_000);
        assertEq(uint256(preview.costStatus), uint256(ICostBasisManager.PositionStatus.UNKNOWN));
    }

    function testBuyNormalSellConvertBuybackAndDividendClaim() public {
        vm.prank(USER);
        uint256 netBought = tradeRouter.buy{value: 10 ether}(9 ether, block.timestamp + 5 minutes);
        assertEq(netBought, 9.6 ether);
        assertEq(token.balanceOf(USER), 9.6 ether);
        assertEq(feeVault.dividendBalance(), 0.4 ether);
        ICostBasisManager.Position memory position = costBasis.positionOf(USER);
        assertEq(position.costWbnbWei, 10 ether);
        assertEq(position.trackedBalance, 9.6 ether);
        assertEq(uint256(position.status), uint256(ICostBasisManager.PositionStatus.KNOWN));
        vm.startPrank(USER);
        token.approve(address(tradeRouter), 1 ether);
        uint256 bnbOut = tradeRouter.sell(1 ether, 0.9 ether, block.timestamp + 5 minutes);
        vm.stopPrank();
        assertEq(bnbOut, 0.96 ether);
        assertEq(feeVault.supportBalance(), 0.04 ether);
        vm.prank(KEEPER);
        uint256 converted = feeVault.convertSupport(0.04 ether, 0.03 ether, block.timestamp + 5 minutes);
        assertEq(converted, 0.04 ether);
        assertEq(address(supportPool).balance, 0.04 ether);
        uint256 boughtBack = supportPool.buyback();
        assertEq(boughtBack, 0.01 ether);
        assertEq(token.balanceOf(address(locker)), 0.01 ether);
        assertEq(locker.outstandingLocked(), 0.01 ether);
        assertEq(address(supportPool).balance, 0.03 ether);
        feeVault.fundDividendDistributor(0.1 ether);
        bytes32 leaf = distributor.leafFor(1, USER, 0.1 ether);
        _approveAndPublishEpoch(1, leaf, 0.1 ether, keccak256("epoch-1-artifact"));
        bytes32[] memory proof = new bytes32[](0);
        vm.prank(USER);
        distributor.claim(1, 0.1 ether, proof);
        assertEq(token.balanceOf(USER), 8.7 ether);
    }

    function testBuybackFailureDoesNotAdvanceTimestamp() public {
        assertEq(supportPool.lastSuccessfulBuybackAt(), 0);
        vm.expectRevert();
        supportPool.buyback();
        assertEq(supportPool.lastSuccessfulBuybackAt(), 0);
    }

    function testGovernanceAdapterRestrictsSelectorAndValue() public {
        GovernanceAdapter governanceAdapter = new GovernanceAdapter(address(this));
        MockGovernedTarget target = new MockGovernedTarget();
        governanceAdapter.setPermission(address(target), MockGovernedTarget.setValue.selector, true, 1 ether);
        bytes memory data = abi.encodeCall(MockGovernedTarget.setValue, (7));
        bytes memory result = governanceAdapter.execute(address(target), 0, data);
        assertEq(abi.decode(result, (uint256)), 7);
        assertEq(target.value(), 7);
        vm.expectRevert(GovernanceAdapter.PermissionDenied.selector);
        governanceAdapter.execute{value: 2 ether}(address(target), 2 ether, data);
    }

    function testFuzz_OrdinaryTransferDoesNotApplyTax(uint96 rawAmount) public {
        uint256 amount = bound(uint256(rawAmount), 1, 1_000_000 ether);
        address recipient = address(0x1234);
        uint256 supplyBefore = token.totalSupply();
        token.transfer(recipient, amount);
        assertEq(token.balanceOf(recipient), amount);
        assertEq(token.totalSupply(), supplyBefore);
    }

    function _approveAndPublishEpoch(uint256 epochId, bytes32 root, uint256 totalAmount, bytes32 artifactChecksum) internal {
        IDividendDistributor.EpochCommitment memory commitment = IDividendDistributor.EpochCommitment({
            merkleRoot: root,
            artifactChecksum: artifactChecksum,
            totalAmount: totalAmount,
            claimStart: uint64(block.timestamp),
            claimEnd: uint64(block.timestamp + 30 days),
            snapshotBlock: uint32(block.number),
            schemaVersion: 1
        });
        distributor.approveEpochCommitment(epochId, commitment);
        distributor.publishEpoch(epochId, commitment);
    }
}
