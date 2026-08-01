// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Pangu2IntegrationTest} from "../Pangu2Integration.t.sol";
import {Pangu2Token} from "pangu2/Pangu2Token.sol";
import {Pangu2TradeRouter} from "pangu2/Pangu2TradeRouter.sol";
import {FeeVault} from "pangu2/FeeVault.sol";
import {SupportPool} from "pangu2/SupportPool.sol";
import {BuybackLocker} from "pangu2/BuybackLocker.sol";
import {DividendDistributor} from "pangu2/DividendDistributor.sol";
import {CostBasisManager} from "pangu2/CostBasisManager.sol";
import {ICostBasisManager} from "pangu2/interfaces/ICostBasisManager.sol";
import {IDividendDistributor} from "pangu2/interfaces/IDividendDistributor.sol";
import {ISupportPool} from "pangu2/interfaces/ISupportPool.sol";
import {MockLiquidityManager} from "../mocks/Pangu2Mocks.sol";

contract Pangu2ProtocolHandler is Test {
    Pangu2Token public immutable token;
    Pangu2TradeRouter public immutable tradeRouter;
    FeeVault public immutable feeVault;
    SupportPool public immutable supportPool;
    BuybackLocker public immutable locker;
    DividendDistributor public immutable distributor;
    CostBasisManager public immutable costBasis;
    MockLiquidityManager public immutable liquidityManager;
    address public immutable keeper;

    address[4] public actors;
    uint256 public nextEpochId = 1;

    constructor(
        Pangu2Token token_,
        Pangu2TradeRouter tradeRouter_,
        FeeVault feeVault_,
        SupportPool supportPool_,
        BuybackLocker locker_,
        DividendDistributor distributor_,
        CostBasisManager costBasis_,
        MockLiquidityManager liquidityManager_,
        address keeper_,
        address[4] memory actors_
    ) {
        token = token_;
        tradeRouter = tradeRouter_;
        feeVault = feeVault_;
        supportPool = supportPool_;
        locker = locker_;
        distributor = distributor_;
        costBasis = costBasis_;
        liquidityManager = liquidityManager_;
        keeper = keeper_;
        actors = actors_;
    }

    receive() external payable {}

    function buy(uint256 actorSeed, uint96 rawValue) external {
        address actor = actors[actorSeed % actors.length];
        uint256 value = bound(uint256(rawValue), 0.01 ether, 5 ether);
        vm.deal(actor, actor.balance + value);
        vm.prank(actor);
        tradeRouter.buy{value: value}(value * 9 / 10, block.timestamp + 5 minutes);
    }

    function transferBetweenActors(uint256 fromSeed, uint256 toSeed, uint96 rawAmount) external {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];
        if (from == to) return;
        uint256 balance = token.balanceOf(from);
        if (balance == 0) return;
        uint256 amount = bound(uint256(rawAmount), 1, balance);
        vm.prank(from);
        token.transfer(to, amount);
    }

    function sell(uint256 actorSeed, uint96 rawAmount) external {
        address actor = actors[actorSeed % actors.length];
        uint256 balance = token.balanceOf(actor);
        uint256 minimum = token.MIN_SELL_AMOUNT();
        if (balance < minimum) return;
        uint256 amount = bound(uint256(rawAmount), minimum, balance);
        Pangu2TradeRouter.SellPreview memory p = tradeRouter.previewSell(actor, amount);
        vm.startPrank(actor);
        token.approve(address(tradeRouter), amount);
        tradeRouter.sell(amount, p.estimatedWbnbOut * 8 / 10, block.timestamp + 5 minutes);
        vm.stopPrank();
    }

    function depositLiquidity(uint256 actorSeed, uint96 rawAmount) external {
        address actor = actors[actorSeed % actors.length];
        uint256 balance = token.balanceOf(actor);
        if (balance == 0) return;
        uint256 amount = bound(uint256(rawAmount), 1, balance);
        vm.startPrank(actor);
        token.approve(address(liquidityManager), amount);
        liquidityManager.depositToSelf(actor, amount);
        vm.stopPrank();
    }

    function withdrawLiquidity(uint256 actorSeed, uint96 rawAmount) external {
        address actor = actors[actorSeed % actors.length];
        ICostBasisManager.Position memory lp = costBasis.liquidityPositionOf(actor);
        uint256 available = lp.trackedBalance;
        uint256 managerBalance = token.balanceOf(address(liquidityManager));
        if (available == 0 || managerBalance == 0) return;
        if (available > managerBalance) available = managerBalance;
        uint256 amount = bound(uint256(rawAmount), 1, available);
        liquidityManager.withdrawTo(actor, amount);
    }

    function convertSupport(uint96 rawAmount) external {
        uint256 available = feeVault.supportBalance();
        if (available == 0) return;
        uint256 amount = bound(uint256(rawAmount), 1, available);
        vm.prank(keeper);
        feeVault.convertSupport(amount, amount * 8 / 10, block.timestamp + 5 minutes);
    }

    function triggerBuyback() external {
        (
            bool allowed,
            ISupportPool.BuybackBlockReason reason,
            uint256 ignoredBalance,
            uint256 nextAllowedAt
        ) = supportPool.canExecuteBuyback();
        if (!allowed && reason == ISupportPool.BuybackBlockReason.COOLDOWN) {
            vm.warp(nextAllowedAt);
            ISupportPool.BuybackBlockReason ignoredReason;
            (allowed, ignoredReason, ignoredBalance, nextAllowedAt) = supportPool.canExecuteBuyback();
        }
        if (!allowed) return;
        supportPool.buyback();
    }

    function runDividendLifecycle(uint256 actorSeed, uint96 rawAmount) external {
        uint256 available = feeVault.dividendBalance();
        if (available == 0 || block.number == 0) return;
        address actor = actors[actorSeed % actors.length];
        uint256 amount = bound(uint256(rawAmount), 1, available);
        feeVault.fundDividendDistributor(amount);

        uint256 epochId = nextEpochId++;
        bytes32 leaf = distributor.leafFor(epochId, actor, amount);
        IDividendDistributor.EpochCommitment memory c = IDividendDistributor.EpochCommitment({
            merkleRoot: leaf,
            artifactChecksum: keccak256(abi.encode("INVARIANT_EPOCH", epochId, actor, amount)),
            totalAmount: amount,
            claimStart: uint64(block.timestamp),
            claimEnd: uint64(block.timestamp + 30 days),
            snapshotBlock: uint32(block.number),
            schemaVersion: distributor.LEAF_SCHEMA_VERSION()
        });
        distributor.approveEpochCommitment(epochId, c);
        distributor.publishEpoch(epochId, c);
        bytes32[] memory proof = new bytes32[](0);
        vm.prank(actor);
        distributor.claim(epochId, amount, proof);
        vm.warp(uint256(c.claimEnd) + 1);
        distributor.closeEpoch(epochId);
    }
}

