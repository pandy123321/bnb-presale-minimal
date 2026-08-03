// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { Pangu2Token } from "../src/Pangu2Token.sol";
import { CostBasisManager } from "../src/CostBasisManager.sol";
import { PancakeV2Adapter } from "../src/adapters/PancakeV2Adapter.sol";
import { PancakeV2TwapOracle } from "../src/oracle/PancakeV2TwapOracle.sol";
import { SupportPool } from "../src/SupportPool.sol";
import { FeeVault } from "../src/FeeVault.sol";
import { BuybackLocker } from "../src/BuybackLocker.sol";
import { DividendDistributor } from "../src/DividendDistributor.sol";
import { Pangu2TradeRouter } from "../src/Pangu2TradeRouter.sol";
import { IPancakeFactory, IPancakePair } from "../src/interfaces/IPancakeV2.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { TransferContext } from "../src/libraries/TransferContext.sol";

/// @notice Deploy PANGU2 V2 core contracts.
///         Does NOT enable pair trading or add liquidity — see BootstrapPangu2.
contract DeployPangu2 is Script {
    uint256 internal constant LOCK_DURATION = 365 days;
    uint32 internal constant TWAP_WINDOW = 30 minutes;
    uint16 internal constant MAX_DEVIATION_BPS = 300;

    // Chain-aware PancakeSwap V2 addresses
    function _wbnb() internal view returns (address) {
        if (block.chainid == 56) return 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // BSC Mainnet
        if (block.chainid == 97) return 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd; // BSC Testnet
        revert("Unsupported chain");
    }
    function _factory() internal view returns (address) {
        if (block.chainid == 56) return 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73; // BSC Mainnet
        if (block.chainid == 97) return 0x6725F303b657a9451d8BA641348b6761A6CC7a17; // BSC Testnet
        revert("Unsupported chain");
    }
    function _router() internal view returns (address) {
        if (block.chainid == 56) return 0x10ED43C718714eb63d5aA57B78B54704E256024E; // BSC Mainnet
        if (block.chainid == 97) return 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3; // BSC Testnet
        revert("Unsupported chain");
    }

    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        require(deployer != address(0), "invalid deployer key");

        address governance = vm.envAddress("GOVERNANCE_ADDRESS");
        address emergencyAccount = vm.envAddress("EMERGENCY_ADDRESS");
        address keeper = vm.envAddress("KEEPER_ADDRESS");
        address releaseRecipient = vm.envAddress("RELEASE_RECIPIENT_ADDRESS");
        address initialHolder = vm.envAddress("INITIAL_HOLDER_ADDRESS");
        address rootPublisher = vm.envAddress("ROOT_PUBLISHER_ADDRESS");

        uint256 rawTokenReserve = vm.envUint("MIN_TOKEN_RESERVE");
        uint256 rawWbnbReserve = vm.envUint("MIN_WBNB_RESERVE");
        require(rawTokenReserve <= type(uint112).max, "MIN_TOKEN_RESERVE > uint112");
        require(rawWbnbReserve <= type(uint112).max, "MIN_WBNB_RESERVE > uint112");
        uint112 minTokenReserve = uint112(rawTokenReserve);
        uint112 minWbnbReserve = uint112(rawWbnbReserve);
        require(minTokenReserve > 0 && minWbnbReserve > 0, "zero min reserve");

        // Resolve chain-specific PancakeSwap addresses
        address WBNB = _wbnb();
        address FACTORY = _factory();
        address ROUTER = _router();

        // Safety checks
        if (block.chainid != 56 && block.chainid != 97) revert("Unsupported chain - BSC Mainnet (56) or Testnet (97) only");
        require(WBNB.code.length > 0, "WBNB not deployed");
        require(FACTORY.code.length > 0, "Factory not deployed");
        require(ROUTER.code.length > 0, "Router not deployed");
        require(deployer != governance, "deployer must differ from governance");
        require(deployer != initialHolder, "deployer must differ from initialHolder");
        require(governance != initialHolder, "governance must differ from initialHolder");
        require(governance != rootPublisher, "governance must differ from rootPublisher");

        address[] memory addrs = new address[](6);
        addrs[0] = governance;
        addrs[1] = emergencyAccount;
        addrs[2] = keeper;
        addrs[3] = releaseRecipient;
        addrs[4] = initialHolder;
        addrs[5] = rootPublisher;
        for (uint256 i = 0; i < addrs.length; i++) {
            require(addrs[i] != address(0), "zero address");
        }

        vm.startBroadcast(deployerKey);

        // 1. Token (deployer = temporary governance)
        Pangu2Token token = new Pangu2Token(initialHolder, deployer, emergencyAccount);

        // 2. CostBasis
        CostBasisManager costBasis = new CostBasisManager(address(token), deployer);

        // 3. Create V2 pair (NOT yet enabled as isPair — Bootstrap enables it)
        address pair = IPancakeFactory(FACTORY).createPair(address(token), WBNB);
        require(pair != address(0), "createPair returned zero");
        require(pair.code.length > 0, "Pair has no code");
        require(IPancakeFactory(FACTORY).getPair(address(token), WBNB) == pair, "getPair mismatch");

        // 4. Adapter + Oracle
        PancakeV2Adapter adapter = new PancakeV2Adapter(address(token), WBNB, FACTORY, pair, ROUTER, deployer);
        PancakeV2TwapOracle oracle = new PancakeV2TwapOracle(
            address(token), WBNB, FACTORY, pair, TWAP_WINDOW, MAX_DEVIATION_BPS, minTokenReserve, minWbnbReserve
        );

        // 5. SupportPool, FeeVault, Locker
        SupportPool supportPool = new SupportPool(
            address(token), WBNB, address(adapter), address(oracle), 300, 5 minutes, deployer, emergencyAccount
        );
        FeeVault feeVault = new FeeVault(
            address(token),
            WBNB,
            address(adapter),
            address(oracle),
            payable(address(supportPool)),
            1_000_000 ether,
            300,
            deployer,
            keeper,
            emergencyAccount
        );
        BuybackLocker locker = new BuybackLocker(
            address(token),
            address(supportPool),
            BuybackLocker.LockMode.FIXED_DURATION,
            uint64(LOCK_DURATION),
            releaseRecipient
        );

        // 6. Distributor + TradeRouter
        DividendDistributor distributor =
            new DividendDistributor(address(token), address(costBasis), deployer, rootPublisher, emergencyAccount);
        Pangu2TradeRouter tradeRouter = new Pangu2TradeRouter(
            address(token), WBNB, address(costBasis), address(adapter), address(oracle), deployer, emergencyAccount
        );

        // 7. Configure system contracts
        token.configureCore(address(costBasis), address(feeVault));
        // NOTE: pair NOT enabled yet — BootstrapPangu2 handles this
        token.setSystemAddress(address(tradeRouter), true);
        token.setSystemAddress(address(adapter), true);
        token.setSystemAddress(address(supportPool), true);
        token.setSystemAddress(address(locker), true);
        token.setSystemAddress(address(distributor), true);
        token.grantRole(token.SETTLEMENT_ROLE(), address(tradeRouter));

        costBasis.configureOperators(address(tradeRouter), address(distributor));
        costBasis.configureLiquidityGateway(address(adapter));

        adapter.setCaller(address(tradeRouter), true);
        adapter.setCaller(address(feeVault), true);
        adapter.setCaller(address(supportPool), true);

        supportPool.configureFeeVault(address(feeVault));
        supportPool.configureLocker(address(locker));
        feeVault.configureDividendDistributor(address(distributor));

        // 8. Transfer Contexts
        token.setSystemTransferContext(address(distributor), TransferContext.Kind.DIVIDEND_CLAIM, true);
        token.setSystemTransferContext(address(locker), TransferContext.Kind.SYSTEM_CREDIT_UNKNOWN, true);

        // 9. Governance handover: grant target governance
        bytes32 DA = 0x00;
        bytes32 GOV = keccak256("GOVERNANCE_ROLE");
        bytes32 UNP = keccak256("UNPAUSER_ROLE");

        // Contracts WITH UNPAUSER_ROLE
        address[] memory acFull = new address[](5);
        acFull[0] = address(token);
        acFull[1] = address(tradeRouter);
        acFull[2] = address(distributor);
        acFull[3] = address(supportPool);
        acFull[4] = address(feeVault);

        for (uint256 i = 0; i < acFull.length; i++) {
            AccessControl c = AccessControl(acFull[i]);
            c.grantRole(DA, governance);
            require(c.hasRole(DA, governance), "grant DA failed");
            c.grantRole(GOV, governance);
            require(c.hasRole(GOV, governance), "grant GOV failed");
            c.grantRole(UNP, governance);
            require(c.hasRole(UNP, governance), "grant UNP failed");
        }

        // Contracts WITHOUT UNPAUSER_ROLE: CostBasis, Adapter
        {
            AccessControl cb = AccessControl(address(costBasis));
            cb.grantRole(DA, governance);
            require(cb.hasRole(DA, governance), "costBasis grant DA failed");
            cb.grantRole(GOV, governance);
            require(cb.hasRole(GOV, governance), "costBasis grant GOV failed");
        }
        {
            AccessControl ad = AccessControl(address(adapter));
            ad.grantRole(DA, governance);
            require(ad.hasRole(DA, governance), "adapter grant DA failed");
            ad.grantRole(GOV, governance);
            require(ad.hasRole(GOV, governance), "adapter grant GOV failed");
        }

        // 10. Renounce deployer: ALL admin roles
        _renounceAll(AccessControl(address(token)), deployer);
        _renounceAll(AccessControl(address(costBasis)), deployer);
        _renounceAll(AccessControl(address(tradeRouter)), deployer);
        _renounceAll(AccessControl(address(distributor)), deployer);
        _renounceAll(AccessControl(address(supportPool)), deployer);
        _renounceAll(AccessControl(address(feeVault)), deployer);
        _renounceAll(AccessControl(address(adapter)), deployer);

        // Also renounce SETTLEMENT_ROLE if deployer was granted it
        bytes32 SETTLE = token.SETTLEMENT_ROLE();
        if (token.hasRole(SETTLE, deployer)) token.renounceRole(SETTLE, deployer);
        // Renounce CALLER_ROLE if held
        bytes32 CALLER = adapter.CALLER_ROLE();
        if (adapter.hasRole(CALLER, deployer)) adapter.renounceRole(CALLER, deployer);

        // 11. Post-handover assertions — full contracts
        for (uint256 i = 0; i < acFull.length; i++) {
            IAccessControl c = IAccessControl(acFull[i]);
            require(!c.hasRole(DA, deployer), "deployer retains DA");
            require(!c.hasRole(GOV, deployer), "deployer retains GOV");
            require(!c.hasRole(UNP, deployer), "deployer retains UNP");
            require(c.hasRole(DA, governance), "gov missing DA");
            require(c.hasRole(GOV, governance), "gov missing GOV");
            require(c.hasRole(UNP, governance), "gov missing UNP");
        }
        // CostBasis (no UNPAUSER)
        {
            IAccessControl cb = IAccessControl(address(costBasis));
            require(!cb.hasRole(DA, deployer), "costBasis deployer retains DA");
            require(!cb.hasRole(GOV, deployer), "costBasis deployer retains GOV");
            require(cb.hasRole(DA, governance), "costBasis gov missing DA");
            require(cb.hasRole(GOV, governance), "costBasis gov missing GOV");
        }
        // Adapter (no UNPAUSER)
        {
            IAccessControl a = IAccessControl(address(adapter));
            require(!a.hasRole(DA, deployer), "adapter deployer retains DA");
            require(!a.hasRole(GOV, deployer), "adapter deployer retains GOV");
            require(a.hasRole(DA, governance), "adapter gov missing DA");
            require(a.hasRole(GOV, governance), "adapter gov missing GOV");
        }

        require(token.hasRole(SETTLE, address(tradeRouter)), "router missing SETTLEMENT");
        require(!token.hasRole(SETTLE, deployer), "deployer retains SETTLEMENT");
        require(!adapter.hasRole(CALLER, deployer), "deployer retains CALLER");

        // Adapter whitelist
        require(adapter.hasRole(CALLER, address(tradeRouter)), "router not adapter CALLER");
        require(adapter.hasRole(CALLER, address(feeVault)), "feeVault not adapter CALLER");
        require(adapter.hasRole(CALLER, address(supportPool)), "supportPool not adapter CALLER");

        // CostBasis operators
        require(costBasis.tradeRouter() == address(tradeRouter), "costBasis router mismatch");
        require(costBasis.dividendDistributor() == address(distributor), "costBasis distributor mismatch");

        // Transfer contexts
        require(
            token.systemTransferContextAllowed(address(distributor), TransferContext.Kind.DIVIDEND_CLAIM),
            "distributor missing DIVIDEND_CLAIM"
        );
        require(
            token.systemTransferContextAllowed(address(locker), TransferContext.Kind.SYSTEM_CREDIT_UNKNOWN),
            "locker missing SYSTEM_CREDIT_UNKNOWN"
        );

        // Pair NOT yet trading-enabled
        require(!token.isPair(pair), "pair must NOT be enabled yet");

        vm.stopBroadcast();

        console.log("=== PANGU2 V2 Deployed ===");
        console.log("Token:", address(token));
        console.log("TradeRouter:", address(tradeRouter));
        console.log("DividendDistributor:", address(distributor));
        console.log("SupportPool:", address(supportPool));
        console.log("FeeVault:", address(feeVault));
        console.log("BuybackLocker:", address(locker));
        console.log("V2Pair:", pair);
        console.log("V2Adapter:", address(adapter));
        console.log("V2Oracle:", address(oracle));
        console.log("Governance:", governance);
        console.log("Deployer:", deployer);
        console.log("");
        console.log("Next: BootstrapPangu2 to add initial liquidity.");
    }

    function _renounceAll(AccessControl target, address d) internal {
        bytes32 DA = 0x00;
        bytes32 GOV = keccak256("GOVERNANCE_ROLE");
        bytes32 UNP = keccak256("UNPAUSER_ROLE");
        if (target.hasRole(DA, d)) target.renounceRole(DA, d);
        if (target.hasRole(GOV, d)) target.renounceRole(GOV, d);
        if (target.hasRole(UNP, d)) target.renounceRole(UNP, d);
    }
}
