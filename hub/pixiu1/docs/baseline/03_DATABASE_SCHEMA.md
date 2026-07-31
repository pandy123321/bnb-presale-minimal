# BNB Presale Internal System
## 03 Database Schema

Version: 1.1.1-FINAL  
Database: PostgreSQL  
ORM: Laravel Eloquent  
Precision rule: blockchain values use `numeric(78,0)` or normalized lowercase hex strings.

---

## 1. General Rules

- Primary keys use `bigserial` unless UUID is explicitly required.
- Blockchain addresses are stored lowercase.
- Transaction hashes are stored lowercase.
- Raw blockchain amounts are integer values.
- No blockchain amount uses floating point.
- Timestamps use `timestamptz`.
- Immutable ledger rows are never updated except status metadata required for chain finality.
- Administrative changes are recorded in `admin_audit_logs`.
- Secret keys are never stored in the database.

---

## 2. Enumerations

### 2.1 Administrator Role

- `SUPER_ADMIN`
- `ADMIN`

### 2.2 Purchase Status

- `PENDING_CONFIRMATION`
- `CONFIRMED`
- `REORGED`

### 2.3 Collection Status

- `READY`
- `SUBMITTED`
- `CONFIRMED`
- `FAILED`
- `CANCELLED`
- `REORGED`

### 2.4 Blockchain Transaction Status

- `CREATED`
- `SIGNED`
- `BROADCAST`
- `CONFIRMED`
- `FAILED`
- `DROPPED`
- `REPLACED`
- `REORGED`

### 2.5 Asset Type

- `BNB`
- `TOKEN`

### 2.6 Ledger Direction

- `IN`
- `OUT`

### 2.7 Ledger Entry Type

BNB:

- `PURCHASE_IN`
- `TREASURY_OUT`
- `ADJUSTMENT`

Token:

- `INVENTORY_IN`
- `PURCHASE_OUT`
- `UNSOLD_WITHDRAWAL_OUT`
- `ADJUSTMENT`
- `REVERSAL`

BNB also supports:

- `REVERSAL`

### 2.8 Task Status

- `HEALTHY`
- `DEGRADED`
- `FAILED`
- `RUNNING`
- `UNKNOWN`

### 2.9 Reconciliation Status

- `MATCHED`
- `MISMATCHED`
- `FAILED`

---

## 3. Tables

## 3.1 `admins`

| Column | Type | Rules |
|---|---|---|
| id | bigserial | PK |
| name | varchar(100) | required |
| email | varchar(255) | unique, lowercase |
| password | varchar(255) | hashed |
| role | varchar(32) | enum |
| is_active | boolean | default true |
| last_login_at | timestamptz | nullable |
| created_at | timestamptz | required |
| updated_at | timestamptz | required |

Indexes:

- unique `email`
- index `(role, is_active)`

---

## 3.2 `personal_access_tokens`

Use Laravel Sanctum-compatible structure.

Required fields:

- id
- tokenable_type
- tokenable_id
- name
- token
- abilities
- last_used_at
- expires_at
- timestamps

---

## 3.3 `system_configs`

Stores backend-only configuration.

| Column | Type | Rules |
|---|---|---|
| id | bigserial | PK |
| key | varchar(120) | unique |
| value | text | required |
| value_type | varchar(32) | STRING, INTEGER_STRING, BOOLEAN, JSON |
| is_sensitive | boolean | default false |
| description | text | nullable |
| updated_by | bigint | nullable FK admins |
| created_at | timestamptz | required |
| updated_at | timestamptz | required |

Baseline keys:

- `chain.id`
- `chain.rpc_url`
- `chain.backup_rpc_url`
- `chain.required_confirmations`
- `chain.scan_batch_size`
- `chain.deployment_block`
- `chain.expected_chain_id`
- `chain.allow_mainnet_writes`
- `chain.operator_address`
- `contract.presale_address`
- `contract.sale_token_address`
- `contract.sale_token_decimals`
- `contract.wbnb_address`
- `explorer.base_url`
- `pancake.v2_pair_address`
- `pancake.price_coefficient_numerator`
- `pancake.price_coefficient_denominator`
- `pancake.minimum_wbnb_reserve_wei`
- `pancake.maximum_price_deviation_bps`
- `treasury.collection_threshold_wei`
- `treasury.retained_balance_wei`
- `scheduler.purchase_sync_enabled`
- `scheduler.collection_monitor_enabled`
- `scheduler.reconciliation_enabled`

Sensitive values must not be stored here if they are private keys.

