// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {BuybackLocker} from "pangu2/BuybackLocker.sol";
import {TransferContext} from "pangu2/libraries/TransferContext.sol";

contract LockerToken is ERC20 {
    constructor() ERC20("Locker Token", "LOCK") {
        _mint(msg.sender, 1_000_000 ether);
    }

    function systemTransfer(address to, uint256 amount, TransferContext.Kind) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }
}

contract LockerSupportPoolStub {}

contract BuybackLockerTest is Test {
    LockerToken internal token;
    LockerSupportPoolStub internal supportPool;
    address internal constant RECIPIENT = address(0xA11CE);
    uint64 internal constant TEST_FIXTURE_LOCK_DURATION = 7 days;

    function setUp() public {
        token = new LockerToken();
        supportPool = new LockerSupportPoolStub();
    }

    function testFixedDurationRejectsEarlyAndReleasesOnlyToImmutableRecipient() public {
        BuybackLocker locker = new BuybackLocker(
            address(token), address(supportPool), BuybackLocker.LockMode.FIXED_DURATION, TEST_FIXTURE_LOCK_DURATION, RECIPIENT
        );
        token.transfer(address(locker), 10 ether);
        vm.prank(address(supportPool));
        uint256 batchId = locker.registerBuyback(1, 10 ether);

        vm.expectRevert(BuybackLocker.BatchStillLocked.selector);
        locker.release(batchId);
        vm.warp(block.timestamp + TEST_FIXTURE_LOCK_DURATION);
        locker.release(batchId);
        assertEq(token.balanceOf(RECIPIENT), 10 ether);
        assertEq(locker.outstandingLocked(), 0);

        vm.expectRevert(BuybackLocker.BatchNotLocked.selector);
        locker.release(batchId);
    }

    function testPermanentModeNeverReleases() public {
        BuybackLocker locker = new BuybackLocker(
            address(token), address(supportPool), BuybackLocker.LockMode.PERMANENT, 0, RECIPIENT
        );
        token.transfer(address(locker), 1 ether);
        vm.prank(address(supportPool));
        uint256 batchId = locker.registerBuyback(1, 1 ether);
        vm.warp(block.timestamp + 3650 days);
        vm.expectRevert(BuybackLocker.PermanentMode.selector);
        locker.release(batchId);
    }

    function testUnauthorizedRegistrationAndUnbackedBatchRevert() public {
        BuybackLocker locker = new BuybackLocker(
            address(token), address(supportPool), BuybackLocker.LockMode.FIXED_DURATION, TEST_FIXTURE_LOCK_DURATION, RECIPIENT
        );
        vm.expectRevert(BuybackLocker.UnauthorizedCaller.selector);
        locker.registerBuyback(1, 1 ether);

        vm.prank(address(supportPool));
        vm.expectRevert(BuybackLocker.InsufficientBacking.selector);
        locker.registerBuyback(1, 1 ether);
    }
}
