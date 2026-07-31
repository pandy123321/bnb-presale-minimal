// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { MockSaleToken } from "../src/MockSaleToken.sol";
import { BNBPresale } from "../src/BNBPresale.sol";
import { ScriptBase } from "./utils/ScriptBase.sol";

/// @notice 本地 Anvil 部署：部署测试币、私募合约并转入销售库存，最终保持 PAUSED。
contract DeployLocal is ScriptBase {
    uint256 internal constant TOTAL_SUPPLY = 1_000_000_000 ether;
    uint256 internal constant INVENTORY = 100_000_000 ether;
    uint256 internal constant TOKEN_PER_BNB = 100_000 ether;

    error LocalInventoryTransferMismatch(uint256 expectedInventory, uint256 actualInventory);
    error LocalDeploymentMustRemainPaused();

    function run() external returns (MockSaleToken token, BNBPresale presale) {
        _requireLocalAnvilChain();

        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.envAddress("CONTRACT_OWNER_ADDRESS");
        _requirePrivateKeyMatchesOwner(deployerPrivateKey, deployer);
        address treasury = vm.envAddress("TREASURY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);
        token = new MockSaleToken(deployer, TOTAL_SUPPLY);
        presale = new BNBPresale(
            deployer, address(token), treasury, TOKEN_PER_BNB, 0.01 ether, 10 ether, 50 ether, true, INVENTORY
        );
        if (!token.transfer(address(presale), INVENTORY)) revert("INVENTORY_TRANSFER_FAILED");
        vm.stopBroadcast();

        uint256 actualInventory = token.balanceOf(address(presale));
        if (actualInventory != INVENTORY) revert LocalInventoryTransferMismatch(INVENTORY, actualInventory);
        if (!presale.paused() || presale.saleFinalized()) revert LocalDeploymentMustRemainPaused();
    }
}
