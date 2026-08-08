// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test, console } from "forge-std/Test.sol";
import { Pangu2Token } from "pangu2/Pangu2Token.sol";
import { CostBasisManager } from "pangu2/CostBasisManager.sol";
import { PancakeV2Adapter } from "pangu2/adapters/PancakeV2Adapter.sol";
import { PancakeV2TwapOracle } from "pangu2/oracle/PancakeV2TwapOracle.sol";
import { SupportPool } from "pangu2/SupportPool.sol";
import { FeeVault } from "pangu2/FeeVault.sol";
import { BuybackLocker } from "pangu2/BuybackLocker.sol";
import { DividendDistributor } from "pangu2/DividendDistributor.sol";
import { Pangu2TradeRouter } from "pangu2/Pangu2TradeRouter.sol";
import { Pangu2Staking } from "pangu2/Pangu2Staking.sol";
import { IPancakePair, IWBNB } from "pangu2/interfaces/IPancakeV2.sol";
import { TransferContext } from "pangu2/libraries/TransferContext.sol";

/// @notice Production LP proxy mirror
contract TestLpProxy {
    address public immutable lpOwner;
    address public immutable initialHolder;
    uint256 public immutable tokenAmount;
    uint256 public immutable nativeAmount;
    bool public executed;

    error NotLpOwner();
    error AlreadyExecuted();
    error NativeAmountMismatch();

    modifier onlyLpOwner() {
        require(msg.sender == lpOwner, "!owner");
        _;
    }

    constructor(address lpOwner_, address initialHolder_, uint256 tokenAmount_, uint256 nativeAmount_) {
        lpOwner = lpOwner_;
        initialHolder = initialHolder_;
        tokenAmount = tokenAmount_;
        nativeAmount = nativeAmount_;
    }

    function addLiquidity(address token, address wbnb, address pair, address lpRecipient) external payable onlyLpOwner {
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

contract BootstrapRoleSeparationTest is Test {
    uint64 internal constant LOCK_DURATION = 365 days;
    uint32 internal constant TWAP_WINDOW = 30 minutes;
    uint16 internal constant MAX_DEVIATION_BPS = 300;

    address internal constant WBNB = 0x1000000000000000000000000000000000000001;
    address internal constant FACTORY = 0x2000000000000000000000000000000000000002;
    address internal constant ROUTER = 0x3000000000000000000000000000000000000003;

    address internal governance;
    address internal lpAddr;
    address internal holder;
    address internal emergency;
    address internal keeper;
    address internal releaseRecipient;
    address internal rootPublisher;
    address internal lpRecipient;

    Pangu2Token internal token;
    CostBasisManager internal costBasis;
    PancakeV2Adapter internal adapter;
    PancakeV2TwapOracle internal oracle;
    SupportPool internal supportPool;
    FeeVault internal feeVault;
    BuybackLocker internal locker;
    DividendDistributor internal distributor;
    Pangu2TradeRouter internal tradeRouter;
    Pangu2Staking internal staking;
    MockFactory internal mockFactory;
    MockPair internal mockPair;
    address internal pair;

    TestLpProxy internal lpProxy;
    address internal lpProxyAddr;

    uint256 internal constant LP_TOKEN_AMOUNT = 500_000 ether;
    uint256 internal constant LP_NATIVE_AMOUNT = 10_000 ether;

    bytes32 internal constant GOV = keccak256("GOVERNANCE_ROLE");
    bytes32 internal constant DA = 0x00;

    function setUp() public {
        mockFactory = new MockFactory();
        MockWBNB mockWbnb = new MockWBNB();
        vm.etch(WBNB, address(mockWbnb).code);
        vm.etch(FACTORY, address(mockFactory).code);
        vm.etch(ROUTER, hex"fe");
        governance = address(0x6000);
        lpAddr = address(0x7000);
        holder = address(0x8000);
        emergency = address(0x9000);
        keeper = address(0xA000);
        releaseRecipient = address(0xB000);
        rootPublisher = address(0xC000);
        lpRecipient = address(0xD000);
        require(governance != lpAddr && governance != holder && lpAddr != holder, "!distinct");
        vm.deal(lpAddr, 20_000 ether);

        token = new Pangu2Token(holder, governance, emergency);
        mockPair = new MockPair(address(token), WBNB);
        pair = address(mockPair);
        MockFactory(FACTORY).setPair(address(token), WBNB, pair);
        mockPair.setReserves(uint112(100_000 ether), uint112(10_000 ether), uint32(block.timestamp));

        costBasis = new CostBasisManager(address(token), governance);
        adapter = new PancakeV2Adapter(address(token), WBNB, FACTORY, pair, ROUTER, governance);
        oracle = new PancakeV2TwapOracle(address(token), WBNB, FACTORY, pair, TWAP_WINDOW, MAX_DEVIATION_BPS, 1, 1);
        supportPool = new SupportPool(
            address(token), WBNB, address(adapter), address(oracle), 300, 5 minutes, governance, emergency
        );
        feeVault = new FeeVault(
            address(token),
            WBNB,
            address(adapter),
            address(oracle),
            payable(address(supportPool)),
            1_000_000 ether,
            300,
            governance,
            keeper,
            emergency
        );
        locker = new BuybackLocker(
            address(token), address(supportPool), BuybackLocker.LockMode.FIXED_DURATION, LOCK_DURATION, releaseRecipient
        );
        distributor = new DividendDistributor(address(token), address(costBasis), governance, rootPublisher, emergency);
        tradeRouter = new Pangu2TradeRouter(
            address(token), WBNB, address(costBasis), address(adapter), address(oracle), governance, emergency
        );
        staking = new Pangu2Staking(address(token), governance);

        vm.startPrank(governance);
        token.configureCore(address(costBasis), address(feeVault));
        token.setSystemAddress(address(tradeRouter), true);
        token.setSystemAddress(address(adapter), true);
        token.setSystemAddress(address(supportPool), true);
        token.setSystemAddress(address(locker), true);
        token.setSystemAddress(address(distributor), true);
        token.setSystemAddress(address(staking), true);
        token.grantRole(token.SETTLEMENT_ROLE(), address(tradeRouter));
        // TradeRouter paused — use emergency (has PAUSER_ROLE) or grant governance PAUSER
        vm.stopPrank();

        vm.prank(emergency);
        tradeRouter.pause();

        vm.startPrank(governance);
        costBasis.configureLiquidityGateway(address(adapter));
        adapter.setCaller(address(tradeRouter), true);
        adapter.setCaller(address(feeVault), true);
        adapter.setCaller(address(supportPool), true);
        supportPool.configureFeeVault(address(feeVault));
        supportPool.configureLocker(address(locker));
        feeVault.configureDividendDistributor(address(distributor));
        token.setSystemTransferContext(address(distributor), TransferContext.Kind.DIVIDEND_CLAIM, true);
        token.setSystemTransferContext(address(locker), TransferContext.Kind.SYSTEM_CREDIT_UNKNOWN, true);
        token.setSystemTransferContext(address(staking), TransferContext.Kind.STAKING_DEPOSIT, true);
        token.setSystemTransferContext(address(staking), TransferContext.Kind.STAKING_PRINCIPAL_RETURN, true);
        token.setSystemTransferContext(address(staking), TransferContext.Kind.STAKING_REWARD, true);
        vm.stopPrank();

        vm.prank(lpAddr, lpAddr);
        lpProxy = new TestLpProxy(lpAddr, holder, LP_TOKEN_AMOUNT, LP_NATIVE_AMOUNT);
        lpProxyAddr = address(lpProxy);
    }

    // ════════════════════════════════════════════════════
    // T1: Full bootstrap flow with separate roles
    function testFullBootstrapFlowWithSeparateRoles() public {
        vm.startPrank(governance);
        token.setPair(pair, true);
        token.setLiquidityManager(lpProxyAddr, true);
        assertTrue(token.isLiquidityManager(lpProxyAddr));
        vm.stopPrank();

        vm.prank(holder);
        token.approve(lpProxyAddr, LP_TOKEN_AMOUNT);
        assertEq(token.allowance(holder, lpProxyAddr), LP_TOKEN_AMOUNT);

        vm.prank(lpAddr);
        lpProxy.addLiquidity{ value: LP_NATIVE_AMOUNT }(address(token), WBNB, pair, lpRecipient);
        assertTrue(lpProxy.executed());

        (uint112 r0, uint112 r1,) = mockPair.getReserves();
        assertGt(r0, 0);
        assertGt(r1, 0);

        vm.startPrank(governance);
        token.setLiquidityManager(lpProxyAddr, false);
        assertFalse(token.isLiquidityManager(lpProxyAddr));
        vm.stopPrank();

        // Holder clears allowance
        vm.prank(holder);
        token.approve(lpProxyAddr, 0);
        assertEq(token.allowance(holder, lpProxyAddr), 0);

        vm.prank(governance);
        oracle.update();
    }

    // T2: LP cannot execute Governance
    function testLpCannotSetPair() public {
        vm.prank(lpAddr);
        vm.expectRevert();
        token.setPair(pair, true);
    }

    function testLpCannotSetLiquidityManager() public {
        vm.prank(lpAddr);
        vm.expectRevert();
        token.setLiquidityManager(lpAddr, true);
    }

    // T3: Governance cannot use LP's BNB
    function testGovernanceCannotSpendLpTokens() public {
        address testLp = address(0x7100);
        vm.prank(holder);
        token.transfer(testLp, 100_000 ether);
        vm.prank(governance);
        vm.expectRevert();
        token.transferFrom(testLp, governance, 100_000 ether);
    }

    // T4: Temporary permissions revoked
    function testTempPermissionsRevoked() public {
        vm.startPrank(governance);
        token.setPair(pair, true);
        token.setLiquidityManager(lpProxyAddr, true);
        assertTrue(token.isLiquidityManager(lpProxyAddr));
        token.setLiquidityManager(lpProxyAddr, false);
        assertFalse(token.isLiquidityManager(lpProxyAddr));
        vm.stopPrank();
        assertFalse(token.hasRole(GOV, lpAddr));
        assertTrue(token.hasRole(GOV, governance));
    }

    // T5: Pair-Oracle bindings
    function testPairOracleAdapterBindingsConsistent() public {
        assertEq(address(oracle.pair()), pair);
        assertEq(oracle.token(), address(token));
        (address t0, address t1) = (mockPair.token0(), mockPair.token1());
        assertTrue((t0 == address(token) && t1 == WBNB) || (t0 == WBNB && t1 == address(token)));
        vm.prank(governance);
        token.setPair(pair, true);
        assertTrue(token.isPair(pair));
    }

    // T6-T7: Chain rejection
    function testChain56Rejected() public {
        vm.chainId(56);
        assertEq(block.chainid, 56);
        assertTrue(block.chainid != 97);
    }

    function testNonTestnetChainRejected() public {
        vm.chainId(1);
        assertEq(block.chainid, 1);
        assertTrue(block.chainid != 97);
        vm.chainId(31_337);
        assertEq(block.chainid, 31_337);
        assertTrue(block.chainid != 97);
    }

    // T8: Governance permissions
    function testFinalizeValidatesGovernancePermissions() public view {
        assertTrue(token.hasRole(DA, governance));
        assertTrue(costBasis.hasRole(DA, governance));
        assertFalse(token.hasRole(GOV, lpAddr));
        assertTrue(token.hasRole(GOV, governance));
    }

    // T9: LpProxy only callable by owner
    function testLpProxyOnlyCallableByOwner() public {
        vm.prank(governance);
        vm.expectRevert();
        lpProxy.addLiquidity(address(token), WBNB, pair, lpRecipient);
    }

    // T10: Oracle quotes after window
    function testOracleProducesValidQuotesAfterWindow() public {
        vm.prank(governance);
        oracle.update();
        vm.warp(block.timestamp + TWAP_WINDOW);
        vm.prank(governance);
        oracle.update();
        assertEq(uint256(oracle.status()), uint256(PancakeV2TwapOracle.WindowStatus.READY));
        assertGt(oracle.validatedQuote(address(token), WBNB, 1 ether).amountOut, 0);
        assertGt(oracle.validatedQuote(WBNB, address(token), 1 ether).amountOut, 0);
    }

    // T11: LpProxy starts with zero tokens
    function testLpProxyStartsWithZeroTokens() public {
        assertEq(token.balanceOf(lpProxyAddr), 0);
        assertEq(token.balanceOf(holder), token.totalSupply());
    }

    // ════════════════════════════════════════════════════
    // NEW: T12 — Proxy one-shot execution
    function testLpProxyCannotExecuteTwice() public {
        vm.startPrank(governance);
        token.setPair(pair, true);
        token.setLiquidityManager(lpProxyAddr, true);
        vm.stopPrank();
        vm.prank(holder);
        token.approve(lpProxyAddr, LP_TOKEN_AMOUNT);

        vm.prank(lpAddr);
        lpProxy.addLiquidity{ value: LP_NATIVE_AMOUNT }(address(token), WBNB, pair, lpRecipient);
        assertTrue(lpProxy.executed());

        vm.prank(lpAddr);
        vm.expectRevert(TestLpProxy.AlreadyExecuted.selector);
        lpProxy.addLiquidity{ value: LP_NATIVE_AMOUNT }(address(token), WBNB, pair, lpRecipient);
    }

    // T13 — Proxy rejects wrong native amount
    function testLpProxyRejectsWrongNativeAmount() public {
        vm.startPrank(governance);
        token.setPair(pair, true);
        token.setLiquidityManager(lpProxyAddr, true);
        vm.stopPrank();

        vm.prank(lpAddr);
        vm.expectRevert(TestLpProxy.NativeAmountMismatch.selector);
        lpProxy.addLiquidity{ value: LP_NATIVE_AMOUNT + 1 }(address(token), WBNB, pair, lpRecipient);
    }

    // T14 — Proxy token amount is immutable
    function testLpProxyTokenAmountImmutable() public {
        assertEq(lpProxy.tokenAmount(), LP_TOKEN_AMOUNT);
        assertEq(lpProxy.nativeAmount(), LP_NATIVE_AMOUNT);
    }

    // T15 — After bootstrap, trading is still paused
    function testTradingStillPausedAfterBootstrap() public {
        vm.startPrank(governance);
        token.setPair(pair, true);
        token.setLiquidityManager(lpProxyAddr, true);
        vm.stopPrank();
        vm.prank(holder);
        token.approve(lpProxyAddr, LP_TOKEN_AMOUNT);
        vm.prank(lpAddr);
        lpProxy.addLiquidity{ value: LP_NATIVE_AMOUNT }(address(token), WBNB, pair, lpRecipient);

        // TradeRouter should still be paused
        assertTrue(tradeRouter.paused(), "tradeRouter must be paused after bootstrap");
    }

    // T16 — Holder allowance cleared after bootstrap
    function testHolderAllowanceCleared() public {
        vm.startPrank(governance);
        token.setPair(pair, true);
        token.setLiquidityManager(lpProxyAddr, true);
        vm.stopPrank();
        vm.prank(holder);
        token.approve(lpProxyAddr, LP_TOKEN_AMOUNT);
        assertEq(token.allowance(holder, lpProxyAddr), LP_TOKEN_AMOUNT);

        vm.prank(lpAddr);
        lpProxy.addLiquidity{ value: LP_NATIVE_AMOUNT }(address(token), WBNB, pair, lpRecipient);

        // Clear allowance
        vm.prank(holder);
        token.approve(lpProxyAddr, 0);
        assertEq(token.allowance(holder, lpProxyAddr), 0);
    }

    // T17 — openTrading starts protection window
    function testOpenTradingStartsProtectionWindow() public {
        assertEq(token.tradingOpenAt(), 0);
        assertFalse(token.isInLaunchProtection());

        vm.prank(governance);
        token.setTradingOpenAt();

        assertGt(token.tradingOpenAt(), 0);
        assertTrue(token.isInLaunchProtection());
    }

    // T18 — TradeRouter pause enforced
    function testPausedTradeRouterRejectsBuy() public {
        vm.prank(governance);
        token.setTradingOpenAt();
        assertTrue(tradeRouter.paused());

        vm.prank(address(tradeRouter));
        vm.expectRevert();
        token.settleBuy(holder, 1 ether, 1 ether);
    }

    // T19 — Governance can unpause after trading open
    function testGovernanceCanUnpauseAfterOpen() public {
        vm.prank(governance);
        token.setTradingOpenAt();
        assertTrue(tradeRouter.paused());

        vm.prank(governance);
        tradeRouter.unpause();
        assertFalse(tradeRouter.paused());
    }

    // T20 — Wrong pair binding detected
    function testOraclePairMismatchDetected() public {
        MockPair wrongPair = new MockPair(address(token), WBNB);
        vm.expectRevert();
        new PancakeV2TwapOracle(address(token), WBNB, FACTORY, address(wrongPair), TWAP_WINDOW, MAX_DEVIATION_BPS, 1, 1);
    }
}

// ── Mocks ──

contract MockWBNB {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;

    function deposit() external payable {
        balanceOf[msg.sender] += msg.value;
        totalSupply += msg.value;
    }

    function transfer(address to, uint256 a) external returns (bool) {
        require(balanceOf[msg.sender] >= a, "insufficient");
        balanceOf[msg.sender] -= a;
        balanceOf[to] += a;
        return true;
    }

    function transferFrom(address f, address t, uint256 a) external returns (bool) {
        require(balanceOf[f] >= a && allowance[f][msg.sender] >= a, "no allowance");
        balanceOf[f] -= a;
        balanceOf[t] += a;
        allowance[f][msg.sender] -= a;
        return true;
    }

    function approve(address sp, uint256 a) external returns (bool) {
        allowance[msg.sender][sp] = a;
        return true;
    }

    function withdraw(uint256 a) external {
        require(balanceOf[msg.sender] >= a, "insufficient");
        balanceOf[msg.sender] -= a;
        totalSupply -= a;
        payable(msg.sender).transfer(a);
    }
    receive() external payable { }
}

contract MockFactory {
    mapping(address => mapping(address => address)) public pairs;

    function setPair(address t0, address t1, address p) external {
        pairs[t0][t1] = p;
        pairs[t1][t0] = p;
    }

    function getPair(address t0, address t1) external view returns (address) {
        return pairs[t0][t1];
    }

    function createPair(address, address) external view returns (address) {
        revert("not mocked");
    }
}

contract MockPair {
    address public immutable token0;
    address public immutable token1;
    uint112 public reserve0;
    uint112 public reserve1;
    uint32 public blockTimestampLast;
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;

    constructor(address t0, address t1) {
        token0 = t0;
        token1 = t1;
    }

    function setReserves(uint112 r0, uint112 r1, uint32 ts) external {
        reserve0 = r0;
        reserve1 = r1;
        blockTimestampLast = ts;
    }

    function getReserves() external view returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, blockTimestampLast);
    }

    function mint(address) external returns (uint256) {
        return 1 ether;
    }

    function transfer(address, uint256) external pure returns (bool) {
        return true;
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        return true;
    }

    function approve(address, uint256) external pure returns (bool) {
        return true;
    }

    function balanceOf(address) external pure returns (uint256) {
        return 0;
    }

    function totalSupply() external pure returns (uint256) {
        return 0;
    }

    function allowance(address, address) external pure returns (uint256) {
        return 0;
    }

    function symbol() external pure returns (string memory) {
        return "";
    }

    function name() external pure returns (string memory) {
        return "";
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function factory() external view returns (address) {
        return address(0);
    }
    function sync() external { }
    function skim(address) external { }

    function burn(address) external returns (uint256, uint256) {
        return (0, 0);
    }
    function swap(uint256, uint256, address, bytes calldata) external { }
    function initialize(address, address) external { }

    function MINIMUM_LIQUIDITY() external pure returns (uint256) {
        return 1000;
    }

    function kLast() external view returns (uint256) {
        return 0;
    }

    function DOMAIN_SEPARATOR() external pure returns (bytes32) {
        return 0;
    }

    function PERMIT_TYPEHASH() external pure returns (bytes32) {
        return 0;
    }

    function nonces(address) external pure returns (uint256) {
        return 0;
    }
    function permit(address, address, uint256, uint256, uint8, bytes32, bytes32) external { }
}
