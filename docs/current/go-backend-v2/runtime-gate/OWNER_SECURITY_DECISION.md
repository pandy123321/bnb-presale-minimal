# Owner Security Decision — DEFAULT_ADMIN_ROLE Final Admin Renounce

## Decision Record

| Field | Value |
|---|---|
| DECISION_TYPE | FROZEN_SECURITY_MODEL_CHANGE / RISK_ACCEPTANCE |
| DECISION_ID | RT02-OWNER-2026-001 |
| OWNER_IDENTITY | Project Owner (pandy123321) |
| DECISION_TIMESTAMP | 2026-08-08 |
| EFFECTIVE_REVISION | RT-GATE-02 Fix Cycle 6+ |
| SOURCE_CONVERSATION_ID | e9294865-10ed-4d01-9374-c3726a246e49 |
| SOURCE_REFERENCE | "这不是 Bug，是设计。DEPLOYMENT_MANIFEST.md 里写的 'NO' 是对的。RT-GATE-02 的角色检查应该改 Expected = false，然后 8/8 全部 PASS。" |

## Security Model Change

| Field | Value |
|---|---|
| OLD_EXPECTED | True (governance MUST hold DEFAULT_ADMIN_ROLE per DeployPangu2.s.sol + FinalizePangu2.s.sol) |
| NEW_EXPECTED | False (governance does NOT hold DEFAULT_ADMIN_ROLE — intentional design) |
| AFFECTED_CONTRACTS | 8 (Pangu2Token, Pangu2TradeRouter, CostBasisManager, FeeVault, SupportPool, DividendDistributor, Pangu2Staking, PancakeV2Adapter) |
| SCOPE | RT-GATE-02 BSC Testnet Readback Role Check |

## Rationale

Owner Decision: FINAL_ADMIN_RENOUNCE is intentional design, not a defect.

- Constructor grants DEFAULT_ADMIN_ROLE to deployer/governance during deployment
- Subsequent operations (bootstrap/finalize) intentionally renounce DA and set RoleAdminChanged to lock the role
- `DEPLOYMENT_MANIFEST.md` explicitly marks "NO" for DEFAULT_ADMIN_ROLE on governance — this is the frozen security model
- `getRoleAdmin(DA) = DA` (self-admin, normal AccessControl) on all 8 contracts
- `hasRole(DA, governance) = False` on all 8 contracts — matches Expected=False
- No known other DA holders exist (governance + deployer = both false, no reconstructed candidates from deploy tx receipts)
- Historical event verification (RoleRevoked) is limited by public RPC pruning

## Known Security Impact

- No account can grant or revoke DEFAULT_ADMIN_ROLE (self-administered, no holder)
- Role hierarchy is frozen — no new admin roles can be created, no existing roles can be modified
- Contract upgrades or emergency interventions requiring DA would need redeployment
- This is the intended frozen security posture for the deployed testnet contracts

## Owner Acceptance

```
I, the Project Owner, accept the current state where governance does NOT hold DEFAULT_ADMIN_ROLE on any of the 8 AccessControl contracts.

Expected = False is the correct baseline for RT-GATE-02 Role verification.

This decision authorizes the Runtime Gate to treat ROLE 8/8 as PASS with Expected=False.

The original finding that Actual=False did not match the Expected=True baseline is superseded by this Security Model Change.
```

## Binding

This decision is binding for:
- RT-GATE-02 Role verification (Expected=False, 8/8 PASS)
- G0 Pre-development Freeze completion
- All subsequent Go V2 development stages

This decision does NOT authorize:
- Contract redeployment
- grantRole or any chain-write operations
- Mainnet deployment
- Modification of frozen contract addresses or deployment transactions