---

## 3.4 `chain_sync_cursors`

| Column | Type | Rules |
|---|---|---|
| id | bigserial | PK |
| chain_id | bigint | required |
| stream | varchar(64) | `PURCHASE_EVENTS`, `PRESALE_ADMIN_EVENTS`, or `SALE_TOKEN_TRANSFERS` |
| last_scanned_block | bigint | required |
| last_finalized_block | bigint | nullable |
| last_scanned_block_hash | varchar(66) | nullable |
| status | varchar(32) | task status |
| last_error | text | nullable |
| last_run_started_at | timestamptz | nullable |
| last_run_completed_at | timestamptz | nullable |
| created_at | timestamptz | required |
| updated_at | timestamptz | required |

Unique:

- `(chain_id, stream)`

---

## 3.5 `purchase_orders`

| Column | Type | Rules |
|---|---|---|
| id | bigserial | PK |
| order_no | varchar(40) | unique |
| chain_id | bigint | required |
| contract_address | varchar(42) | lowercase |
| buyer_address | varchar(42) | lowercase |
| bnb_amount_wei | numeric(78,0) | required |
| token_amount_raw | numeric(78,0) | required |
| token_per_bnb_raw | numeric(78,0) | required |
| wallet_purchase_count | numeric(78,0) | required |
| total_bnb_raised_wei | numeric(78,0) | required |
| total_tokens_sold_raw | numeric(78,0) | required |
| transaction_hash | varchar(66) | lowercase |
| transaction_index | integer | nullable |
| log_index | integer | required |
| block_number | bigint | required |
| block_hash | varchar(66) | required |
| block_timestamp | timestamptz | required |
| confirmations | integer | default 0 |
| status | varchar(32) | purchase status |
| confirmed_at | timestamptz | nullable |
| reorged_at | timestamptz | nullable |
| created_at | timestamptz | required |
| updated_at | timestamptz | required |

Unique:

- `(chain_id, transaction_hash, log_index)`

Indexes:

- `(buyer_address, block_timestamp desc)`
- `(status, block_number)`
- `(block_number, log_index)`
- `transaction_hash`
- `block_timestamp`

---

## 3.6 `wallet_statistics`

| Column | Type | Rules |
|---|---|---|
| id | bigserial | PK |
| chain_id | bigint | required |
| wallet_address | varchar(42) | lowercase |
| total_bnb_spent_wei | numeric(78,0) | default 0 |
| total_tokens_received_raw | numeric(78,0) | default 0 |
| purchase_count | bigint | default 0 |
| first_purchase_at | timestamptz | nullable |
| last_purchase_at | timestamptz | nullable |
| first_purchase_block | bigint | nullable |
| last_purchase_block | bigint | nullable |
| created_at | timestamptz | required |
| updated_at | timestamptz | required |

Unique:

- `(chain_id, wallet_address)`

Wallet statistics are rebuilt or adjusted only from purchase orders with `CONFIRMED` status.

---

## 3.7 `asset_ledger_entries`

| Column | Type | Rules |
|---|---|---|
| id | bigserial | PK |
| ledger_no | varchar(40) | unique |
| chain_id | bigint | required |
| asset_type | varchar(16) | BNB or TOKEN |
| entry_type | varchar(40) | ledger type |
| direction | varchar(8) | IN or OUT |
| amount_raw | numeric(78,0) | positive integer |
| wallet_address | varchar(42) | nullable |
| contract_address | varchar(42) | required |
| reference_type | varchar(40) | PURCHASE_ORDER, COLLECTION, TOKEN_TRANSFER, ADJUSTMENT |
| reference_id | bigint | nullable |
| transaction_hash | varchar(66) | nullable |
| log_index | integer | nullable |
| block_number | bigint | nullable |
| block_hash | varchar(66) | nullable |
| effective_at | timestamptz | required |
| is_final | boolean | default false |
| is_reversal | boolean | default false |
| reversal_of_id | bigint | nullable self FK |
| reversal_reason | varchar(120) | nullable |
| metadata | jsonb | default `{}` |
| created_at | timestamptz | required |

Unique indexes where applicable:

- purchase ledger uniqueness: `(entry_type, chain_id, transaction_hash, log_index)`
- collection ledger uniqueness: `(entry_type, reference_type, reference_id)`

Ledger amount must be greater than zero.

Confirmed purchase creates:

- one `BNB / PURCHASE_IN / IN`;
- one `TOKEN / PURCHASE_OUT / OUT`.

A reorganization uses one fixed policy:

