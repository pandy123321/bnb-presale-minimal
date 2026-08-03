<?php

declare(strict_types=1);

namespace App\Jobs;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\DB;

/**
 * Shared lifecycle for retry-token-based Queue Jobs.
 * Each Job owns exactly one job_retry_tokens row. The Job MUST
 * call $this->transition('running') at start and
 * $this->markCompleted() / $this->markFailed() at end.
 */
trait RetryTokenJob
{
    /**
     * Transition the token to a new status, verifying current state.
     */
    protected function transition(int $retryTokenId, string $toStatus): void
    {
        $allowed = match ($toStatus) {
            'running'   => ['queued'],
            'completed' => ['running'],
            'failed'    => ['queued', 'running'],
            default     => [],
        };

        $updated = DB::table('job_retry_tokens')
            ->where('id', $retryTokenId)
            ->whereIn('status', $allowed)
            ->update([
                'status'     => $toStatus,
                'updated_at' => now(),
            ]);

        if ($updated === 0) {
            throw new \RuntimeException(
                "Token #{$retryTokenId} cannot transition from current status to {$toStatus}"
            );
        }
    }

    /**
     * Mark as completed with optional result payload.
     */
    protected function markCompleted(int $retryTokenId, ?array $result = null): void
    {
        DB::table('job_retry_tokens')
            ->where('id', $retryTokenId)
            ->update([
                'status'      => 'completed',
                'result'      => $result ? json_encode($result) : null,
                'executed_at' => now(),
                'updated_at'  => now(),
            ]);
    }

    /**
     * Mark as failed with error message.
     */
    protected function markFailed(int $retryTokenId, string $errorMessage): void
    {
        DB::table('job_retry_tokens')
            ->where('id', $retryTokenId)
            ->update([
                'status'        => 'failed',
                'error_message' => mb_substr($errorMessage, 0, 2000),
                'executed_at'   => now(),
                'updated_at'    => now(),
            ]);
    }
}
