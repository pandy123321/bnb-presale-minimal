// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {Pangu2Token} from "pangu2/Pangu2Token.sol";
import {GovernanceAdapter} from "pangu2/GovernanceAdapter.sol";

contract TimelockTarget {
    uint256 public value;

    function setValue(uint256 value_) external returns (uint256) {
        value = value_;
        return value_;
    }
}

contract GovernanceDeploymentTest is Test {
    address internal constant PROPOSER = address(0xA001);
    address internal constant EXECUTOR = address(0xA002);
    address internal constant EMERGENCY = address(0xA003);

    TimelockController internal timelock;
    Pangu2Token internal token;

    function setUp() public {
        address[] memory proposers = new address[](1);
        proposers[0] = PROPOSER;
        address[] memory executors = new address[](1);
        executors[0] = EXECUTOR;
        timelock = new TimelockController(1 hours, proposers, executors, address(this));
        token = new Pangu2Token(address(this), address(this), EMERGENCY);
    }

    function testOneHourDelayAndDeployerRoleHandoff() public {
        assertEq(timelock.getMinDelay(), 1 hours);

        token.grantRole(token.DEFAULT_ADMIN_ROLE(), address(timelock));
        token.grantRole(token.GOVERNANCE_ROLE(), address(timelock));
        token.grantRole(token.UNPAUSER_ROLE(), address(timelock));
        token.renounceRole(token.UNPAUSER_ROLE(), address(this));
        token.renounceRole(token.GOVERNANCE_ROLE(), address(this));
        token.renounceRole(token.DEFAULT_ADMIN_ROLE(), address(this));

        assertFalse(token.hasRole(token.DEFAULT_ADMIN_ROLE(), address(this)));
        assertFalse(token.hasRole(token.GOVERNANCE_ROLE(), address(this)));
        assertFalse(token.hasRole(token.UNPAUSER_ROLE(), address(this)));
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), address(timelock)));
        assertTrue(token.hasRole(token.GOVERNANCE_ROLE(), address(timelock)));
        assertTrue(token.hasRole(token.UNPAUSER_ROLE(), address(timelock)));
        assertTrue(token.hasRole(token.PAUSER_ROLE(), EMERGENCY));
    }

    function testGovernanceAdapterExecutesOnlyAfterTimelockDelay() public {
        GovernanceAdapter adapter = new GovernanceAdapter(address(timelock));
        TimelockTarget target = new TimelockTarget();

        bytes memory permissionData = abi.encodeCall(
            GovernanceAdapter.setPermission, (address(target), TimelockTarget.setValue.selector, true, uint96(0))
        );
        bytes32 permissionSalt = keccak256("PANGU2_PERMISSION");

        vm.prank(PROPOSER);
        timelock.schedule(address(adapter), 0, permissionData, bytes32(0), permissionSalt, 1 hours);
        vm.prank(EXECUTOR);
        vm.expectRevert();
        timelock.execute(address(adapter), 0, permissionData, bytes32(0), permissionSalt);

        vm.warp(block.timestamp + 1 hours);
        vm.prank(EXECUTOR);
        timelock.execute(address(adapter), 0, permissionData, bytes32(0), permissionSalt);

        bytes memory targetData = abi.encodeCall(TimelockTarget.setValue, (42));
        bytes memory adapterData = abi.encodeCall(GovernanceAdapter.execute, (address(target), 0, targetData));
        bytes32 executionSalt = keccak256("PANGU2_EXECUTION");
        vm.prank(PROPOSER);
        timelock.schedule(address(adapter), 0, adapterData, bytes32(0), executionSalt, 1 hours);
        vm.warp(block.timestamp + 1 hours);
        vm.prank(EXECUTOR);
        timelock.execute(address(adapter), 0, adapterData, bytes32(0), executionSalt);

        assertEq(target.value(), 42);
    }
}
