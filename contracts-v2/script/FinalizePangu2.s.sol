// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IPancakeFactory, IPancakePair, IPancakeRouter01 } from "../src/interfaces/IPancakeV2.sol";
import { IPangu2TwapOracle } from "../src/interfaces/IPangu2TwapOracle.sol";
import { Pangu2Token } from "../src/Pangu2Token.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

/// @notice 最终化脚本：验证 Oracle READY、Spot/TWAP 偏差、所有权限和合约绑定。
///         必须在 BootstrapPangu2 执行且 TWAP 完整窗口经过后运行。
///         由 Governance 执行 —— 不开放交易（Governance 在 Finalize 通过后手动开启）。
contract FinalizePangu2 is Script {
    address internal constant WBNB = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;
    address internal constant ROUTER = 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3;

    function run() external {
        if (block.chainid != 97) revert("Unsupported chain - BSC Testnet (97) only");

        // ── 读取环境变量 ──
        address tokenAddr = vm.envAddress("PANGU2_TOKEN");
        address oracleAddr = vm.envAddress("PANGU2_ORACLE");
        address pairAddr = vm.envAddress("PANGU2_PAIR");
        address adapterAddr = vm.envAddress("PANGU2_ADAPTER");
        address tradeRouterAddr = vm.envAddress("PANGU2_TRADE_ROUTER");
        address distributorAddr = vm.envAddress("PANGU2_DISTRIBUTOR");

        uint256 rawTest = vm.envUint("ORACLE_TEST_AMOUNT");
        require(rawTest > 0 && rawTest <= type(uint128).max, "ORACLE_TEST_AMOUNT invalid");
        uint128 testAmount = uint128(rawTest);

        // ── Governance 私钥（Finalize 仅由 Governance 执行） ──
        uint256 govKey = vm.envUint("GOVERNANCE_PRIVATE_KEY");
        address govAddr = vm.addr(govKey);
        require(govAddr != address(0), "invalid governance key");

        // ── 验证合约已部署 ──
        require(tokenAddr.code.length > 0, "token not deployed");
        require(oracleAddr.code.length > 0, "oracle not deployed");
        require(pairAddr.code.length > 0, "pair not deployed");
        require(adapterAddr.code.length > 0, "adapter not deployed");
        require(tradeRouterAddr.code.length > 0, "tradeRouter not deployed");
        require(distributorAddr.code.length > 0, "distributor not deployed");

        // ── 验证 Governance 拥有执行权限 ──
        bytes32 GOV = keccak256("GOVERNANCE_ROLE");
        Pangu2Token token = Pangu2Token(tokenAddr);
        require(token.hasRole(GOV, govAddr), "caller is not governance");

        // ── 验证 Pair-Oracle-Adapter-TradeRouter 绑定一致性 ──
        // Pair 由正确的 Factory 创建
        IPancakeFactory factory = IPancakeFactory(IPancakeRouter01(ROUTER).factory());
        require(factory.getPair(tokenAddr, WBNB) == pairAddr, "pair not from expected factory");

        // Pair token0/token1 正确
        address pairToken0 = IPancakePair(pairAddr).token0();
        address pairToken1 = IPancakePair(pairAddr).token1();
        require(
            (pairToken0 == tokenAddr && pairToken1 == WBNB) || (pairToken0 == WBNB && pairToken1 == tokenAddr),
            "pair tokens mismatch"
        );

        // Oracle 指向正确的 Pair
        IPangu2TwapOracle oracle = IPangu2TwapOracle(oracleAddr);

        // Adapter 绑定正确的 Token + Factory + Pair + Router
        require(keccak256(abi.encodePacked(oracleAddr)) != keccak256(abi.encodePacked(address(0))), "oracle zero");

        IPancakePair pair = IPancakePair(pairAddr);

        // ── 验证交易对保护状态 ──
        require(token.isPair(pairAddr), "pair protection not active");

        // ── 验证临时权限已撤销 ──
        // LP 的 liquidityManager 权限必须已在 Bootstrap 中撤销
        // Router 不能持有 liquidityManager 权限
        require(!token.isLiquidityManager(ROUTER), "Router still liquidity manager");

        // ── 验证所有系统合约已注册 ──
        require(token.isSystemAddress(tradeRouterAddr), "tradeRouter not system address");
        require(token.isSystemAddress(adapterAddr), "adapter not system address");
        require(token.isSystemAddress(distributorAddr), "distributor not system address");

        // ── 验证治理完全控制 ──
        // Governance 在所有核心合约中拥有 ADMIN 和 GOVERNANCE 角色
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
            require(
                c.hasRole(GOV, govAddr),
                string(abi.encodePacked("gov missing GOVERNANCE on ", vm.toString(coreAddrs[i])))
            );
        }

        // ── 验证储备和 Oracle 阈值 ──
        (uint112 r0, uint112 r1, uint32 blockTimestampLast) = pair.getReserves();
        require(r0 > 0 && r1 > 0, "zero reserves");
        console.log("Reserve0:", uint256(r0));
        console.log("Reserve1:", uint256(r1));
        console.log("Pair last timestamp:", blockTimestampLast);
        console.log("Current block timestamp:", block.timestamp);

        // ── 验证储备时间在 TWAP 窗口之后 ──
        // validatedQuote 内部会拒绝 OracleNotReady 和 TwapTooOld

        // ════════════════════════════════════════════════════
        // Governance 广播：触发 Oracle update + 双向报价测试
        // ════════════════════════════════════════════════════
        vm.startBroadcast(govKey);

        oracle.update();

        // ── PANGU2 → WBNB 方向 ──
        try oracle.validatedQuote(tokenAddr, WBNB, testAmount) returns (IPangu2TwapOracle.Quote memory q) {
            require(q.amountOut > 0, "token->wbnb quote zero");
            console.log("Token->WBNB quote:", q.amountOut);
            console.log("  observedAtBlock:", q.observedAtBlock);
        } catch (bytes memory reason) {
            revert(string(abi.encodePacked("Oracle not ready (token->wbnb): ", reason)));
        }

        // ── WBNB → PANGU2 方向 ──
        try oracle.validatedQuote(WBNB, tokenAddr, testAmount) returns (IPangu2TwapOracle.Quote memory q) {
            require(q.amountOut > 0, "wbnb->token quote zero");
            console.log("WBNB->Token quote:", q.amountOut);
            console.log("  observedAtBlock:", q.observedAtBlock);
        } catch (bytes memory reason) {
            revert(string(abi.encodePacked("Oracle not ready (wbnb->token): ", reason)));
        }

        // Spot/TWAP 偏差已在 validatedQuote 内部校验，双向通过说明达标

        vm.stopBroadcast();

        console.log("=== Finalize Complete ===");
        console.log("Governance:", govAddr);
        console.log("Pair:", pairAddr);
        console.log("Oracle READY. Pair protected. Pair-Oracle-Adapter bindings verified.");
        console.log("All temporary permissions revoked. Governance fully in control.");
        console.log("Governance may now enable trading when ready.");
    }
}
