# BNB Presale Internal System
## 01 Product Specification

Version: 1.1.1-FINAL  
Status: Phase 1 Final Baseline  
Scope: Internal Test MVP  
Network: BNB Smart Chain compatible network  
Primary environments: Anvil, BNB Chain Testnet

---

## 1. Product Objective

Build a single-project internal presale system that accepts only native BNB.

There is no user-facing application, user account, user login, wallet connection, KYC, refund, claim, vesting, or multi-project support.

A buyer sends native BNB directly from a self-controlled wallet to the `BNBPresale` contract. The contract validates the sale rules, calculates the token amount using the current on-chain exchange rate, checks the configured sale cap and actual token inventory, and transfers the sale token to the buyer within the same transaction.

The Laravel backend indexes successful `PurchaseCompleted` events, creates purchase orders, updates wallet aggregates and asset ledgers, monitors contract balances, reads a manually configured PancakeSwap V2 pool as a reference price source, and permits a super administrator to confirm and submit contract changes.

When the BNB balance reaches the configured collection threshold, the backend creates a collection record. Collection never happens automatically. A super administrator must confirm and execute the transaction.

---

## 2. User and Administrator Roles

### 2.1 Buyer

A buyer:

- uses a self-controlled wallet;
- sends native BNB directly to the presale contract;
- receives sale tokens in the same transaction;
- is identified only by the paying wallet address;
- cannot request a refund after a successful purchase.

The product does not guarantee compatibility with transfers initiated by exchanges, bridges, custodial systems, smart-contract wallets, or intermediary contracts.

### 2.2 Super Administrator

The super administrator may:

- log in to the management backend;
- view all system data;
- update supported contract parameters;
- pause and unpause the presale;
- confirm and submit a price update;
- configure the PancakeSwap V2 pool;
- configure collection thresholds;
- execute BNB collection;
- update the Treasury address through the contract;
- permanently finalize the sale while paused and withdraw unsold tokens only after finalization;
- export data;
- review system logs and reconciliation results.

### 2.3 Normal Administrator

The normal administrator may:

- log in;
- view dashboard data;
- view purchase orders;
- view wallet statistics;
- view contract configuration;
- view reference prices;
- view collection records;
- view ledgers;
- view administrative and system logs;
- export data.

A normal administrator cannot perform any blockchain write operation or modify financial configuration.

### 2.4 Chain Operator, Contract Owner, and Treasury

The first-phase ownership model is fixed:

- `CHAIN_OPERATOR_ADDRESS` is the public address derived from the backend signing key.
- `BNBPresale.owner()` must equal `CHAIN_OPERATOR_ADDRESS`.
- the signed-in super administrator authorizes an application action, but is not itself the on-chain signer;
- `treasuryAddress` is the BNB receiving address and remains a separate concept from Owner;
- before every blockchain write, the backend must verify the configured chain ID and confirm that `BNBPresale.owner() == CHAIN_OPERATOR_ADDRESS`;
- if the addresses do not match, all blockchain writes are disabled and a Blocker anomaly is created;
- the first-phase backend exposes no ownership-transfer or ownership-renunciation API.

---

## 3. Core Business Flow

### 3.1 Contract Deployment

1. Deploy a standard sale token or provide an existing compatible BEP-20/ERC-20 token.
2. Deploy `BNBPresale` with:
   - immutable sale token address;
   - Treasury address;
   - initial token-per-BNB price;
   - minimum purchase amount;
   - maximum purchase amount;
   - maximum cumulative BNB per wallet;
   - repeat purchase rule;
   - maximum token sale amount;
   - contract owner.
3. Transfer the sale inventory into the presale contract.
4. Verify that the contract token balance is sufficient.
5. Call `unpause()` to move the sale from `PAUSED` to `ACTIVE`.
6. When the sale is permanently complete, pause it and call `finalizeSale()`.
7. `FINALIZED` is irreversible; the sale cannot be unpaused again.

### 3.2 Purchase

