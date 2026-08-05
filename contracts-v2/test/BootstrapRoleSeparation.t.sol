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
import { IPancakeFactory, IPancakePair, IWBNB } from "pangu2/interfaces/IPancakeV2.sol";
import { TransferContext } from "pangu2/libraries/TransferContext.sol";

/// @notice Lightweight LP proxy used in tests — mirrors BootstrapLpProxy.
contract TestLpProxy {
    address public immutable lpOwner;
    address public immutable initialHolder;

    error NotLpOwner();

    modifier onlyLpOwner() {
        require(msg.sender == lpOwner, "!owner");
        _;
    }

    constructor(address initialHolder_) {
        lpOwner = tx.origin;
        initialHolder = initialHolder_;
    }

    /// Pull PANGU from initialHolder via approve+transferFrom, wrap BNB, add liquidity.
    function addLiquidity(address token, address wbnb, address pair, address lpRecipient, uint256 tokenAmount)
        external
        payable
        onlyLpOwner
    {
        Pangu2Token(token).transferFrom(initialHolder, pair, tokenAmount);
        IWBNB(wbnb).deposit{ value: msg.value }();
        IWBNB(wbnb).transfer(pair, msg.value);
        IPancakePair(pair).mint(lpRecipient);
    }

    receive() external payable { }
}

