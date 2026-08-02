# PANGU2 P2-B07 — Admin RBAC + Job + Audit API Verification

- **Date:** 2026-08-02
- **Phase:** PB-S0 (Backend Admin)
- **Status:** COMPLETE (Code delivered, tests pending Docker environment)

## 1. Route Verification

All admin API routes registered in `backend/routes/web.php`:

| Method | Path | Controller | Middleware |
|---|---|---|---|
| GET | `/admin-api/v1/projects/pangu2/dashboard` | AdminDashboardController@dashboard | `auth:web` + `rbac:dashboard.read` |
| GET | `/admin-api/v1/projects/pangu2/contracts` | AdminDashboardController@contracts | `auth:web` + `rbac:dashboard.read` |
| GET | `/admin-api/v1/projects/pangu2/jobs` | AdminJobsController@index | `auth:web` + `rbac:dashboard.read` |
| POST | `/admin-api/v1/projects/pangu2/jobs/{taskName}/retry` | AdminJobsController@retry | `auth:web` + `rbac:dashboard.read` |
| GET | `/admin-api/v1/projects/pangu2/audit-logs` | AdminAuditController@index | `auth:web` + `rbac:dashboard.read` |
| GET | `/admin-api/v1/projects/pangu2/audit-logs/{id}` | AdminAuditController@show | `auth:web` + `rbac:dashboard.read` |

**Middleware chain:** `auth:web` → `rbac:<permission>` → `AdminRbacMiddleware@handle`

`AdminRbacMiddleware` checks:
1. `$request->user()` exists → else 401
2. `$admin->is_active` → else 403
3. `RbacMatrix::can($role, $permission)` → else 403

**rbac middleware registered in `bootstrap/app.php`:**
```php
$middleware->alias(['rbac' => AdminRbacMiddleware::class]);
```

## 2. RBAC Permission Matrix

| Permission | SUPER_ADMIN | OPERATOR | AUDITOR | VIEWER |
|---|---|---|---|---|
| `dashboard.read` | ✓ | ✓ | ✓ | ✓ |
| `contracts.read` | ✓ | ✓ | ✓ | ✓ |
| `jobs.read` | ✓ | ✓ | ✓ | ✓ |
| `jobs.retry` | ✓ | ✓ | — | — |
| `audit.read` | ✓ | — | ✓ | — |
| `chain.write` | ✓ | — | — | — |

## 3. Database Migrations

| Migration | Table/Change |
|---|---|
| `2026_08_02_030000_...` | `admin_audit_logs` + `idempotency_key` column |
| | `job_retry_tokens` table: UNIQUE(task_name, idempotency_key) |
| (Pre-existing) | `admin_audit_logs` — append-only, no `updated_at` |

## 4. Test Coverage (16 tests)

| Test | Category | Asserts |
|---|---|---|
| SUPER_ADMIN has all permissions | RBAC static | 4 asserts |
| OPERATOR can retry but not audit | RBAC static | 3 asserts |
| AUDITOR can audit but not retry | RBAC static | 2 asserts |
| VIEWER read-only | RBAC static | 5 asserts |
| Invalid role has no permissions | RBAC static | 1 assert |
| All roles access dashboard | API integration | 4 iterations |
| Unauthenticated blocked | API integration | 401 |
| Deactivated admin blocked | API integration | 403 |
| VIEWER cannot retry | RBAC + API | 403 |
| OPERATOR can retry | RBAC + API | 200 |
| Idempotent retry | API idempotency | First→false, Second→true |
| Missing Idempotency-Key | API validation | 422 |
| VIEWER cannot access audit | RBAC + API | 403 |
| AUDITOR can access audit | RBAC + API | 200 |
| Audit append-only | Schema check | No `updated_at` column |
| Contracts endpoint | API | 4 contracts |

## 5. Pending Docker

The following require Docker + PHP 8.4 + PostgreSQL:

```bash
cd backend
php artisan test --filter=AdminRbacTest   # 16 tests
php artisan migrate:refresh --seed
```