1. Buyer sends native BNB to `receive()` or calls `buy()` while the sale lifecycle is `ACTIVE`.
2. The contract checks:
   - not paused;
   - payment greater than zero;
   - exchange rate greater than zero;
   - minimum purchase rule;
   - maximum purchase rule;
   - repeat purchase rule;
   - cumulative wallet limit;
   - maximum token sale amount;
   - actual token inventory.
3. The contract calculates:

   `tokenAmount = msg.value × tokenPerBNB ÷ 1 ether`

4. The contract updates:
   - total BNB raised;
   - total tokens sold;
   - wallet cumulative BNB;
   - wallet cumulative tokens;
   - wallet purchase count.
5. The contract transfers sale tokens to the buyer.
6. The contract emits `PurchaseCompleted`, and the sale token emits a standard `Transfer` from the presale contract to the buyer.
7. Any failure reverts the entire transaction.

### 3.3 Backend Indexing

1. The backend scans blocks from the saved cursor.
2. It reads `PurchaseCompleted` logs.
3. It creates a unique record using:

   `chain_id + transaction_hash + log_index`

4. New events enter `PENDING_CONFIRMATION`.
5. After the required number of confirmations, and after confirming the event still exists in the canonical block, the order becomes `CONFIRMED`.
6. If a pending event disappears because of chain reorganization, the order becomes `REORGED`; no confirmed ledger or wallet aggregate is created.
7. If a previously confirmed event is reorganized, the backend must atomically mark the order `REORGED`, append one BNB reversal and one TOKEN reversal, rebuild the affected wallet aggregate from remaining `CONFIRMED` orders, create a P0 anomaly, rewind the relevant cursors, and rescan.
8. Purchase orders are never created from user-submitted data.
9. Reverted transactions do not create purchase orders.
10. The backend independently indexes presale administrative events and sale-token `Transfer` events involving the presale contract.
11. An administrative event without a matching backend transaction record is classified as `EXTERNAL_OPERATION`, triggers a state refresh, and creates an anomaly.

### 3.4 Price Reference

1. A super administrator manually configures a PancakeSwap V2 pair address.
2. The backend validates:
   - pair contract is readable;
   - token0 and token1 are expected assets;
   - one side is WBNB;
   - the other side is the sale token.
3. The backend reads reserves.
4. When the sale token reserve is `reserveTokenRaw` and WBNB reserve is `reserveWBNBWei`, calculate:

   `marketTokenPerBNBRaw = reserveTokenRaw × 10^18 ÷ reserveWBNBWei`

5. Apply the coefficient:

   `suggestedTokenPerBNBRaw = marketTokenPerBNBRaw × coefficientNumerator ÷ coefficientDenominator`
6. The backend displays a suggested presale ratio.
7. Only the super administrator can confirm a price.
8. Confirmation creates and broadcasts an on-chain price update.
9. The system must never update the contract price automatically.
10. Both reserves must be greater than zero.
11. A configurable minimum WBNB reserve produces a low-liquidity warning.
12. A configurable deviation threshold between suggested and current on-chain price requires a second confirmation.
13. A coefficient greater than one means the buyer receives more tokens per BNB.

### 3.5 BNB Collection

1. The backend reads the presale contract BNB balance.
2. If balance is at least the configured threshold, and no active collection exists, the backend creates a `READY` collection.
3. Default collection amount:

   `contract BNB balance - configured retained BNB`

4. A super administrator confirms execution and supplies an `Idempotency-Key`.
5. Before signing, the backend reacquires collection and nonce locks, validates chain/operator/Owner safety, rereads the contract balance, and recalculates the executable amount.
6. The backend signs and broadcasts the contract collection transaction.
7. The business collection becomes `SUBMITTED` after broadcast succeeds.
8. A successful canonical receipt changes it to `CONFIRMED` and creates one Treasury-out ledger entry.
9. A receipt failure, or an unreplaced dropped transaction, changes it to `FAILED`.
10. Cancellation before submission changes it to `CANCELLED`.
11. A chain reorganization changes it to `REORGED`; any confirmed ledger effect is neutralized by an auditable reversal.
12. A replacement transaction remains part of the same collection business record.
13. The first version supports one Treasury address only.

