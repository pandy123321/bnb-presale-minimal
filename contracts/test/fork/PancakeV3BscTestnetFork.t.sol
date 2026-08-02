// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Pangu2Token} from "pangu2/Pangu2Token.sol";
import {Pangu2TradeRouter} from "pangu2/Pangu2TradeRouter.sol";
import {Pangu2LiquidityGateway} from "pangu2/Pangu2LiquidityGateway.sol";
import {CostBasisManager} from "pangu2/CostBasisManager.sol";
import {FeeVault} from "pangu2/FeeVault.sol";
import {SupportPool} from "pangu2/SupportPool.sol";
import {BuybackLocker} from "pangu2/BuybackLocker.sol";
import {DividendDistributor} from "pangu2/DividendDistributor.sol";
import {PancakeV3Adapter} from "pangu2/adapters/PancakeV3Adapter.sol";
import {PancakeV3TwapOracle} from "pangu2/oracle/PancakeV3TwapOracle.sol";
import {ICostBasisManager} from "pangu2/interfaces/ICostBasisManager.sol";
import {IDividendDistributor} from "pangu2/interfaces/IDividendDistributor.sol";
import {
    IPancakeV3Pool,
    IPancakeV3NonfungiblePositionManager,
    IWBNB
} from "pangu2/interfaces/IPancakeV3.sol";
import {TransferContext} from "pangu2/libraries/TransferContext.sol";

