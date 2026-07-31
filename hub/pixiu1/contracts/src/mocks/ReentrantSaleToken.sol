// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IReentrantPurchaseTarget {
    function buy() external payable;
}

/// @notice 在私募合约向用户发币时尝试再次调用 buy()，用于验证认购重入保护。
contract ReentrantSaleToken is ERC20 {
    address public target;
    bool public attackEnabled;
    bool public reentryBlocked;

    constructor(address initialHolder, uint256 supply) ERC20("Reentrant Sale Token", "RST") {
        _mint(initialHolder, supply);
    }

    function setAttack(address newTarget, bool enabled) external {
        target = newTarget;
        attackEnabled = enabled;
        reentryBlocked = false;
    }

    function _update(address from, address to, uint256 value) internal override {
        super._update(from, to, value);

        if (attackEnabled && from == target && target != address(0)) {
            attackEnabled = false;
            try IReentrantPurchaseTarget(target).buy{ value: 1 wei }() {
                reentryBlocked = false;
            } catch {
                reentryBlocked = true;
            }
        }
    }
}
