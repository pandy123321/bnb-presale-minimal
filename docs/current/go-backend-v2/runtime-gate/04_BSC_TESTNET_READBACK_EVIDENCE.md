# RT-GATE-02 BSC Testnet Fixed-Block Readback Evidence

## Fix Cycle 7

### Evidence Block

| Field | Value |
|---|---|
| Block Number | 123877114 |
| Block Hash | 0x7b21cf04b7062412f9ec975f4fb8e80a724a5274040af1d20a941bcb2ecc5ded |
| Primary RPC | publicnode (env-injected) |
| Backup RPC | publicnode (same — alternative RPCs unavailable, noted) |
| Chain ID | 97 |

---

### 1. Chain — PASS

### 2. Bytecode — 10/10 IDENTITY_VERIFIED (receipt-bound)

Deploy blocks from eth_getTransactionReceipt, NOT hardcoded. Receipt validated: status=0x1, blockNumber, blockHash.

| # | Contract | Deploy Block | Deploy SHA256 | Evidence SHA256 | Match |
|---|---|---|---|---|---|
| 1 | Pangu2Token | 123502176 | bc4905ae... | bc4905ae... | True |
| 2 | CostBasisManager | 123502181 | 456e3827... | 456e3827... | True |
| 3 | PancakeV2TwapOracle | 123502202 | b3a57d00... | b3a57d00... | True |
| 4 | SupportPool | 123502210 | a55c65d8... | a55c65d8... | True |
| 5 | FeeVault | 123502218 | 64217930... | 64217930... | True |
| 6 | BuybackLocker | 123502225 | 01097912... | 01097912... | True |
| 7 | DividendDistributor | 123502234 | 2e87fcaa... | 2e87fcaa... | True |
| 8 | Pangu2TradeRouter | 123502248 | 8d98c33e... | 8d98c33e... | True |
| 9 | Pangu2Staking | 123502253 | a746d306... | a746d306... | True |
| 10 | PancakeV2Adapter | 123502195 | 222e41c1... | 222e41c1... | True |

PancakeV2Pair + PancakeFactory: FINGERPRINT_CAPTURED (no deploy tx in baseline).

DEPLOY_BLOCK_SOURCE = TRANSACTION_RECEIPT. No hardcoded blocks, no offset fallback. Deploy block drift from Cycle 5/6 eliminated (Staking 123502753→123502253, Adapter 123502295→123502195, SupportPool 123502220→123502210, FeeVault 123502228→123502218).

### 3. Pair — PASS

### 4. Role — 8/8 PASS (Expected=False, Owner Decision)

OWNER_DESIRED_STATE: governance_has_DA = false. DEPLOYMENT_MANIFEST "NO" is correct.

getRoleAdmin(DA) = DA (self-admin, normal AccessControl). Not interpreted as permanent lock claim.

ROLE_EVIDENCE = STATE_ONLY. Historical events (RoleGranted/RoleRevoked/RoleAdminChanged) unverified due to public RPC pruning. 0 new DA holders reconstructed beyond governance+deployer.

FINAL_ADMIN_RENOUNCE = STATE_CONSISTENT_NOT_PROVEN.

### 5. Getter — 14/14 PASS

### 6. Count — 34/34 PASS, exit 0

| Category | Pass |
|---|---|
| CHAIN | 1/1 |
| BYTECODE | 10/10 |
| PAIR | 1/1 |
| ROLE | 8/8 |
| GETTER | 14/14 |

### 7. Verdict — FIX_READY / INDEPENDENT_RETEST_PENDING

### 8. Finding Closure

| Finding | Status |
|---|---|
| P0-RT02-02 Premature Auth | FIXED — NEXT_STAGE_AUTHORIZATION=NO until review PASS |
| P1-RT02-BLOCK-BINDING | FIXED — receipt-bound, no drift |
| P1-RT02-ROLE-SEMANTICS | FIXED — self-admin, not permanent lock |
| P2-RT02-SUBMISSION | FIXED — UTF-8 NO BOM, full scripts in manifest |