---

## 4. Token Compatibility Requirements

The sale token must be:

- standard BEP-20/ERC-20 compatible;
- non-rebasing;
- free of transfer tax;
- free of burn tax;
- free of blacklist restrictions affecting the presale;
- free of wallet holding limits;
- free of maximum transaction restrictions;
- transferable by the presale contract;
- compatible with OpenZeppelin `SafeERC20`.

Tokens that violate these requirements are outside the first-phase scope.

---

## 5. Configuration Ownership

### 5.1 On-Chain Configuration

The contract is the source of truth for:

- sale token address;
- Treasury address;
- token-per-BNB ratio;
- minimum BNB per purchase;
- maximum BNB per purchase;
- maximum cumulative BNB per wallet;
- repeat purchase permission;
- maximum token sale amount;
- pause state;
- irreversible finalization state;
- contract Owner;
- total BNB raised;
- total token sold;
- wallet cumulative amounts;
- wallet purchase count.

### 5.2 Backend Configuration

The backend is the source of truth for:

- RPC endpoints;
- chain ID;
- contract deployment block;
- required confirmations;
- scan batch size;
- PancakeSwap V2 pair address;
- reference price coefficient;
- BNB collection threshold;
- retained BNB amount;
- BscScan base URL;
- scheduler configuration;
- system health status;
- administrator accounts and roles.

Backend configuration must not claim a contract parameter changed until the corresponding transaction is confirmed.

---

## 6. Amount and Precision Rules

- Native BNB values are stored as wei integer strings.
- Token values are stored as smallest-unit integer strings.
- `tokenPerBNB` is stored as smallest token units per one full BNB.
- PHP must use strings and BCMath.
- Vue must treat all asset amounts as strings and may use BigInt-compatible utilities.
- PostgreSQL stores blockchain raw values as `numeric(78,0)`.
- PHP `float` is prohibited for asset calculations.
- JavaScript `number` is prohibited for blockchain asset calculations.
- Display formatting must use token decimals and must not alter stored raw values.

Default example:

- token decimals: 18;
- `1 BNB = 100,000 PST`;
- on-chain `tokenPerBNB = 100000 × 10^18`.

---

## 7. Order Statuses

Only these purchase statuses are valid:

- `PENDING_CONFIRMATION`
- `CONFIRMED`
- `REORGED`

A failed or reverted blockchain transaction is not a purchase order because it emits no successful purchase event.

System and RPC failures belong in task logs or anomaly records, not purchase order status.

---

## 8. Collection Statuses

Valid collection statuses:

- `READY`
- `SUBMITTED`
- `CONFIRMED`
- `FAILED`
- `CANCELLED`
- `REORGED`

Only one active collection may exist at a time for statuses `READY` or `SUBMITTED`.

---

## 9. Ledger Scope

The first version maintains these ledger entry types:

### BNB

- `PURCHASE_IN`
- `TREASURY_OUT`
- `ADJUSTMENT`

### Token

- `INVENTORY_IN`
- `PURCHASE_OUT`
- `UNSOLD_WITHDRAWAL_OUT`
- `ADJUSTMENT`

Blockchain events and confirmed transaction receipts are the primary evidence. The backend ledger is an indexed operational record, not the ultimate source of asset truth.

Ledger rows are immutable. Corrections use new adjustment rows.

---

## 10. Reconciliation

BNB:

`opening BNB + confirmed purchase BNB - confirmed Treasury out = expected closing BNB`

Token:

`opening token + inventory in - confirmed purchase token - unsold withdrawal = expected closing token`

The backend compares expected balances with current on-chain balances and creates a reconciliation result.

A mismatch does not automatically modify any order or ledger row.

---

## 11. Default Test Parameters

