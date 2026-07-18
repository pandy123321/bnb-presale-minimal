// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { BNBPresale } from "../src/BNBPresale.sol";
import { ScriptBase } from "./utils/ScriptBase.sol";

/// @notice 使用已存在的标准项目代币部署私募合约并转入初始库存。
/// @dev 本脚本永远不会恢复销售。部署、库存核验与激活必须分成独立步骤。
contract DeployBNBPresale is ScriptBase {
    using SafeERC20 for IERC20;

    struct DeploymentConfig {
        address owner;
        address treasury;
        address tokenAddress;
        uint256 tokenPerBNB;
        uint256 minimum;
        uint256 maximum;
        uint256 walletMaximum;
        uint256 maximumTokens;
        uint256 initialInventory;
        bool repeatAllowed;
    }

    error InvalidConfiguredContract(address configuredAddress);
    error InventoryTransferMismatch(uint256 expectedIncrease, uint256 actualIncrease);
    error DeploymentPostCheckFailed();

    function run() external returns (BNBPresale presale) {
        _requireExpectedChain(vm.envUint("EXPECTED_CHAIN_ID"), vm.envBool("ALLOW_MAINNET_WRITES"));

        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        DeploymentConfig memory config = _loadConfig();
        _requirePrivateKeyMatchesOwner(deployerPrivateKey, config.owner);
        if (config.tokenAddress.code.length == 0) revert InvalidConfiguredContract(config.tokenAddress);

        vm.startBroadcast(deployerPrivateKey);
        presale = new BNBPresale(
            config.owner,
            config.tokenAddress,
            config.treasury,
            config.tokenPerBNB,
            config.minimum,
            config.maximum,
            config.walletMaximum,
            config.repeatAllowed,
            config.maximumTokens
        );
        _transferInventory(presale, config.tokenAddress, config.initialInventory);
        vm.stopBroadcast();

        _requireDeploymentPostChecks(presale, config);
    }

    function _loadConfig() internal returns (DeploymentConfig memory config) {
        config.owner = vm.envAddress("CONTRACT_OWNER_ADDRESS");
        config.treasury = vm.envAddress("TREASURY_ADDRESS");
        config.tokenAddress = vm.envAddress("SALE_TOKEN_ADDRESS");
        config.tokenPerBNB = vm.envUint("TOKEN_PER_BNB_RAW");
        config.minimum = vm.envUint("MIN_PURCHASE_BNB_WEI");
        config.maximum = vm.envUint("MAX_PURCHASE_BNB_WEI");
        config.walletMaximum = vm.envUint("MAX_PURCHASE_PER_WALLET_WEI");
        config.maximumTokens = vm.envUint("MAX_TOKENS_SOLD_RAW");
        config.initialInventory = vm.envUint("INITIAL_INVENTORY_RAW");
        config.repeatAllowed = vm.envBool("ALLOW_REPEAT_PURCHASE");
    }

    function _transferInventory(BNBPresale presale, address tokenAddress, uint256 initialInventory) internal {
        if (initialInventory == 0) return;
        IERC20 token = IERC20(tokenAddress);
        uint256 inventoryBefore = token.balanceOf(address(presale));
        token.safeTransfer(address(presale), initialInventory);
        uint256 inventoryAfter = token.balanceOf(address(presale));
        uint256 actualIncrease = inventoryAfter >= inventoryBefore ? inventoryAfter - inventoryBefore : 0;
        if (actualIncrease != initialInventory) revert InventoryTransferMismatch(initialInventory, actualIncrease);
    }

    function _requireDeploymentPostChecks(BNBPresale presale, DeploymentConfig memory config) internal view {
        if (
            !presale.paused() || presale.saleFinalized() || presale.owner() != config.owner
                || presale.treasuryAddress() != config.treasury || address(presale.saleToken()) != config.tokenAddress
                || presale.tokenPerBNB() != config.tokenPerBNB || presale.minPurchaseBNB() != config.minimum
                || presale.maxPurchaseBNB() != config.maximum || presale.maxPurchasePerWallet() != config.walletMaximum
                || presale.allowRepeatPurchase() != config.repeatAllowed
                || presale.maxTokensSold() != config.maximumTokens
        ) {
            revert DeploymentPostCheckFailed();
        }
    }
}
