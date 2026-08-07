// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IPancakeFactory, IPancakePair, IWBNB } from "../src/interfaces/IPancakeV2.sol";
import { IPangu2TwapOracle } from "../src/interfaces/IPangu2TwapOracle.sol";
import { Pangu2Token } from "../src/Pangu2Token.sol";

/// @notice Production LP proxy — deployed by the LP in Bootstrap.
contract BootstrapLpProxy {
    address public immutable lpOwner;
    address public immutable token;
    address public immutable wbnb;
    address public immutable pair;
    address public immutable lpRecipient;
    address public immutable initialHolder;
    uint256 public immutable tokenAmount;
    uint256 public immutable nativeAmount;
    bool public executed;

    error NotLpOwner();
    error AlreadyExecuted();
    error NativeAmountMismatch();

    modifier onlyLpOwner() {
        if (msg.sender != lpOwner) revert NotLpOwner();
        _;
    }

    constructor(
        address lpOwner_,
        address token_,
        address wbnb_,
        address pair_,
        address lpRecipient_,
        address initialHolder_,
        uint256 tokenAmount_,
        uint256 nativeAmount_
    ) {
        lpOwner = lpOwner_;
        token = token_;
        wbnb = wbnb_;
        pair = pair_;
        lpRecipient = lpRecipient_;
        initialHolder = initialHolder_;
        tokenAmount = tokenAmount_;
        nativeAmount = nativeAmount_;
    }

    function addLiquidity() external payable onlyLpOwner {
        if (executed) revert AlreadyExecuted();
        if (msg.value != nativeAmount) revert NativeAmountMismatch();
        executed = true;
        Pangu2Token(token).transferFrom(initialHolder, pair, tokenAmount);
        IWBNB(wbnb).deposit{ value: nativeAmount }();
        IWBNB(wbnb).transfer(pair, nativeAmount);
        IPancakePair(pair).mint(lpRecipient);
    }

    receive() external payable { }
}

