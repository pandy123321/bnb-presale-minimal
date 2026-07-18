// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Foundry Cheatcode 最小接口，避免测试项目依赖额外测试库。
interface Vm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }

    function prank(address msgSender) external;
    function startPrank(address msgSender) external;
    function stopPrank() external;
    function deal(address account, uint256 newBalance) external;
    function chainId(uint256 newChainId) external;
    function assume(bool condition) external;
    function bound(uint256 value, uint256 min, uint256 max) external returns (uint256 result);
    function expectRevert(bytes4 revertData) external;
    function expectRevert(bytes calldata revertData) external;
    function expectEmit(bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData, address emitter) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory entries);
    function envUint(string calldata name) external returns (uint256 value);
    function envAddress(string calldata name) external returns (address value);
    function envBool(string calldata name) external returns (bool value);
    function startBroadcast(uint256 privateKey) external;
    function stopBroadcast() external;
}

/// @notice 项目自带的轻量断言基类。
abstract contract TestBase {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    error AssertionFailed(string message);

    function assertTrue(bool condition, string memory message) internal pure {
        if (!condition) revert AssertionFailed(message);
    }

    function assertFalse(bool condition, string memory message) internal pure {
        if (condition) revert AssertionFailed(message);
    }

    function assertEq(uint256 actual, uint256 expected, string memory message) internal pure {
        if (actual != expected) revert AssertionFailed(message);
    }

    function assertEq(address actual, address expected, string memory message) internal pure {
        if (actual != expected) revert AssertionFailed(message);
    }

    function assertEq(bool actual, bool expected, string memory message) internal pure {
        if (actual != expected) revert AssertionFailed(message);
    }

    function assertEq(bytes32 actual, bytes32 expected, string memory message) internal pure {
        if (actual != expected) revert AssertionFailed(message);
    }
}
