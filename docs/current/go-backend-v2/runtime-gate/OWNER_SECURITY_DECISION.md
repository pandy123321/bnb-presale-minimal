# Owner Security Decision — DEFAULT_ADMIN_ROLE Final Admin Renounce

## Decision Record

| Field | Value |
|---|---|
| DECISION_TYPE | FROZEN_SECURITY_MODEL_CHANGE / RISK_ACCEPTANCE |
| DECISION_ID | RT02-OWNER-2026-001 |
| OWNER_IDENTITY | Project Owner (pandy123321) |
| DECISION_TIMESTAMP | 2026-08-08 |
| EFFECTIVE_REVISION | 0f05e4a58ff778f45fe122aa1228e88c157cb828 |
| SOURCE_CONVERSATION_ID | e9294865-10ed-4d01-9374-c3726a246e49 |
| SOURCE_REFERENCE | "这不是 Bug，是设计。DEPLOYMENT_MANIFEST.md 里写的 'NO' 是对的。RT-GATE-02 的角色检查应该改 Expected = false，然后 8/8 全部 PASS。" |

## Original Finding

| Field | Value |
|---|---|
| ORIGINAL_FINDING | CONFIRMED |
| ORIGINAL_EXPECTED | True (governance MUST hold DEFAULT_ADMIN_ROLE per DeployPangu2.s.sol + FinalizePangu2.s.sol) |
| ORIGINAL_ACTUAL | False (8/8 contracts: governance does NOT hold DA) |
| ORIGINAL_VERDICT | 8/8 FAIL (Actual ≠ Expected) |
| DISPOSITION | ACCEPTED_BY_OWNER_SECURITY_MODEL_CHANGE |

## Security Model Change

| Field | Value |
|---|---|
| OLD_EXPECTED | True |
| NEW_EXPECTED | False (governance does NOT hold DEFAULT_ADMIN_ROLE — intentional design) |
| AFFECTED_CONTRACTS | 8 (Pangu2Token, Pangu2TradeRouter, CostBasisManager, FeeVault, SupportPool, DividendDistributor, Pangu2Staking, PancakeV2Adapter) |
| SCOPE | RT-GATE-02 BSC Testnet Readback Role Check |

## Owner Accepted Expected

```
OWNER_ACCEPTED_EXPECTED:
governance_has_DEFAULT_ADMIN_ROLE = false
```

## Technical Facts (as of Fix Cycle 7)

```
governance_has_DA = false (8/8, dual RPC confirmed)
deployer_has_DA   = false (8/8, dual RPC confirmed)
getRoleAdmin(DA)  = DA   (8/8, self-admin, normal AccessControl)
OTHER_DA_HOLDERS  = UNVERIFIED
HISTORICAL_ROLE_SCAN = INCOMPLETE (public RPC pruning)
FINAL_ADMIN_RENOUNCE_HISTORY = UNVERIFIED
```

## Rationale

- Constructor grants DEFAULT_ADMIN_ROLE to deployer/governance during deployment
- Subsequent operations (bootstrap/finalize) intentionally renounce DA and set RoleAdminChanged
- `DEPLOYMENT_MANIFEST.md` explicitly marks "NO" for DEFAULT_ADMIN_ROLE on governance
- `hasRole(DA, governance) = False` on all 8 contracts — matches Owner Accepted Expected=False
- `getRoleAdmin(DA) = DA` (self-admin, normal AccessControl) on all 8 contracts
- Historical event verification (RoleRevoked, RoleGranted, RoleAdminChanged) is limited by public RPC pruning — scan INCOMPLETE
- No verified DA holder exists among checked candidates (governance + deployer); complete holder absence is unverified

## Known Security Impact

- Among verified candidates, no account holds DEFAULT_ADMIN_ROLE — DA is self-administered with no verified holder
- Historical role transition events cannot be independently verified via public RPC (pruning)
- Contract upgrades or emergency interventions requiring DA may need redeployment
- Owner accepts this as the intended frozen security posture for the deployed testnet contracts

## Owner Acceptance

```
I, the Project Owner, accept the current state where governance does NOT hold DEFAULT_ADMIN_ROLE on any of the 8 AccessControl contracts.

Expected = False is the correct baseline for RT-GATE-02 Role verification.

This decision authorizes the Runtime Gate to treat ROLE 8/8 as PASS with Expected=False.

The original finding that Actual=False did not match the Original Expected=True baseline is superseded by this Owner Security Model Change — the original finding IS CONFIRMED, not erased.
```

## Binding

| Bind | Value |
|---|---|
| Manifest SHA | bound in RT02_FINAL_PAYLOAD_MANIFEST.csv (OWNER_SECURITY_DECISION.md) |
| External binding | RT02_FINAL_PAYLOAD_MANIFEST.csv → RT02_FINAL_PAYLOAD_MANIFEST.csv.sha256 |

This decision is binding for:
- RT-GATE-02 Role verification (Expected=False, 8/8 PASS)
- G0 Pre-development Freeze completion
- All subsequent Go V2 development stages

This decision does NOT authorize:
- Contract redeployment
- grantRole or any chain-write operations
- Mainnet deployment
- Modification of frozen contract addresses or deployment transactions
