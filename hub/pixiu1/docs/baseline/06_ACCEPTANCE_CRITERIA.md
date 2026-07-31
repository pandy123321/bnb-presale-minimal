# BNB Presale Internal System
## 06 Acceptance Criteria

Version: 1.1.1-FINAL

---

## 1. Acceptance Levels

- **Blocker**: project cannot run, compile, build, or complete the core purchase flow.
- **P0**: direct asset-loss, unauthorized write, duplicate purchase, duplicate collection, precision, ledger, nonce, or private-key risk.
- **P1**: important business or synchronization failure, incomplete exception handling, incorrect page/API mapping.
- **P2**: maintainability, observability, UX, or noncritical quality defect.

A phase passes only when:

- no Blocker;
- no P0;
- all required P1 items for the phase are fixed;
- tests relevant to the phase pass;
- unresolved P2 items are documented.

---

## 2. Phase 1 Documentation Acceptance

- seven required documents exist;
- business scope is identical across documents;
- statuses are identical;
- units and precision are identical;
- role permissions are identical;
- contract functions map to APIs;
- APIs map to admin pages;
- database supports all APIs;
- excluded features do not appear as implementation requirements;
- automatic price update does not exist;
- automatic collection does not exist;
- purchase orders originate only from chain events;
- failed transactions are not modeled as purchase orders;
- private keys are not stored in source or database;
- traceability, role-permission, state-machine, and amount-precision matrices exist and contain no open Blocker/P0 conflicts.

---

## 3. Smart Contract Acceptance

### 3.1 Deployment

- contract compiles with Solidity 0.8.24;
- OpenZeppelin 5.x imports resolve;
- zero sale token rejected;
- zero Treasury rejected;
- zero owner rejected;
- zero price rejected;
- zero maximum token sale rejected;
- maximum below minimum is rejected; wallet maximum below a nonzero minimum is rejected;
- contract starts paused;
- sale token is immutable;
- contract uses `Ownable2Step`;
- ownership renunciation is disabled;
- calculation uses `Math.mulDiv`;
- sale lifecycle starts `PAUSED` and supports irreversible `FINALIZED`.

### 3.2 Normal Purchase

Given:

- contract unpaused;
- sufficient token inventory;
- price `1 BNB = 100,000 PST`;
- buyer sends `1 BNB`;

Then:

- transaction succeeds;
- buyer receives exactly `100,000 PST` in raw units;
- contract BNB balance increases by `1 BNB`;
- total raised increases;
- total sold increases;
- buyer totals increase;
- purchase count increases;
- exactly one `PurchaseCompleted` event is emitted.

### 3.3 Entry Points

- direct native BNB transfer invokes purchase;
- explicit `buy()` invokes purchase;
- both produce the same state changes;
- both use the same internal purchase logic.

### 3.4 Reversion

The whole transaction reverts when:

- paused;
- zero payment;
- zero price state is impossible through setter but covered defensively;
- below minimum;
- above maximum;
- repeat purchase not allowed;
- wallet cumulative maximum exceeded;
- output rounds to zero;
- maximum token sale exceeded;
- token inventory insufficient;
- token transfer fails.

No successful purchase event is emitted on revert.

### 3.5 Administration

- owner updates price;
- non-owner cannot;
- owner updates limits;
- invalid limit combination rejected;
- owner updates repeat rule;
- owner updates maximum token sale;
- maximum cannot be below sold amount;
- owner updates Treasury;
- zero Treasury rejected;
- owner pauses and unpauses before finalization;
- owner finalizes only while paused;
- finalization is irreversible;
- unpause after finalization reverts;
- non-owner cannot pause;
- renounce ownership always reverts;
- two-step ownership transfer behavior is tested.

### 3.6 Collection

- owner collects positive amount to Treasury only;
- non-owner cannot collect;
- amount above balance rejected;
- zero amount rejected;
- Treasury receives the expected BNB;
- event contains Treasury and amount;
- reentrancy attempt fails.

### 3.7 Unsold Token Withdrawal

