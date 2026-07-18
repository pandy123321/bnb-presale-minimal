# BNB Presale Internal System
## 02 Smart Contract Specification

Version: 1.1.1-FINAL  
Contract: `BNBPresale`  
Compiler: Solidity 0.8.24  
Libraries: OpenZeppelin Contracts 5.x  
Testing: Foundry

---

## 1. Contract Responsibilities

`BNBPresale` is responsible only for:

- receiving native BNB;
- validating purchase limits;
- calculating sale token output;
- checking maximum sale amount;
- checking actual token inventory;
- transferring the sale token immediately;
- tracking aggregate sale statistics;
- tracking per-wallet statistics;
- pausing and unpausing purchases;
- updating supported sale parameters;
- collecting BNB to a single Treasury address;
- permanently finalizing the sale and withdrawing unsold tokens only after finalization;
- emitting authoritative events.

It does not implement:

- USDT;
- refunds;
- claim;
- vesting;
- user registration;
- referral logic;
- automatic Pancake pricing;
- multi-project logic;
- upgradeability;
- multi-address distribution.

---

## 2. Inheritance and Libraries

The contract must use:

- `Ownable2Step`
- `Pausable`
- `ReentrancyGuard`
- `SafeERC20`
- `Math`

Recommended declaration:

```solidity
contract BNBPresale is Ownable2Step, Pausable, ReentrancyGuard
```

`SafeERC20` is used for token transfers. `Math.mulDiv` is used for full-precision purchase calculation. `Ownable2Step` is used to reduce accidental ownership-transfer risk.

---

## 3. Immutable State

```solidity
IERC20 public immutable saleToken;
```

The sale token is set in the constructor and cannot be changed.

The contract constructor must reject the zero address.

---

## 4. Mutable State

```solidity
address public treasuryAddress;

uint256 public tokenPerBNB;
uint256 public minPurchaseBNB;
uint256 public maxPurchaseBNB;
uint256 public maxPurchasePerWallet;
uint256 public maxTokensSold;

uint256 public totalBNBRaised;
uint256 public totalTokensSold;

bool public allowRepeatPurchase;
bool public saleFinalized;

mapping(address => uint256) public walletBNBSpent;
mapping(address => uint256) public walletTokensReceived;
mapping(address => uint256) public walletPurchaseCount;
```

### 4.1 Unit Definitions

- BNB amounts: wei.
- Token amounts: sale token smallest units.
- `tokenPerBNB`: sale token smallest units for `1 ether` wei.
- `maxTokensSold`: sale token smallest units.
- wallet token totals: sale token smallest units.

---

## 5. Constructor

Required constructor parameters:

```solidity
constructor(
    address initialOwner,
    address saleTokenAddress,
    address initialTreasuryAddress,
    uint256 initialTokenPerBNB,
    uint256 initialMinPurchaseBNB,
    uint256 initialMaxPurchaseBNB,
    uint256 initialMaxPurchasePerWallet,
    bool initialAllowRepeatPurchase,
    uint256 initialMaxTokensSold
)
```

Validation:

- `initialOwner != address(0)`
- `saleTokenAddress != address(0)`
- `initialTreasuryAddress != address(0)`
- `initialTokenPerBNB > 0`
- `initialMaxTokensSold > 0`
- if `initialMaxPurchaseBNB > 0`, it must be `>= initialMinPurchaseBNB`
- if `initialMaxPurchasePerWallet > 0` and `initialMinPurchaseBNB > 0`, the wallet maximum must be at least the minimum purchase amount.

The constructor initializer must call the inherited `Ownable` constructor through `Ownable2Step`:

```solidity
Ownable(initialOwner)
```

The constructor must call `_pause()`. The contract always starts in `PAUSED`. The owner deposits inventory, verifies configuration, then calls the external `unpause()` wrapper.

---

## 6. Purchase Entry Points

```solidity
receive() external payable
```

```solidity
function buy() external payable
```

Both call:

```solidity
function _purchase(address buyer, uint256 bnbAmount) internal
```

Both external entry points must use:

- `whenNotPaused`
- `nonReentrant`

The internal purchase path must also reject `saleFinalized == true` defensively.

Do not use `tx.origin`.

---

## 7. Purchase Validation Order

`_purchase` must validate:

1. buyer is not zero address;
2. `bnbAmount > 0`;
3. `tokenPerBNB > 0`;
4. if minimum is nonzero, amount is at least minimum;
5. if maximum is nonzero, amount is not greater than maximum;
6. if repeat purchase is disabled, purchase count must be zero;
7. if wallet cumulative maximum is nonzero, new cumulative BNB must not exceed it;
8. calculate token amount;
9. token amount must be greater than zero;
10. `totalTokensSold + tokenAmount <= maxTokensSold`;
11. current contract token balance is at least token amount.

State updates must occur before the external token transfer.

Token transfer uses:

```solidity
saleToken.safeTransfer(buyer, tokenAmount);
```

