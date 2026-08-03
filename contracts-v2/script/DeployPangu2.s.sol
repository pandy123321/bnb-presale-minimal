// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IPancakeFactory, IPancakeRouter01} from "../src/interfaces/IPancakeV2.sol";
import {Pangu2Token} from "../src/Pangu2Token.sol";
import {CostBasisManager} from "../src/CostBasisManager.sol";
import {PancakeV2Adapter} from "../src/adapters/PancakeV2Adapter.sol";
import {PancakeV2TwapOracle} from "../src/oracle/PancakeV2TwapOracle.sol";
import {SupportPool} from "../src/SupportPool.sol";
import {FeeVault} from "../src/FeeVault.sol";
import {BuybackLocker} from "../src/BuybackLocker.sol";
import {DividendDistributor} from "../src/DividendDistributor.sol";
import {Pangu2TradeRouter} from "../src/Pangu2TradeRouter.sol";

contract DeployPangu2 is Script {
    uint256 internal constant TESTNET_LOCK_DURATION = 365 days;
    uint32 internal constant TWAP_WINDOW = 30 minutes;
    uint16 internal constant MAX_DEVIATION_BPS = 300;

    // BSC Testnet PancakeSwap V2 addresses
    address internal constant WBNB = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;
    address internal constant FACTORY = 0x6725F303b657a9451d8BA641348b6761A6CC7a17;
    address internal constant ROUTER = 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3;

    address internal governance;
    address internal emergencyAccount;
    address internal keeper;
    address internal releaseRecipient;

    function run() external {
        governance = vm.envAddress("GOVERNANCE_ADDRESS");
        emergencyAccount = vm.envAddress("EMERGENCY_ADDRESS");
        keeper = vm.envAddress("KEEPER_ADDRESS");
        releaseRecipient = vm.envAddress("RELEASE_RECIPIENT_ADDRESS");

        if (block.chainid != 97) revert(string(abi.encodePacked("chainId ", vm.toString(block.chainid), " unsupported - only BSC Testnet (97) allowed")));
        require(WBNB.code.length > 0, "WBNB not deployed");
        require(FACTORY.code.length > 0, "Factory not deployed");
        require(ROUTER.code.length > 0, "Router not deployed");
        // Validate Factory->Pair association proactively
        require(FACTORY == IPancakeRouter01(ROUTER).factory(), "Factory-Router mismatch");

        address[] memory roles = new address[](4);
        roles[0] = governance; roles[1] = emergencyAccount; roles[2] = keeper; roles[3] = releaseRecipient;
        for (uint256 i = 0; i < roles.length; i++) {
            for (uint256 j = i + 1; j < roles.length; j++) {
                require(roles[i] != roles[j], "duplicate role address");
            }
        }

        vm.startBroadcast();

        // 1. Token
        Pangu2Token token = new Pangu2Token(governance, governance, emergencyAccount);

        // 2. CostBasis
        CostBasisManager costBasis = new CostBasisManager(address(token), governance);

        // 3. Create V2 pair
        address pair = createV2Pair(address(token));

        // 4. Adapter + Oracle
        PancakeV2Adapter adapter = new PancakeV2Adapter(address(token), WBNB, FACTORY, pair, ROUTER, governance);
        PancakeV2TwapOracle oracle = new PancakeV2TwapOracle(address(token), WBNB, FACTORY, pair, TWAP_WINDOW, MAX_DEVIATION_BPS);

        // 5. SupportPool, FeeVault, Locker
        SupportPool supportPool = new SupportPool(address(token), WBNB, address(adapter), address(oracle), 300, 5 minutes, governance, emergencyAccount);
        FeeVault feeVault = new FeeVault(address(token), WBNB, address(adapter), address(oracle), payable(address(supportPool)), 1_000_000 ether, 300, governance, keeper, emergencyAccount);
        BuybackLocker locker = new BuybackLocker(address(token), address(supportPool), BuybackLocker.LockMode.FIXED_DURATION, uint64(TESTNET_LOCK_DURATION), releaseRecipient);

        // 6. Distributor + TradeRouter
        DividendDistributor distributor = new DividendDistributor(address(token), address(costBasis), governance, governance, emergencyAccount);
        Pangu2TradeRouter tradeRouter = new Pangu2TradeRouter(address(token), WBNB, address(costBasis), address(adapter), address(oracle), governance, emergencyAccount);

        // 7. Configure system
        token.configureCore(address(costBasis), address(feeVault));
        token.setPair(pair, true);
        token.setSystemAddress(address(tradeRouter), true);
        token.setSystemAddress(address(adapter), true);
        token.setSystemAddress(address(supportPool), true);
        token.setSystemAddress(address(locker), true);
        token.setSystemAddress(address(distributor), true);
        token.grantRole(token.SETTLEMENT_ROLE(), address(tradeRouter));

        costBasis.configureOperators(address(tradeRouter), address(distributor));

        // System addresses on CostBasisManager are set through Token (onlyToken gated)
        // The Token contract internally calls costBasis.setSystemAddress when token.setSystemAddress is called
        // Lines 78-82 below already register these as system addresses on Token

        // V2 has no LiquidityGateway — use configureLiquidityGateway if a real gateway is deployed later
        // costBasis.configureLiquidityGateway(...) — not yet configured

        adapter.setCaller(address(tradeRouter), true);
        adapter.setCaller(address(feeVault), true);
        adapter.setCaller(address(supportPool), true);

        supportPool.configureFeeVault(address(feeVault));
        supportPool.configureLocker(address(locker));
        feeVault.configureDividendDistributor(address(distributor));

        // ── Governance handover: deployer renounces residual admin ──
        // Use the deployer key to determine the actual broadcast address.
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        require(deployer != address(0), "invalid deployer key");

        _renounceDeployerRoles(token, costBasis, tradeRouter, distributor, supportPool, feeVault, locker, adapter, deployer);

        // Assert governance handover
        _assertRoleAbsent(token, token.GOVERNANCE_ROLE(), deployer, "Token GOVERNANCE");
        _assertRoleAbsent(costBasis, costBasis.GOVERNANCE_ROLE(), deployer, "CostBasis GOVERNANCE");
        _assertRoleAbsent(tradeRouter, tradeRouter.GOVERNANCE_ROLE(), deployer, "TradeRouter GOVERNANCE");
        _assertRolePresent(distributor, distributor.ROOT_PUBLISHER_ROLE(), governance, "Distributor ROOT_PUBLISHER");

        console.log("Governance:", governance);
        console.log("Deployer:", deployer);
        console.log("Deployer admin roles renounced and verified.");

        vm.stopBroadcast();

        // Log addresses
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
    }

    function createV2Pair(address token) internal returns (address) {
        bytes memory payload = abi.encodeWithSignature("createPair(address,address)", token, WBNB);
        (bool ok, bytes memory data) = FACTORY.call(payload);
        if (!ok) {
            if (data.length > 0) {
                assembly { revert(add(data, 0x20), mload(data)) }
            }
            revert("createPair reverted");
        }
        address pair = abi.decode(data, (address));
        require(pair != address(0), "createPair returned zero");
        require(pair.code.length > 0, "Pair has no code");
        require(IPancakeFactory(FACTORY).getPair(token, WBNB) == pair, "getPair mismatch");
        return pair;
    }

    function _renounceDeployerRoles(
        Pangu2Token token,
        CostBasisManager costBasis,
        Pangu2TradeRouter tradeRouter,
        DividendDistributor distributor,
        SupportPool supportPool,
        FeeVault feeVault,
        BuybackLocker locker,
        PancakeV2Adapter adapter,
        address deployer
    ) internal {
        bytes32 DA = 0x00;
        _tryRenounce(token, DA, deployer);
        _tryRenounce(token, token.GOVERNANCE_ROLE(), deployer);
        _tryRenounce(costBasis, DA, deployer);
        _tryRenounce(costBasis, costBasis.GOVERNANCE_ROLE(), deployer);
        _tryRenounce(tradeRouter, DA, deployer);
        _tryRenounce(tradeRouter, tradeRouter.GOVERNANCE_ROLE(), deployer);
        _tryRenounce(distributor, DA, deployer);
        _tryRenounce(distributor, distributor.GOVERNANCE_ROLE(), deployer);
        _tryRenounce(supportPool, DA, deployer);
        _tryRenounce(supportPool, supportPool.GOVERNANCE_ROLE(), deployer);
        _tryRenounce(feeVault, DA, deployer);
        _tryRenounce(feeVault, feeVault.GOVERNANCE_ROLE(), deployer);
        _tryRenounce(locker, DA, deployer);
        _tryRenounce(locker, locker.GOVERNANCE_ROLE(), deployer);
        _tryRenounce(adapter, DA, deployer);
        _tryRenounce(adapter, adapter.GOVERNANCE_ROLE(), deployer);
    }

    function _tryRenounce(AccessControl target, bytes32 role, address deployer) internal {
        if (target.hasRole(role, deployer)) {
            target.renounceRole(role, deployer);
        }
    }

    function _assertRoleAbsent(AccessControl target, bytes32 role, address account, string memory label) internal view {
        require(!target.hasRole(role, account), string(abi.encodePacked(label, ": role not renounced")));
    }

    function _assertRolePresent(AccessControl target, bytes32 role, address account, string memory label) internal view {
        require(target.hasRole(role, account), string(abi.encodePacked(label, ": role missing")));
    }
}