| Parameter | Value |
|---|---:|
| Token name | Presale Test Token |
| Token symbol | PST |
| Token decimals | 18 |
| Total supply | 1,000,000,000 PST |
| Initial contract inventory | 100,000,000 PST |
| Initial price | 1 BNB = 100,000 PST |
| Minimum purchase | 0.01 BNB |
| Maximum purchase | 10 BNB |
| Wallet cumulative maximum | 50 BNB |
| Repeat purchase | Allowed |
| Maximum token sale | 100,000,000 PST |
| Collection threshold | 10 BNB |
| Retained contract balance | 1 BNB |
| Required confirmations | 12 |
| Reference pool | PancakeSwap V2 |
| Development chain | Anvil |
| Integration chain | BNB Chain Testnet |

---

## 12. Explicitly Excluded

- USDT or any other payment token;
- user frontend;
- buyer account;
- buyer login;
- wallet connection;
- KYC;
- refunds;
- claims;
- vesting;
- locking;
- referrals;
- multiple projects;
- multiple sale tokens;
- multi-address distribution;
- multisig;
- complex approval workflow;
- PancakeSwap V3;
- automatic contract price updates;
- upgradeable contracts;
- exchange deposit attribution;
- full-chain failed transaction scanning;
- marketing features.

---

## 13. Product Acceptance Gate

The product baseline is accepted only if:

- all seven Phase 1 documents use the same statuses and units;
- all contract write operations are super-admin-only at the application level;
- normal administrators remain read-only;
- purchase orders are event-derived;
- no automatic price change exists;
- no automatic asset collection exists;
- all asset values use integer precision;
- contract and backend sources of truth are clearly separated;
- API and admin pages map to defined database entities;
- excluded features do not appear in requirements.

---

## 14. Sale Lifecycle

The sale lifecycle is authoritative and irreversible where stated:

- `PAUSED`: deployment state or temporary operational pause; purchases are rejected.
- `ACTIVE`: purchases are accepted.
- `FINALIZED`: permanent terminal state; purchases and unpause are permanently rejected.

Allowed transitions:

- deployment → `PAUSED`;
- `PAUSED` → `ACTIVE` through `unpause()`;
- `ACTIVE` → `PAUSED` through `pause()`;
- `PAUSED` → `FINALIZED` through `finalizeSale()`.

Unsold token withdrawal is allowed only in `FINALIZED`.

---

## 15. Indexed Event Streams

The backend maintains three independent cursors:

1. `PURCHASE_EVENTS`
2. `PRESALE_ADMIN_EVENTS`
3. `SALE_TOKEN_TRANSFERS`

`PRESALE_ADMIN_EVENTS` includes price, limits, repeat-purchase, sale-cap, Treasury, pause, unpause, finalization, BNB sweep, unsold-token withdrawal, and ownership events.

`SALE_TOKEN_TRANSFERS` indexes standard token `Transfer` events where either `from` or `to` equals the presale contract.

A transfer to the presale contract creates `TOKEN / INVENTORY_IN / IN`. A transfer from the presale contract must reconcile with a successful purchase or unsold-token withdrawal.

---

## 16. Blockchain Write Safety

Every application blockchain write requires:

- authenticated `SUPER_ADMIN`;
- request `Idempotency-Key`;
- expected chain ID match;
- `CHAIN_OPERATOR_ADDRESS` match with the key-derived address;
- current contract Owner match with `CHAIN_OPERATOR_ADDRESS`;
- `ALLOW_MAINNET_WRITES=true` when the configured chain is classified as mainnet;
- distributed nonce lock;
- persisted business intent and transaction attempt;
- receipt tracking;
- support for `DROPPED` and `REPLACED` attempts without duplicating the business operation.

The backend must never expose or log the private key or mnemonic.

---

## 17. Unexplained Balance Changes

A reconciliation difference that cannot be explained by indexed purchase, token transfer, sweep, or withdrawal events must:

1. create `UNEXPLAINED_BALANCE_CHANGE`;
2. remain unresolved until reviewed;
3. never silently mutate existing orders or ledger rows;
4. be resolved only through an explicit `ADJUSTMENT` ledger entry with reason, evidence, and administrator identity.
