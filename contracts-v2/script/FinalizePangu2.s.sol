// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IPancakeFactory, IPancakePair, IPancakeRouter01 } from "../src/interfaces/IPancakeV2.sol";
import { IPangu2TwapOracle } from "../src/interfaces/IPangu2TwapOracle.sol";
import { Pangu2Token } from "../src/Pangu2Token.sol";

/// @notice Finalize: verifies Oracle READY, Spot/TWAP deviation, and business gates.
///         Does NOT enable trading — that requires governance action after Finalize passes.
contract FinalizePangu2 is Script {
    address internal constant WBNB = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;
    address internal constant ROUTER = 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3;

    function run() external {
        if (block.chainid != 97) revert("Unsupported chain - BSC Testnet (97) only");

        address tokenAddr = vm.envAddress("PANGU2_TOKEN");
        address oracleAddr = vm.envAddress("PANGU2_ORACLE");
        address pairAddr = vm.envAddress("PANGU2_PAIR");
        address govAddr = vm.envAddress("GOVERNANCE_ADDRESS");

        uint256 rawTest = vm.envUint("ORACLE_TEST_AMOUNT");
        require(rawTest > 0 && rawTest <= type(uint128).max, "ORACLE_TEST_AMOUNT invalid");
        uint128 testAmount = uint128(rawTest);

        require(tokenAddr.code.length > 0, "token not deployed");
        require(oracleAddr.code.length > 0, "oracle not deployed");
        require(pairAddr.code.length > 0, "pair not deployed");
        require(govAddr != address(0), "zero gov");

        // Verify pair-factory bindings
        Pangu2Token token = Pangu2Token(tokenAddr);
        IPancakeFactory factory = IPancakeFactory(IPancakeRouter01(ROUTER).factory());
        require(factory.getPair(tokenAddr, WBNB) == pairAddr, "pair not from expected factory");

        address pairToken0 = IPancakePair(pairAddr).token0();
        address pairToken1 = IPancakePair(pairAddr).token1();
        require(
            (pairToken0 == tokenAddr && pairToken1 == WBNB) || (pairToken0 == WBNB && pairToken1 == tokenAddr),
            "pair tokens mismatch"
        );

        IPancakePair pair = IPancakePair(pairAddr);
        IPangu2TwapOracle oracle = IPangu2TwapOracle(oracleAddr);

        // Verify pair protection is active
        require(token.isPair(pairAddr), "pair protection not active");
        // Verify Router is NOT a liquidity manager anymore
        require(!token.isLiquidityManager(ROUTER), "Router still liquidity manager");

        // Verify reserves and oracle minimums
        (uint112 r0, uint112 r1, uint32 blockTimestampLast) = pair.getReserves();
        require(r0 > 0 && r1 > 0, "zero reserves");

        console.log("Reserve0:", uint256(r0));
        console.log("Reserve1:", uint256(r1));
        console.log("Pair last timestamp:", blockTimestampLast);
        console.log("Block timestamp:", block.timestamp);

        // Trigger Oracle update
        uint256 govKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        require(govKey != 0, "missing deployer key");
        vm.startBroadcast(govKey);

        oracle.update();

        // Verify Oracle is READY — bidirectional quotes
        try oracle.validatedQuote(tokenAddr, WBNB, testAmount) returns (IPangu2TwapOracle.Quote memory q) {
            require(q.amountOut > 0, "token->wbnb quote zero");
            console.log("Token->WBNB quote:", q.amountOut);
        } catch (bytes memory reason) {
            revert(string(abi.encodePacked("Oracle not ready (token->wbnb): ", reason)));
        }

        try oracle.validatedQuote(WBNB, tokenAddr, testAmount) returns (IPangu2TwapOracle.Quote memory q) {
            require(q.amountOut > 0, "wbnb->token quote zero");
            console.log("WBNB->Token quote:", q.amountOut);
        } catch (bytes memory reason) {
            revert(string(abi.encodePacked("Oracle not ready (wbnb->token): ", reason)));
        }

        // Spot/TWAP deviation in acceptable range (this is implicitly checked by validatedQuote,
        // but we note that both directions succeeded without ExcessiveSpotTwapDeviation)

        vm.stopBroadcast();

        console.log("=== Finalize Complete ===");
        console.log("Oracle READY. Pair protected. All gates passed.");
        console.log("Governance must now enable trading via governance-controlled mechanisms.");
    }
}
