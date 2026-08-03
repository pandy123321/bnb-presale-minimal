// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IPancakeFactory, IPancakePair, IPancakeRouter01, IWBNB } from "../src/interfaces/IPancakeV2.sol";
import { IPangu2TwapOracle } from "../src/interfaces/IPangu2TwapOracle.sol";
import { Pangu2Token } from "../src/Pangu2Token.sol";

/// @notice Bootstrap: adds initial liquidity under pair protection, sets Oracle anchor.
///         Requires liquidity provider private key (may differ from deployer).
///         Does NOT enable trading — FinalizePangu2 handles that.
contract BootstrapPangu2 is Script {
    address internal constant WBNB = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;
    address internal constant ROUTER = 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3;

    function run() external {
        if (block.chainid != 97) revert("Unsupported chain - BSC Testnet (97) only");

        address tokenAddr = vm.envAddress("PANGU2_TOKEN");
        address oracleAddr = vm.envAddress("PANGU2_ORACLE");
        address pairAddr = vm.envAddress("PANGU2_PAIR");
        address lpRecipient = vm.envAddress("LP_RECIPIENT");
        address govAddr = vm.envAddress("GOVERNANCE_ADDRESS");

        uint256 rawToken = vm.envUint("INITIAL_LIQUIDITY_TOKENS");
        uint256 rawBnb = vm.envUint("INITIAL_LIQUIDITY_BNB");
        uint256 rawMinTok = vm.envUint("MIN_LIQUIDITY_TOKENS");
        uint256 rawMinBnb = vm.envUint("MIN_LIQUIDITY_BNB");
        require(rawToken > 0 && rawBnb > 0, "zero initial liquidity");
        require(rawMinTok > 0 && rawMinBnb > 0, "zero min liquidity");
        uint256 initialTokenAmount = rawToken;
        uint256 initialBnbAmount = rawBnb;
        uint256 minTokenAmount = rawMinTok;
        uint256 minBnbAmount = rawMinBnb;

        // Liquidity provider may differ from deployer
        uint256 lpKey = vm.envUint("LIQUIDITY_PROVIDER_PRIVATE_KEY");
        address lpAddr = vm.addr(lpKey);
        require(lpAddr != address(0), "invalid LP key");

        require(tokenAddr.code.length > 0, "token not deployed");
        require(oracleAddr.code.length > 0, "oracle not deployed");
        require(pairAddr.code.length > 0, "pair not deployed");
        require(lpRecipient != address(0), "zero LP recipient");
        require(govAddr != address(0), "zero gov");

        Pangu2Token token = Pangu2Token(tokenAddr);
        IPancakeFactory factory = IPancakeFactory(IPancakeRouter01(ROUTER).factory());
        require(factory.getPair(tokenAddr, WBNB) == pairAddr, "pair-factory mismatch");
        IPancakePair pair = IPancakePair(pairAddr);
        IPangu2TwapOracle oracle = IPangu2TwapOracle(oracleAddr);

        // Verify pair is NOT yet enabled for trading
        require(!token.isPair(pairAddr), "pair already trading-enabled");

        // Verify liquidity provider holds enough tokens
        uint256 lpBalance = token.balanceOf(lpAddr);
        require(lpBalance >= initialTokenAmount, "LP has insufficient tokens");
        uint256 lpBnb = address(lpAddr).balance;
        require(lpBnb >= initialBnbAmount, "LP has insufficient BNB");

        vm.startBroadcast(lpKey);

        // 1. Protect pair BEFORE adding liquidity — but allow liquidity via Router
        // Set Router as temporary liquidityManager so addLiquidity succeeds
        // (user->pair via Router is only allowed when Router is liquidityManager)
        token.setLiquidityManager(ROUTER, true);

        // 2. Enable pair protection (now blocks all non-system pair interactions)
        token.setPair(pairAddr, true);

        // 3. Add initial liquidity via Pancake Router
        token.approve(ROUTER, initialTokenAmount);
        IWBNB(WBNB).deposit{ value: initialBnbAmount }();
        IWBNB(WBNB).approve(ROUTER, initialBnbAmount);

        (uint256 amountToken, uint256 amountBnb, uint256 liquidity) = IPancakeRouter01(ROUTER)
            .addLiquidity(
                tokenAddr,
                WBNB,
                initialTokenAmount,
                initialBnbAmount,
                minTokenAmount,
                minBnbAmount,
                lpRecipient,
                block.timestamp + 5 minutes
            );

        // 4. REMOVE Router liquidityManager — MUST be done immediately
        // Router is now a system address so setLiquidityManager handles the flags
        token.setLiquidityManager(ROUTER, false);

        // 5. Verify reserves meet Oracle minimums
        (uint112 r0, uint112 r1,) = pair.getReserves();
        require(r0 > 0 && r1 > 0, "zero reserves after bootstrap");
        console.log("Liquidity added:");
        console.log("  PANGU:", amountToken);
        console.log("  WBNB:", amountBnb);
        console.log("  LP:", liquidity);
        console.log("Pair reserve0:", uint256(r0));
        console.log("Pair reserve1:", uint256(r1));

        // 6. Verify reserves meet Oracle thresholds
        (uint112 tokenRes, uint112 wbnbRes) = _mappedReserves(tokenAddr, pairAddr, r0, r1);
        console.log("Token reserve:", uint256(tokenRes));
        console.log("WBNB reserve:", uint256(wbnbRes));

        // (Oracle thresholds verified during Finalize)

        // 7. Set Oracle anchor
        oracle.update();

        // 8. Verify pair protection is active
        require(token.isPair(pairAddr), "pair protection not active");
        require(!token.isLiquidityManager(ROUTER), "Router still liquidity manager");

        vm.stopBroadcast();

        console.log("=== Bootstrap Complete ===");
        console.log("Pair:", pairAddr);
        console.log("LP recipient:", lpRecipient);
        console.log("Pair protected. Router liquidity manager removed.");
        console.log("Oracle anchor set. Wait TWAP window, then run FinalizePangu2.");
    }

    function _mappedReserves(address tokenAddr, address pairAddr, uint112 r0, uint112 r1)
        private
        view
        returns (uint112 tokenRes, uint112 wbnbRes)
    {
        address t0 = IPancakePair(pairAddr).token0();
        if (t0 == tokenAddr) {
            tokenRes = r0;
            wbnbRes = r1;
        } else {
            tokenRes = r1;
            wbnbRes = r0;
        }
    }
}
