# BNB Presale Internal System
## 08 Contract-to-Test Traceability Matrix

Version: 1.1.1-FINAL  
Status: Normative

| Contract method/read | Authoritative event/evidence | Database | API | Admin page | Required tests |
|---|---|---|---|---|---|
| constructor | deployment receipt, `OwnershipTransferred`, `Paused` | system config, contract events | deployment script only; `/contract/state` read | Presale Config identity | zero addresses, zero price/cap, invalid limits, starts paused, immutable token |
| `receive()` | `PurchaseCompleted` + token `Transfer` | purchase_orders, token_transfer_events, ledgers, wallets | no buyer API; read through orders | Orders, Wallets, Dashboard | direct transfer, exact amount, limits, cap, inventory, event |
| `buy()` | `PurchaseCompleted` + token `Transfer` | same as receive | no buyer API | same | explicit buy and shared internal logic |
| `setTokenPerBNB()` | `TokenPerBNBUpdated` | contract_event_logs, contract_write_transactions, price snapshot link | `POST /contract/price` | Presale Config, Pancake Price | owner, non-owner, zero, idempotency, confirmation |
| `setPurchaseLimits()` | `PurchaseLimitsUpdated` | contract_event_logs, contract_write_transactions | `POST /contract/purchase-limits` | Presale Config | valid/invalid combinations, historical wallet behavior |
| `setAllowRepeatPurchase()` | `RepeatPurchaseRuleUpdated` | contract_event_logs, contract_write_transactions | `POST /contract/repeat-purchase` | Presale Config | enable/disable and repeated purchase |
| `setMaxTokensSold()` | `MaxTokensSoldUpdated` | contract_event_logs, contract_write_transactions | `POST /contract/max-token-sale` | Presale Config | zero, below sold, exact sold, increase |
| `setTreasuryAddress()` | `TreasuryAddressUpdated` | contract_event_logs, contract_write_transactions | `POST /contract/treasury` | Presale Config, Treasury | zero, owner, event, confirmed-state handling |
| `pause()` | `Paused` | contract_event_logs, contract_write_transactions | `POST /contract/pause` | Presale Config | owner/non-owner, purchase blocked |
| `unpause()` | `Unpaused` | contract_event_logs, contract_write_transactions | `POST /contract/unpause` | Presale Config | before finalization succeeds; after finalization reverts |
| `finalizeSale()` | `SaleFinalized` | contract_event_logs, contract_write_transactions | `POST /contract/finalize` | Presale Config | paused-only, irreversible, duplicate finalize |
| `sweepBNB()` | `BNBSwept` + receipt balance movement | contract_event_logs, treasury_collections, contract_write_transactions, ledgers | `POST /treasury/collections/{id}/execute` | Treasury | only owner, only Treasury, amount checks, reentrancy, replacement |
| `withdrawUnsoldTokens()` | `UnsoldTokensWithdrawn` + token `Transfer` | contract_event_logs, token_transfer_events, contract_write_transactions, ledgers | `POST /contract/withdraw-unsold-token` | Presale Config, Ledgers | finalized-only, amount/address, reconciliation |
| `transferOwnership()` inherited | `OwnershipTransferStarted` | contract_event_logs | no Phase-1 API | System Status read-only | Ownable2Step behavior |
| `acceptOwnership()` inherited | `OwnershipTransferred` | contract_event_logs | no Phase-1 API | System Status read-only | pending owner acceptance |
| `renounceOwnership()` overridden | revert evidence only | no successful event | no API | no control | always reverts |
| public getters | `eth_call` | optional state cache/task evidence | `GET /contract/state` | Dashboard, Presale Config | decoding, string precision, owner/operator preflight |
| sale token `Transfer(to=presale)` | token event | token_transfer_events, inventory ledger | system/token-transfers read | Ledgers, System Status | inventory-in indexing and idempotency |
| sale token `Transfer(from=presale)` | token event + purchase/withdraw event | token_transfer_events, ledgers, anomaly if unmatched | system/token-transfers read | Orders/Ledgers/System | purchase/withdraw matching and unmatched outflow |
