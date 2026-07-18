// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice 购买转账时扣除 1% 的测试代币，用于证明私募会拒绝非精确到账。
contract FeeOnTransferToken is ERC20 {
    uint256 internal constant FEE_BPS = 100;
    uint256 internal constant BPS = 10_000;

    constructor() ERC20("Fee On Transfer Token", "FOT") { }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0) && value != 0) {
            uint256 fee = (value * FEE_BPS) / BPS;
            if (fee != 0) {
                super._update(from, address(0xdead), fee);
                super._update(from, to, value - fee);
                return;
            }
        }
        super._update(from, to, value);
    }
}
