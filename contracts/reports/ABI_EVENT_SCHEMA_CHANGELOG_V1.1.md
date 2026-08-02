# ABI and Event Schema Changelog V1.1

## Added ABI Surface

```solidity
enum BuybackBlockReason {
    NONE,
    PAUSED,
    LOCKER_NOT_CONFIGURED,
    INSUFFICIENT_BNB,
    COOLDOWN,
    ORACLE_UNAVAILABLE,
    INVALID_QUOTE
}

function canExecuteBuyback()
    external
    view
    returns (
        bool allowed,
        BuybackBlockReason reason,
        uint256 poolBalance,
        uint256 nextAllowedAt
    );
```

## Added Error

```solidity
error InvalidOracleQuote(uint256 amountOut, uint256 minimumAmountOut);
```

## Events

No event was added, removed, renamed or semantically changed by V1.1.

## Pending Generated Evidence

Full ABI JSON, method identifiers, storage layouts and event topic hashes must be generated from Solidity `0.8.24` compiler output and bound to the final PR Head SHA. They are not fabricated in the local artifact environment.
