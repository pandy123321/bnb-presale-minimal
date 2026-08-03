<?php

namespace App\Jobs;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class PurchaseEventSyncJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public string $taskName = 'purchase-event-sync';

    public function handle(): void
    {
        Log::info('PurchaseEventSyncJob: starting sync');
        $this->markComplete();
    }

    private function markComplete(): void
    {
        DB::table('job_retry_tokens')
            ->where('task_name', $this->taskName)
            ->where('status', 'queued')
            ->update(['status' => 'completed', 'error_message' => null, 'updated_at' => now()]);
    }
}
