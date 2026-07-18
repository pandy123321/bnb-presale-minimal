// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ScriptBase } from "../script/utils/ScriptBase.sol";
import { TestBase } from "./utils/TestBase.sol";

contract ScriptBaseHarness is ScriptBase {
    function requireExpectedChain(uint256 expectedChainId, bool allowMainnetWrites) external view {
        _requireExpectedChain(expectedChainId, allowMainnetWrites);
    }

    function requireLocalAnvilChain() external view {
        _requireLocalAnvilChain();
    }
}

contract ScriptSafetyTest is TestBase {
    ScriptBaseHarness internal harness;

    function setUp() public {
        harness = new ScriptBaseHarness();
    }

    function test_ExpectedChainMismatchRevertsBeforeBroadcast() public {
        vm.chainId(97);
        vm.expectRevert(abi.encodeWithSelector(ScriptBase.UnexpectedChainId.selector, 97, 56));
        harness.requireExpectedChain(56, true);
    }

    function test_BSCMainnetIsRejectedByDefault() public {
        vm.chainId(56);
        vm.expectRevert(abi.encodeWithSelector(ScriptBase.MainnetWritesDisabled.selector, 56));
        harness.requireExpectedChain(56, false);
    }

    function test_BSCMainnetRequiresExplicitWriteAuthorization() public {
        vm.chainId(56);
        harness.requireExpectedChain(56, true);
    }

    function test_BSCTestnetExpectedChainPasses() public {
        vm.chainId(97);
        harness.requireExpectedChain(97, false);
    }

    function test_LocalDeploymentRequiresAnvilChain31337() public {
        vm.chainId(97);
        vm.expectRevert(abi.encodeWithSelector(ScriptBase.LocalDeploymentChainRequired.selector, 97));
        harness.requireLocalAnvilChain();

        vm.chainId(31_337);
        harness.requireLocalAnvilChain();
    }
}
