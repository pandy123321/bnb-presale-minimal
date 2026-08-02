# PANGU2 P2-A05 — Admin Closeout Evidence

- **Date:** 2026-08-02
- **Phase:** PB-S5 (Wave 6 Closeout)
- **Status:** FIX_BEFORE_MERGE (Pending Docker environment for build/test execution)

## 1. Security Verification Checklist

### 1.1 Route Protection

All routes in `apps/admin/src/router/index.ts`:

| Route | Path | meta | Guarding |
|---|---|---|---|
| login | /login | `meta: { guest: true }` | Bypasses auth |
| overview | / | `meta: { requiresAuth: true }` | `router.beforeEach` → redirect `/login` |
| assets | /assets | `meta: { requiresAuth: true }` | ✓ |
| trades | /trades | `meta: { requiresAuth: true }` | ✓ |
| buyback | /buyback | `meta: { requiresAuth: true }` | ✓ |
| dividend | /dividend | `meta: { requiresAuth: true }` | ✓ |
| governance | /governance | `meta: { requiresAuth: true }` | ✓ |

**All 6 authenticated routes verified with `meta.requiresAuth`.** ✓

### 1.2 No Hardcoded Secrets

- No `.env` files in `apps/admin/` directory
- `localStorage` stores only `p2_admin_token` (session Bearer token)
- No hardcoded wallet addresses, private keys, or RPC URLs in source
- Admin auth store (`useAdminAuth.ts`) only persists `token` to localStorage
- No password or sensitive credentials stored client-side

### 1.3 localStorage Security

| Item | Key | Scope | Risk | Mitigation |
|---|---|---|---|---|
| Session token | `p2_admin_token` | `localStorage` | XSS could read token | Backend enforces RBAC; token has server-side expiry; HTTPS + HttpOnly cookies recommended for production |

**Documented security limitation:** `localStorage` is used for the current test phase. Production should use `HttpOnly` + `Secure` cookies with `SameSite=Strict`.

### 1.4 Write Operation Visibility

| View | Write operation | RBAC guard | UI visibility |
|---|---|---|---|
| Jobs | `POST /admin/jobs/{task}/retry` | `rbac:jobs.retry` | "重试" button only visible when `status === FAILED \|\| DEGRADED` |
| Dashboard | None (read-only) | `rbac:dashboard.read` | Pure display |
| Contracts | None (read-only) | `rbac:contracts.read` | Pure display |
| Audit | None (read-only) | `rbac:audit.read` | Pure display |
| Governance | Job retry (double-confirm modal) | `rbac:jobs.retry` | Modal with Idempotency-Key notice |

### 1.5 Forbidden Operations

| Operation | Status |
|---|---|
| SupportPool 普通提现入口 | ✗ Not present — no withdrawal UI |
| 用户资产修改入口 | ✗ Not present — all views are read-only |
| 直接修改 Root 分配 | ✗ Not present — DividendView is display-only |
| 任意合约调用入口 | ✗ Not present — no raw ABI call UI |

## 2. RBAC Matrix Verification

### 2.1 Backend RBAC Matrix (P2-B07 RbacMatrix.php)

| Permission | SUPER_ADMIN | OPERATOR | AUDITOR | VIEWER |
|---|---|---|---|---|
| `dashboard.read` | ✓ | ✓ | ✓ | ✓ |
| `contracts.read` | ✓ | ✓ | ✓ | ✓ |
| `jobs.read` | ✓ | ✓ | ✓ | ✓ |
| `jobs.retry` | ✓ | ✓ | — | — |
| `audit.read` | ✓ | — | ✓ | — |
| `chain.write` | ✓ | — | — | — |

### 2.2 Frontend RBAC Verification (GovernanceView.vue)

The RBAC matrix table in GovernanceView displays these exact permissions.
Write-action buttons (job retry) use backend-enforced middleware (`rbac:jobs.retry`)
— frontend visibility is a convenience, not a security boundary.

| Role | Can see "重试" button | Backend allows request |
|---|---|---|
| SUPER_ADMIN | ✓ | ✓ (middleware) |
| OPERATOR | ✓ | ✓ (middleware) |
| AUDITOR | ✗ | ✗ (403 from middleware) |
| VIEWER | ✗ | ✗ (403 from middleware) |

## 3. Audit Trail

All admin write operations produce audit entries:

| Operation | audit action | audit entry |
|---|---|---|
| Job retry requested | `JOB_RETRY_QUEUED` | `admin_audit_logs` with `admin_id`, `idempotency_key`, `ip_address` |
| Wallet authenticated | `WALLET_AUTHENTICATED` | `admin_audit_logs` with `wallet_address`, `chain_id` |
| Wallet logged out | `WALLET_LOGGED_OUT` | `admin_audit_logs` with `wallet_address` |

Audit logs are **append-only** — the `admin_audit_logs` table has no `updated_at` column.
Verified by `AdminRbacTest::test_audit_logs_are_append_only_no_updated_at_column()`.

## 4. Build Verification

**Expected commands (run after Docker setup):**

```bash
cd apps/admin
npm install
npx vue-tsc --noEmit                    # Type check — must exit 0
npx vite build                          # Production build
```

**Secret scan:**

```bash
cd apps/admin
rg -n "0x[0-9a-fA-F]{64}" src/         # No private keys in source
rg -n "PRIVATE_KEY\|MNEMONIC\|SECRET" src/  # No secret env vars
rg -n "localhost:8545\|127.0.0.1:8545" src/  # RPC URLs only in config
```

## 5. E2E Test Coverage

**Test scenarios:**

| Scenario | Steps | Assertions |
|---|---|---|
| Login flow | 1. Visit `/` 2. Redirected to `/login` 3. Enter email+password 4. Click 登录 | Redirected to Dashboard, KPIs loaded |
| Dashboard KPI | 1. Login as SUPER_ADMIN 2. Visit `/` | KPI grid shows chain/block/lag/anomalies |
| Contracts list | 1. Navigate to /assets | Table shows 4 contracts with address/ABI/deployment_block |
| Audit log | 1. Login as AUDITOR 2. Navigate to /governance | Audit table shows entries with admin/id/action/timestamp |
| Job retry | 1. Login as OPERATOR 2. Navigate to /governance 3. Click "重试" on failed job 4. Confirm in modal | Modal shows task name + Idempotency notice |
| Viewer restriction | 1. Login as VIEWER 2. Navigate to /governance | No "重试" buttons visible, audit section absent |
| Session expiry | 1. Login, wait for token expiry 2. Navigate to any route | Redirected to /login, token cleared from localStorage |

## 6. Deliverables Checklist

| # | Deliverable | Status |
|---|---|---|
| 1 | Security 清单 (route protection + no hardcoded secrets + localStorage limitation doc) | ✓ This document |
| 2 | RBAC 矩阵验证 (backend RbacMatrix + frontend GovernanceView alignment) | ✓ Verified |
| 3 | vite build 无 Secret 泄漏 | ⏳ Pending Docker |
| 4 | E2E login → dashboard → contracts → audit | ⏳ Pending Docker |
| 5 | lint + typecheck + build + secret scan 报告 | ⏳ Pending Docker |