- pending, nonfinal business effects are marked invalid without confirmed ledgers;
- previously confirmed purchase effects are neutralized by appending one BNB `REVERSAL` and one TOKEN `REVERSAL`;
- reversal rows reference the original rows using `reversal_of_id`;
- wallet aggregates are rebuilt from remaining `CONFIRMED` orders;
- original ledger rows are never deleted.

---

## 3.8 `pancake_pools`

Only one active pool is expected.

| Column | Type | Rules |
|---|---|---|
| id | bigserial | PK |
| chain_id | bigint | required |
| version | varchar(8) | must be V2 |
| pair_address | varchar(42) | lowercase |
| token0_address | varchar(42) | lowercase |
| token1_address | varchar(42) | lowercase |
| token0_decimals | integer | required |
| token1_decimals | integer | required |
| sale_token_is_token0 | boolean | required |
| wbnb_address | varchar(42) | lowercase |
| is_active | boolean | default true |
| validated_at | timestamptz | nullable |
| validation_error | text | nullable |
| created_by | bigint | FK admins |
| updated_by | bigint | FK admins |
| created_at | timestamptz | required |
| updated_at | timestamptz | required |

Unique partial expectation:

- at most one active pool per chain and presale contract, enforced in service transaction.

---

## 3.9 `price_snapshots`

| Column | Type | Rules |
|---|---|---|
| id | bigserial | PK |
| pancake_pool_id | bigint | FK |
| chain_id | bigint | required |
| block_number | bigint | required |
| reserve_sale_token_raw | numeric(78,0) | required |
| reserve_wbnb_wei | numeric(78,0) | required |
| market_token_per_bnb_raw | numeric(78,0) | required |
| coefficient_numerator | numeric(78,0) | required |
| coefficient_denominator | numeric(78,0) | required |
| suggested_token_per_bnb_raw | numeric(78,0) | required |
| observed_at | timestamptz | required |
| created_at | timestamptz | required |

Indexes:

- `(pancake_pool_id, observed_at desc)`
- `(chain_id, block_number)`

No floating-point percentage column is used.

---

## 3.10 `contract_write_transactions`

Every blockchain write operation creates a record.

| Column | Type | Rules |
|---|---|---|
| id | bigserial | PK |
| operation | varchar(64) | required |
| idempotency_key | varchar(128) | required |
| chain_id | bigint | required |
| from_address | varchar(42) | lowercase |
| to_address | varchar(42) | lowercase |
| nonce | numeric(78,0) | nullable |
| value_wei | numeric(78,0) | default 0 |
| gas_limit | numeric(78,0) | nullable |
| max_fee_per_gas_wei | numeric(78,0) | nullable |
| max_priority_fee_per_gas_wei | numeric(78,0) | nullable |
| gas_price_wei | numeric(78,0) | nullable |
| calldata_hex | text | required |
| transaction_hash | varchar(66) | nullable |
| status | varchar(32) | transaction status |
| receipt_block_number | bigint | nullable |
| receipt_block_hash | varchar(66) | nullable |
| receipt_status | integer | nullable |
| error_code | varchar(100) | nullable |
| error_message | text | nullable |
| initiated_by | bigint | FK admins |
| related_type | varchar(64) | nullable |
| related_id | bigint | nullable |
| replacement_of_id | bigint | nullable self FK |
| replaced_by_id | bigint | nullable self FK |
| last_checked_at | timestamptz | nullable |
| created_at | timestamptz | required |
| signed_at | timestamptz | nullable |
| broadcast_at | timestamptz | nullable |
| confirmed_at | timestamptz | nullable |
| failed_at | timestamptz | nullable |
| updated_at | timestamptz | required |

Unique:

- `(operation, idempotency_key)`
- `(chain_id, transaction_hash)` when hash is not null
- `(chain_id, from_address, nonce)` when nonce is not null and status is not FAILED before broadcast policy

No private key or signed raw transaction is stored by default.

---

## 3.11 `treasury_collections`