- only owner;
- only after finalization;
- temporary pause without finalization is insufficient;
- recipient nonzero;
- positive amount;
- not above balance;
- event emitted.

### 3.8 Fuzz and Boundary

- supported input domain does not overflow;
- token calculation uses `Math.mulDiv` and rounds down consistently;
- large bounded operands do not fail because of avoidable intermediate multiplication overflow;
- exact min/max/cap boundaries behave correctly;
- cumulative wallet boundary behaves correctly.

---

## 4. Laravel Foundation Acceptance

- Laravel 13 application boots under PHP 8.4;
- PostgreSQL migrations run;
- Redis connection works;
- seed creates one super admin without hardcoded production password;
- login, logout, and current-user endpoints work;
- inactive admin cannot login;
- role middleware blocks normal-admin writes;
- unified response format is used;
- validation errors are structured;
- audit log created for protected mutations;
- no private key stored in database;
- tests pass.

---

## 5. Blockchain Infrastructure Acceptance

- RPC chain ID is validated;
- primary and backup RPC behavior is defined;
- ABI calls encode/decode correctly;
- on-chain reads return string integers;
- nonce allocation is protected by distributed lock;
- gas is estimated;
- transaction is signed locally from environment-loaded test key;
- private key never appears in logs;
- transaction hash stored;
- receipt status tracked;
- failed broadcast captured;
- confirmed transaction updates related state;
- reorganization status can be represented;
- every blockchain write uses an idempotency key;
- duplicate idempotent request does not create duplicate business operations;
- operator address is derived from the loaded key and matches configuration;
- contract Owner matches operator before signing;
- chain ID mismatch blocks signing;
- mainnet write is blocked unless explicitly enabled;
- `DROPPED` and `REPLACED` attempts are tracked without duplicating business records.

---

## 6. Event Sync Acceptance

- scanner starts from deployment block or saved cursor;
- scanner processes batches;
- event uniqueness uses chain ID, transaction hash, log index;
- restart resumes from cursor;
- duplicate scan does not duplicate order;
- new order is pending confirmation;
- confirmation count updates;
- confirmed order creates wallet aggregate and two ledger entries;
- pending reorg creates no confirmed ledgers;
- confirmed reorg appends exactly one BNB reversal and one TOKEN reversal;
- confirmed reorg rebuilds the affected wallet aggregate from remaining confirmed orders;
- confirmed reorg creates a P0 anomaly and rewinds the cursor safely;
- order becomes `REORGED`;
- scanner records block hash;
- RPC failures do not advance cursor incorrectly;
- task status and error are recorded;
- all presale administrative events are indexed;
- sale-token transfers involving the presale are indexed;
- inventory-in ledger derives from confirmed token `Transfer`;
- purchase and withdrawal outflows reconcile with token `Transfer`;
- unmatched administrative or token outflow is classified and creates an anomaly.

---

## 7. Pancake V2 Acceptance

- only manually configured pair is used;
- pair token0/token1 validated;
- pair must contain sale token and WBNB;
- reserves read as raw integers;
- decimals handled correctly;
- market token-per-BNB computed without float;
- coefficient uses integer numerator and denominator;
- exact market formula is used;
- exact integer coefficient formula is used;
- suggested price computed without float;
- zero reserve blocks calculation;
- low WBNB reserve warning works;
- configured deviation threshold requires second confirmation;
- snapshot stored;
- no automatic contract update;
- normal admin cannot confirm;
- super admin can submit selected price;
- confirmed chain state is not shown before receipt confirmation.

---

## 8. Collection and Reconciliation Acceptance

- monitor reads contract BNB balance;
- below threshold creates nothing;
- at or above threshold creates one `READY`;
- second active `READY`/`SUBMITTED` is prevented;
- proposed amount equals balance minus retained amount;
- nonpositive amount creates nothing;
- execution rereads balance;
- normal admin cannot execute;
- super admin can execute;
- record becomes `SUBMITTED` after broadcast;
- becomes `CONFIRMED` after receipt;
- ledger records Treasury out once;
- failed transaction recorded;
- reconciliation compares expected and on-chain balances;
- mismatch creates result/anomaly;
- unexplained balance difference requires reviewed `ADJUSTMENT` and never silently changes historical rows;
- reconciliation never silently changes ledger.

