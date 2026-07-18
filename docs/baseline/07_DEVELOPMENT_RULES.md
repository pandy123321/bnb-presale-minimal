# BNB Presale Internal System
## 07 Development Rules

Version: 1.1.1-FINAL

---

## 1. Scope Control

Do not add:

- USDT;
- buyer frontend;
- wallet connection;
- buyer account;
- KYC;
- refunds;
- vesting;
- claim;
- referral;
- multiple projects;
- multiple tokens;
- multi-address distribution;
- multisig;
- complex approval;
- Pancake V3;
- automatic price update;
- automatic collection;
- proxy upgrade;
- exchange attribution;
- marketing features.

A requested change outside scope must be documented before implementation.

---

## 2. Fixed Stack

- Solidity 0.8.24
- Foundry
- OpenZeppelin 5.x
- PHP 8.4
- Laravel 13
- PostgreSQL
- Redis
- Laravel Queue
- Laravel Scheduler
- BCMath
- Vue 3
- TypeScript
- Vite
- Element Plus
- Pinia
- Vue Router
- Axios
- ECharts
- Docker Compose
- Nginx

Do not silently replace a component.

---

## 3. Asset Precision

- blockchain values are decimal integer strings;
- Solidity uses uint256;
- PostgreSQL uses `numeric(78,0)`;
- PHP uses string + BCMath;
- TypeScript uses string and BigInt-compatible utilities;
- no PHP float;
- no JavaScript number for asset calculations;
- no scientific notation;
- raw and formatted values are distinct.

---

## 4. Blockchain Source of Truth

- contract state and confirmed receipts are authoritative;
- backend records are indexed operational views;
- purchase orders come only from `PurchaseCompleted`;
- no manual purchase order creation;
- failed transaction is not a purchase order;
- all event records include chain ID, block number, block hash, transaction hash, and log index;
- all blockchain writes include nonce, hash, broadcast and receipt states.

---

## 5. Idempotency

- event uniqueness: chain ID + transaction hash + log index;
- write request idempotency key used where practical;
- collection monitor prevents duplicate active collection;
- nonce allocation uses distributed lock;
- job retries must be safe;
- synchronization restart must not duplicate records;
- ledger entries have deterministic uniqueness.

---

## 6. Reorganization Handling

- store block hash;
- retain pending state until required confirmations;
- verify block/event existence before finalization;
- represent reorganized orders explicitly;
- a confirmed purchase reorg must append one BNB and one TOKEN reversal;
- rebuild affected wallet statistics from remaining confirmed orders;
- never silently delete financial history;
- record a P0 anomaly when reorganization affects confirmed data;
- rewind the affected event cursors to a safe prior block.

---

## 7. Contract Security

- no `tx.origin`;
- no upgrade proxy;
- no delegatecall;
- immutable sale token;
- owner-only mutation;
- single Treasury destination for BNB sweep;
- `SafeERC20`;
- `Math.mulDiv`;
- `Ownable2Step`;
- ownership renunciation disabled;
- `ReentrancyGuard`;
- `Pausable`;
- Checks-Effects-Interactions;
- explicit cap and inventory check;
- contract starts paused;
- finalization is irreversible;
- unsold-token withdrawal requires finalization;
- custom errors preferred;
- all functions and events documented;
- no real key in scripts.

---

## 8. Backend Security

- Sanctum authentication;
- password hashing;
- role middleware;
- super-admin-only blockchain writes;
- normal admin read-only;
- input validation;
- request IDs;
- structured errors;
- rate limits for authentication and write endpoints;
- audit all mutations;
- redact secrets;
- never persist private key;
- environment-loaded test key only;
- transaction calldata may be logged; private key and signed raw transaction may not;
- every blockchain write requires an idempotency key;
- chain/operator/owner/mainnet preflight is mandatory;
- business operation and transaction attempt are separate records;
- dropped and replaced transactions do not duplicate business actions.

---

## 9. Frontend Rules

- TypeScript strict mode;
- API types defined;
- all asset amounts remain strings;
- permission UI mirrors backend but does not replace it;
- do not show success before confirmation;
- show submitted/confirming/confirmed/failed/reorged;
- raw value available in detail;
- addresses and hashes copyable;
- explorer link configurable;
- every page has loading, empty, and error states.

---

## 10. Database Rules

- migrations for every schema change;
- no manual production schema edits;
- financial rows are append-only;
- no hard delete for orders, ledgers, transactions, collections, audit logs;
- lowercase addresses and hashes;
- transactions wrap aggregate and ledger updates;
- constraints and unique indexes enforce invariants;
- database and Redis locks are used for critical concurrency.

---

## 11. Testing Rules

Every implementation task includes tests.

Contract:

