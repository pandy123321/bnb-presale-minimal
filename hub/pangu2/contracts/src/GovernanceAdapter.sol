// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract GovernanceAdapter is AccessControl, ReentrancyGuard {
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant TIMELOCK_ROLE = keccak256("TIMELOCK_ROLE");

    struct Permission {
        bool enabled;
        uint96 maximumValue;
    }

    mapping(address => mapping(bytes4 => Permission)) public permissions;

    error ZeroAddress();
    error AddressHasNoCode(address account);
    error InvalidCalldata();
    error PermissionDenied(address target, bytes4 selector, uint256 value);
    error ValueMismatch(uint256 msgValue, uint256 requestedValue);
    error TargetCallFailed(address target, bytes4 selector, bytes returnData);

    event PermissionUpdated(address indexed target, bytes4 indexed selector, bool enabled, uint96 maximumValue);
    event GovernedCallExecuted(
        address indexed caller,
        address indexed target,
        bytes4 indexed selector,
        uint256 value,
        bytes32 calldataHash,
        bytes returnData
    );

    constructor(address timelock) {
        if (timelock == address(0)) revert ZeroAddress();
        if (timelock.code.length == 0) revert AddressHasNoCode(timelock);
        _grantRole(DEFAULT_ADMIN_ROLE, timelock);
        _grantRole(GOVERNANCE_ROLE, timelock);
        _grantRole(TIMELOCK_ROLE, timelock);
        _setRoleAdmin(TIMELOCK_ROLE, GOVERNANCE_ROLE);
    }

    function setPermission(address target, bytes4 selector, bool enabled, uint96 maximumValue)
        external
        onlyRole(GOVERNANCE_ROLE)
    {
        if (target == address(0)) revert ZeroAddress();
        if (target.code.length == 0) revert AddressHasNoCode(target);
        if (selector == bytes4(0)) revert InvalidCalldata();
        permissions[target][selector] = Permission({enabled: enabled, maximumValue: maximumValue});
        emit PermissionUpdated(target, selector, enabled, maximumValue);
    }

    function execute(address target, uint256 value, bytes calldata data)
        external
        payable
        onlyRole(TIMELOCK_ROLE)
        nonReentrant
        returns (bytes memory returnData)
    {
        if (data.length < 4) revert InvalidCalldata();
        if (msg.value != value) revert ValueMismatch(msg.value, value);
        bytes4 selector;
        assembly ("memory-safe") {
            selector := calldataload(data.offset)
        }
        Permission memory permission = permissions[target][selector];
        if (!permission.enabled || value > permission.maximumValue) {
            revert PermissionDenied(target, selector, value);
        }
        if (target.code.length == 0) revert AddressHasNoCode(target);

        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) revert TargetCallFailed(target, selector, result);
        emit GovernedCallExecuted(msg.sender, target, selector, value, keccak256(data), result);
        return result;
    }
}
