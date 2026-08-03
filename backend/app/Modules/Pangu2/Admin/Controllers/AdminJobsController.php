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
     * Task name → Queue Job class mapping. All retried tasks dispatch to the queue.
     */
    private const TASK_JOB_MAP = [
        'chain-sync'          => \App\Jobs\ChainSyncJob::class,
        'purchase_event_sync' => \App\Jobs\PurchaseEventSyncJob::class,
        'dividend-snapshot'   => \App\Jobs\DividendSnapshotJob::class,
        'buyback-watcher'     => \App\Jobs\BuybackWatcherJob::class,
    ];

    /**
     * Allowed task names for retry. Only known, idempotent-safe tasks can be retried.
     */
    private const RETRY_ALLOWLIST = [
        'chain-sync',
        'purchase_event_sync',
        'dividend-snapshot',
        'buyback-watcher',
    ];

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

        if (!$idempotencyKey || strlen($idempotencyKey) < 16 || strlen($idempotencyKey) > 128) {
            return ApiEnvelope::error(
                'VALIDATION_MISSING_HEADER',
                'Idempotency-Key header is required (16-128 chars).',
                false,
                [],
                422,
            );
        }

        // Validate task name against allowlist
        if (!in_array($taskName, self::RETRY_ALLOWLIST, true)) {
            return ApiEnvelope::error(
                'INVALID_TASK',
                "Task '{$taskName}' is not in the retry allowlist.",
                false,
                ['allowed_tasks' => self::RETRY_ALLOWLIST],
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

        // Atomically insert the retry token + audit in one transaction
        $adminId = $request->user()?->id;
        $now     = now();

        $result = DB::transaction(function () use ($taskName, $idempotencyKey, $adminId, $request, $now): array {
            $inserted = DB::table('job_retry_tokens')->insertOrIgnore([
                'task_name'       => $taskName,
                'idempotency_key' => $idempotencyKey,
                'admin_id'        => $adminId,
                'status'          => 'queued',
                'created_at'      => $now,
                'updated_at'      => $now,
            ]);

            if (!$inserted) {
                return false;
            }

            DB::table('admin_audit_logs')->insert([
                'admin_id'        => $adminId,
                'action'          => 'JOB_RETRY_QUEUED',
                'target_type'     => 'job',
                'idempotency_key' => $idempotencyKey,
                'ip_address'      => $request->ip(),
                'user_agent'      => $request->userAgent(),
                'after_data'      => json_encode(['task_name' => $taskName]),
                'result'          => 'SUCCESS',
                'created_at'      => $now,
            ]);

            // Read back token ID for dispatch
            $tokenRow = DB::table('job_retry_tokens')
                ->where('idempotency_key', $idempotencyKey)
                ->where('task_name', $taskName)
                ->first();

            return ['consumed' => true, 'token_id' => $tokenRow?->id ?? 0];
        });

        if (!$result['consumed']) {
            $retry = DB::table('job_retry_tokens')
                ->where('task_name', $taskName)
                ->where('idempotency_key', $idempotencyKey)
                ->first();

            return ApiEnvelope::success([
                'task_name'       => $taskName,
                'status'          => $retry?->status ?? 'queued',
                'idempotent'      => true,
                'created_at'      => $retry?->created_at,
            ], 'LIVE');
        }

        // Dispatch to queue AFTER transaction commits
        if ($result['consumed'] ?? false) {
            $this->dispatchRetry($taskName, (int) ($result['token_id'] ?? 0));
        }

        return ApiEnvelope::success([
            'task_name'       => $taskName,
            'status'          => 'queued',
            'idempotent'      => false,
            'created_at'      => $now->toIso8601String(),
        ], 'LIVE');
    }

    private function dispatchRetry(string $taskName, int $tokenId): void
    {
        $jobClass = self::TASK_JOB_MAP[$taskName] ?? null;
        if (!$jobClass || !class_exists($jobClass)) {
            DB::table('job_retry_tokens')->where('id', $tokenId)->update([
                'status' => 'failed', 'error_message' => "Job class not found: {$taskName}", 'updated_at' => now(),
            ]);
            return;
        }
        try {
            dispatch(new $jobClass);
        } catch (\Throwable $e) {
            DB::table('job_retry_tokens')->where('id', $tokenId)->update([
                'status' => 'failed', 'error_message' => $e->getMessage(), 'updated_at' => now(),
            ]);
        }
    }

    // ── Helpers writer removed — audit is now inline in the transaction ──
}