| Column | Type | Rules |
|---|---|---|
| id | bigserial | PK |
| collection_no | varchar(40) | unique |
| chain_id | bigint | required |
| contract_address | varchar(42) | lowercase |
| treasury_address | varchar(42) | lowercase |
| observed_contract_balance_wei | numeric(78,0) | required |
| threshold_wei | numeric(78,0) | required |
| retained_balance_wei | numeric(78,0) | required |
| proposed_amount_wei | numeric(78,0) | required |
| actual_amount_wei | numeric(78,0) | nullable |
| status | varchar(32) | collection status |
| contract_write_transaction_id | bigint | nullable FK |
| created_by_system | boolean | default true |
| executed_by | bigint | nullable FK admins |
| cancelled_by | bigint | nullable FK admins |
| failure_reason | text | nullable |
| ready_at | timestamptz | required |
| submitted_at | timestamptz | nullable |
| confirmed_at | timestamptz | nullable |
| failed_at | timestamptz | nullable |
| cancelled_at | timestamptz | nullable |
| reorged_at | timestamptz | nullable |
| created_at | timestamptz | required |
| updated_at | timestamptz | required |

Rules:

- proposed amount must be greater than zero;
- only one active record in `READY` or `SUBMITTED`;
- amount is recalculated before execution;
- if current balance no longer supports the amount, execution must be rejected or amount regenerated explicitly.

---

## 3.12 `reconciliation_runs`

| Column | Type | Rules |
|---|---|---|
| id | bigserial | PK |
| chain_id | bigint | required |
| asset_type | varchar(16) | BNB or TOKEN |
| expected_balance_raw | numeric(78,0) | required |
| onchain_balance_raw | numeric(78,0) | required |
| difference_raw | numeric(78,0) | signed numeric |
| status | varchar(32) | reconciliation status |
| block_number | bigint | required |
| checked_at | timestamptz | required |
| error_message | text | nullable |
| created_at | timestamptz | required |

Indexes:

- `(asset_type, checked_at desc)`
- `(status, checked_at desc)`

---

## 3.13 `admin_audit_logs`

| Column | Type | Rules |
|---|---|---|
| id | bigserial | PK |
| admin_id | bigint | nullable FK admins |
| action | varchar(120) | required |
| target_type | varchar(80) | nullable |
| target_id | bigint | nullable |
| request_id | varchar(64) | nullable |
| ip_address | inet | nullable |
| user_agent | text | nullable |
| before_data | jsonb | nullable |
| after_data | jsonb | nullable |
| result | varchar(32) | SUCCESS or FAILED |
| transaction_hash | varchar(66) | nullable |
| error_message | text | nullable |
| created_at | timestamptz | required |

Logs are append-only.

---

## 3.14 `system_task_runs`

| Column | Type | Rules |
|---|---|---|
| id | bigserial | PK |
| task_name | varchar(100) | required |
| run_id | varchar(64) | unique |
| status | varchar(32) | task status |
| started_at | timestamptz | required |
| completed_at | timestamptz | nullable |
| last_processed_block | bigint | nullable |
| processed_count | bigint | default 0 |
| error_count | bigint | default 0 |
| error_message | text | nullable |
| metadata | jsonb | default `{}` |
| created_at | timestamptz | required |

Tasks:

- `purchase_event_sync`
- `purchase_confirmation`
- `reorg_check`
- `pancake_price_snapshot`
- `collection_monitor`
- `contract_transaction_receipt`
- `reconciliation`

---

## 3.15 `system_anomalies`

| Column | Type | Rules |
|---|---|---|
| id | bigserial | PK |
| anomaly_type | varchar(100) | required |
| severity | varchar(16) | BLOCKER, P0, P1, P2 |
| status | varchar(32) | OPEN, ACKNOWLEDGED, RESOLVED |
| title | varchar(255) | required |
| details | jsonb | required |
| related_type | varchar(64) | nullable |
| related_id | bigint | nullable |
| detected_at | timestamptz | required |
| resolved_at | timestamptz | nullable |
| resolved_by | bigint | nullable FK admins |
| created_at | timestamptz | required |
| updated_at | timestamptz | required |

---

## 4. Derived Dashboard Queries

Dashboard values are derived from:

- confirmed purchase orders;
- confirmed ledger entries;
- latest on-chain reads;
- latest price snapshot;
- latest task runs;
- latest reconciliation runs.

No dashboard number is manually editable.

---

## 5. Deletion Policy

- purchase orders: no hard delete;
- ledger entries: no hard delete;
- contract write transactions: no hard delete;
- treasury collections: no hard delete;
- audit logs: no hard delete;
- administrators: deactivate instead of delete after activity exists;
- price snapshots: may be retained according to archival policy, but first version keeps all.

---

## 6. Database Consistency Rules

- purchase order creation and pending event ledger preparation occur in one transaction;
- confirmation and confirmed ledger creation occur in one transaction;
- wallet aggregates update in the same transaction as purchase confirmation;
- reorganization handling is idempotent;
- collection creation uses database and Redis locks;
- blockchain write nonce allocation uses a distributed lock;
- audit logs are written for every protected API mutation;
- all address input is normalized before uniqueness checks.

