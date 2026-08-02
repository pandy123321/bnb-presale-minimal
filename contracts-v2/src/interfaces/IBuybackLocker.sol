// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IBuybackLocker {
    function registerBuyback(uint256 buybackId, uint256 amount) external returns (uint256 batchId);
    function outstandingLocked() external view returns (uint256);
}
