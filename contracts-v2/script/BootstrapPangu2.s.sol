// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IPancakeFactory, IPancakePair, IWBNB } from "../src/interfaces/IPancakeV2.sol";
import { IPangu2TwapOracle } from "../src/interfaces/IPangu2TwapOracle.sol";
import { Pangu2Token } from "../src/Pangu2Token.sol";

/// @notice 引导脚本：在交易对保护下添加初始流动性并建立 Oracle 锚点。
///         流动性提供者可以使用独立于 deployer 的私钥。
///         不开放交易 —— 需要等待 FinalizePangu2 在 TWAP 窗口后完成。
contract BootstrapPangu2 is Script {
    address internal constant WBNB = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;   // BSC 测试网 WBNB
    address internal constant FACTORY = 0x6725F303b657a9451d8BA641348b6761A6CC7a17; // BSC 测试网 PancakeV2 Factory

    function run() external {
        if (block.chainid != 97) revert("Unsupported chain - BSC Testnet (97) only");

        // ── 读取环境变量 ──
        address tokenAddr = vm.envAddress("PANGU2_TOKEN");
        address oracleAddr = vm.envAddress("PANGU2_ORACLE");
        address pairAddr = vm.envAddress("PANGU2_PAIR");
        address lpRecipient = vm.envAddress("LP_RECIPIENT");
        address govAddr = vm.envAddress("GOVERNANCE_ADDRESS");

        uint256 initialTokenAmount = vm.envUint("INITIAL_LIQUIDITY_TOKENS");
        uint256 initialBnbAmount   = vm.envUint("INITIAL_LIQUIDITY_BNB");
        uint256 minTokenAmount     = vm.envUint("MIN_LIQUIDITY_TOKENS");
        uint256 minBnbAmount       = vm.envUint("MIN_LIQUIDITY_BNB");
        require(initialTokenAmount > 0 && initialBnbAmount > 0, "zero initial liquidity");
        require(minTokenAmount > 0 && minBnbAmount > 0, "zero min liquidity");

        uint256 lpKey = vm.envUint("LIQUIDITY_PROVIDER_PRIVATE_KEY");
        address lpAddr = vm.addr(lpKey);
        require(lpAddr != address(0), "invalid LP key");

        // ── 验证合约已部署 ──
        require(tokenAddr.code.length > 0, "token not deployed");
        require(oracleAddr.code.length > 0, "oracle not deployed");
        require(pairAddr.code.length > 0, "pair not deployed");
        require(lpRecipient != address(0), "zero LP recipient");
        require(govAddr != address(0), "zero gov");

        Pangu2Token token = Pangu2Token(tokenAddr);
        IPancakeFactory factory = IPancakeFactory(FACTORY);
        require(factory.getPair(tokenAddr, WBNB) == pairAddr, "pair-factory mismatch");
        IPancakePair pair = IPancakePair(pairAddr);
        IPangu2TwapOracle oracle = IPangu2TwapOracle(oracleAddr);

        // 交易对尚未开放交易
        require(!token.isPair(pairAddr), "pair already trading-enabled");

        // 验证流动性提供者持有足够代币和 BNB
        require(token.balanceOf(lpAddr) >= initialTokenAmount, "LP has insufficient tokens");
        require(address(lpAddr).balance >= initialBnbAmount, "LP has insufficient BNB");

        vm.startBroadcast(lpKey);

        // ── 第 1 步：启用交易对保护（此时所有非系统交易对交互都被阻止） ──
        token.setPair(pairAddr, true);

        // ── 第 2 步：直接转代币到 Pair（绕过 Router） ──
        token.transfer(pairAddr, initialTokenAmount);

        // 第 3 步：Wrap BNB → WBNB，转 WBNB 到 Pair
        IWBNB(WBNB).deposit{ value: initialBnbAmount }();
        IWBNB(WBNB).transfer(pairAddr, initialBnbAmount);

        // ── 第 4 步：Mint LP tokens ──
        uint256 liquidity = pair.mint(lpRecipient);

        // ── 第 5 步：验证储备满足基本要求 ──
        (uint112 r0, uint112 r1,) = pair.getReserves();
        require(r0 > 0 && r1 > 0, "zero reserves after bootstrap");
        console.log("Liquidity added:");
        console.log("  PANGU:", initialTokenAmount);
        console.log("  WBNB:", initialBnbAmount);
        console.log("  LP:", liquidity);
        console.log("Pair reserve0:", uint256(r0));
        console.log("Pair reserve1:", uint256(r1));

        // ── 第 6 步：按 token0/token1 映射储备 ──
        (uint112 tokenRes, uint112 wbnbRes) = _mappedReserves(tokenAddr, pairAddr, r0, r1);
        console.log("Token reserve:", uint256(tokenRes));
        console.log("WBNB reserve:", uint256(wbnbRes));

        // ── 第 7 步：建立 Oracle 锚点 ──
        oracle.update();

        // ── 第 8 步：验证交易对保护已激活 ──
        require(token.isPair(pairAddr), "pair protection not active");

        vm.stopBroadcast();

        console.log("=== Bootstrap Complete ===");
        console.log("Pair:", pairAddr);
        console.log("LP recipient:", lpRecipient);
        console.log("Pair protected. Oracle anchor set. Wait TWAP window, then run FinalizePangu2.");
    }

    function _mappedReserves(address tokenAddr, address pairAddr, uint112 r0, uint112 r1)
        private view returns (uint112 tokenRes, uint112 wbnbRes)
    {
        address t0 = IPancakePair(pairAddr).token0();
        if (t0 == tokenAddr) { tokenRes = r0; wbnbRes = r1; }
        else { tokenRes = r1; wbnbRes = r0; }
    }
}
