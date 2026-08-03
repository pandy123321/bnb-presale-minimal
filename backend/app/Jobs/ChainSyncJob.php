<?php

declare(strict_types=1);

namespace App\Jobs;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class ChainSyncJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels, RetryTokenJob;

    public function __construct(public readonly int $retryTokenId) {}

    public function handle(): void
    {
        $this->transition($this->retryTokenId, 'running');

        try {
            // TODO: call real chain sync service when implemented
            // For now, fail-closed: this service is not yet implemented.
            // When ready, replace with: app(ChainSyncService::class)->sync();
            throw new \RuntimeException('ChainSyncService not yet implemented — Task marked as not_implemented');
        } catch (\Throwable $e) {
            $this->markFailed($this->retryTokenId, $e->getMessage());
            throw $e;
        }
    }
}