contract Pangu2AccountingInvariantTest is Pangu2IntegrationTest, StdInvariant {
    address internal constant ACTOR_0 = address(0x1001);
    address internal constant ACTOR_1 = address(0x1002);
    address internal constant ACTOR_2 = address(0x1003);
    address internal constant ACTOR_3 = address(0x1004);

    Pangu2ProtocolHandler internal handler;
    address[4] internal actors;

    function setUp() public override {
        super.setUp();
        address[4] memory actorList = [ACTOR_0, ACTOR_1, ACTOR_2, ACTOR_3];
        actors = actorList;
        handler = new Pangu2ProtocolHandler(
            token,
            tradeRouter,
            feeVault,
            supportPool,
            locker,
            distributor,
            costBasis,
            liquidityManager,
            KEEPER,
            actorList
        );
        feeVault.grantRole(feeVault.GOVERNANCE_ROLE(), address(handler));
        distributor.grantRole(distributor.GOVERNANCE_ROLE(), address(handler));
        distributor.grantRole(distributor.ROOT_PUBLISHER_ROLE(), address(handler));
        targetContract(address(handler));
    }

    function invariant_TotalSupplyEqualsEnumeratedBalanceSum() public view {
        uint256 sum = token.balanceOf(address(this)) + token.balanceOf(address(pool))
            + token.balanceOf(address(tradeRouter)) + token.balanceOf(address(feeVault))
            + token.balanceOf(address(supportPool)) + token.balanceOf(address(locker))
            + token.balanceOf(address(distributor)) + token.balanceOf(address(adapter))
            + token.balanceOf(address(liquidityManager)) + token.balanceOf(address(handler));
        for (uint256 i; i < actors.length; ++i) sum += token.balanceOf(actors[i]);
        assertEq(sum, token.totalSupply());
    }

    function invariant_BuybackAmountRemainsExactlyPointZeroOneBnb() public view {
        assertEq(supportPool.BUYBACK_AMOUNT(), 0.01 ether);
    }

    function invariant_LockerBalanceCoversOutstanding() public view {
        assertGe(token.balanceOf(address(locker)), locker.outstandingLocked());
    }

    function invariant_FeeBucketsNeverExceedVaultBalance() public view {
        assertGe(token.balanceOf(address(feeVault)), feeVault.totalAccounted());
    }

    function invariant_DividendAndSupportBucketsRemainSeparatelyAccounted() public view {
        assertEq(feeVault.dividendBalance() + feeVault.supportBalance(), feeVault.totalAccounted());
    }

    function invariant_DistributorReservationsAreFullyBacked() public view {
        assertLe(distributor.totalReservedClaims(), token.balanceOf(address(distributor)));
    }

    function invariant_KnownPositionsMatchActualBalances() public view {
        for (uint256 i; i < actors.length; ++i) {
            ICostBasisManager.Position memory p = costBasis.positionOf(actors[i]);
            if (p.status == ICostBasisManager.PositionStatus.KNOWN) {
                assertEq(p.trackedBalance, token.balanceOf(actors[i]));
            }
        }
    }

    function invariant_UnknownPositionsCannotPreviewBelowTenPercent() public view {
        for (uint256 i; i < actors.length; ++i) {
            address actor = actors[i];
            ICostBasisManager.Position memory p = costBasis.positionOf(actor);
            if (
                p.status == ICostBasisManager.PositionStatus.UNKNOWN
                    && token.balanceOf(actor) >= token.MIN_SELL_AMOUNT()
            ) {
                Pangu2TradeRouter.SellPreview memory preview = tradeRouter.previewSell(
                    actor, token.MIN_SELL_AMOUNT()
                );
                assertEq(preview.taxBps, token.PROFIT_SELL_TAX_BPS());
            }
        }
    }
}
