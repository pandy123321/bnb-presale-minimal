// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {Pangu2Token} from "../src/Pangu2Token.sol";
import {CostBasisManager} from "../src/CostBasisManager.sol";
import {PancakeV3Adapter} from "../src/adapters/PancakeV3Adapter.sol";
import {PancakeV3TwapOracle} from "../src/oracle/PancakeV3TwapOracle.sol";
import {SupportPool} from "../src/SupportPool.sol";
import {FeeVault} from "../src/FeeVault.sol";
import {BuybackLocker} from "../src/BuybackLocker.sol";
import {DividendDistributor} from "../src/DividendDistributor.sol";
import {Pangu2TradeRouter} from "../src/Pangu2TradeRouter.sol";
import {Pangu2LiquidityGateway} from "../src/Pangu2LiquidityGateway.sol";
import {TransferContext} from "../src/libraries/TransferContext.sol";
import {GovernanceAdapter} from "../src/GovernanceAdapter.sol";
import {IPancakeV3Factory, IPancakeV3Pool} from "../src/interfaces/IPancakeV3.sol";
import {LockDecisionConfig} from "./LockDecisionConfig.sol";

contract DeployPangu2 is Script {
    uint256 internal constant TESTNET_TIMELOCK_DELAY = 1 hours;
    uint24 internal constant PANCAKE_FEE_TIER = 2500;
    uint32 internal constant TWAP_WINDOW = 30 minutes;
    uint16 internal constant MIN_CARDINALITY = 16;
    uint16 internal constant MAX_SPOT_TWAP_DEVIATION_BPS = 300;
    uint16 internal constant BUYBACK_MAX_SLIPPAGE_BPS = 300;
    uint16 internal constant CONVERSION_MAX_SLIPPAGE_BPS = 300;
    uint32 internal constant QUOTE_DEADLINE_WINDOW = 5 minutes;

    struct Deployment {
        TimelockController timelock;
        Pangu2Token token;
        CostBasisManager costBasis;
        PancakeV3Adapter adapter;
        PancakeV3TwapOracle oracle;
        SupportPool supportPool;
        FeeVault feeVault;
        BuybackLocker locker;
        DividendDistributor distributor;
        Pangu2TradeRouter tradeRouter;
        Pangu2LiquidityGateway liquidityGateway;
        GovernanceAdapter governanceAdapter;
    }

    struct DeployConfig {
        uint256 deployerKey;
        address deployer;
        address initialHolder;
        address emergency;
        address keeper;
        address rootPublisher;
        address positionManager;
        address releaseRecipient;
        BuybackLocker.LockMode lockMode;
        uint64 lockDuration;
        string lockDecisionId;
        address proposer;
        address executor;
        address wbnb;
        address factory;
        address swapRouter;
        address quoter;
        bytes32 poolCodeHash;
        uint160 initialSqrtPriceX96;
        uint128 minimumHarmonicLiquidity;
        uint256 maximumConversionAmount;
        string sourceSha;
        string manifestPath;
    }

    error UnsupportedChain(uint256 chainId);
    error InvalidOperationalAccount(address account);
    error InvalidDeploymentParameter();
    error UnexpectedCodeHash(address target, bytes32 expected, bytes32 actual);

    event DeploymentCompleted(
        uint256 indexed chainId,
        address indexed timelock,
        address indexed token,
        address costBasis,
        address adapter,
        address oracle,
        address supportPool,
        address feeVault,
        address locker,
        address distributor,
        address tradeRouter,
        address liquidityGateway,
        address governanceAdapter,
        address pool
    );

    function run() external returns (Deployment memory d) {
        if (block.chainid != 31_337 && block.chainid != 97) revert UnsupportedChain(block.chainid);
        DeployConfig memory c = _readAndValidateConfig();
        address[] memory proposers = new address[](1);
        proposers[0] = c.proposer;
        address[] memory executors = new address[](1);
        executors[0] = c.executor;

        vm.startBroadcast(c.deployerKey);
        d.timelock = new TimelockController(TESTNET_TIMELOCK_DELAY, proposers, executors, c.deployer);
        d.token = new Pangu2Token(c.initialHolder, c.deployer, c.emergency);
        d.costBasis = new CostBasisManager(address(d.token), c.deployer);

        address pool = _createOrLoadPool(c, address(d.token));
        d.adapter = new PancakeV3Adapter(
            address(d.token),
            c.wbnb,
            c.factory,
            pool,
            c.swapRouter,
            c.quoter,
            PANCAKE_FEE_TIER,
            c.deployer
        );
        d.oracle = new PancakeV3TwapOracle(
            address(d.token),
            c.wbnb,
            c.factory,
            pool,
            PANCAKE_FEE_TIER,
            TWAP_WINDOW,
            MIN_CARDINALITY,
            MAX_SPOT_TWAP_DEVIATION_BPS,
            c.minimumHarmonicLiquidity
        );
        d.supportPool = new SupportPool(
            address(d.token),
            c.wbnb,
            address(d.adapter),
            address(d.oracle),
            BUYBACK_MAX_SLIPPAGE_BPS,
            QUOTE_DEADLINE_WINDOW,
            c.deployer,
            c.emergency
        );
        d.feeVault = new FeeVault(
            address(d.token),
            c.wbnb,
            address(d.adapter),
            address(d.oracle),
            payable(address(d.supportPool)),
            c.maximumConversionAmount,
            CONVERSION_MAX_SLIPPAGE_BPS,
            c.deployer,
            c.keeper,
            c.emergency
        );
        d.locker = new BuybackLocker(
            address(d.token),
            address(d.supportPool),
            c.lockMode,
            c.lockDuration,
            c.releaseRecipient
        );
        d.distributor =
            new DividendDistributor(
                address(d.token), address(d.costBasis), c.deployer, c.rootPublisher, c.emergency
            );
        d.tradeRouter = new Pangu2TradeRouter(
            address(d.token),
            c.wbnb,
            address(d.costBasis),
            address(d.adapter),
            address(d.oracle),
            c.deployer,
            c.emergency
        );
        d.liquidityGateway = new Pangu2LiquidityGateway(
            address(d.token), c.wbnb, c.positionManager, address(d.costBasis),
            PANCAKE_FEE_TIER, c.deployer, c.emergency
        );
        d.governanceAdapter = new GovernanceAdapter(address(d.timelock));

        _configureProtocol(d, pool);
        _handoffGovernance(d, c.deployer);

        emit DeploymentCompleted(
            block.chainid,
            address(d.timelock),
            address(d.token),
            address(d.costBasis),
            address(d.adapter),
            address(d.oracle),
            address(d.supportPool),
            address(d.feeVault),
            address(d.locker),
            address(d.distributor),
            address(d.tradeRouter),
            address(d.liquidityGateway),
            address(d.governanceAdapter),
            pool
        );
        vm.stopBroadcast();
        _writeManifest(d, c);
    }

    function _readAndValidateConfig() private returns (DeployConfig memory c) {
        c.deployerKey = vm.envUint("LOCAL_OR_TESTNET_DEPLOYER_PRIVATE_KEY");
        c.deployer = vm.addr(c.deployerKey);
        c.initialHolder = vm.envAddress("PANGU2_INITIAL_HOLDER");
        c.emergency = vm.envAddress("PANGU2_EMERGENCY_ACCOUNT");
        c.keeper = vm.envAddress("PANGU2_KEEPER_ACCOUNT");
        c.rootPublisher = vm.envAddress("PANGU2_ROOT_PUBLISHER_ACCOUNT");
        c.positionManager = vm.envAddress("PANGU2_PANCAKE_V3_POSITION_MANAGER");
        c.releaseRecipient = vm.envAddress("LOCK_RELEASE_RECIPIENT");
        string memory lockModeValue = vm.envString("LOCK_MODE");
        uint256 lockDurationValue = vm.envUint("LOCK_DURATION");
        c.lockDecisionId = vm.envString("LOCK_DECISION_ID");
        (c.lockMode, c.lockDuration) = LockDecisionConfig.validate(
            lockModeValue, lockDurationValue, c.releaseRecipient, c.lockDecisionId
        );
        c.proposer = vm.envAddress("PANGU2_TIMELOCK_PROPOSER");
        c.executor = vm.envAddress("PANGU2_TIMELOCK_EXECUTOR");
        c.wbnb = vm.envAddress("PANGU2_WBNB");
        c.factory = vm.envAddress("PANGU2_PANCAKE_V3_FACTORY");
        c.swapRouter = vm.envAddress("PANGU2_PANCAKE_V3_SWAP_ROUTER");
        c.quoter = vm.envAddress("PANGU2_PANCAKE_V3_QUOTER_V2");
        c.poolCodeHash = vm.envBytes32("PANGU2_POOL_CODEHASH");

        uint256 rawSqrtPrice = vm.envUint("PANGU2_INITIAL_SQRT_PRICE_X96");
        uint256 rawMinimumLiquidity = vm.envUint("PANGU2_MIN_HARMONIC_LIQUIDITY");
        c.maximumConversionAmount = vm.envUint("PANGU2_MAX_CONVERSION_TOKEN_AMOUNT");
        c.sourceSha = vm.envString("PANGU2_SOURCE_SHA");
        c.manifestPath = vm.envString("PANGU2_DEPLOYMENT_MANIFEST_PATH");
        if (
            rawSqrtPrice == 0 || rawSqrtPrice > type(uint160).max || rawMinimumLiquidity == 0
                || rawMinimumLiquidity > type(uint128).max || c.maximumConversionAmount == 0
                || bytes(c.sourceSha).length == 0 || bytes(c.manifestPath).length == 0
        ) revert InvalidDeploymentParameter();
        c.initialSqrtPriceX96 = uint160(rawSqrtPrice);
        c.minimumHarmonicLiquidity = uint128(rawMinimumLiquidity);

        _validateOperationalAccount(c.initialHolder, c.deployer);
        _validateOperationalAccount(c.emergency, c.deployer);
        _validateOperationalAccount(c.keeper, c.deployer);
        _validateOperationalAccount(c.rootPublisher, c.deployer);
        _validateOperationalAccount(c.proposer, c.deployer);
        _validateOperationalAccount(c.executor, c.deployer);
        _validateOperationalAccount(c.releaseRecipient, c.deployer);
        if (
            c.emergency == c.keeper || c.emergency == c.rootPublisher || c.keeper == c.rootPublisher
                || c.proposer == c.emergency || c.proposer == c.keeper || c.proposer == c.rootPublisher
        ) revert InvalidOperationalAccount(c.emergency);

        _assertExpectedCodeHash(c.wbnb, vm.envBytes32("PANGU2_WBNB_CODEHASH"));
        _assertExpectedCodeHash(c.factory, vm.envBytes32("PANGU2_FACTORY_CODEHASH"));
        _assertExpectedCodeHash(c.swapRouter, vm.envBytes32("PANGU2_SWAP_ROUTER_CODEHASH"));
        _assertExpectedCodeHash(c.quoter, vm.envBytes32("PANGU2_QUOTER_CODEHASH"));
        _assertExpectedCodeHash(
            c.positionManager, vm.envBytes32("PANGU2_POSITION_MANAGER_CODEHASH")
        );
    }

    function _createOrLoadPool(DeployConfig memory c, address token) private returns (address pool) {
        pool = IPancakeV3Factory(c.factory).getPool(token, c.wbnb, PANCAKE_FEE_TIER);
        if (pool == address(0)) {
            pool = IPancakeV3Factory(c.factory).createPool(token, c.wbnb, PANCAKE_FEE_TIER);
        }
        _assertExpectedCodeHash(pool, c.poolCodeHash);
        (uint160 sqrtPriceX96, , , , uint16 observationCardinalityNext, , ) = IPancakeV3Pool(pool).slot0();
        if (sqrtPriceX96 == 0) IPancakeV3Pool(pool).initialize(c.initialSqrtPriceX96);
        if (observationCardinalityNext < MIN_CARDINALITY) {
            IPancakeV3Pool(pool).increaseObservationCardinalityNext(MIN_CARDINALITY);
        }
    }

    function _configureProtocol(Deployment memory d, address pool) private {
        d.token.configureCore(address(d.costBasis), address(d.feeVault));
        d.token.setPair(pool, true);
        d.token.setLiquidityManager(address(d.liquidityGateway), true);
        d.token.setSystemAddress(address(d.tradeRouter), true);
        d.token.setSystemAddress(address(d.adapter), true);
        d.token.setSystemAddress(address(d.supportPool), true);
        d.token.setSystemAddress(address(d.locker), true);
        d.token.setSystemAddress(address(d.distributor), true);
        d.token.setSystemTransferContext(
            address(d.liquidityGateway), TransferContext.Kind.LIQUIDITY_WITHDRAWAL, true
        );
        d.token.setSystemTransferContext(
            address(d.liquidityGateway), TransferContext.Kind.LIQUIDITY_FEE_COLLECTION, true
        );
        d.token.setSystemTransferContext(
            address(d.distributor), TransferContext.Kind.DIVIDEND_CLAIM, true
        );
        d.token.setSystemTransferContext(
            address(d.locker), TransferContext.Kind.SYSTEM_CREDIT_UNKNOWN, true
        );
        d.token.grantRole(d.token.SETTLEMENT_ROLE(), address(d.tradeRouter));

        d.costBasis.configureOperators(address(d.tradeRouter), address(d.distributor));
        d.costBasis.configureLiquidityGateway(address(d.liquidityGateway));
        d.adapter.setCaller(address(d.tradeRouter), true);
        d.adapter.setCaller(address(d.feeVault), true);
        d.adapter.setCaller(address(d.supportPool), true);
        d.supportPool.configureFeeVault(address(d.feeVault));
        d.supportPool.configureLocker(address(d.locker));
        d.feeVault.configureDividendDistributor(address(d.distributor));
    }

    function _handoffGovernance(Deployment memory d, address deployer) private {
        address timelock = address(d.timelock);
        _handoffToken(d.token, timelock, deployer);
        _handoffCostBasis(d.costBasis, timelock, deployer);
        _handoffAdapter(d.adapter, timelock, deployer);
        _handoffSupportPool(d.supportPool, timelock, deployer);
        _handoffFeeVault(d.feeVault, timelock, deployer);
        _handoffDistributor(d.distributor, timelock, deployer);
        _handoffTradeRouter(d.tradeRouter, timelock, deployer);
        _handoffGateway(d.liquidityGateway, timelock, deployer);
        d.timelock.renounceRole(d.timelock.DEFAULT_ADMIN_ROLE(), deployer);
    }

    function _writeManifest(Deployment memory d, DeployConfig memory c) private {
        string memory objectKey = "PANGU2_PB_S1";
        vm.serializeUint(objectKey, "chainId", block.chainid);
        vm.serializeString(objectKey, "environment", block.chainid == 97 ? "BSC_TESTNET" : "LOCAL_OR_CI");
        vm.serializeString(objectKey, "abiVersion", "PANGU2-PB-S1-ABI-V1");
        vm.serializeString(objectKey, "sourceSha", c.sourceSha);
        vm.serializeAddress(objectKey, "deployer", c.deployer);
        vm.serializeAddress(objectKey, "initialHolder", c.initialHolder);
        vm.serializeAddress(objectKey, "emergency", c.emergency);
        vm.serializeAddress(objectKey, "keeper", c.keeper);
        vm.serializeAddress(objectKey, "rootPublisher", c.rootPublisher);
        vm.serializeAddress(objectKey, "pancakeV3PositionManager", c.positionManager);
        vm.serializeAddress(objectKey, "releaseRecipient", c.releaseRecipient);
        vm.serializeString(
            objectKey,
            "lockerMode",
            c.lockMode == BuybackLocker.LockMode.PERMANENT ? "PERMANENT" : "FIXED_DURATION"
        );
        vm.serializeString(objectKey, "lockerDecisionId", c.lockDecisionId);
        vm.serializeAddress(objectKey, "timelockProposer", c.proposer);
        vm.serializeAddress(objectKey, "timelockExecutor", c.executor);
        vm.serializeAddress(objectKey, "wbnb", c.wbnb);
        vm.serializeAddress(objectKey, "pancakeV3Factory", c.factory);
        vm.serializeAddress(objectKey, "pancakeV3SwapRouter", c.swapRouter);
        vm.serializeAddress(objectKey, "pancakeV3QuoterV2", c.quoter);
        vm.serializeAddress(objectKey, "timelock", address(d.timelock));
        vm.serializeAddress(objectKey, "token", address(d.token));
        vm.serializeAddress(objectKey, "costBasis", address(d.costBasis));
        vm.serializeAddress(objectKey, "adapter", address(d.adapter));
        vm.serializeAddress(objectKey, "oracle", address(d.oracle));
        vm.serializeAddress(objectKey, "supportPool", address(d.supportPool));
        vm.serializeAddress(objectKey, "feeVault", address(d.feeVault));
        vm.serializeAddress(objectKey, "locker", address(d.locker));
        vm.serializeAddress(objectKey, "distributor", address(d.distributor));
        vm.serializeAddress(objectKey, "tradeRouter", address(d.tradeRouter));
        vm.serializeAddress(objectKey, "liquidityGateway", address(d.liquidityGateway));
        vm.serializeAddress(objectKey, "governanceAdapter", address(d.governanceAdapter));
        vm.serializeAddress(objectKey, "pancakeV3Pool", d.adapter.poolAddress());
        vm.serializeUint(objectKey, "initialSqrtPriceX96", c.initialSqrtPriceX96);
        vm.serializeUint(objectKey, "pancakeFeeTier", PANCAKE_FEE_TIER);
        vm.serializeUint(objectKey, "twapWindowSeconds", TWAP_WINDOW);
        vm.serializeUint(objectKey, "minimumObservationCardinality", MIN_CARDINALITY);
        vm.serializeUint(objectKey, "maximumSpotTwapDeviationBps", MAX_SPOT_TWAP_DEVIATION_BPS);
        vm.serializeUint(objectKey, "minimumHarmonicLiquidity", c.minimumHarmonicLiquidity);
        vm.serializeUint(objectKey, "timelockDelaySeconds", TESTNET_TIMELOCK_DELAY);
        vm.serializeUint(objectKey, "lockerDurationSeconds", c.lockDuration);
        vm.serializeUint(objectKey, "maximumConversionTokenAmount", c.maximumConversionAmount);
        vm.serializeUint(objectKey, "buybackMaximumSlippageBps", BUYBACK_MAX_SLIPPAGE_BPS);
        vm.serializeUint(objectKey, "conversionMaximumSlippageBps", CONVERSION_MAX_SLIPPAGE_BPS);
        vm.serializeUint(objectKey, "buybackAmountWei", d.supportPool.BUYBACK_AMOUNT());
        vm.serializeUint(objectKey, "buybackIntervalSeconds", d.supportPool.MIN_BUYBACK_INTERVAL());
        vm.serializeBytes32(objectKey, "timelockCodeHash", address(d.timelock).codehash);
        vm.serializeBytes32(objectKey, "tokenCodeHash", address(d.token).codehash);
        vm.serializeBytes32(objectKey, "costBasisCodeHash", address(d.costBasis).codehash);
        vm.serializeBytes32(objectKey, "adapterCodeHash", address(d.adapter).codehash);
        vm.serializeBytes32(objectKey, "oracleCodeHash", address(d.oracle).codehash);
        vm.serializeBytes32(objectKey, "supportPoolCodeHash", address(d.supportPool).codehash);
        vm.serializeBytes32(objectKey, "feeVaultCodeHash", address(d.feeVault).codehash);
        vm.serializeBytes32(objectKey, "lockerCodeHash", address(d.locker).codehash);
        vm.serializeBytes32(objectKey, "dividendDistributorCodeHash", address(d.distributor).codehash);
        vm.serializeBytes32(objectKey, "tradeRouterCodeHash", address(d.tradeRouter).codehash);
        vm.serializeBytes32(
            objectKey, "liquidityGatewayCodeHash", address(d.liquidityGateway).codehash
        );
        string memory json = vm.serializeBytes32(
            objectKey, "governanceAdapterCodeHash", address(d.governanceAdapter).codehash
        );
        vm.writeJson(json, c.manifestPath);
    }

    function _validateOperationalAccount(address account, address deployer) private pure {
        if (account == address(0) || account == deployer) revert InvalidOperationalAccount(account);
    }

    function _assertExpectedCodeHash(address target, bytes32 expected) private view {
        bytes32 actual = target.codehash;
        if (target == address(0) || target.code.length == 0 || expected == bytes32(0) || actual != expected) {
            revert UnexpectedCodeHash(target, expected, actual);
        }
    }

    function _handoffToken(Pangu2Token c, address timelock, address deployer) private {
        c.grantRole(c.DEFAULT_ADMIN_ROLE(), timelock);
        c.grantRole(c.GOVERNANCE_ROLE(), timelock);
        c.grantRole(c.UNPAUSER_ROLE(), timelock);
        c.renounceRole(c.UNPAUSER_ROLE(), deployer);
        c.renounceRole(c.GOVERNANCE_ROLE(), deployer);
        c.renounceRole(c.DEFAULT_ADMIN_ROLE(), deployer);
    }

    function _handoffCostBasis(CostBasisManager c, address timelock, address deployer) private {
        c.grantRole(c.DEFAULT_ADMIN_ROLE(), timelock);
        c.grantRole(c.GOVERNANCE_ROLE(), timelock);
        c.renounceRole(c.GOVERNANCE_ROLE(), deployer);
        c.renounceRole(c.DEFAULT_ADMIN_ROLE(), deployer);
    }

    function _handoffAdapter(PancakeV3Adapter c, address timelock, address deployer) private {
        c.grantRole(c.DEFAULT_ADMIN_ROLE(), timelock);
        c.grantRole(c.GOVERNANCE_ROLE(), timelock);
        c.renounceRole(c.GOVERNANCE_ROLE(), deployer);
        c.renounceRole(c.DEFAULT_ADMIN_ROLE(), deployer);
    }

    function _handoffSupportPool(SupportPool c, address timelock, address deployer) private {
        c.grantRole(c.DEFAULT_ADMIN_ROLE(), timelock);
        c.grantRole(c.GOVERNANCE_ROLE(), timelock);
        c.grantRole(c.UNPAUSER_ROLE(), timelock);
        c.renounceRole(c.UNPAUSER_ROLE(), deployer);
        c.renounceRole(c.GOVERNANCE_ROLE(), deployer);
        c.renounceRole(c.DEFAULT_ADMIN_ROLE(), deployer);
    }

    function _handoffFeeVault(FeeVault c, address timelock, address deployer) private {
        c.grantRole(c.DEFAULT_ADMIN_ROLE(), timelock);
        c.grantRole(c.GOVERNANCE_ROLE(), timelock);
        c.grantRole(c.UNPAUSER_ROLE(), timelock);
        c.renounceRole(c.UNPAUSER_ROLE(), deployer);
        c.renounceRole(c.GOVERNANCE_ROLE(), deployer);
        c.renounceRole(c.DEFAULT_ADMIN_ROLE(), deployer);
    }

    function _handoffDistributor(DividendDistributor c, address timelock, address deployer) private {
        c.grantRole(c.DEFAULT_ADMIN_ROLE(), timelock);
        c.grantRole(c.GOVERNANCE_ROLE(), timelock);
        c.grantRole(c.UNPAUSER_ROLE(), timelock);
        c.renounceRole(c.UNPAUSER_ROLE(), deployer);
        c.renounceRole(c.GOVERNANCE_ROLE(), deployer);
        c.renounceRole(c.DEFAULT_ADMIN_ROLE(), deployer);
    }

    function _handoffTradeRouter(Pangu2TradeRouter c, address timelock, address deployer) private {
        c.grantRole(c.DEFAULT_ADMIN_ROLE(), timelock);
        c.grantRole(c.GOVERNANCE_ROLE(), timelock);
        c.grantRole(c.UNPAUSER_ROLE(), timelock);
        c.renounceRole(c.UNPAUSER_ROLE(), deployer);
        c.renounceRole(c.GOVERNANCE_ROLE(), deployer);
        c.renounceRole(c.DEFAULT_ADMIN_ROLE(), deployer);
    }

    function _handoffGateway(Pangu2LiquidityGateway c, address timelock, address deployer) private {
        c.grantRole(c.DEFAULT_ADMIN_ROLE(), timelock);
        c.grantRole(c.GOVERNANCE_ROLE(), timelock);
        c.grantRole(c.UNPAUSER_ROLE(), timelock);
        c.renounceRole(c.UNPAUSER_ROLE(), deployer);
        c.renounceRole(c.GOVERNANCE_ROLE(), deployer);
        c.renounceRole(c.DEFAULT_ADMIN_ROLE(), deployer);
    }
}