---

## 3.16 `contract_event_logs`

Stores every indexed presale administrative event.

| Column | Type | Rules |
|---|---|---|
| id | bigserial | PK |
| chain_id | bigint | required |
| contract_address | varchar(42) | lowercase |
| event_name | varchar(100) | required |
| transaction_hash | varchar(66) | lowercase |
| log_index | integer | required |
| block_number | bigint | required |
| block_hash | varchar(66) | required |
| block_timestamp | timestamptz | required |
| decoded_data | jsonb | required |
| source | varchar(32) | `BACKEND_OPERATION` or `EXTERNAL_OPERATION` |
| contract_write_transaction_id | bigint | nullable FK |
| status | varchar(32) | `PENDING_CONFIRMATION`, `CONFIRMED`, `REORGED` |
| confirmed_at | timestamptz | nullable |
| reorged_at | timestamptz | nullable |
| created_at | timestamptz | required |
| updated_at | timestamptz | required |

Unique:

- `(chain_id, transaction_hash, log_index)`

Indexed events:

- `TokenPerBNBUpdated`
- `PurchaseLimitsUpdated`
- `RepeatPurchaseRuleUpdated`
- `MaxTokensSoldUpdated`
- `TreasuryAddressUpdated`
- `Paused`
- `Unpaused`
- `SaleFinalized`
- `BNBSwept`
- `UnsoldTokensWithdrawn`
- `OwnershipTransferStarted`
- `OwnershipTransferred`

An `EXTERNAL_OPERATION` creates an anomaly and triggers a full contract-state refresh.

---

## 3.17 `token_transfer_events`

Stores sale-token `Transfer` events involving the presale contract.

| Column | Type | Rules |
|---|---|---|
| id | bigserial | PK |
| chain_id | bigint | required |
| token_address | varchar(42) | lowercase |
| presale_address | varchar(42) | lowercase |
| from_address | varchar(42) | lowercase |
| to_address | varchar(42) | lowercase |
| amount_raw | numeric(78,0) | required |
| transfer_class | varchar(40) | `INVENTORY_IN`, `PURCHASE_OUT`, `UNSOLD_WITHDRAWAL_OUT`, `UNCLASSIFIED_OUT` |
| transaction_hash | varchar(66) | lowercase |
| log_index | integer | required |
| block_number | bigint | required |
| block_hash | varchar(66) | required |
| block_timestamp | timestamptz | required |
| related_purchase_order_id | bigint | nullable FK |
| related_contract_event_log_id | bigint | nullable FK |
| status | varchar(32) | `PENDING_CONFIRMATION`, `CONFIRMED`, `REORGED` |
| created_at | timestamptz | required |
| updated_at | timestamptz | required |

Unique:

- `(chain_id, transaction_hash, log_index)`

Rules:

- `to_address == presale_address` creates confirmed `TOKEN / INVENTORY_IN / IN`;
- purchase outflow must reconcile with `PurchaseCompleted`;
- withdrawal outflow must reconcile with `UnsoldTokensWithdrawn`;
- unmatched outflow creates a P0 anomaly.

---

## 7. Fixed Reorganization Transaction

When a confirmed purchase is reorganized, one database transaction must:

1. lock the purchase order;
2. mark it `REORGED`;
3. append BNB and TOKEN reversal ledgers;
4. mark associated event and token-transfer rows `REORGED`;
5. rebuild the affected wallet aggregate from remaining confirmed orders;
6. create a P0 system anomaly;
7. move the relevant sync cursors to a safe block before the reorganization.

The operation is idempotent and must not create duplicate reversals.

---

## 8. Blockchain Write Replacement Rules

- `idempotency_key` identifies the business request.
- A business request may have multiple transaction attempts.
- A replacement attempt uses the same nonce and references `replacement_of_id`.
- The old attempt becomes `REPLACED` only after the replacement hash is broadcast.
- A transaction not found in the mempool or chain after the configured timeout may become `DROPPED`.
- A confirmed attempt is never replaced.
- Collection or configuration business records reference the currently active attempt without creating a duplicate business operation.

---

## 9. Environment Write Guard

Before creating `SIGNED` status, the service must verify:

- configured chain ID equals RPC chain ID;
- key-derived address equals `chain.operator_address`;
- contract Owner equals operator address;
- mainnet write is explicitly enabled if applicable.

A failure creates a Blocker anomaly and no transaction is signed.
