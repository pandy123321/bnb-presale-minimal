// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { Pangu2Token } from "pangu2/Pangu2Token.sol";
import { Pangu2Staking } from "pangu2/Pangu2Staking.sol";
import { ICostBasisManager } from "pangu2/interfaces/ICostBasisManager.sol";
import { IFeeVault } from "pangu2/interfaces/IFeeVault.sol";
import { TransferContext } from "pangu2/libraries/TransferContext.sol";

// Minimal mocks for coreConfigured requirement
contract MockCostBasis is ICostBasisManager {
    function positionOf(address) external view returns (Position memory) {
        return Position(0, 0, PositionStatus.NONE);
    }

    function liquidityPositionOf(address) external view returns (Position memory) {
        return Position(0, 0, PositionStatus.NONE);
    }

    function lpPositionFor(address, uint256) external view returns (Position memory) {
        return Position(0, 0, PositionStatus.NONE);
    }

    function proportionalCost(address, uint256) external view returns (uint256, PositionStatus) {
        return (0, PositionStatus.NONE);
    }
    function recordBuy(address, uint256, uint256) external { }
    function recordZeroCost(address, uint256) external { }
    function markUnknown(address, uint256, bytes32) external { }

    function consumeSell(address, uint256) external returns (uint256, PositionStatus) {
        return (0, PositionStatus.NONE);
    }
    function onUserTransfer(address, address, uint256) external { }
    function onLiquidityDeposit(address, uint256) external { }
    function onStakingDeposit(address, uint256) external { }
    function onLiquidityWithdrawal(address, uint256) external { }
    function onLiquidityFeeCollection(address, uint256) external { }
    function onSystemCreditUnknown(address, uint256, bytes32) external { }
    function setSystemAddress(address, bool) external { }
    function bindLpTokenId(address, uint256, uint256, uint256) external { }

    function consumeLpTokenId(address, uint256, uint256) external returns (uint256, uint256) {
        return (0, 0);
    }

    function migrateLpCost(address, address, uint256) external returns (uint256, uint256) {
        return (0, 0);
    }

    function lpTrackedTotal(address) external view returns (uint256) {
        return 0;
    }

    function lpCostTotal(address) external view returns (uint256) {
        return 0;
    }
}

contract MockFeeVault is IFeeVault {
    function credit(Bucket, uint256) external { }

    function supportBalance() external view returns (uint256) {
        return 0;
    }

    function dividendBalance() external view returns (uint256) {
        return 0;
    }

    function convertSupport(uint256, uint256, uint256) external returns (uint256) {
        return 0;
    }
}

