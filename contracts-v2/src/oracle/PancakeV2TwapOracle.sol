// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IPancakeFactory, IPancakePair} from "../interfaces/IPancakeV2.sol";
import {IPangu2TwapOracle} from "../interfaces/IPangu2TwapOracle.sol";
import {FullMath} from "../libraries/FullMath.sol";

contract PancakeV2TwapOracle is IPangu2TwapOracle {
    address public immutable token;
    address public immutable wbnb;
    IPancakeFactory public immutable factory;
    IPancakePair public immutable pair;
    uint32 public immutable twapWindow;
    uint16 public immutable maximumSpotTwapDeviationBps;

    uint16 public constant BPS_DENOMINATOR = 10_000;
    uint256 private constant Q112 = 2**112;

    struct Observation { uint32 timestamp; uint256 price0CumulativeLast; uint256 price1CumulativeLast; }

    /// Completed window TWAP averages (in Q112). Always available once a window completes.
    /// Even after update() advances to a new window, these remain valid for quoting.
    uint256 public lastTwapPrice0Accumulator; // avg price0 over completed window (Q112)
    uint256 public lastTwapPrice1Accumulator; // avg price1 over completed window (Q112)
    uint256 public lastTwapElapsed;            // elapsed seconds of completed window

    Observation public prevObservation;  // start of completed window (for computing averages)
    Observation public curObservation;   // start of current window (accumulating)
    uint8 public windowStatus; // 0=uninitialized, 1=firstWindowAccumulating, 2=ready, 3=ready+accumulatingNext

    error ZeroAddress();
    error AddressHasNoCode(address account);
    error InvalidPair();
    error InvalidAmount();
    error ZeroQuote();
    error ZeroReserves();
    error ExcessiveSpotTwapDeviation(uint256 spot, uint256 twap, uint256 deviationBps);
    error OracleNotReady(uint256 elapsed, uint32 required);
    error NoAnchor();

    constructor(
        address token_, address wbnb_, address factory_, address pair_, uint32 twapWindow_,
        uint16 maximumSpotTwapDeviationBps_
    ) {
        _requireContract(token_); _requireContract(wbnb_); _requireContract(factory_); _requireContract(pair_);
        if (twapWindow_ == 0 || maximumSpotTwapDeviationBps_ > BPS_DENOMINATOR) revert InvalidAmount();
        token = token_; wbnb = wbnb_; factory = IPancakeFactory(factory_); pair = IPancakePair(pair_);
        twapWindow = twapWindow_; maximumSpotTwapDeviationBps = maximumSpotTwapDeviationBps_;
        address pairToken0 = IPancakePair(pair_).token0();
        address pairToken1 = IPancakePair(pair_).token1();
        if (!((pairToken0 == token_ && pairToken1 == wbnb_) || (pairToken0 == wbnb_ && pairToken1 == token_))) {
            revert InvalidPair();
        }
        if (IPancakeFactory(factory_).getPair(token_, wbnb_) != pair_) revert InvalidPair();
    }

    function update() external {
        (uint112 r0, uint112 r1, uint32 ts) = pair.getReserves();
        if (r0 == 0 || r1 == 0) { windowStatus = 0; return; }
        uint256 p0 = pair.price0CumulativeLast();
        uint256 p1 = pair.price1CumulativeLast();

        if (windowStatus == 0) {
            // First observation: start current window
            curObservation = Observation({timestamp: ts, price0CumulativeLast: p0, price1CumulativeLast: p1});
            windowStatus = 1;
            return;
        }

        // Check if current window has matured
        if (ts >= curObservation.timestamp && ts - curObservation.timestamp >= twapWindow) {
            // Compute averages for the completed window and lock them in lastTwap*
            uint256 elapsed = ts - curObservation.timestamp;
            lastTwapElapsed = elapsed;
            // unchecked: Uniswap V2 cumulative prices wrap naturally via uint256 overflow
            unchecked {
                lastTwapPrice0Accumulator = (p0 - curObservation.price0CumulativeLast) / elapsed;
                lastTwapPrice1Accumulator = (p1 - curObservation.price1CumulativeLast) / elapsed;
            }
            // The completed window becomes prevObservation; new window starts at current
            prevObservation = curObservation;
            curObservation = Observation({timestamp: ts, price0CumulativeLast: p0, price1CumulativeLast: p1});
            windowStatus = windowStatus == 1 ? 2 : 3;
        }
    }

    function validatedQuote(address baseToken, address quoteToken, uint128 baseAmount)
        external view override returns (Quote memory quote)
    {
        if (!((baseToken == token && quoteToken == wbnb) || (baseToken == wbnb && quoteToken == token)))
            revert InvalidPair();
        if (baseAmount == 0) revert InvalidAmount();
        if (windowStatus < 2) {
            if (windowStatus == 0) revert NoAnchor();
            // Status 1: first window still accumulating, check if long enough
            uint256 accElapsed = block.timestamp >= curObservation.timestamp ? block.timestamp - curObservation.timestamp : 0;
            if (accElapsed < twapWindow) revert OracleNotReady(accElapsed, twapWindow);
        }

        (uint112 r0, uint112 r1,) = pair.getReserves();
        if (r0 == 0 || r1 == 0) revert ZeroReserves();
        bool tokenIsToken0 = token < wbnb;
        uint256 tRes = tokenIsToken0 ? uint256(r0) : uint256(r1);
        uint256 wRes = tokenIsToken0 ? uint256(r1) : uint256(r0);

        // Spot
        uint256 spotOut = baseToken == token
            ? FullMath.mulDiv(uint256(baseAmount), wRes, tRes)
            : FullMath.mulDiv(uint256(baseAmount), tRes, wRes);
        if (spotOut == 0) revert ZeroQuote();

        // TWAP from completed window (always available once windowStatus >= 2)
        // Use lastTwapPrice which is the average Q112 price from the PREVIOUS completed window
        // This remains valid even after update() advances to a new window — the attacker
        // cannot erase the completed window's TWAP by calling update().
        uint256 qpb;
        if (tokenIsToken0) {
            qpb = baseToken == token ? lastTwapPrice0Accumulator : lastTwapPrice1Accumulator;
        } else {
            qpb = baseToken == token ? lastTwapPrice1Accumulator : lastTwapPrice0Accumulator;
        }
        if (qpb == 0) revert ZeroQuote();

        uint256 twapOut = FullMath.mulDiv(uint256(baseAmount), qpb, Q112);
        if (twapOut == 0) revert ZeroQuote();

        if (maximumSpotTwapDeviationBps < BPS_DENOMINATOR) {
            uint256 dev = spotOut > twapOut
                ? ((spotOut - twapOut) * BPS_DENOMINATOR) / twapOut
                : ((twapOut - spotOut) * BPS_DENOMINATOR) / spotOut;
            if (dev > maximumSpotTwapDeviationBps)
                revert ExcessiveSpotTwapDeviation(spotOut, twapOut, dev);
        }

        quote = Quote({amountOut: twapOut, arithmeticMeanTick: 0, spotTick: 0, harmonicMeanLiquidity: 0, observedAtBlock: uint40(block.number)});
    }

    function _requireContract(address account) private view {
        if (account == address(0)) revert ZeroAddress();
        if (account.code.length == 0) revert AddressHasNoCode(account);
    }
}
