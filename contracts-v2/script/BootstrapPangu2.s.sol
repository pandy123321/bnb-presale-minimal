// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IPancakeFactory, IPancakePair, IWBNB } from "../src/interfaces/IPancakeV2.sol";
import { IPangu2TwapOracle } from "../src/interfaces/IPangu2TwapOracle.sol";
import { Pangu2Token } from "../src/Pangu2Token.sol";

/// @notice Lightweight LP proxy — deployed by the LP in Bootstrap.
///         Provides a contract address that can receive liquidityManager permission,
///         then pulls PANGU from initialHolder via approve+transferFrom and adds
///         liquidity in a single transaction.
contract BootstrapLpProxy {
    address public immutable lpOwner;
    address public immutable token;
    address public immutable wbnb;
    address public immutable pair;
    address public immutable lpRecipient;
    address public immutable initialHolder;

    error NotLpOwner();

    modifier onlyLpOwner() {
        if (msg.sender != lpOwner) revert NotLpOwner();
        _;
    }

    constructor(address token_, address wbnb_, address pair_, address lpRecipient_, address initialHolder_) {
        lpOwner = tx.origin;
        token = token_;
        wbnb = wbnb_;
        pair = pair_;
        lpRecipient = lpRecipient_;
        initialHolder = initialHolder_;
    }

    /// @notice Pull PANGU from initialHolder (via pre-approved allowance), wrap BNB, add liquidity.
    /// @param tokenAmount Exact PANGU tokens to pull from initialHolder and add to pair.
    function addLiquidity(uint256 tokenAmount) external payable onlyLpOwner {
        // Pull PANGU from initialHolder — msg.sender is this proxy (liquidityManager) → allowed
        Pangu2Token(token).transferFrom(initialHolder, pair, tokenAmount);
        // Deposit BNB → WBNB and send to pair
        IWBNB(wbnb).deposit{ value: msg.value }();
        IWBNB(wbnb).transfer(pair, msg.value);
        IPancakePair(pair).mint(lpRecipient);
    }

    receive() external payable { }
}

