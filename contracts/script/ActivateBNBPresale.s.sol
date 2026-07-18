// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { BNBPresale } from "../src/BNBPresale.sol";
import { ScriptBase } from "./utils/ScriptBase.sol";

/// @notice 在部署和库存转入完成后，独立核验全部关键配置并显式激活私募。
contract ActivateBNBPresale is ScriptBase {
    struct ActivationConfig {
        address owner;
        address treasury;
        address tokenAddress;
        uint256 tokenPerBNB;
        uint256 minimum;
        uint256 maximum;
        uint256 walletMaximum;
        uint256 maximumTokens;
        uint256 requiredInventory;
        bool repeatAllowed;
    }

    error InvalidConfiguredContract(address configuredAddress);
    error ActivationConfigurationMismatch();
    error ActivationStateInvalid(bool paused, bool finalized);
    error ActivationInventoryInsufficient(uint256 actualInventory, uint256 requiredInventory);
    error ActivationMinimumPurchaseUnsupported(uint256 actualInventory, uint256 minimumTokenOutput);
    error ActivationPostCheckFailed();

    function run() external returns (BNBPresale presale) {
        _requireExpectedChain(vm.envUint("EXPECTED_CHAIN_ID"), vm.envBool("ALLOW_MAINNET_WRITES"));

        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        ActivationConfig memory config = _loadConfig();
        _requirePrivateKeyMatchesOwner(deployerPrivateKey, config.owner);

        address presaleAddress = vm.envAddress("PRESALE_ADDRESS");
        if (presaleAddress.code.length == 0) revert InvalidConfiguredContract(presaleAddress);
        presale = BNBPresale(payable(presaleAddress));

        _requireConfigurationMatches(presale, config);
        _requireReadyForActivation(presale, config);

        vm.startBroadcast(deployerPrivateKey);
        presale.unpause();
        vm.stopBroadcast();

        if (presale.paused() || presale.saleFinalized()) revert ActivationPostCheckFailed();
    }

    function _loadConfig() internal returns (ActivationConfig memory config) {
        config.owner = vm.envAddress("CONTRACT_OWNER_ADDRESS");
        config.treasury = vm.envAddress("TREASURY_ADDRESS");
        config.tokenAddress = vm.envAddress("SALE_TOKEN_ADDRESS");
        config.tokenPerBNB = vm.envUint("TOKEN_PER_BNB_RAW");
        config.minimum = vm.envUint("MIN_PURCHASE_BNB_WEI");
        config.maximum = vm.envUint("MAX_PURCHASE_BNB_WEI");
        config.walletMaximum = vm.envUint("MAX_PURCHASE_PER_WALLET_WEI");
        config.maximumTokens = vm.envUint("MAX_TOKENS_SOLD_RAW");
        config.requiredInventory = vm.envUint("INITIAL_INVENTORY_RAW");
        config.repeatAllowed = vm.envBool("ALLOW_REPEAT_PURCHASE");
    }

    function _requireConfigurationMatches(BNBPresale presale, ActivationConfig memory config) internal view {
        if (
            presale.owner() != config.owner || presale.treasuryAddress() != config.treasury
                || address(presale.saleToken()) != config.tokenAddress || presale.tokenPerBNB() != config.tokenPerBNB
                || presale.minPurchaseBNB() != config.minimum || presale.maxPurchaseBNB() != config.maximum
                || presale.maxPurchasePerWallet() != config.walletMaximum
                || presale.allowRepeatPurchase() != config.repeatAllowed
                || presale.maxTokensSold() != config.maximumTokens
        ) {
            revert ActivationConfigurationMismatch();
        }
    }

    function _requireReadyForActivation(BNBPresale presale, ActivationConfig memory config) internal view {
        bool isPaused = presale.paused();
        bool isFinalized = presale.saleFinalized();
        if (!isPaused || isFinalized) revert ActivationStateInvalid(isPaused, isFinalized);
        if (config.requiredInventory == 0) revert ActivationInventoryInsufficient(0, 1);

        uint256 actualInventory = IERC20(config.tokenAddress).balanceOf(address(presale));
        if (actualInventory < config.requiredInventory) {
            revert ActivationInventoryInsufficient(actualInventory, config.requiredInventory);
        }

        uint256 minimumPayment = config.minimum == 0 ? 1 : config.minimum;
        uint256 minimumTokenOutput = Math.mulDiv(minimumPayment, config.tokenPerBNB, 1 ether);
        if (minimumTokenOutput == 0 || actualInventory < minimumTokenOutput) {
            revert ActivationMinimumPurchaseUnsupported(actualInventory, minimumTokenOutput);
        }
    }
}
