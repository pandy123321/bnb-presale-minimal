// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IPancakeFactory, IPancakePair, IPancakeRouter01 } from "../src/interfaces/IPancakeV2.sol";
import { IPangu2TwapOracle } from "../src/interfaces/IPangu2TwapOracle.sol";
import { Pangu2Token } from "../src/Pangu2Token.sol";

/// @notice 最终化脚本：验证 Oracle READY、Spot/TWAP 偏差和所有业务门控。
///         必须在 BootstrapPangu2 执行且 TWAP 完整窗口经过后运行。
///         不直接开启交易 —— 需 governance 在 Finalize 通过后手动开启。
contract FinalizePangu2 is Script {
    address internal constant WBNB = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;
    address internal constant ROUTER = 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3;

    function run() external {
        if (block.chainid != 97) revert("Unsupported chain - BSC Testnet (97) only");

        // ── 读取环境变量 ──
        address tokenAddr = vm.envAddress("PANGU2_TOKEN");
        address oracleAddr = vm.envAddress("PANGU2_ORACLE");
        address pairAddr = vm.envAddress("PANGU2_PAIR");
        address govAddr = vm.envAddress("GOVERNANCE_ADDRESS");

        uint256 rawTest = vm.envUint("ORACLE_TEST_AMOUNT"); // 双向报价测试的小额数量
        require(rawTest > 0 && rawTest <= type(uint128).max, "ORACLE_TEST_AMOUNT invalid");
        uint128 testAmount = uint128(rawTest);

        // ── 验证合约已部署 ──
        require(tokenAddr.code.length > 0, "token not deployed");
        require(oracleAddr.code.length > 0, "oracle not deployed");
        require(pairAddr.code.length > 0, "pair not deployed");
        require(govAddr != address(0), "zero gov");

        // ── 验证交易对与 Factory 的绑定关系 ──
        Pangu2Token token = Pangu2Token(tokenAddr);
        IPancakeFactory factory = IPancakeFactory(IPancakeRouter01(ROUTER).factory());
        require(factory.getPair(tokenAddr, WBNB) == pairAddr, "pair not from expected factory"); // 防止伪造 pair

        address pairToken0 = IPancakePair(pairAddr).token0();
        address pairToken1 = IPancakePair(pairAddr).token1();
        require((pairToken0 == tokenAddr && pairToken1 == WBNB) || (pairToken0 == WBNB && pairToken1 == tokenAddr), "pair tokens mismatch");

        IPancakePair pair = IPancakePair(pairAddr);
        IPangu2TwapOracle oracle = IPangu2TwapOracle(oracleAddr);

        // ── 验证交易对保护是否激活 ──
        require(token.isPair(pairAddr), "pair protection not active");
        // Router 不能仍然持有 liquidityManager 权限
        require(!token.isLiquidityManager(ROUTER), "Router still liquidity manager");

        // ── 验证储备和 Oracle 阈值 ──
        (uint112 r0, uint112 r1, uint32 blockTimestampLast) = pair.getReserves();
        require(r0 > 0 && r1 > 0, "zero reserves");
        console.log("Reserve0:", uint256(r0));
        console.log("Reserve1:", uint256(r1));
        console.log("Pair last timestamp:", blockTimestampLast);
        console.log("Block timestamp:", block.timestamp);

        // ── 触发第二次 Oracle update ──
        uint256 govKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        require(govKey != 0, "missing deployer key");
        vm.startBroadcast(govKey);
        oracle.update();

        // ── 验证 Oracle 已进入 READY 状态 —— 双向报价测试 ──
        // PANGU2 → WBNB 方向
        try oracle.validatedQuote(tokenAddr, WBNB, testAmount) returns (IPangu2TwapOracle.Quote memory q) {
            require(q.amountOut > 0, "token->wbnb quote zero");
            console.log("Token->WBNB quote:", q.amountOut);
        } catch (bytes memory reason) {
            revert(string(abi.encodePacked("Oracle not ready (token->wbnb): ", reason)));
        }
        // WBNB → PANGU2 方向
        try oracle.validatedQuote(WBNB, tokenAddr, testAmount) returns (IPangu2TwapOracle.Quote memory q) {
            require(q.amountOut > 0, "wbnb->token quote zero");
            console.log("WBNB->Token quote:", q.amountOut);
        } catch (bytes memory reason) {
            revert(string(abi.encodePacked("Oracle not ready (wbnb->token): ", reason)));
        }
        // Spot/TWAP 偏差在允许范围内
        // （validatedQuote 内部已校验，双向成功说明偏差未超标）

        vm.stopBroadcast();

        console.log("=== Finalize Complete ===");
        console.log("Oracle READY. Pair protected. All gates passed.");
        console.log("Governance must now enable trading via governance-controlled mechanisms.");
    }
}