If transfer fails, the whole transaction reverts.

---

## 8. Purchase Calculation

```solidity
tokenAmount = Math.mulDiv(
    bnbAmount,
    tokenPerBNB,
    1 ether
);
```

`Math.mulDiv` is mandatory to avoid avoidable intermediate multiplication overflow while preserving full-precision floor division.

Rounding is down toward zero. No partial refund or residual compensation is made.

---

## 9. Administrative Functions

All write functions below are `onlyOwner`.

### 9.1 Price

```solidity
function setTokenPerBNB(uint256 newTokenPerBNB) external onlyOwner
```

Rules:

- new value must be greater than zero;
- emit `TokenPerBNBUpdated`.

### 9.2 Purchase Limits

```solidity
function setPurchaseLimits(
    uint256 newMinPurchaseBNB,
    uint256 newMaxPurchaseBNB,
    uint256 newMaxPurchasePerWallet
) external onlyOwner
```

Rules:

- zero means disabled for min, max, and wallet limit;
- if max is nonzero, it must be at least min;
- if wallet maximum and minimum are both nonzero, wallet maximum must be at least the minimum;
- existing wallet totals are not reset;
- setting a new wallet maximum below a wallet's historical total does not alter history, but prevents further purchases by that wallet.

Emit `PurchaseLimitsUpdated`.

### 9.3 Repeat Purchase

```solidity
function setAllowRepeatPurchase(bool allowed) external onlyOwner
```

Emit `RepeatPurchaseRuleUpdated`.

### 9.4 Maximum Sale Amount

```solidity
function setMaxTokensSold(uint256 newMaxTokensSold) external onlyOwner
```

Rules:

- new maximum must be greater than zero;
- new maximum must be at least `totalTokensSold`.

Emit `MaxTokensSoldUpdated`.

### 9.5 Treasury Address

```solidity
function setTreasuryAddress(address newTreasuryAddress) external onlyOwner
```

Rules:

- nonzero address;
- emit old and new addresses.

### 9.6 Pause, Unpause, and Finalization

`Pausable` exposes internal `_pause()` and `_unpause()` operations. The presale must implement explicit external wrappers:

```solidity
function pause() external onlyOwner {
    _pause();
}

function unpause() external onlyOwner {
    if (saleFinalized) revert SaleAlreadyFinalized();
    _unpause();
}
```

Permanent completion:

```solidity
function finalizeSale() external onlyOwner whenPaused {
    if (saleFinalized) revert SaleAlreadyFinalized();
    saleFinalized = true;
    emit SaleFinalized(msg.sender);
}
```

Rules:

- deployment starts paused;
- temporary pause may be resumed before finalization;
- finalization requires paused state;
- finalization is irreversible;
- unpause after finalization reverts.

### 9.7 Ownership Safety

The contract inherits `Ownable2Step`.

The inherited two-step transfer flow may be used outside the first-phase backend, but the backend exposes no ownership-transfer API.

Ownership renunciation is disabled:

```solidity
function renounceOwnership() public override onlyOwner {
    revert OwnershipRenounceDisabled();
}
```

---

## 10. BNB Collection

```solidity
function sweepBNB(uint256 amount) external onlyOwner nonReentrant
```

Rules:

- Treasury address must be nonzero;
- amount must be greater than zero;
- amount must not exceed contract BNB balance;
- transfer only to `treasuryAddress`;
- use low-level call and require success;
- emit `BNBSwept`.

The backend calculates the proposed amount. The contract does not know backend thresholds or retained balance.

The contract must not implement automatic collection.

---

## 11. Unsold Token Withdrawal

```solidity
function withdrawUnsoldTokens(
    address recipient,
    uint256 amount
) external onlyOwner whenPaused nonReentrant
```

The implementation must explicitly enforce:

```solidity
if (!saleFinalized) revert SaleNotFinalized();
```

Rules:

- `saleFinalized == true`;
- recipient nonzero;
- amount greater than zero;
- amount not greater than current token balance;
- transfer with `SafeERC20`;
- emit `UnsoldTokensWithdrawn`.

There are no claim liabilities because all successful purchases distribute immediately. Temporary pause alone is not sufficient; withdrawal is permitted only after irreversible finalization.

---

## 12. Required Events

```solidity
event PurchaseCompleted(
    address indexed buyer,
    uint256 bnbAmount,
    uint256 tokenAmount,
    uint256 tokenPerBNB,
    uint256 walletPurchaseCount,
    uint256 totalBNBRaised,
    uint256 totalTokensSold
);
```

```solidity
event TokenPerBNBUpdated(
    uint256 previousValue,
    uint256 newValue
);
```

```solidity
event PurchaseLimitsUpdated(
    uint256 minPurchaseBNB,
    uint256 maxPurchaseBNB,
    uint256 maxPurchasePerWallet
);
```

```solidity
event RepeatPurchaseRuleUpdated(bool allowed);
```