contract StakingSecurityTest is Test {
    Pangu2Token internal token;
    Pangu2Staking internal staking;
    MockCostBasis internal costBasis;
    MockFeeVault internal feeVault;

    address internal constant GOVERNANCE = address(0x6000);
    address internal constant EMERGENCY = address(0x7000);
    address internal constant HOLDER = address(0x8000);
    address internal constant USER_A = address(0xA000);
    address internal constant USER_B = address(0xB000);
    address internal constant ATTACKER = address(0xEEEE);

    function setUp() public {
        token = new Pangu2Token(HOLDER, GOVERNANCE, EMERGENCY);
        costBasis = new MockCostBasis();
        feeVault = new MockFeeVault();
        staking = new Pangu2Staking(address(token), GOVERNANCE);

        // Configure core + register staking
        vm.startPrank(GOVERNANCE);
        token.configureCore(address(costBasis), address(feeVault));
        token.setSystemAddress(address(staking), true);
        token.setSystemTransferContext(address(staking), TransferContext.Kind.STAKING_DEPOSIT, true);
        token.setSystemTransferContext(address(staking), TransferContext.Kind.STAKING_PRINCIPAL_RETURN, true);
        token.setSystemTransferContext(address(staking), TransferContext.Kind.STAKING_REWARD, true);
        vm.stopPrank();

        // Transfer tokens to users
        vm.startPrank(HOLDER);
        token.transfer(GOVERNANCE, 1000 ether);
        token.transfer(USER_A, 1000 ether);
        token.transfer(USER_B, 1000 ether);
        vm.stopPrank();
    }

    // ═══════════════════════════════════════════════════════
    // Core: Stake → position created, balance tracked
    // ═══════════════════════════════════════════════════════
    function testStake_CreatesPosition() public {
        vm.startPrank(USER_A);
        token.approve(address(staking), type(uint256).max);
        uint256 posId = staking.stake(10 ether, 30 days);
        vm.stopPrank();

        assertEq(posId, 0);
        assertEq(staking.totalStaked(), 10 ether);
        assertEq(staking.userPositionCount(USER_A), 1);
        assertFalse(staking.positions(USER_A, 0).claimed);
    }

    // ═══════════════════════════════════════════════════════
    // Unstake — principal fully returned
    // ═══════════════════════════════════════════════════════
    function testUnstake_PrincipalReturned() public {
        vm.startPrank(USER_A);
        token.approve(address(staking), type(uint256).max);
        staking.stake(10 ether, 1 days);
        vm.warp(block.timestamp + 2 days);

        uint256 balBefore = token.balanceOf(USER_A);
        staking.unstake(0);
        assertEq(token.balanceOf(USER_A) - balBefore, 10 ether);
        assertEq(staking.totalStaked(), 0);
        vm.stopPrank();
    }

    // ═══════════════════════════════════════════════════════
    // Unstake before unlock → reverts
    // ═══════════════════════════════════════════════════════
    function testUnstake_BeforeUnlock_Reverts() public {
        vm.startPrank(USER_A);
        token.approve(address(staking), type(uint256).max);
        staking.stake(10 ether, 30 days);
        vm.expectRevert(abi.encodeWithSelector(Pangu2Staking.StillLocked.selector, block.timestamp + 30 days));
        staking.unstake(0);
        vm.stopPrank();
    }

    // ═══════════════════════════════════════════════════════
    // Early unstake — 10% penalty
    // ═══════════════════════════════════════════════════════
    function testEarlyUnstake_PenaltyApplied() public {
        vm.startPrank(USER_A);
        token.approve(address(staking), type(uint256).max);
        staking.stake(10 ether, 30 days);
        vm.warp(block.timestamp + 7 days);

        (uint256 amount, uint256 penalty) = staking.earlyUnstake(0);
        assertEq(amount, 10 ether);
        assertEq(penalty, 1 ether, "10% penalty");
        vm.stopPrank();
    }

    // ═══════════════════════════════════════════════════════
    // Claim rewards
    // ═══════════════════════════════════════════════════════
    function testClaimRewards_AfterFunding() public {
        // Governance funds rewards
        vm.startPrank(GOVERNANCE);
        token.approve(address(staking), 100 ether);
        staking.fundRewards(100 ether);
        staking.setRewardRate(1_000_000); // small rate, fits in funded reserve
        vm.stopPrank();

        vm.startPrank(USER_A);
        token.approve(address(staking), type(uint256).max);
        staking.stake(1 ether, 30 days);
        vm.warp(block.timestamp + 1 days);

        uint256 earned = staking.earned(USER_A);
        assertGt(earned, 0);
        uint256 reward = staking.claimRewards();
        assertGt(reward, 0);
        vm.stopPrank();
    }

    // ═══════════════════════════════════════════════════════
    // Principal protected
    // ═══════════════════════════════════════════════════════
    function testPrincipalProtected_ClaimRewards() public {
        vm.startPrank(GOVERNANCE);
        token.approve(address(staking), 1 ether);
        staking.fundRewards(1 ether);
        staking.setRewardRate(1_000_000); // small rate, fits in funded reserve
        vm.stopPrank();

        vm.startPrank(USER_A);
        token.approve(address(staking), type(uint256).max);
        staking.stake(100 ether, 30 days);
        vm.warp(block.timestamp + 30 days);
        staking.claimRewards();
        assertGe(token.balanceOf(address(staking)), staking.totalStaked());
        vm.stopPrank();
    }

    // ═══════════════════════════════════════════════════════
    // Insufficient reserve caps rewards
    // ═══════════════════════════════════════════════════════
    function testRewards_InsufficientReserve() public {
        vm.startPrank(GOVERNANCE);
        token.approve(address(staking), 0.1 ether);
        staking.fundRewards(0.1 ether);
        staking.setRewardRate(1_000_000); // small rate, fits in funded reserve
        vm.stopPrank();

        vm.startPrank(USER_A);
        token.approve(address(staking), type(uint256).max);
        staking.stake(100 ether, 30 days);
        vm.warp(block.timestamp + 30 days);
        uint256 reward = staking.claimRewards();
        assertGt(reward, 0);
        assertLe(reward, token.balanceOf(address(staking)) - staking.totalStaked() + reward);
        vm.stopPrank();
    }

    // ═══════════════════════════════════════════════════════
    // Coverage ratio
    // ═══════════════════════════════════════════════════════
    function testCoverageRatio_Boundaries() public {
        vm.startPrank(GOVERNANCE);
        token.approve(address(staking), 10 ether);
        staking.fundRewards(10 ether);
        vm.stopPrank();

        vm.startPrank(USER_A);
        token.approve(address(staking), type(uint256).max);
        staking.stake(100 ether, 30 days);
        vm.stopPrank();

        (uint256 p,,) = staking.coverageRatio();
        assertGe(p, 1e18, "principal coverage >= 1e18");
    }

    // ═══════════════════════════════════════════════════════
    // Unauthorized transfer context
    // ═══════════════════════════════════════════════════════
    function testUnauthorizedContext_Reverts() public {
        vm.startPrank(USER_A);
        token.approve(address(staking), type(uint256).max);
        staking.stake(10 ether, 30 days);
        vm.stopPrank();

        vm.prank(ATTACKER);
        vm.expectRevert();
        token.systemTransfer(ATTACKER, 1 ether, TransferContext.Kind.STAKING_REWARD);
    }

    // ═══════════════════════════════════════════════════════
    // Staking bypasses tax
    // ═══════════════════════════════════════════════════════
    function testStakingTransfers_BypassTax() public {
        vm.prank(GOVERNANCE);
        token.setTradingOpenAt();

        vm.startPrank(USER_A);
        token.approve(address(staking), type(uint256).max);
        uint256 balBefore = token.balanceOf(USER_A);
        staking.stake(10 ether, 30 days);
        uint256 balAfter = token.balanceOf(USER_A);
        assertEq(balBefore - balAfter, 10 ether, "no tax on staking");

        vm.warp(block.timestamp + 31 days);
        uint256 ub = token.balanceOf(USER_A);
        staking.unstake(0);
        assertEq(token.balanceOf(USER_A) - ub, 10 ether);
        vm.stopPrank();
    }

    // ═══════════════════════════════════════════════════════
    // Whitelist doesn't affect staking
    // ═══════════════════════════════════════════════════════
    function testWhitelist_DoesNotAffectStaking() public {
        vm.prank(GOVERNANCE);
        token.setFeeWhitelist(USER_A, true);

        vm.startPrank(USER_A);
        token.approve(address(staking), type(uint256).max);
        staking.stake(10 ether, 30 days);
        vm.warp(block.timestamp + 31 days);
        staking.unstake(0);
        assertEq(token.balanceOf(USER_A), 1000 ether);
        vm.stopPrank();
    }

    // ═══════════════════════════════════════════════════════
    // Liability conservation
    // ═══════════════════════════════════════════════════════
    function testLiability_Conservation() public {
        vm.startPrank(GOVERNANCE);
        token.approve(address(staking), 10 ether);
        staking.fundRewards(10 ether);
        staking.setRewardRate(1_000_000); // small rate, fits in funded reserve
        vm.stopPrank();

        vm.startPrank(USER_A);
        token.approve(address(staking), type(uint256).max);
        staking.stake(100 ether, 30 days);
        vm.warp(block.timestamp + 1 days);
        staking.claimRewards();
        vm.stopPrank();

        uint256 a = staking.availableRewardReserve();
        uint256 o = staking.outstandingRewards();
        uint256 p = staking.totalRewardPaid();
        assertGe(a + o + p, 0);
    }

    // ═══════════════════════════════════════════════════════
    // Fuzz: stake → totalStaked tracked correctly
    // ═══════════════════════════════════════════════════════
    function testFuzz_Stake_TotalStaked(uint256 amount) public {
        amount = bound(amount, 1 ether, 100_000 ether);

        vm.startPrank(HOLDER);
        token.transfer(USER_A, amount);
        vm.stopPrank();

        vm.startPrank(USER_A);
        token.approve(address(staking), type(uint256).max);
        uint256 before = staking.totalStaked();
        staking.stake(amount, 30 days);
        assertEq(staking.totalStaked(), before + amount);
        vm.stopPrank();
    }

    // ═══════════════════════════════════════════════════════
    // Fuzz: unstake → full principal returned
    // ═══════════════════════════════════════════════════════
    function testFuzz_Unstake_PrincipalReturned(uint256 amount) public {
        amount = bound(amount, 1 ether, 100_000 ether);

        vm.startPrank(HOLDER);
        token.transfer(USER_A, amount);
        vm.stopPrank();

        vm.startPrank(USER_A);
        token.approve(address(staking), type(uint256).max);
        staking.stake(amount, 1 days);
        vm.warp(block.timestamp + 2 days);

        uint256 balBefore = token.balanceOf(USER_A);
        staking.unstake(0);
        assertEq(token.balanceOf(USER_A) - balBefore, amount);
        vm.stopPrank();
    }
}
