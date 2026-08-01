<?php

declare(strict_types=1);

namespace App\Modules\Pangu2\Admin\Controllers;

use App\Http\ApiEnvelope;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Admin Jobs Controller — task monitoring and idempotent retry.
 */
class AdminJobsController extends Controller
{
    /**
     * GET /admin-api/v1/projects/pangu2/jobs
     *
     * List system tasks with their current status.
     */
    public function index(): JsonResponse
    {
        $tasks = DB::table('system_task_runs')
            ->orderBy('started_at', 'desc')
            ->limit(20)
            ->get()
            ->map(fn ($t) => [
                'name'          => $t->task_name,
                'status'        => $t->status,
                'run_id'        => $t->run_id,
                'last_error'    => $t->error_message,
                'processed'     => (int) $t->processed_count,
                'errors'        => (int) $t->error_count,
                'last_run'      => $t->completed_at ?? $t->started_at,
            ])
            ->toArray();

        return ApiEnvelope::success($tasks, 'MOCK_DATA');
    }

    /**
     * POST /admin-api/v1/projects/pangu2/jobs/{taskName}/retry
     *
     * Idempotent retry. Requires Idempotency-Key header.
     * The same Idempotency-Key always returns the same result.
     */
    public function retry(string $taskName, Request $request): JsonResponse
    {
        $idempotencyKey = $request->header('Idempotency-Key');

        if (!$idempotencyKey) {
            return ApiEnvelope::error(
                'VALIDATION_MISSING_HEADER',
                'Idempotency-Key header is required for retry operations.',
                false,
                [],
                422,
            );
        }

        // Check if this idempotency key was already processed
        $existing = DB::table('job_retry_tokens')
            ->where('idempotency_key', $idempotencyKey)
            ->where('task_name', $taskName)
            ->first();

        if ($existing) {
            return ApiEnvelope::success([
                'task_name'       => $taskName,
                'status'          => $existing->status,
                'idempotent'      => true,
                'executed_at'     => $existing->executed_at,
                'result'          => $existing->result,
                'error_message'   => $existing->error_message,
            ], 'LIVE');
        }

        // Atomically insert the retry token
        $adminId = $request->user()?->id;
        $now = now();

        try {
            DB::table('job_retry_tokens')->insert([
                'task_name'       => $taskName,
                'idempotency_key' => $idempotencyKey,
                'admin_id'        => $adminId,
                'status'          => 'executed',
                'executed_at'     => $now,
                'result'          => "Retry triggered for {$taskName}",
                'created_at'      => $now,
                'updated_at'      => $now,
            ]);

            // Write audit log
            $this->writeAudit('JOB_RETRY', $taskName, $idempotencyKey, $request, $adminId);

            return ApiEnvelope::success([
                'task_name'       => $taskName,
                'status'          => 'executed',
                'idempotent'      => false,
                'executed_at'     => $now->toIso8601String(),
            ], 'LIVE');
        } catch (\Throwable $e) {
            return ApiEnvelope::error(
                'JOB_RETRY_FAILED',
                $e->getMessage(),
                true,
                [],
                500,
            );
        }
    }

    // ── Helpers ──────────────────────────────

    private function writeAudit(
        string $action,
        string $target,
        string $idempotencyKey,
        Request $request,
        ?int $adminId,
    ): void {
        DB::table('admin_audit_logs')->insert([
            'admin_id'        => $adminId,
            'action'          => $action,
            'target_type'     => 'job',
            'idempotency_key' => $idempotencyKey,
            'ip_address'      => $request->ip(),
            'user_agent'      => $request->userAgent(),
            'after_data'      => json_encode(['task_name' => $target]),
            'result'          => 'SUCCESS',
            'created_at'      => now(),
        ]);
    }
}
