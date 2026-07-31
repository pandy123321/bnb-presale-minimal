# BNB Presale Internal System
## 10 State Machines

Version: 1.1.1-FINAL  
Status: Normative

## 1. Sale Lifecycle

```text
DEPLOY
  |
  v
PAUSED <------ ACTIVE
  |              |
  | unpause      | pause
  +------------->+
  |
  | finalizeSale (paused only)
  v
FINALIZED
```

Rules:

- `FINALIZED` is terminal.
- `unpause()` from `FINALIZED` is forbidden.
- unsold-token withdrawal is allowed only in `FINALIZED`.

## 2. Purchase Order State

```text
EVENT_FOUND
    |
    v
PENDING_CONFIRMATION ---- reorg before finality ----> REORGED
    |
    | required confirmations and event still exists
    v
CONFIRMED ---- confirmed-chain reorg ----> REORGED
```

On pending reorg:

- no confirmed ledgers;
- no confirmed wallet aggregate effect.

On confirmed reorg:

- append exactly one BNB reversal;
- append exactly one TOKEN reversal;
- rebuild wallet aggregate;
- create P0 anomaly;
- rewind and rescan.

`REORGED` is terminal for that event identity. If a logically similar purchase appears under a new transaction/log identity, it is a new order.

## 3. Treasury Collection State

```text
ELIGIBLE -> READY
READY -> CANCELLED
READY -> SUBMITTED          (broadcast succeeds)
SUBMITTED -> CONFIRMED      (successful canonical receipt)
SUBMITTED -> FAILED         (receipt failure or dropped without replacement)
SUBMITTED -> REORGED        (submitted transaction/event is reorganized)
CONFIRMED -> REORGED        (later canonical-chain reorganization)
```

Rules:

- only one `READY` or `SUBMITTED` collection exists at once;
- execution recalculates the amount;
- a replacement transaction remains within the same `SUBMITTED` business collection;
- `CANCELLED`, `FAILED`, `CONFIRMED`, and `REORGED` are terminal for that collection record.

## 4. Blockchain Transaction Attempt State

```text
CREATED -> SIGNED
SIGNED -> BROADCAST
BROADCAST -> CONFIRMED      (successful canonical receipt)
BROADCAST -> FAILED         (receipt status 0)
BROADCAST -> DROPPED        (not found after configured timeout)
BROADCAST -> REPLACED       (same-nonce replacement broadcast)
CONFIRMED -> REORGED        (canonical-chain reorganization)
```

Rules:

- a `REPLACED` attempt links to the new attempt;
- replacement does not create another business operation;
- a `DROPPED` attempt may be followed by a new attempt with the same business idempotency key;
- `CONFIRMED`, `FAILED`, `REPLACED`, and `REORGED` are terminal for that transaction attempt;
- the business operation may remain pending while attempts are replaced.

## 5. Contract Event State

```text
PENDING_CONFIRMATION -> CONFIRMED -> REORGED
          |
          +----------------------> REORGED
```

Source classification is independent:

- `BACKEND_OPERATION`
- `EXTERNAL_OPERATION`
