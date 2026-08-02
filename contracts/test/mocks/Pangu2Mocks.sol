// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPangu2Token} from "pangu2/interfaces/IPangu2Token.sol";
import {TransferContext} from "pangu2/libraries/TransferContext.sol";
import {
    IPancakeV3Factory,
    IPancakeV3Pool,
    IPancakeV3SwapRouter,
    IPancakeV3QuoterV2,
    IWBNB
} from "pangu2/interfaces/IPancakeV3.sol";

contract MockWBNB is ERC20 {
    constructor() ERC20("Wrapped BNB", "WBNB") {}

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
        (bool ok,) = payable(msg.sender).call{value: amount}("");
        require(ok, "NATIVE_TRANSFER");
    }
}

contract MockPancakeV3Factory is IPancakeV3Factory {
    mapping(bytes32 => address) private _pools;

    function setPool(address tokenA, address tokenB, uint24 fee, address pool) external {
        _pools[_key(tokenA, tokenB, fee)] = pool;
    }

    function getPool(address tokenA, address tokenB, uint24 fee) external view override returns (address pool) {
        return _pools[_key(tokenA, tokenB, fee)];
    }

    function createPool(address tokenA, address tokenB, uint24 fee) external override returns (address pool) {
        bytes32 key = _key(tokenA, tokenB, fee);
        require(_pools[key] == address(0), "POOL_EXISTS");
        pool = address(new MockPancakeV3Pool(address(this), tokenA, tokenB, fee));
        _pools[key] = pool;
    }

    function _key(address tokenA, address tokenB, uint24 fee) private pure returns (bytes32) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        return keccak256(abi.encode(token0, token1, fee));
    }
}

contract MockPancakeV3Pool is IPancakeV3Pool {
    address public immutable override factory;
    address public immutable override token0;
    address public immutable override token1;
    uint24 public immutable override fee;

    uint128 public override liquidity = 1_000_000 ether;
    int24 public currentTick;
    int24 public twapTick;
    uint16 public observationCardinality = 16;
    address public swapRouter;
    bool public initialized;

    constructor(address factory_, address tokenA, address tokenB, uint24 fee_) {
        factory = factory_;
        if (tokenA < tokenB) {
            token0 = tokenA;
            token1 = tokenB;
        } else {
            token0 = tokenB;
            token1 = tokenA;
        }
        fee = fee_;
    }

    function configureRouter(address swapRouter_) external {
        require(swapRouter == address(0), "ROUTER_SET");
        swapRouter = swapRouter_;
    }

    function setOracleState(int24 tick_, uint16 cardinality_, uint128 liquidity_) external {
        currentTick = tick_;
        twapTick = tick_;
        observationCardinality = cardinality_;
        liquidity = liquidity_;
    }

    function setOracleTicks(int24 spotTick_, int24 twapTick_) external {
        currentTick = spotTick_;
        twapTick = twapTick_;
    }

    function initialize(uint160) external override {
        require(!initialized, "INITIALIZED");
        initialized = true;
    }

    function increaseObservationCardinalityNext(uint16 next) external override {
        if (next > observationCardinality) observationCardinality = next;
    }

    function slot0()
        external
        view
        override
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 cardinality,
            uint16 observationCardinalityNext,
            uint32 feeProtocol,
            bool unlocked
        )
    {
        sqrtPriceX96 = 1 << 96;
        tick = currentTick;
        observationIndex = 0;
        cardinality = observationCardinality;
        observationCardinalityNext = observationCardinality;
        feeProtocol = 0;
        unlocked = true;
    }

    function observe(uint32[] calldata secondsAgos)
        external
        view
        override
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s)
    {
        require(secondsAgos.length == 2 && secondsAgos[1] == 0, "OBSERVE_SHAPE");
        tickCumulatives = new int56[](2);
        secondsPerLiquidityCumulativeX128s = new uint160[](2);

        uint32 elapsed = secondsAgos[0];
        tickCumulatives[0] = -int56(twapTick) * int56(uint56(elapsed));
        tickCumulatives[1] = 0;
        uint256 delta = (uint256(elapsed) << 128) / uint256(liquidity);
        secondsPerLiquidityCumulativeX128s[0] = 0;
        secondsPerLiquidityCumulativeX128s[1] = uint160(delta);
    }

    function payout(address asset, address recipient, uint256 amount) external {
        require(msg.sender == swapRouter, "ONLY_ROUTER");
        require(IERC20(asset).transfer(recipient, amount), "PAYOUT");
    }
}

contract MockPancakeV3SwapRouter is IPancakeV3SwapRouter {
    MockPancakeV3Pool public immutable pool;
    uint16 public outputBps = 10_000;

    constructor(address pool_) {
        pool = MockPancakeV3Pool(pool_);
    }

    function setOutputBps(uint16 outputBps_) external {
        require(outputBps_ <= 20_000, "RATE");
        outputBps = outputBps_;
    }

    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        override
        returns (uint256 amountOut)
    {
        require(block.timestamp <= params.deadline, "DEADLINE");
        require(params.fee == pool.fee(), "FEE");
        require(IERC20(params.tokenIn).transferFrom(msg.sender, address(pool), params.amountIn), "INPUT");
        amountOut = (params.amountIn * outputBps) / 10_000;
        require(amountOut >= params.amountOutMinimum, "MIN_OUT");
        pool.payout(params.tokenOut, params.recipient, amountOut);
    }
}

contract MockPancakeV3QuoterV2 is IPancakeV3QuoterV2 {
    uint16 public outputBps = 10_000;

    function setOutputBps(uint16 outputBps_) external {
        outputBps = outputBps_;
    }

    function quoteExactInputSingle(QuoteExactInputSingleParams calldata params)
        external
        override
        returns (uint256 amountOut, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed, uint256 gasEstimate)
    {
        amountOut = (params.amountIn * outputBps) / 10_000;
        sqrtPriceX96After = uint160(1 << 96);
        initializedTicksCrossed = 1;
        gasEstimate = 100_000;
    }
}

contract MockGovernedTarget {
    uint256 public value;

    function setValue(uint256 value_) external payable returns (uint256) {
        value = value_;
        return value_;
    }
}

contract MockLiquidityManager {
    IPangu2Token public immutable token;

    constructor(address token_) {
        token = IPangu2Token(token_);
    }

    function depositToSelf(address account, uint256 amount) external {
        require(token.transferFrom(account, address(this), amount), "DEPOSIT");
    }

    function depositToPair(address account, address pair, uint256 amount) external {
        require(token.transferFrom(account, pair, amount), "PAIR_DEPOSIT");
    }

    function withdrawTo(address account, uint256 amount) external {
        token.systemTransfer(account, amount, TransferContext.Kind.LIQUIDITY_WITHDRAWAL);
    }

    function unknownCredit(address account, uint256 amount) external {
        token.systemTransfer(account, amount, TransferContext.Kind.SYSTEM_CREDIT_UNKNOWN);
    }

    function rawTransfer(address account, uint256 amount) external {
        require(token.transfer(account, amount), "RAW_TRANSFER");
    }
}
