// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Protocol-controlled reasons for a transfer that crosses the user/system boundary.
/// @dev The token never accepts a context supplied by an end user. A context is created only by
///      an allowlisted system contract or by a dedicated token settlement function.
library TransferContext {
    enum Kind {
        NONE,
        BUY_SETTLEMENT,
        SELL_ENTRY,
        LIQUIDITY_DEPOSIT,
        /// @dev LP principal withdrawal — tracked cost moves from LP to user.
        LIQUIDITY_WITHDRAWAL,
        /// @dev LP fee collection — ZERO COST, never moves LP principal or cost.
        LIQUIDITY_FEE_COLLECTION,
        DIVIDEND_CLAIM,
        SYSTEM_CREDIT_UNKNOWN,
        /// @dev User → Staking: staking deposit. Preserves user Cost Basis.
        STAKING_DEPOSIT,
        /// @dev Staking → User: principal return on unstake.
        STAKING_PRINCIPAL_RETURN,
        /// @dev Staking → User: reward payment.
        STAKING_REWARD
    }
}