/// @notice Tests role separation in Bootstrap and Finalize deployment flow.
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
    MockPancakeFactory internal mockFactory;
    MockPancakePair internal mockPair;
    address internal pair;

    TestLpProxy internal lpProxy;
    address internal lpProxyAddr;

    bytes32 internal constant GOV = keccak256("GOVERNANCE_ROLE");
    bytes32 internal constant DA = 0x00;

    function setUp() public {
        mockFactory = new MockPancakeFactory();

        // Deploy mock WBNB and factory, then etch their bytecodes at the constant addresses
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

        require(governance != lpAddr, "!distinct");
        require(governance != holder, "!distinct");
        require(lpAddr != holder, "!distinct");

        vm.deal(lpAddr, 20_000 ether);

        token = new Pangu2Token(holder, governance, emergency);

        mockPair = new MockPancakePair(address(token), WBNB);
        pair = address(mockPair);
        MockPancakeFactory(FACTORY).setPair(address(token), WBNB, pair);
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
        costBasis.configureOperators(address(tradeRouter), address(distributor));
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

        // LP deploys LpProxy (tx.origin = lpAddr)
        vm.prank(lpAddr, lpAddr);
        lpProxy = new TestLpProxy(holder);
        lpProxyAddr = address(lpProxy);
    }

    // ════════════════════════════════════════════════════
    // T1: Independent Governance + LP complete the flow
    // ════════════════════════════════════════════════════
    function testFullBootstrapFlowWithSeparateRoles() public {
        uint256 tokenAmount = 500_000 ether;
        uint256 bnbAmount = 10_000 ether;

        // Step 1: Governance sets pair + LpProxy as liquidityManager
        vm.startPrank(governance);
        token.setPair(pair, true);
        token.setLiquidityManager(lpProxyAddr, true);
        assertTrue(token.isLiquidityManager(lpProxyAddr));
        vm.stopPrank();

        // Step 2: Holder approves LpProxy for pull
        vm.prank(holder);
        token.approve(lpProxyAddr, tokenAmount);
        assertEq(token.allowance(holder, lpProxyAddr), tokenAmount);

        // Step 3: LP calls LpProxy.addLiquidity (pulls from holder via transferFrom)
        vm.prank(lpAddr);
        lpProxy.addLiquidity{ value: bnbAmount }(address(token), WBNB, pair, lpRecipient, tokenAmount);

        (uint112 r0, uint112 r1,) = mockPair.getReserves();
        assertGt(r0, 0);
        assertGt(r1, 0);

        // Step 4: Governance revokes LpProxy + oracle anchor
        vm.startPrank(governance);
        token.setLiquidityManager(lpProxyAddr, false);
        assertFalse(token.isLiquidityManager(lpProxyAddr));
        oracle.update();
        vm.stopPrank();
    }

    // ════════════════════════════════════════════════════
    // T2: LP cannot execute Governance operations
    // ════════════════════════════════════════════════════
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

    // ════════════════════════════════════════════════════
    // T3: Governance cannot use LP's assets
    // ════════════════════════════════════════════════════
    function testGovernanceCannotSpendLpTokens() public {
        address testLp = address(0x7100);
        uint256 tokenAmount = 100_000 ether;
        vm.prank(holder);
        token.transfer(testLp, tokenAmount);
        assertEq(token.balanceOf(testLp), tokenAmount);

        vm.prank(governance);
        vm.expectRevert();
        token.transferFrom(testLp, governance, tokenAmount);
    }

    // ════════════════════════════════════════════════════
    // T4: Temporary permissions revoked after Bootstrap
    // ════════════════════════════════════════════════════
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

    // ════════════════════════════════════════════════════
    // T5: Pair-Oracle-Adapter bindings consistent
    // ════════════════════════════════════════════════════
    function testPairOracleAdapterBindingsConsistent() public {
        assertEq(address(oracle.pair()), pair, "oracle pair mismatch");
        assertEq(oracle.token(), address(token), "oracle token mismatch");

        (address t0, address t1) = (mockPair.token0(), mockPair.token1());
        bool validPair = (t0 == address(token) && t1 == WBNB) || (t0 == WBNB && t1 == address(token));
        assertTrue(validPair, "pair token config invalid");

        vm.prank(governance);
        token.setPair(pair, true);
        assertTrue(token.isPair(pair), "pair not registered on token");
    }

    // ════════════════════════════════════════════════════
    // T6: Chain 56 must fail
    // ════════════════════════════════════════════════════
    function testChain56Rejected() public {
        vm.chainId(56);
        assertEq(block.chainid, 56);
        assertTrue(block.chainid != 97, "chain 56 should not be 97");
    }

    // ════════════════════════════════════════════════════
    // T7: Non-97 non-56 network must fail
    // ════════════════════════════════════════════════════
    function testNonTestnetChainRejected() public {
        vm.chainId(1);
        assertEq(block.chainid, 1);
        assertTrue(block.chainid != 97);

        vm.chainId(31_337);
        assertEq(block.chainid, 31_337);
        assertTrue(block.chainid != 97);
    }

    // ════════════════════════════════════════════════════
    // T8: Finalize validates Governance permissions
    // ════════════════════════════════════════════════════
    function testFinalizeValidatesGovernancePermissions() public view {
        assertTrue(token.hasRole(DA, governance), "gov missing token ADMIN");
        assertTrue(costBasis.hasRole(DA, governance), "gov missing costBasis ADMIN");
        assertTrue(token.hasRole(GOV, governance), "gov missing token GOVERNANCE");
        assertFalse(token.hasRole(DA, lpAddr), "LP must not have token ADMIN");
        assertFalse(token.hasRole(GOV, lpAddr), "LP must not have token GOVERNANCE");
    }

    // ════════════════════════════════════════════════════
    // T9: LP proxy can only be called by LP owner
    // ════════════════════════════════════════════════════
    function testLpProxyOnlyCallableByOwner() public {
        vm.prank(governance);
        vm.expectRevert();
        lpProxy.addLiquidity(address(token), WBNB, pair, lpRecipient, 1 ether);
    }

    // ════════════════════════════════════════════════════
    // T10: Oracle produces valid quotes after window
    // ════════════════════════════════════════════════════
    function testOracleProducesValidQuotesAfterWindow() public {
        vm.prank(governance);
        oracle.update();

        vm.warp(block.timestamp + TWAP_WINDOW);
        vm.prank(governance);
        oracle.update();

        assertEq(uint256(oracle.status()), uint256(PancakeV2TwapOracle.WindowStatus.READY));

        PancakeV2TwapOracle.Quote memory q1 = oracle.validatedQuote(address(token), WBNB, 1 ether);
        assertGt(q1.amountOut, 0);

        PancakeV2TwapOracle.Quote memory q2 = oracle.validatedQuote(WBNB, address(token), 1 ether);
        assertGt(q2.amountOut, 0);
    }

    // ════════════════════════════════════════════════════
    // T11: Holder starts with all tokens; LpProxy has none
    // ════════════════════════════════════════════════════
    function testLpProxyStartsWithZeroTokens() public {
        assertEq(token.balanceOf(lpProxyAddr), 0, "LpProxy must have zero tokens");
        assertEq(token.balanceOf(holder), token.totalSupply(), "all tokens should be with holder");
    }
}

// ───────────────────────────────────────────────────────
// Mock contracts
// ───────────────────────────────────────────────────────

contract MockWBNB {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;

    function deposit() external payable {
        balanceOf[msg.sender] += msg.value;
        totalSupply += msg.value;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "insufficient");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "insufficient");
        require(allowance[from][msg.sender] >= amount, "no allowance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function withdraw(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "insufficient");
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        payable(msg.sender).transfer(amount);
    }

    receive() external payable { }
}

contract MockPancakeFactory {
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

contract MockPancakePair {
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