```solidity
event MaxTokensSoldUpdated(
    uint256 previousValue,
    uint256 newValue
);
```

```solidity
event TreasuryAddressUpdated(
    address indexed previousAddress,
    address indexed newAddress
);
```

```solidity
event BNBSwept(
    address indexed treasuryAddress,
    uint256 amount
);
```

```solidity
event UnsoldTokensWithdrawn(
    address indexed recipient,
    uint256 amount
);
```

```solidity
event SaleFinalized(address indexed operator);
```

Pausable inherited events:

- `Paused(address)`
- `Unpaused(address)`

Ownable2Step/Ownable inherited events:

- `OwnershipTransferStarted(address,address)`
- `OwnershipTransferred(address,address)`

---

## 13. Custom Errors

Preferred custom errors:

- `ZeroAddress()`
- `ZeroPayment()`
- `InvalidPrice()`
- `BelowMinimumPurchase()`
- `AboveMaximumPurchase()`
- `RepeatPurchaseNotAllowed()`
- `WalletLimitExceeded()`
- `ZeroTokenOutput()`
- `SaleCapExceeded()`
- `InsufficientTokenInventory()`
- `InvalidPurchaseLimits()`
- `InvalidMaxTokensSold()`
- `InvalidAmount()`
- `BNBTransferFailed()`
- `SaleAlreadyFinalized()`
- `SaleNotFinalized()`
- `OwnershipRenounceDisabled()`

The final code may use named custom errors instead of long revert strings.

---

## 14. Security Requirements

- no `tx.origin`;
- no delegatecall;
- no upgrade proxy;
- no arbitrary receiver for BNB collection;
- no arbitrary sale token replacement;
- Checks-Effects-Interactions order;
- `nonReentrant` on purchase and asset transfer functions;
- `SafeERC20`;
- owner-only writes;
- two-step ownership transfer;
- ownership renunciation disabled;
- zero-address validation;
- explicit maximum sale cap;
- actual token inventory check;
- start paused;
- irreversible finalization before unsold-token withdrawal;
- `Math.mulDiv` for price calculation;
- no private key in repository.

---

## 15. Foundry Test Matrix

Required tests:

### Purchase success

- `receive()` successful purchase;
- `buy()` successful purchase;
- exact token amount;
- event fields;
- wallet statistics;
- global statistics;
- contract BNB balance;
- buyer token balance.

### Limits

- below minimum reverts;
- above maximum reverts;
- exact minimum succeeds;
- exact maximum succeeds;
- cumulative wallet maximum enforced;
- repeat purchase disabled;
- repeat purchase enabled.

### Sale cap and inventory

- cap exceeded reverts;
- exact remaining cap succeeds;
- inventory insufficient reverts;
- maximum cannot be set below sold amount;
- maximum cannot be zero.

### Price and precision

- price zero rejected;
- price update works;
- calculation uses `Math.mulDiv`;
- rounding down documented;
- large bounded operands do not fail from avoidable intermediate overflow;
- fuzz supported BNB amounts;
- fuzz price within bounded range.

### Pause and permissions

- purchase while paused reverts;
- owner can pause/unpause before finalization;
- owner can finalize only while paused;
- finalization is irreversible;
- unpause after finalization reverts;
- ownership renunciation reverts;
- Ownable2Step transfer behavior is tested;
- non-owner cannot modify;
- non-owner cannot collect;
- non-owner cannot withdraw tokens.

### Collection

- successful BNB sweep;
- zero amount rejected;
- excessive amount rejected;
- sent only to Treasury;
- failure path covered with rejecting Treasury test contract if applicable.

### Token withdrawal

- only after finalization;
- pause without finalization is insufficient;
- successful withdrawal;
- excessive amount rejected;
- recipient zero rejected.

### Reentrancy

- malicious token or Treasury callback attempt cannot reenter protected functions;
- state remains consistent.

---

## 16. Contract-to-Backend Mapping

| Contract item | Backend usage |
|---|---|
| `PurchaseCompleted` | creates purchase order and purchase ledgers |
| `TokenPerBNBUpdated` | confirms price-change transaction |
| `PurchaseLimitsUpdated` | confirms configuration transaction |
| `RepeatPurchaseRuleUpdated` | confirms configuration transaction |
| `MaxTokensSoldUpdated` | confirms configuration transaction |
| `TreasuryAddressUpdated` | confirms Treasury update |
| `BNBSwept` | confirms collection and BNB ledger out |
| `UnsoldTokensWithdrawn` | creates token withdrawal ledger and reconciles token Transfer |
| `Paused/Unpaused` | confirms temporary sale state |
| `SaleFinalized` | confirms irreversible terminal state |
| `OwnershipTransferStarted/OwnershipTransferred` | refreshes and audits owner state |
| sale-token `Transfer` | creates inventory-in evidence or reconciles token outflow |
| public getters | dashboard and configuration reads |
