# BNB Presale Internal System
## 04 API Specification

Version: 1.0.0  
Backend: Laravel 13  
API prefix: `/api/v1`  
Authentication: Laravel Sanctum bearer token  
Content type: `application/json`

---

## 1. General Response Format

### Success

```json
{
  "success": true,
  "data": {},
  "meta": {},
  "request_id": "uuid"
}
```

### Error

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed",
    "details": {}
  },
  "request_id": "uuid"
}
```

No endpoint returns PHP floating-point asset values. Raw amounts are strings.

---

## 2. Authentication and Authorization

Roles:

- `SUPER_ADMIN`
- `ADMIN`

Rules:

- all endpoints except login require authentication;
- write endpoints require `SUPER_ADMIN`;
- `ADMIN` is read-only;
- every write endpoint creates an audit log;
- blockchain writes also create `contract_write_transactions`.

---

## 3. Authentication APIs

### `POST /auth/login`

Request:

```json
{
  "email": "admin@example.com",
  "password": "password"
}
```

Response:

```json
{
  "success": true,
  "data": {
    "token": "plain-text-token-returned-once",
    "admin": {
      "id": 1,
      "name": "Super Admin",
      "email": "admin@example.com",
      "role": "SUPER_ADMIN"
    }
  }
}
```

### `POST /auth/logout`

Revokes the current token.

### `GET /auth/me`

Returns current administrator.

---

## 4. Dashboard APIs

### `GET /dashboard`

Returns:

- on-chain contract state;
- current price;
- latest Pancake reference price;
- today and lifetime confirmed BNB received;
- contract BNB balance;
- confirmed collected BNB;
- today and lifetime token distributed;
- contract token inventory;
- unique confirmed buyer count;
- confirmed purchase count;
- current sync cursor;
- task health;
- latest reconciliation status.

All raw amounts are strings and formatted values may be returned separately.

---

## 5. Purchase Order APIs

### `GET /purchase-orders`

Query parameters:

- `page`
- `per_page`
- `status`
- `buyer_address`
- `transaction_hash`
- `from`
- `to`
- `sort`

Allowed statuses:

- `PENDING_CONFIRMATION`
- `CONFIRMED`
- `REORGED`

### `GET /purchase-orders/{id}`

Returns complete order, confirmation metadata, and related ledgers.

### `GET /purchase-orders/export`

Read-only export endpoint. Supports same filters.

---

## 6. Wallet Statistics APIs

### `GET /wallets`

Filters:

- wallet address;
- minimum purchase count;
- date range;
- sort by BNB, token, count, first or last purchase.

### `GET /wallets/{address}`

Returns:

- aggregate confirmed BNB;
- aggregate confirmed tokens;
- purchase count;
- first and last purchase;
- related orders.

### `GET /wallets/export`

---

## 7. Contract State APIs

### `GET /contract/state`

Returns on-chain values:

```json
{
  "sale_token_address": "0x...",
  "treasury_address": "0x...",
  "token_per_bnb_raw": "100000000000000000000000",
  "min_purchase_bnb_wei": "10000000000000000",
  "max_purchase_bnb_wei": "10000000000000000000",
  "max_purchase_per_wallet_wei": "50000000000000000000",
  "allow_repeat_purchase": true,
  "max_tokens_sold_raw": "100000000000000000000000000",
  "total_bnb_raised_wei": "0",
  "total_tokens_sold_raw": "0",
  "paused": true,
  "contract_bnb_balance_wei": "0",
  "contract_token_balance_raw": "0"
}
```

### `POST /contract/price`

Role: `SUPER_ADMIN`

Request:

```json
{
  "token_per_bnb_raw": "100000000000000000000000",
  "source": "MANUAL",
  "price_snapshot_id": null
}
```

Rules:

- value greater than zero;
- optional snapshot must exist if source is `PANCAKE_REFERENCE`;
- creates blockchain transaction;
- does not update confirmed state before receipt confirmation.

### `POST /contract/purchase-limits`

Role: `SUPER_ADMIN`

```json
{
  "min_purchase_bnb_wei": "10000000000000000",
  "max_purchase_bnb_wei": "10000000000000000000",
  "max_purchase_per_wallet_wei": "50000000000000000000"
}
```

### `POST /contract/repeat-purchase`

```json
{
  "allowed": true
}
```

### `POST /contract/max-token-sale`

```json
{
  "max_tokens_sold_raw": "100000000000000000000000000"
}
```

Must be greater than zero and not below current total sold.

### `POST /contract/treasury`

```json
{
  "treasury_address": "0x..."
}
```

### `POST /contract/pause`

### `POST /contract/unpause`

### `POST /contract/withdraw-unsold-token`

Role: `SUPER_ADMIN`

```json
{
  "recipient_address": "0x...",
  "amount_raw": "1000000000000000000"
}
```

The backend verifies current paused state before submission. The contract remains authoritative.

---

## 8. PancakeSwap V2 APIs

### `GET /pancake/pool`

Returns active pool configuration and last validation.

### `PUT /pancake/pool`

Role: `SUPER_ADMIN`

```json
{
  "pair_address": "0x...",
  "wbnb_address": "0x..."
}
```

Backend reads token0/token1 and validates the sale token/WBNB pair.

### `POST /pancake/pool/validate`

Role: `SUPER_ADMIN`

Reads chain state and returns validation result. Does not change contract price.

### `POST /pancake/price/refresh`

Role: `SUPER_ADMIN`

Creates a fresh snapshot.

### `GET /pancake/price/latest`

Returns:

```json
{
  "market_token_per_bnb_raw": "90000000000000000000000",
  "coefficient_numerator": "120",
  "coefficient_denominator": "100",
  "suggested_token_per_bnb_raw": "108000000000000000000000",
  "observed_at": "..."
}
```

### `PUT /pancake/coefficient`

Role: `SUPER_ADMIN`

```json
{
  "numerator": "120",
  "denominator": "100"
}
```

Both are positive integers.

The backend never submits a price automatically. Price confirmation uses `POST /contract/price`.

---

## 9. Treasury Collection APIs

### `GET /treasury/config`

Returns:

- threshold wei;
- retained balance wei;
- on-chain Treasury address.

### `PUT /treasury/config`

Role: `SUPER_ADMIN`

```json
{
  "collection_threshold_wei": "10000000000000000000",
  "retained_balance_wei": "1000000000000000000"
}
```

These values are backend-only.

### `GET /treasury/collections`

Filters by status and date.

### `GET /treasury/collections/{id}`

### `POST /treasury/collections/check`

Role: `SUPER_ADMIN`

Runs the same safe collection eligibility logic as scheduler.

### `POST /treasury/collections/{id}/execute`

Role: `SUPER_ADMIN`

Rules:

- status must be `READY`;
- no other active collection;
- reacquire distributed lock;
- reread contract BNB balance;
- recalculate executable amount;
- amount must be positive;
- creates contract write transaction;
- changes status to `SUBMITTED` only after broadcast succeeds.

### `POST /treasury/collections/{id}/cancel`

Role: `SUPER_ADMIN`

Only `READY` may be cancelled.

---

## 10. Ledger APIs

### `GET /ledgers`

Filters:

- asset type;
- entry type;
- direction;
- reference type;
- transaction hash;
- date range.

### `GET /ledgers/summary`

Returns confirmed totals.

### `GET /ledgers/export`

---

## 11. Reconciliation APIs

### `GET /reconciliations`

### `GET /reconciliations/latest`

### `POST /reconciliations/run`

Role: `SUPER_ADMIN`

Runs BNB and TOKEN reconciliation. Does not mutate ledger or order data.

---

## 12. Administrative Audit APIs

### `GET /admin-audit-logs`

Available to both roles.

Filters:

- administrator;
- action;
- result;
- transaction hash;
- date range.

No mutation endpoint is provided.

---

## 13. System APIs

### `GET /system/status`

Returns:

- RPC health;
- chain ID;
- latest chain block;
- sync cursor;
- lag;
- queue status;
- scheduler status;
- latest task runs;
- open anomalies;
- latest transaction tracker status.

### `GET /system/tasks`

### `GET /system/transactions`

Returns blockchain write audit records.

### `GET /system/anomalies`

### `POST /system/anomalies/{id}/acknowledge`

Role: `SUPER_ADMIN`

### `POST /system/anomalies/{id}/resolve`

Role: `SUPER_ADMIN`

---

## 14. Transaction Tracking Rules

All contract write endpoints respond with an application transaction record:

```json
{
  "contract_write_transaction_id": 123,
  "status": "BROADCAST",
  "transaction_hash": "0x..."
}
```

The endpoint must not claim the contract state has changed until confirmation.

Frontend must display:

- submitted;
- confirming;
- confirmed;
- failed;
- reorged.

---

## 15. Validation Rules

- Ethereum-compatible addresses must be exactly 20 bytes and normalized lowercase.
- Hashes must be exactly 32 bytes.
- All integer asset fields are decimal strings matching `^[0-9]+$`.
- No exponent notation.
- No negative asset amounts.
- Coefficient denominator cannot be zero.
- Pagination is bounded.
- Date filters use ISO 8601.
- Write requests support idempotency key where appropriate.
- Validation failures return `422`.
- Authentication failure returns `401`.
- Authorization failure returns `403`.
- Conflict or invalid state returns `409`.
- RPC or blockchain provider failure returns `503` when no safe fallback exists.

---

## 16. API-to-Page Mapping

| Page | APIs |
|---|---|
| Login | auth login/me/logout |
| Dashboard | dashboard, system status |
| Purchase Orders | purchase-orders |
| Wallet Statistics | wallets |
| Presale Configuration | contract state and contract write APIs |
| Pancake Price | pancake pool, coefficient, snapshots, contract price |
| BNB Collection | treasury config and collections |
| Asset Ledger | ledgers and reconciliation |
| Admin Audit | admin-audit-logs |
| System Status | system status, tasks, transactions, anomalies |
