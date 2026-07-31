// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IOwnedPresale {
    function acceptOwnership() external;
    function sweepBNB(uint256 amount) external;
}

/// @notice 同时作为 Owner 和 Treasury，在收款回调中尝试再次归集，用于验证重入保护。
contract ReentrantTreasury {
    IOwnedPresale public immutable presale;
    bool public attackEnabled;
    bool public reentryBlocked;

    constructor(address presaleAddress) {
        presale = IOwnedPresale(presaleAddress);
    }

    function acceptPresaleOwnership() external {
        presale.acceptOwnership();
    }

    function attackSweep(uint256 amount) external {
        attackEnabled = true;
        reentryBlocked = false;
        presale.sweepBNB(amount);
    }

    receive() external payable {
        if (attackEnabled) {
            attackEnabled = false;
            try presale.sweepBNB(1 wei) {
                reentryBlocked = false;
            } catch {
                reentryBlocked = true;
            }
        }
    }
}

/// @notice 始终拒绝接收 BNB，用于验证归集失败时整笔交易回滚。
contract RejectBNBTreasury {
    receive() external payable {
        revert(unicode"拒绝接收 BNB");
    }
}