- unit;
- fuzz;
- boundary;
- permission;
- reentrancy.

Backend:

- unit;
- feature;
- database;
- queue/job;
- RPC mock;
- idempotency;
- authorization.

Frontend:

- type check;
- unit where useful;
- build;
- route and permission behavior.

Integration:

- complete Anvil flow;
- restart and duplicate prevention;
- collection;
- reconciliation;
- reorganization simulation.

Do not claim a test passed unless executed.

---

## 12. Phase Gate

For each phase:

1. generate;
2. install dependencies;
3. compile/build;
4. run tests;
5. static check;
6. compare against specs;
7. classify findings;
8. fix Blocker, P0, P1;
9. rerun;
10. publish phase report.

Do not start the next phase before the current phase passes.

---

## 13. Severity

### Blocker

- cannot compile/build/run;
- core purchase cannot complete;
- direct asset loss.

### P0

- unauthorized write;
- duplicate distribution;
- duplicate collection;
- precision loss;
- nonce collision;
- private key exposure;
- ledger corruption.

### P1

- sync gaps;
- missing reorg behavior;
- incorrect business mapping;
- missing required exception handling;
- page/API mismatch.

### P2

- noncritical maintainability;
- UX;
- observability;
- documentation improvements.

---

## 14. Documentation Rules

- update baseline documents when a rule changes;
- no contradictory status names;
- no inconsistent field units;
- API and database mappings remain current;
- README includes exact commands;
- known limitations remain explicit;
- generated code contains concise comments for nonobvious logic;
- no false security or test claims.

---

## 15. Secrets

Allowed in `.env.example`:

```env
CHAIN_OPERATOR_PRIVATE_KEY=
```

Prohibited:

- real private key;
- mnemonic;
- production RPC secret;
- real admin password;
- signed raw production transaction.

Tests use generated local keys or environment placeholders.

---

## 16. Default Environment Variables

Required categories:

- application;
- database;
- Redis;
- chain ID;
- primary and backup RPC;
- confirmations;
- deployment block;
- presale address;
- sale token address;
- sale token decimals;
- WBNB address;
- Pancake V2 pair;
- BscScan URL;
- collection threshold;
- retained balance;
- operator public address;
- operator private key placeholder.

---

## 17. Code Review Checklist

Before accepting a change:

- in scope;
- correct units;
- correct authorization;
- idempotent;
- reorg-safe where applicable;
- no float;
- no secret;
- audit trail exists;
- tests exist;
- docs updated;
- no success claimed before receipt confirmation;
- no hidden automatic asset action.

---

## 18. Fixed Ownership Model

- the key-derived `CHAIN_OPERATOR_ADDRESS` must equal the configured operator address;
- `BNBPresale.owner()` must equal the operator address;
- Treasury is independent from Owner;
- the backend exposes no ownership transfer or renunciation endpoint in Phase 1;
- contract ownership renunciation is disabled;
- any mismatch disables all writes and creates a Blocker anomaly.

---

## 19. Required Event Streams

Three cursors are mandatory:

- `PURCHASE_EVENTS`
- `PRESALE_ADMIN_EVENTS`
- `SALE_TOKEN_TRANSFERS`

Do not infer inventory-in from a manually entered balance. It must derive from confirmed token `Transfer` evidence.

Administrative events without a matching application transaction are `EXTERNAL_OPERATION`.

---

## 20. Transaction Attempt Rules

- one idempotency key identifies one business operation;
- one business operation may have multiple transaction attempts;
- replacement attempts reuse the nonce and reference the replaced attempt;
- only an eligible unconfirmed transaction may be replaced;
- status set includes `DROPPED` and `REPLACED`;
- a confirmed attempt terminates the replacement chain;
- signed raw transactions are not persisted by default.

---

## 21. Mainnet Safety

Required environment variables:

```env
EXPECTED_CHAIN_ID=
CHAIN_OPERATOR_ADDRESS=
ALLOW_MAINNET_WRITES=false
```

The write service refuses to sign when:

- RPC chain ID differs;
- loaded key address differs;
- contract Owner differs;
- mainnet write is not explicitly enabled.

---

## 22. PHP Signing Gate

Before Laravel blockchain-write implementation, execute the acceptance spike defined in `06_ACCEPTANCE_CRITERIA.md`.

Do not select a PHP signing package solely from documentation. It must pass the PHP 8.4 Anvil test in the actual environment.

---

## 23. Fixed Matrices

The following are normative:

- `08_TRACEABILITY_MATRIX.md`
- `09_ROLE_PERMISSION_MATRIX.md`
- `10_STATE_MACHINES.md`
- `11_AMOUNT_PRECISION_MATRIX.md`

Implementation and review must fail when code, migration, API, page, or tests conflict with these matrices.
