// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice 不返回 bool 但按标准余额语义转账的历史兼容型代币。
contract NoReturnToken {
    string public constant name = "No Return Token";
    string public constant symbol = "NRT";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    event Transfer(address indexed from, address indexed to, uint256 value);

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function transfer(address to, uint256 amount) external {
        uint256 fromBalance = balanceOf[msg.sender];
        require(fromBalance >= amount, "INSUFFICIENT_BALANCE");
        unchecked {
            balanceOf[msg.sender] = fromBalance - amount;
        }
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
    }
}