/// @notice Bootstrap script — network config from env, no hardcoded chainId.
contract BootstrapPangu2 is Script {
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
        address tradeRouterAddr = vm.envAddress("PANGU2_TRADE_ROUTER");
        address lpRecipient = vm.envAddress("LP_RECIPIENT");

        uint256 initialTokenAmount = vm.envUint("INITIAL_LIQUIDITY_TOKENS");
        uint256 initialBnbAmount = vm.envUint("INITIAL_LIQUIDITY_BNB");
        uint256 minTokenAmount = vm.envUint("MIN_LIQUIDITY_TOKENS");
        uint256 minBnbAmount = vm.envUint("MIN_LIQUIDITY_BNB");
        require(initialTokenAmount > 0 && initialBnbAmount > 0, "zero initial liquidity");
        require(minTokenAmount > 0 && minBnbAmount > 0, "zero min liquidity");

        uint256 govKey = vm.envUint("GOVERNANCE_PRIVATE_KEY");
        address govAddr = vm.addr(govKey);
        require(govAddr != address(0), "invalid governance key");

        uint256 lpKey = vm.envUint("LIQUIDITY_PROVIDER_PRIVATE_KEY");
        address lpAddr = vm.addr(lpKey);
        require(lpAddr != address(0), "invalid LP key");

        uint256 holderKey = vm.envUint("INITIAL_HOLDER_PRIVATE_KEY");
        address holderAddr = vm.addr(holderKey);
        require(holderAddr != address(0), "invalid holder key");

        require(govAddr != lpAddr, "governance must differ from LP");
        require(govAddr != holderAddr, "governance must differ from holder");
        require(lpAddr != holderAddr, "LP must differ from holder");

        require(tokenAddr.code.length > 0, "token not deployed");
        require(oracleAddr.code.length > 0, "oracle not deployed");
        require(pairAddr.code.length > 0, "pair not deployed");
        require(tradeRouterAddr.code.length > 0, "tradeRouter not deployed");
        require(lpRecipient != address(0), "zero LP recipient");

        Pangu2Token token = Pangu2Token(tokenAddr);
        IPancakeFactory factory = IPancakeFactory(expectedFactory);
        require(factory.getPair(tokenAddr, expectedWbnb) == pairAddr, "pair-factory mismatch");
        IPancakePair pair = IPancakePair(pairAddr);
        IPangu2TwapOracle oracle = IPangu2TwapOracle(oracleAddr);

        // Verify pair binding via token0/token1
        address ot0 = pair.token0();
        address ot1 = pair.token1();
        require(
            (ot0 == tokenAddr && ot1 == expectedWbnb) || (ot0 == expectedWbnb && ot1 == tokenAddr),
            "pair tokens mismatch"
        );
        // Bootstrap state detection (three-phase A/B/C)
        //   A: pair not registered + reserves=0     -> first-time bootstrap
        //   B: pair registered     + reserves=0     -> setPair succeeded, liquidity not yet added -> safe to continue
        //   C: pair registered     + reserves>0     -> liquidity already added -> skip injection, verify + cleanup only

        bool pairAlreadyRegistered = token.isPair(pairAddr);
        (uint112 r0Check, uint112 r1Check,) = pair.getReserves();
        bool reservesEmpty = r0Check == 0 && r1Check == 0;
        bool reservesTwoSided = r0Check > 0 && r1Check > 0;

        // Reject inconsistent one-sided reserves
        if (!reservesEmpty && !reservesTwoSided) {
            revert("inconsistent one-sided pair reserves -- manual inspection required");
        }

        // -- State C: liquidity already present, skip all injection, only resume cleanup --
        if (reservesTwoSided) {
            require(pairAlreadyRegistered, "reserves exist but pair not registered -- inconsistent state");
            console.log("Bootstrap: liquidity already present (resume mode) -- skipping token/BNB injection");

            // Cleanup: read prior LpProxy address from deployment artifact (saved by a prior Bootstrap)
            // Artifact is scoped by chainId/token/pair to prevent cross-deployment mismatch
            string memory artifactPath = string(abi.encodePacked(
                vm.projectRoot(), "/broadcast/bootstrap-",
                vm.toString(block.chainid), "-",
                _toHexString(tokenAddr, 40), "-",
                _toHexString(pairAddr, 40), ".txt"
            ));
            string memory artifact = vm.readFile(artifactPath);
            require(bytes(artifact).length > 0, "LpProxy artifact not found -- cannot resume Bootstrap");

            address priorProxyAddr = address(uint160(vm.parseUint(artifact)));
            require(priorProxyAddr.code.length > 0, "LpProxy from artifact has no code");
            console.log("Prior LpProxy found at:");
            console.logAddress(priorProxyAddr);

            if (token.isLiquidityManager(priorProxyAddr)) {
                vm.startBroadcast(govKey);
                token.setLiquidityManager(priorProxyAddr, false);
                vm.stopBroadcast();
                require(!token.isLiquidityManager(priorProxyAddr), "LpProxy liquidityManager not revoked");
                console.log("Revoked stale liquidityManager on prior LpProxy");
            }

            // Step 7: Oracle update with on-chain minimum validation
            vm.startBroadcast(govKey);
            oracle.update();
            vm.stopBroadcast();

            // Verify final state
            (r0Check, r1Check,) = pair.getReserves();
            require(r0Check > 0 && r1Check > 0, "reserves must be two-sided after resume");
            require(token.isPair(pairAddr), "pair protection not active");

            // Map reserves to token/WBNB side using token0/token1 ordering
            (uint112 tokenRes, uint112 wbnbRes) = (ot0 == tokenAddr)
                ? (r0Check, r1Check)
                : (r1Check, r0Check);
            uint112 chainMinToken = oracle.minTokenReserve();
            uint112 chainMinWbnb = oracle.minWbnbReserve();
            require(tokenRes >= chainMinToken, "token reserve below Oracle minimum");
            require(wbnbRes >= chainMinWbnb, "WBNB reserve below Oracle minimum");

            console.log("=== Bootstrap Complete (resume) ===");
            console.log("Governance:");
            console.logAddress(govAddr);
            console.log("Reserve0:", uint256(r0Check), " Reserve1:", uint256(r1Check));
            return;
        }

        // -- State A / State B: fresh or partial Bootstrap (reserves are empty) --
        if (pairAlreadyRegistered) {
            console.log("Pair already registered (retry mode -- liquidity not yet added)");
        }

        require(token.balanceOf(holderAddr) >= initialTokenAmount, "holder has insufficient tokens");
        require(address(lpAddr).balance >= initialBnbAmount, "LP has insufficient BNB");

        // ── 1. LP deploys LpProxy ──
        vm.startBroadcast(lpKey);
        BootstrapLpProxy lpProxy = new BootstrapLpProxy(
            lpAddr, tokenAddr, expectedWbnb, pairAddr, lpRecipient, holderAddr, initialTokenAmount, initialBnbAmount
        );
        vm.stopBroadcast();
        address lpProxyAddr = address(lpProxy);
        console.log("LpProxy deployed at:", lpProxyAddr);

        // Record LpProxy address in deployment artifact for retry/resume scenarios
        // Artifact is scoped by chainId/token/pair to prevent cross-deployment mismatch
        string memory artifactPath = string(abi.encodePacked(
            vm.projectRoot(), "/broadcast/bootstrap-",
            vm.toString(block.chainid), "-",
            _toHexString(tokenAddr, 40), "-",
            _toHexString(pairAddr, 40), ".txt"
        ));
        vm.writeFile(artifactPath, vm.toString(lpProxyAddr));

        // ── 2. Governance — register Pair + authorize LpProxy ──
        vm.startBroadcast(govKey);
        require(token.hasRole(keccak256("GOVERNANCE_ROLE"), govAddr), "gov missing GOVERNANCE_ROLE");
        if (!pairAlreadyRegistered) {
            token.setPair(pairAddr, true);
        }
        token.setLiquidityManager(lpProxyAddr, true);
        require(token.isLiquidityManager(lpProxyAddr), "LpProxy not liquidityManager");
        vm.stopBroadcast();

        // ── 3. Initial Holder — approve LpProxy ──
        vm.startBroadcast(holderKey);
        token.approve(lpProxyAddr, initialTokenAmount);
        vm.stopBroadcast();
        require(token.allowance(holderAddr, lpProxyAddr) >= initialTokenAmount, "holder approval failed");

        // ── 4. LP — addLiquidity via LpProxy ──
        vm.startBroadcast(lpKey);
        lpProxy.addLiquidity{ value: initialBnbAmount }();
        vm.stopBroadcast();

        (uint112 r0, uint112 r1,) = pair.getReserves();
        require(r0 > 0 && r1 > 0, "zero reserves after bootstrap");
        console.log("Liquidity added: PANGU=", initialTokenAmount, " WBNB=", initialBnbAmount);
        console.log("Reserve0:", uint256(r0), " Reserve1:", uint256(r1));

        // ── 5. Governance — revoke LpProxy ──
        vm.startBroadcast(govKey);
        token.setLiquidityManager(lpProxyAddr, false);
        require(!token.isLiquidityManager(lpProxyAddr), "LpProxy not revoked");
        vm.stopBroadcast();

        // ── 6. Holder — clear allowance ──
        vm.startBroadcast(holderKey);
        token.approve(lpProxyAddr, 0);
        vm.stopBroadcast();
        require(token.allowance(holderAddr, lpProxyAddr) == 0, "holder allowance not zero");

        // ── 7. Governance — Oracle anchor ──
        vm.startBroadcast(govKey);
        oracle.update();
        vm.stopBroadcast();

        // ── Final assertions ──
        require(token.isPair(pairAddr), "pair protection not active");
        require(!token.isLiquidityManager(lpProxyAddr), "LpProxy liquidityManager not revoked");
        require(token.allowance(holderAddr, lpProxyAddr) == 0, "holder allowance not zero");
        require(!token.hasRole(keccak256("GOVERNANCE_ROLE"), lpAddr), "LP must not have GOVERNANCE_ROLE");
        require(token.hasRole(keccak256("GOVERNANCE_ROLE"), govAddr), "gov must retain GOVERNANCE_ROLE");

        console.log("=== Bootstrap Complete ===");
        console.log("Governance:");
        console.logAddress(govAddr);
        console.log("LP:");
        console.logAddress(lpAddr);
        console.log("LpProxy:");
        console.logAddress(lpProxyAddr);
        console.log("Oracle anchor set. Trading paused. Wait TWAP window -> run OpenTradingPangu2.");
    }

    function _toHexString(address addr, uint256 length) private pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(2 + length);
        str[0] = "0";
        str[1] = "x";
        uint160 val = uint160(addr);
        for (uint256 i = 0; i < length; i++) {
            str[2 + length - 1 - i] = alphabet[uint8(val & 0xf)];
            val >>= 4;
        }
        return string(str);
    }
}
