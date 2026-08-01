# BNB Presale Internal System
## 05 Admin Page Specification

Version: 1.0.0  
Frontend: Vue 3 + TypeScript + Vite + Element Plus  
State: Pinia  
HTTP: Axios  
Charts: ECharts

---

## 1. Global UX Rules

- Management-only interface.
- No buyer-facing pages.
- Desktop-first responsive layout.
- All blockchain addresses and hashes support copy.
- Address and transaction links use configurable BscScan base URL.
- All asset values arrive as strings.
- No JavaScript `number` is used for BNB or token arithmetic.
- Loading, empty, error, submitted, confirming, confirmed, failed, and reorged states must be visible.
- Write actions require explicit confirmation.
- Normal administrators do not see enabled mutation controls.
- The frontend must not optimistically claim blockchain success.
- Current confirmed on-chain values and pending requested values are displayed separately.

---

## 2. Route Structure

```text
/login
/dashboard
/purchase-orders
/wallets
/presale-config
/pancake-price
/treasury
/ledgers
/admin-audit
/system-status
```

All routes except `/login` require authentication.

---

## 3. Navigation and Permission Rules

### Super Administrator Menu

All pages visible.

### Normal Administrator Menu

All pages visible, but:

- mutation buttons hidden or disabled;
- export allowed;
- no price update;
- no contract configuration update;
- no pause/unpause;
- no Treasury update;
- no collection execution;
- no unsold token withdrawal;
- no anomaly resolution.

Frontend permission control is convenience only. Backend authorization remains authoritative.

---

## 4. Login Page

Fields:

- email;
- password.

States:

- initial;
- submitting;
- invalid credentials;
- inactive account;
- network error.

On success:

- store token securely according to implementation plan;
- fetch `/auth/me`;
- route to Dashboard.

The first version may use browser storage for the test environment, but must document its security limitation.

---

## 5. Dashboard

### 5.1 Contract Cards

- sale token address;
- Treasury address;
- paused/running;
- current token-per-BNB ratio;
- maximum token sale;
- total token sold;
- contract token inventory;
- total BNB raised;
- current contract BNB balance.

### 5.2 Business Cards

- today confirmed BNB;
- lifetime confirmed BNB;
- today confirmed token distributed;
- lifetime confirmed token distributed;
- confirmed unique wallets;
- confirmed order count.

### 5.3 Reference Price

- latest market token-per-BNB;
- coefficient;
- suggested token-per-BNB;
- current on-chain token-per-BNB;
- last observation time;
- pool validation status.

### 5.4 System Status

- latest chain block;
- last scanned block;
- block lag;
- required confirmations;
- RPC status;
- queue/scheduler status;
- latest reconciliation;
- open anomalies.

No manual editing occurs on Dashboard.

---

## 6. Purchase Orders Page

Table columns:

- order number;
- buyer;
- BNB raw/formatted;
- token raw/formatted;
- execution price;
- transaction hash;
- block number;
- confirmations;
- status;
- block timestamp.

Filters:

- status;
- buyer address;
- transaction hash;
- date range.

Order detail drawer:

- all event fields;
- block hash;
- log index;
- related ledger entries;
- confirmation and reorganization timestamps.

Only statuses:

- `PENDING_CONFIRMATION`
- `CONFIRMED`
- `REORGED`

No retry, refund, or manual order creation button.

---

## 7. Wallet Statistics Page

Columns:

- wallet address;
- total confirmed BNB spent;
- total confirmed token received;
- purchase count;
- first purchase;
- last purchase.

Detail:

- aggregate values;
- related confirmed/reorged orders;
- explorer link.

No user profile or KYC fields.

---

## 8. Presale Configuration Page

### 8.1 Read-Only Identity

- presale contract address;
- sale token address;
- sale token name;
- symbol;
- decimals;
- owner address;
- Treasury address.

Sale token address is immutable and cannot be edited.

### 8.2 Mutable Contract Configuration

- token-per-BNB raw and formatted;
- minimum purchase BNB;
- maximum purchase BNB;
- maximum cumulative BNB per wallet;
- repeat purchase;
- maximum token sale;
- pause state.

Super administrator actions:

- update price;
- update purchase limits;
- update repeat purchase;
- update maximum token sale;
- update Treasury;
- pause;
- unpause;
- withdraw unsold token.

Each action dialog shows:

- current confirmed value;
- proposed value;
- raw integer value;
- expected contract method;
- warning;
- confirmation.

After submission, show transaction status. Do not replace current confirmed value until receipt confirmation.

Unsold token withdrawal requires paused state.

---

## 9. Pancake Price Page