/// @notice 引导脚本：在交易对保护下添加初始流动性并建立 Oracle 锚点。
///         四个独立角色：
///           - Liquidity Provider：部署 LpProxy，通过 Proxy 加池（仅加池权限，无 Governance）
///           - Governance：Pair 配置、LpProxy 授权、Oracle 锚点、撤销授权
///           - Initial Holder：approve LpProxy 可拉取代币（不直接转账，保持 Cost Basis 干净）
///           - LpProxy（合约）：接收 liquidityManager 权限，执行单次加池
///         不开放交易 —— 需等待 TWAP 窗口完成后再通过 FinalizePangu2 验证。
contract BootstrapPangu2 is Script {
    address internal constant WBNB = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;
    address internal constant FACTORY = 0x6725F303b657a9451d8BA641348b6761A6CC7a17;

    function run() external {
        if (block.chainid != 97) revert("Unsupported chain - BSC Testnet (97) only");

        // ── 读取环境变量 ──
        address tokenAddr = vm.envAddress("PANGU2_TOKEN");
        address oracleAddr = vm.envAddress("PANGU2_ORACLE");
        address pairAddr = vm.envAddress("PANGU2_PAIR");
        address lpRecipient = vm.envAddress("LP_RECIPIENT");

        uint256 initialTokenAmount = vm.envUint("INITIAL_LIQUIDITY_TOKENS");
        uint256 initialBnbAmount = vm.envUint("INITIAL_LIQUIDITY_BNB");
        uint256 minTokenAmount = vm.envUint("MIN_LIQUIDITY_TOKENS");
        uint256 minBnbAmount = vm.envUint("MIN_LIQUIDITY_BNB");
        require(initialTokenAmount > 0 && initialBnbAmount > 0, "zero initial liquidity");
        require(minTokenAmount > 0 && minBnbAmount > 0, "zero min liquidity");

        // ── 三个独立角色的私钥 —— 严禁复用 ──
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

        // ── 验证合约已部署 ──
        require(tokenAddr.code.length > 0, "token not deployed");
        require(oracleAddr.code.length > 0, "oracle not deployed");
        require(pairAddr.code.length > 0, "pair not deployed");
        require(lpRecipient != address(0), "zero LP recipient");

        Pangu2Token token = Pangu2Token(tokenAddr);
        IPancakeFactory factory = IPancakeFactory(FACTORY);
        require(factory.getPair(tokenAddr, WBNB) == pairAddr, "pair-factory mismatch");
        IPancakePair pair = IPancakePair(pairAddr);
        IPangu2TwapOracle oracle = IPangu2TwapOracle(oracleAddr);

        require(!token.isPair(pairAddr), "pair already trading-enabled");
        require(token.balanceOf(holderAddr) >= initialTokenAmount, "holder has insufficient tokens");
        require(address(lpAddr).balance >= initialBnbAmount, "LP has insufficient BNB");

        // ════════════════════════════════════════════════════
        // 广播 1：LP — 部署 LpProxy 合约
        // ════════════════════════════════════════════════════
        vm.startBroadcast(lpKey);
        BootstrapLpProxy lpProxy = new BootstrapLpProxy(tokenAddr, WBNB, pairAddr, lpRecipient, holderAddr);
        vm.stopBroadcast();
        address lpProxyAddr = address(lpProxy);
        console.log("LpProxy deployed at:", lpProxyAddr);

        // ════════════════════════════════════════════════════
        // 广播 2：Governance — 注册 Pair 并授权 LpProxy
        // ════════════════════════════════════════════════════
        vm.startBroadcast(govKey);
        require(token.hasRole(keccak256("GOVERNANCE_ROLE"), govAddr), "gov missing GOVERNANCE_ROLE");

        token.setPair(pairAddr, true);

        // LpProxy 是合约 → setLiquidityManager 可接受
        token.setLiquidityManager(lpProxyAddr, true);
        require(token.isLiquidityManager(lpProxyAddr), "LpProxy not liquidityManager");
        vm.stopBroadcast();

        // ════════════════════════════════════════════════════
        // 广播 3：Initial Holder — approve LpProxy 拉取代币
        //     （不直接转账给 LpProxy — 避免 unregistered-contract 检测）
        // ════════════════════════════════════════════════════
        vm.startBroadcast(holderKey);
        token.approve(lpProxyAddr, initialTokenAmount);
        vm.stopBroadcast();
        require(token.allowance(holderAddr, lpProxyAddr) >= initialTokenAmount, "holder approval failed");

        // ════════════════════════════════════════════════════
        // 广播 4：LP — 通过 LpProxy 加池
        // ════════════════════════════════════════════════════
        vm.startBroadcast(lpKey);
        lpProxy.addLiquidity{ value: initialBnbAmount }(initialTokenAmount);
        vm.stopBroadcast();

        (uint112 r0, uint112 r1,) = pair.getReserves();
        require(r0 > 0 && r1 > 0, "zero reserves after bootstrap");
        console.log("Liquidity added:");
        console.log("  PANGU:", initialTokenAmount);
        console.log("  WBNB:", initialBnbAmount);
        console.log("  Reserve0:", uint256(r0));
        console.log("  Reserve1:", uint256(r1));

        (uint112 tokenRes, uint112 wbnbRes) = _mappedReserves(tokenAddr, pairAddr, r0, r1);
        console.log("  Token reserve:", uint256(tokenRes));
        console.log("  WBNB reserve:", uint256(wbnbRes));

        // ════════════════════════════════════════════════════
        // 广播 5：Governance — 撤销 LpProxy 授权 + Oracle 锚点
        // ════════════════════════════════════════════════════
        vm.startBroadcast(govKey);

        token.setLiquidityManager(lpProxyAddr, false);
        require(!token.isLiquidityManager(lpProxyAddr), "LpProxy not revoked");

        oracle.update();

        vm.stopBroadcast();

        // ── 广播后权限验证 ──
        require(token.isPair(pairAddr), "pair protection not active");
        require(!token.isLiquidityManager(lpProxyAddr), "LpProxy liquidityManager not revoked");
        require(!token.isLiquidityManager(lpAddr), "LP EOA must not be liquidityManager");
        require(!token.hasRole(keccak256("GOVERNANCE_ROLE"), lpAddr), "LP must not have GOVERNANCE_ROLE");
        require(token.hasRole(keccak256("GOVERNANCE_ROLE"), govAddr), "gov must retain GOVERNANCE_ROLE");

        console.log("=== Bootstrap Complete ===");
        console.log("Governance:", govAddr);
        console.log("LP (EOA):", lpAddr);
        console.log("LpProxy:", lpProxyAddr);
        console.log("LP recipient:", lpRecipient);
        console.log("Initial Holder:", holderAddr);
        console.log("Pair:", pairAddr);
        console.log("Oracle anchor set. Pair protected. LpProxy liquidityManager revoked.");
        console.log("Wait TWAP window, then run FinalizePangu2 with Governance.");
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
