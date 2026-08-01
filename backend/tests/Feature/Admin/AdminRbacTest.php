<?php

declare(strict_types=1);

namespace Tests\Feature\Admin;

use App\Models\Admin;
use App\Modules\Core\RBAC\RbacMatrix;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class AdminRbacTest extends TestCase
{
    private function createAdmin(string $role): Admin
    {
        return Admin::create([
            'name'      => ucfirst(strtolower($role)),
            'email'     => strtolower($role) . '@pangu2.test',
            'password'  => bcrypt('test'),
            'role'      => $role,
            'is_active' => true,
        ]);
    }

    // ── RBAC Matrix ───────────────────────────

    public function test_super_admin_has_all_permissions(): void
    {
        $perms = RbacMatrix::permissionsFor(RbacMatrix::ROLE_SUPER_ADMIN);
        $this->assertContains('dashboard.read', $perms);
        $this->assertContains('jobs.retry', $perms);
        $this->assertContains('audit.read', $perms);
        $this->assertContains('chain.write', $perms);
    }

    public function test_operator_can_retry_jobs_but_not_read_audit(): void
    {
        $perms = RbacMatrix::permissionsFor(RbacMatrix::ROLE_OPERATOR);
        $this->assertContains('jobs.retry', $perms);
        $this->assertNotContains('audit.read', $perms);
        $this->assertNotContains('chain.write', $perms);
    }

    public function test_auditor_can_read_audit_but_not_retry_jobs(): void
    {
        $perms = RbacMatrix::permissionsFor(RbacMatrix::ROLE_AUDITOR);
        $this->assertContains('audit.read', $perms);
        $this->assertNotContains('jobs.retry', $perms);
    }

    public function test_viewer_is_read_only(): void
    {
        $perms = RbacMatrix::permissionsFor(RbacMatrix::ROLE_VIEWER);
        $this->assertContains('dashboard.read', $perms);
        $this->assertNotContains('jobs.retry', $perms);
        $this->assertNotContains('audit.read', $perms);
    }

    public function test_invalid_role_has_no_permissions(): void
    {
        $this->assertFalse(RbacMatrix::can('INVALID_ROLE', 'dashboard.read'));
    }

    // ── API: Dashboard ─────────────────────────

    public function test_all_roles_can_access_dashboard(): void
    {
        foreach (RbacMatrix::ROLES as $role) {
            $admin = $this->createAdmin($role);
            $this->actingAs($admin, 'web')
                ->getJson('/admin-api/v1/projects/pangu2/dashboard')
                ->assertOk();
            $admin->delete();
        }
    }

    public function test_unauthenticated_cannot_access(): void
    {
        $this->getJson('/admin-api/v1/projects/pangu2/dashboard')
            ->assertStatus(401);
    }

    public function test_deactivated_admin_blocked(): void
    {
        $admin = $this->createAdmin(RbacMatrix::ROLE_VIEWER);
        $admin->is_active = false;
        $admin->save();

        $this->actingAs($admin, 'web')
            ->getJson('/admin-api/v1/projects/pangu2/dashboard')
            ->assertStatus(403);
        $admin->delete();
    }

    // ── API: Jobs Retry — RBAC + Idempotency ───

    public function test_viewer_cannot_retry_jobs(): void
    {
        $admin = $this->createAdmin(RbacMatrix::ROLE_VIEWER);
        $this->actingAs($admin, 'web')
            ->postJson('/admin-api/v1/projects/pangu2/jobs/test-task/retry')
            ->assertStatus(403);
        $admin->delete();
    }

    public function test_operator_can_retry_jobs(): void
    {
        $admin = $this->createAdmin(RbacMatrix::ROLE_OPERATOR);
        $this->actingAs($admin, 'web')
            ->postJson('/admin-api/v1/projects/pangu2/jobs/chain-sync/retry', [], [
                'Idempotency-Key' => 'op-' . uniqid(),
            ])
            ->assertOk();
        $admin->delete();
    }

    public function test_job_retry_idempotent(): void
    {
        $admin = $this->createAdmin(RbacMatrix::ROLE_OPERATOR);
        $key   = 'idem-' . uniqid();

        $r1 = $this->actingAs($admin, 'web')
            ->postJson('/admin-api/v1/projects/pangu2/jobs/chain-sync/retry', [], [
                'Idempotency-Key' => $key,
            ]);
        $r1->assertOk();
        $this->assertFalse($r1->json('data.idempotent'));

        $r2 = $this->actingAs($admin, 'web')
            ->postJson('/admin-api/v1/projects/pangu2/jobs/chain-sync/retry', [], [
                'Idempotency-Key' => $key,
            ]);
        $r2->assertOk();
        $this->assertTrue($r2->json('data.idempotent'));
        $admin->delete();
    }

    public function test_job_retry_requires_idempotency_key(): void
    {
        $admin = $this->createAdmin(RbacMatrix::ROLE_OPERATOR);
        $this->actingAs($admin, 'web')
            ->postJson('/admin-api/v1/projects/pangu2/jobs/chain-sync/retry')
            ->assertStatus(422);
        $admin->delete();
    }

    // ── API: Audit Logs — RBAC ─────────────────

    public function test_viewer_cannot_access_audit(): void
    {
        $admin = $this->createAdmin(RbacMatrix::ROLE_VIEWER);
        $this->actingAs($admin, 'web')
            ->getJson('/admin-api/v1/projects/pangu2/audit-logs')
            ->assertStatus(403);
        $admin->delete();
    }

    public function test_auditor_can_access_audit(): void
    {
        $admin = $this->createAdmin(RbacMatrix::ROLE_AUDITOR);
        $this->actingAs($admin, 'web')
            ->getJson('/admin-api/v1/projects/pangu2/audit-logs')
            ->assertOk();
        $admin->delete();
    }

    // ── Audit Immutability ─────────────────────

    public function test_audit_logs_are_append_only_no_updated_at_column(): void
    {
        $this->assertFalse(
            Schema::hasColumn('admin_audit_logs', 'updated_at'),
            'admin_audit_logs must not have updated_at column.',
        );
    }

    // ── Contracts ──────────────────────────────

    public function test_contracts_endpoint_returns_four_contracts(): void
    {
        $admin = $this->createAdmin(RbacMatrix::ROLE_VIEWER);
        $res = $this->actingAs($admin, 'web')
            ->getJson('/admin-api/v1/projects/pangu2/contracts');
        $res->assertOk();
        $this->assertCount(4, $res->json('data'));
        $admin->delete();
    }
}
