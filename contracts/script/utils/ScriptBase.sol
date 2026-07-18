// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice 部署脚本需要的 Foundry Cheatcode 最小接口。
interface ScriptVm {
    function envUint(string calldata name) external returns (uint256 value);
    function envAddress(string calldata name) external returns (address value);
    function envBool(string calldata name) external returns (bool value);
    function addr(uint256 privateKey) external returns (address derivedAddress);
    function startBroadcast(uint256 privateKey) external;
    function stopBroadcast() external;
}

abstract contract ScriptBase {
    ScriptVm internal constant vm = ScriptVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    uint256 internal constant BSC_MAINNET_CHAIN_ID = 56;
    uint256 internal constant LOCAL_ANVIL_CHAIN_ID = 31_337;

    /// @notice 部署私钥推导地址与配置 Owner 不一致。
    error PrivateKeyOwnerMismatch(address derivedAddress, address configuredOwner);

    /// @notice 当前 RPC 的 Chain ID 与显式配置不一致。
    error UnexpectedChainId(uint256 actualChainId, uint256 expectedChainId);

    /// @notice 未显式授权时禁止向 BSC Mainnet 写入。
    error MainnetWritesDisabled(uint256 chainId);

    /// @notice 仅本地脚本被错误指向非 Anvil 网络。
    error LocalDeploymentChainRequired(uint256 actualChainId);

    /// @dev 防止把合约部署给与实际签名钱包不同的 Owner，导致后台失去管理能力。
    function _requirePrivateKeyMatchesOwner(uint256 privateKey, address configuredOwner) internal {
        address derivedAddress = vm.addr(privateKey);
        if (derivedAddress != configuredOwner) {
            revert PrivateKeyOwnerMismatch(derivedAddress, configuredOwner);
        }
    }

    /// @dev 所有生产型链上写脚本必须在广播前校验 Chain ID，并对 BSC Mainnet 默认拒绝。
    function _requireExpectedChain(uint256 expectedChainId, bool allowMainnetWrites) internal view {
        uint256 actualChainId = block.chainid;
        if (actualChainId != expectedChainId) revert UnexpectedChainId(actualChainId, expectedChainId);
        if (actualChainId == BSC_MAINNET_CHAIN_ID && !allowMainnetWrites) {
            revert MainnetWritesDisabled(actualChainId);
        }
    }

    /// @dev 本地部署脚本只能在 Chain ID 31337 的独立 Anvil 环境执行。
    function _requireLocalAnvilChain() internal view {
        if (block.chainid != LOCAL_ANVIL_CHAIN_ID) revert LocalDeploymentChainRequired(block.chainid);
    }
}
