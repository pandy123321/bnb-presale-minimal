# BNB Presale Internal System
## 09 Role and Operation Permission Matrix

Version: 1.1.1-FINAL  
Status: Normative

Legend: `A` allowed, `R` read-only, `D` denied, `N/A` not an application actor.

| Operation | Buyer | ADMIN | SUPER_ADMIN | Backend scheduler/worker | Chain Operator key | Contract Owner | Treasury |
|---|---:|---:|---:|---:|---:|---:|---:|
| Send BNB to `receive()` | A | A as wallet | A as wallet | D | D | A as wallet | A as wallet |
| Call `buy()` | A | A as wallet | A as wallet | D | D | A as wallet | A as wallet |
| View dashboard/orders/wallets | N/A | R | R | N/A | N/A | N/A | N/A |
| Export read-only data | N/A | A | A | N/A | N/A | N/A | N/A |
| Update price/limits/rules/cap | N/A | D | A authorizes | D without approved request | signs | executes as Owner | N/A |
| Pause/unpause/finalize | N/A | D | A authorizes | D without approved request | signs | executes as Owner | N/A |
| Update Treasury address | N/A | D | A authorizes | D without approved request | signs | executes as Owner | receives no control |
| Create `READY` collection | N/A | D | A manual check | A automated detection only | no signing at creation | N/A | N/A |
| Execute collection | N/A | D | A authorizes | processes approved request | signs | executes as Owner | receives BNB |
| Withdraw unsold TOKEN | N/A | D | A authorizes after finalization | D without approved request | signs | executes as Owner | not automatically recipient |
| Configure Pancake Pair/coefficient | N/A | D | A | D | N/A | N/A | N/A |
| Automatically update price | D | D | D | D | D | D | D |
| Automatically sweep BNB | D | D | D | D | D | D | D |
| Resolve anomaly/create adjustment | N/A | D | A with reason/evidence | D | N/A | N/A | N/A |
| Ownership transfer through backend | D | D | D | D | D | may occur externally only | N/A |
| Renounce ownership | D | D | D | D | D | contract reverts | N/A |
| Access private key | D | D | D | process memory only | key identity | N/A | N/A |

## Fixed Identity Rules

- `CHAIN_OPERATOR_ADDRESS` is derived from the loaded private key.
- Contract Owner must equal `CHAIN_OPERATOR_ADDRESS`.
- A signed-in `SUPER_ADMIN` authorizes a write but is not the signer.
- Treasury is not granted contract-control permissions.
- Backend workers may execute only persisted, authorized business requests.
