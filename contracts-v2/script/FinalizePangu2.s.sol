// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IPancakeFactory, IPancakePair, IPancakeRouter01 } from "../src/interfaces/IPancakeV2.sol";
import { IPangu2TwapOracle } from "../src/interfaces/IPangu2TwapOracle.sol";
import { Pangu2Token } from "../src/Pangu2Token.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

/// @notice Finalize — verifies Oracle READY + all bindings.
///         Does NOT open trading. Trading opened separately via OpenTradingPangu2.
contract FinalizePangu2 is Script {
    function run() external {
        uint256 expectedChainId = vm.envUint("EXPECTED_CHAIN_ID");
        address expectedWbnb = vm.envAddress("EXPECTED_WBNB");
        address expectedFactory = vm.envAddress("EXPECTED_FACTORY");
        address expectedRouter = vm.envAddress("EXPECTED_ROUTER");

        if (block.chainid != expectedChainId) revert("wrong chain");
        require(expectedWbnb.code.length > 0, "WBNB has no code");
        require(expectedFactory.code.length > 0, "Factory has no code");
        require(expectedRouter.code.length > 0, "Router has no code");

        address tokenAddr = vm.envAddress("PANGU2_TOKEN");
        address oracleAddr = vm.envAddress("PANGU2_ORACLE");
        address pairAddr = vm.envAddress("PANGU2_PAIR");
        address adapterAddr = vm.envAddress("PANGU2_ADAPTER");
        address tradeRouterAddr = vm.envAddress("PANGU2_TRADE_ROUTER");
        address distributorAddr = vm.envAddress("PANGU2_DISTRIBUTOR");

        uint256 rawTest = vm.envUint("ORACLE_TEST_AMOUNT");
        require(rawTest > 0 && rawTest <= type(uint128).max, "ORACLE_TEST_AMOUNT invalid");
        uint128 testAmount = uint128(rawTest);

        uint256 govKey = vm.envUint("GOVERNANCE_PRIVATE_KEY");
        address govAddr = vm.addr(govKey);
        require(govAddr != address(0), "invalid governance key");

        require(tokenAddr.code.length > 0, "token not deployed");
        require(oracleAddr.code.length > 0, "oracle not deployed");
        require(pairAddr.code.length > 0, "pair not deployed");

        bytes32 GOV = keccak256("GOVERNANCE_ROLE");
        Pangu2Token token = Pangu2Token(tokenAddr);
        require(token.hasRole(GOV, govAddr), "caller is not governance");

        // Pair bindings
        IPancakeFactory factory = IPancakeFactory(IPancakeRouter01(expectedRouter).factory());
        require(factory.getPair(tokenAddr, expectedWbnb) == pairAddr, "pair not from expected factory");

        address pairToken0 = IPancakePair(pairAddr).token0();
        address pairToken1 = IPancakePair(pairAddr).token1();
        require(
            (pairToken0 == tokenAddr && pairToken1 == expectedWbnb)
                || (pairToken0 == expectedWbnb && pairToken1 == tokenAddr),
            "pair tokens mismatch"
        );

        IPangu2TwapOracle oracle = IPangu2TwapOracle(oracleAddr);
        IPancakePair pair = IPancakePair(pairAddr);

        require(token.isPair(pairAddr), "pair protection not active");
        require(!token.isLiquidityManager(expectedRouter), "Router still liquidity manager");

        // Governance permissions
        bytes32 DA = 0x00;
        address[] memory coreAddrs = new address[](4);
        coreAddrs[0] = tokenAddr;
        coreAddrs[1] = tradeRouterAddr;
        coreAddrs[2] = distributorAddr;
        coreAddrs[3] = oracleAddr;
        for (uint256 i = 0; i < coreAddrs.length; i++) {
            IAccessControl c = IAccessControl(coreAddrs[i]);
            require(
                c.hasRole(DA, govAddr), string(abi.encodePacked("gov missing ADMIN on ", vm.toString(coreAddrs[i])))
            );
            require(c.hasRole(GOV, govAddr), string(abi.encodePacked("gov missing GOV on ", vm.toString(coreAddrs[i]))));
        }

        (uint112 r0, uint112 r1, uint32 blockTimestampLast) = pair.getReserves();
        require(r0 > 0 && r1 > 0, "zero reserves");
        console.log("Reserve0:");
        console.log(uint256(r0));
        console.log("Reserve1:");
        console.log(uint256(r1));

        // Oracle update + bidirectional quote validation
        vm.startBroadcast(govKey);
        oracle.update();

        try oracle.validatedQuote(tokenAddr, expectedWbnb, testAmount) returns (IPangu2TwapOracle.Quote memory q) {
            require(q.amountOut > 0, "token->wbnb quote zero");
            console.log("Token->WBNB quote:", q.amountOut);
        } catch (bytes memory reason) {
            revert(string(abi.encodePacked("Oracle not ready (token->wbnb): ", reason)));
        }

        try oracle.validatedQuote(expectedWbnb, tokenAddr, testAmount) returns (IPangu2TwapOracle.Quote memory q) {
            require(q.amountOut > 0, "wbnb->token quote zero");
            console.log("WBNB->Token quote:", q.amountOut);
        } catch (bytes memory reason) {
            revert(string(abi.encodePacked("Oracle not ready (wbnb->token): ", reason)));
        }

        vm.stopBroadcast();

        console.log("=== Finalize Complete ===");
        console.log("Oracle READY. Trading remains PAUSED.");
        console.log("Run OpenTradingPangu2 to activate trading and start the 15min protection window.");
    }
}