/// @notice Mandatory fixed-block BSC Testnet fork validation. CI must provide both environment variables.
contract PancakeV3BscTestnetForkTest is Test {
    uint64 internal constant TEST_FIXTURE_LOCK_DURATION = 7 days;
    uint24 internal constant FEE_TIER = 2500;
    address internal constant WBNB = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;
    address internal constant FACTORY = 0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865;
    address internal constant SWAP_ROUTER = 0x1b81D678ffb9C0263b24A97847620C99d213eB14;
    address internal constant QUOTER_V2 = 0xbC203d7f83677c7ed3F7acEc959963E7F4ECC5C2;
    address internal constant POSITION_MANAGER = 0x427bF5b37357632377eCbEC9de3626C71A5396c1;

    address internal constant USER = address(0xBEEF);
    address internal constant PROFIT_USER = address(0xB0B);
    address internal constant UNKNOWN_USER = address(0xBAD);
    address internal constant EMERGENCY = address(0xE911);
    address internal constant KEEPER = address(0xCAFE);
    address internal constant RELEASE_RECIPIENT = address(0xA11CE);

    Pangu2Token internal token;
    CostBasisManager internal costBasis;
    PancakeV3Adapter internal adapter;
    PancakeV3TwapOracle internal oracle;
    SupportPool internal supportPool;
    FeeVault internal feeVault;
    BuybackLocker internal locker;
    DividendDistributor internal distributor;
    Pangu2TradeRouter internal tradeRouter;
    Pangu2LiquidityGateway internal liquidityGateway;
    IPancakeV3Pool internal pool;

    function setUp() public {
        string memory rpc = vm.envString("BSC_TESTNET_RPC_URL");
        uint256 forkBlock = vm.envUint("BSC_TESTNET_FORK_BLOCK");
        vm.createSelectFork(rpc, forkBlock);
        assertEq(block.chainid, 97);
        assertGt(WBNB.code.length, 0);
        assertGt(FACTORY.code.length, 0);
        assertGt(SWAP_ROUTER.code.length, 0);
        assertGt(QUOTER_V2.code.length, 0);
        assertGt(POSITION_MANAGER.code.length, 0);

        vm.deal(address(this), 5_000 ether);
        vm.deal(USER, 100 ether);
        vm.deal(PROFIT_USER, 100 ether);
        vm.deal(UNKNOWN_USER, 100 ether);

        token = new Pangu2Token(address(this), address(this), EMERGENCY);
        costBasis = new CostBasisManager(address(token), address(this));
        address token0 = address(token) < WBNB ? address(token) : WBNB;
        address token1 = address(token) < WBNB ? WBNB : address(token);
        address poolAddress = IPancakeV3NonfungiblePositionManager(POSITION_MANAGER)
            .createAndInitializePoolIfNecessary(token0, token1, FEE_TIER, uint160(uint256(1) << 96));
        pool = IPancakeV3Pool(poolAddress);

        adapter = new PancakeV3Adapter(
            address(token), WBNB, FACTORY, poolAddress, SWAP_ROUTER, QUOTER_V2, FEE_TIER, address(this)
        );
        oracle = new PancakeV3TwapOracle(
            address(token), WBNB, FACTORY, poolAddress, FEE_TIER, 30 minutes, 16, 300, 1
        );
        supportPool = new SupportPool(
            address(token), WBNB, address(adapter), address(oracle), 300, 5 minutes, address(this), EMERGENCY
        );
        feeVault = new FeeVault(
            address(token),
            WBNB,
            address(adapter),
            address(oracle),
            payable(address(supportPool)),
            1_000_000 ether,
            300,
            address(this),
            KEEPER,
            EMERGENCY
        );
        locker = new BuybackLocker(
            address(token),
            address(supportPool),
            BuybackLocker.LockMode.FIXED_DURATION,
            TEST_FIXTURE_LOCK_DURATION,
            RELEASE_RECIPIENT
        );
        distributor = new DividendDistributor(
            address(token), address(costBasis), address(this), address(this), EMERGENCY
        );
        tradeRouter = new Pangu2TradeRouter(
            address(token), WBNB, address(costBasis), address(adapter), address(oracle), address(this), EMERGENCY
        );
        liquidityGateway = new Pangu2LiquidityGateway(address(token), WBNB, POSITION_MANAGER, FEE_TIER);

        token.configureCore(address(costBasis), address(feeVault));
        token.setPair(poolAddress, true);
        token.setLiquidityManager(address(liquidityGateway), true);
        token.setSystemAddress(address(tradeRouter), true);
        token.setSystemAddress(address(adapter), true);
        token.setSystemAddress(address(supportPool), true);
        token.setSystemAddress(address(locker), true);
        token.setSystemAddress(address(distributor), true);
        token.setSystemTransferContext(
            address(liquidityGateway), TransferContext.Kind.LIQUIDITY_WITHDRAWAL, true
        );
        token.setSystemTransferContext(
            address(distributor), TransferContext.Kind.DIVIDEND_CLAIM, true
        );
        token.setSystemTransferContext(
            address(locker), TransferContext.Kind.SYSTEM_CREDIT_UNKNOWN, true
        );
        token.grantRole(token.SETTLEMENT_ROLE(), address(tradeRouter));
        costBasis.configureOperators(address(tradeRouter), address(distributor));
        adapter.setCaller(address(tradeRouter), true);
        adapter.setCaller(address(feeVault), true);
        adapter.setCaller(address(supportPool), true);
        adapter.setCaller(address(this), true);
        supportPool.configureFeeVault(address(feeVault));
        supportPool.configureLocker(address(locker));
        feeVault.configureDividendDistributor(address(distributor));

        IWBNB(WBNB).deposit{value: 2_000 ether}();
        token.approve(address(liquidityGateway), 1_000 ether);
        IERC20(WBNB).approve(address(liquidityGateway), 1_000 ether);
        liquidityGateway.addLiquidity(
            Pangu2LiquidityGateway.AddLiquidityParams({
                tokenDesired: 1_000 ether,
                wbnbDesired: 1_000 ether,
                tokenMin: 900 ether,
                wbnbMin: 900 ether,
                tickLower: -60_000,
                tickUpper: 60_000,
                deadline: block.timestamp + 5 minutes
            })
        );
        pool.increaseObservationCardinalityNext(16);
        _writeThirtyMinuteOracleHistory(0.000001 ether);
    }

    function testRealPancakeV3CompleteProtocolFlow() public {
        vm.prank(USER);
        tradeRouter.buy{value: 10 ether}(1, block.timestamp + 5 minutes);
        Pangu2TradeRouter.SellPreview memory ordinary = tradeRouter.previewSell(USER, 1 ether);
        assertEq(ordinary.taxBps, token.NORMAL_SELL_TAX_BPS());
        vm.startPrank(USER);
        token.approve(address(tradeRouter), 1 ether);
        tradeRouter.sell(1 ether, 1, block.timestamp + 5 minutes);
        vm.stopPrank();

        vm.prank(PROFIT_USER);
        tradeRouter.buy{value: 10 ether}(1, block.timestamp + 5 minutes);
        _movePriceAndRebuildTwap(100 ether);
        Pangu2TradeRouter.SellPreview memory profitable = tradeRouter.previewSell(PROFIT_USER, 1 ether);
        assertEq(profitable.taxBps, token.PROFIT_SELL_TAX_BPS());
        vm.startPrank(PROFIT_USER);
        token.approve(address(tradeRouter), 1 ether);
        tradeRouter.sell(1 ether, 1, block.timestamp + 5 minutes);
        vm.stopPrank();

        token.transfer(UNKNOWN_USER, 2 ether);
        Pangu2TradeRouter.SellPreview memory unknown = tradeRouter.previewSell(UNKNOWN_USER, 1 ether);
        assertEq(uint256(unknown.costStatus), uint256(ICostBasisManager.PositionStatus.UNKNOWN));
        assertEq(unknown.taxBps, token.PROFIT_SELL_TAX_BPS());
        vm.startPrank(UNKNOWN_USER);
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
            artifactChecksum: keccak256("BSC_TESTNET_FORK_EPOCH_1"),
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
        vm.warp(uint256(c.claimEnd) + 1);
        uint256 carry = distributor.closeEpoch(1);
        assertEq(carry, epochTotal - claimAmount);
        assertEq(distributor.nextEpochCarry(), carry);
    }

    function _writeThirtyMinuteOracleHistory(uint256 amountPerSwap) internal {
        IERC20(WBNB).approve(address(adapter), type(uint256).max);
        for (uint256 i; i < 16; ++i) {
            vm.warp(block.timestamp + 121 seconds);
            adapter.swapExactInput(
                WBNB,
                address(token),
                amountPerSwap,
                1,
                address(liquidityGateway),
                block.timestamp + 5 minutes
            );
        }
        (, , , uint16 cardinality, , , ) = pool.slot0();
        assertGe(cardinality, 16);
    }

    function _movePriceAndRebuildTwap(uint256 amount) internal {
        adapter.swapExactInput(
            WBNB,
            address(token),
            amount,
            1,
            address(liquidityGateway),
            block.timestamp + 5 minutes
        );
        _writeThirtyMinuteOracleHistory(0.000001 ether);
    }
}