---

## 9. Vue Admin Acceptance

- application builds;
- login works;
- protected routes redirect unauthenticated users;
- role controls match backend policy;
- normal admin has no enabled write operations;
- dashboard loads;
- all required pages load;
- all asset values handled as strings;
- no scientific notation for large values;
- copy address/hash works;
- BscScan links use configuration;
- empty/loading/error states exist;
- blockchain write progress exists;
- pending proposal and confirmed state are distinct;
- API 401/403/409/422/503 handled;
- no buyer frontend exists.

---

## 10. Docker Acceptance

- Docker Compose starts required services;
- PostgreSQL health check passes;
- Redis health check passes;
- Laravel API health check passes;
- queue worker runs;
- scheduler runs;
- Vue served through Nginx;
- Anvil local chain starts for development;
- initialization scripts are documented;
- no real secret committed;
- `.env.example` is complete.

---

## 11. Integration Acceptance

1. Start Anvil.
2. Deploy test token.
3. Deploy presale paused.
4. Transfer inventory.
5. Unpause.
6. Buyer sends BNB.
7. Buyer receives exact token amount.
8. Backend indexes pending order.
9. Confirmation advances to confirmed.
10. Wallet statistics update once.
11. BNB and token ledgers update once.
12. Restart sync service.
13. No duplicate order or ledger appears.
14. Reach collection threshold.
15. Create one ready collection.
16. Super admin executes.
17. Treasury receives BNB.
18. Collection confirms.
19. Reconciliation matches.
20. Reorg simulation results in auditable `REORGED` handling.
21. Admin pages display correct states.

---

## 12. Security Acceptance

- no private key in repository;
- no private key in database;
- no private key in logs;
- no arbitrary destination in sweep;
- sale token immutable;
- write APIs super-admin only;
- normal admin read-only;
- all amount operations integer-safe;
- no automatic price update;
- no automatic collection;
- no hard delete of financial records;
- no untracked blockchain write;
- no duplicate nonce under concurrent requests;
- no duplicate event ingestion.

---

## 13. Final Delivery Acceptance

Final package includes:

- full source;
- tests;
- migrations;
- Docker;
- environment example;
- local startup guide;
- BSC Testnet guide;
- deployment and verification scripts;
- initial admin creation guide;
- API documentation;
- database documentation;
- security notes;
- known limitations;
- test report;
- audit report;
- downloadable archive.

Any unexecuted test must be explicitly identified.

---

## 14. Mandatory PHP Signing Feasibility Gate

Before implementing the production Laravel blockchain-write service, a PHP 8.4 feasibility spike must:

1. connect to Anvil;
2. validate chain ID;
3. read nonce;
4. ABI-encode `setTokenPerBNB`;
5. construct and locally sign a transaction;
6. broadcast with `eth_sendRawTransaction`;
7. obtain a successful receipt;
8. verify the contract value changed;
9. verify the selected legacy or EIP-1559 transaction type works on the target client;
10. prove the private key and signed raw transaction are not written to application logs.

Failure of this gate is a Blocker for the Laravel blockchain-write phase, not for the Solidity phase.

---

## 15. Traceability Matrix Acceptance

For every contract method:

- authoritative event is identified;
- database evidence table is identified;
- API endpoint is identified where applicable;
- admin page action or read display is identified;
- tests are identified.

No asset-changing method may lack event, persistence, API authorization, page confirmation, or test coverage.

---

## 16. State Machine Acceptance

Order, collection, and blockchain transaction transitions must match `10_STATE_MACHINES.md`.

Any undocumented transition is rejected.

Terminal states cannot transition back to active states except through a new business record or replacement transaction attempt explicitly defined in the matrix.
