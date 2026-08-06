// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { Pangu2Token } from "../src/Pangu2Token.sol";

/// @notice Opens trading by calling setTradingOpenAt() — starts the 15-minute launch protection window.
///         Must be called AFTER Bootstrap and after Finalize (Oracle READY).
///         TradeRouter remains paused — governance unpauses separately if desired.
contract OpenTradingPangu2 is Script {
    function run() external {
        uint256 expectedChainId = vm.envUint("EXPECTED_CHAIN_ID");
        if (block.chainid != expectedChainId) revert("wrong chain");

        address tokenAddr = vm.envAddress("PANGU2_TOKEN");
        require(tokenAddr.code.length > 0, "token not deployed");

        uint256 govKey = vm.envUint("GOVERNANCE_PRIVATE_KEY");
        address govAddr = vm.addr(govKey);
        require(govAddr != address(0), "invalid governance key");

        Pangu2Token token = Pangu2Token(tokenAddr);
        require(token.hasRole(keccak256("GOVERNANCE_ROLE"), govAddr), "caller is not governance");

        vm.startBroadcast(govKey);
        token.setTradingOpenAt();
        vm.stopBroadcast();

        console.log("=== Trading Opened ===");
        console.log("tradingOpenAt:", token.tradingOpenAt());
        console.log("15-minute launch protection window started.");
        console.log("TradeRouter still PAUSED - unpause via governance when ready.");
    }
}