### 9.1 Pool Configuration

- version: fixed `V2`;
- pair address;
- token0;
- token1;
- WBNB address;
- sale token side;
- validation status;
- validation error;
- last validated time.

Actions:

- save pair;
- validate pair;
- refresh price.

No pool discovery UI.

### 9.2 Price Snapshot

- reserve sale token;
- reserve WBNB;
- market token-per-BNB;
- coefficient numerator;
- coefficient denominator;
- suggested token-per-BNB;
- observed block;
- observed time.

### 9.3 Price Confirmation

Super administrator may:

1. select latest snapshot;
2. review suggested price;
3. optionally enter another positive raw price;
4. choose source `MANUAL` or `PANCAKE_REFERENCE`;
5. confirm on-chain update.

The page never auto-submits.

---

## 10. BNB Treasury Page

### 10.1 Configuration

Backend-only:

- collection threshold;
- retained BNB amount.

On-chain:

- Treasury address.

### 10.2 Balance and Eligibility

- current contract BNB balance;
- threshold;
- retained amount;
- calculated collectible amount;
- active collection status.

### 10.3 Collection Table

Columns:

- collection number;
- observed balance;
- proposed amount;
- actual amount;
- Treasury;
- status;
- transaction hash;
- ready/submitted/confirmed time;
- executor;
- failure reason.

Super administrator actions:

- run check;
- execute `READY`;
- cancel `READY`.

Before execution, frontend warns that amount will be recalculated from the latest chain balance.

---

## 11. Asset Ledger Page

Tabs:

- BNB ledger;
- Token ledger;
- reconciliation.

BNB types:

- purchase in;
- Treasury out;
- adjustment.

Token types:

- inventory in;
- purchase out;
- unsold withdrawal out;
- adjustment.

Columns:

- ledger number;
- asset;
- type;
- direction;
- raw amount;
- formatted amount;
- reference;
- transaction hash;
- block number;
- effective time;
- final state.

Reconciliation section:

- expected;
- on-chain;
- difference;
- checked block;
- status;
- checked time.

No ledger edit or delete control.

---

## 12. Administrator Audit Page

Columns:

- administrator;
- action;
- target;
- before;
- after;
- result;
- transaction hash;
- IP;
- time;
- error.

Read-only.

---

## 13. System Status Page

Sections:

### RPC

- primary endpoint status;
- backup endpoint status;
- chain ID;
- latest block;
- latency.

### Sync

- deployment block;
- last scanned block;
- finalized block;
- lag;
- last run;
- last error.

### Tasks

- task name;
- status;
- start/end;
- processed count;
- errors.

### Blockchain Writes

- operation;
- nonce;
- status;
- hash;
- receipt block;
- initiator;
- error.

### Anomalies

- severity;
- title;
- status;
- detected time;
- related object.

Super administrator may acknowledge or resolve anomalies. No hidden mutation of source records occurs.

---

## 14. Shared Components

- `RawAmountDisplay`
- `FormattedAmountDisplay`
- `AddressDisplay`
- `TransactionHashDisplay`
- `ExplorerLink`
- `CopyButton`
- `StatusTag`
- `PermissionGuard`
- `BlockchainWriteDialog`
- `TransactionProgress`
- `EmptyState`
- `ErrorState`
- `LoadingState`
- `ReconciliationStatus`

---

## 15. High-Precision Display

Input values remain decimal strings.

Example utility responsibilities:

- validate unsigned integer strings;
- convert wei to formatted BNB;
- convert raw token units by decimals;
- truncate display without changing raw value;
- avoid scientific notation;
- copy raw value;
- display both raw and formatted in detail views.

No multiplication or division through JavaScript `number`.

---

## 16. API Mapping

| Page | Required endpoints |
|---|---|
| Login | `/auth/*` |
| Dashboard | `/dashboard`, `/system/status` |
| Orders | `/purchase-orders*` |
| Wallets | `/wallets*` |
| Presale Config | `/contract/state`, `/contract/*` |
| Pancake | `/pancake/*`, `/contract/price` |
| Treasury | `/treasury/*` |
| Ledgers | `/ledgers*`, `/reconciliations*` |
| Audit | `/admin-audit-logs` |
| System | `/system/*` |

---

## 17. Frontend Acceptance

- route permission works;
- backend 403 is handled;
- no write button for normal admin;
- all amounts are string-safe;
- address/hash copy works;
- explorer URLs are configurable;
- failed API states do not show stale success;
- blockchain transaction progress is visible;
- confirmed and pending values are separate;
- empty and loading states exist on every data page;
- no excluded buyer-facing feature exists.
