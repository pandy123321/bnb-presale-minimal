<?php

declare(strict_types=1);

namespace App\Modules\Core\Chain\Controllers;

use App\Http\ApiEnvelope;
use App\Modules\Core\Chain\Services\ChainConfigService;
use App\Modules\Core\Chain\Services\SystemStatusService;
use App\Modules\Core\ContractRegistry\Services\ContractRegistryService;

/**
 * Public system endpoints:
 *   GET /config        – environment & chain info
 *   GET /system-status – sync, queue, anomalies
 *   GET /contracts     – contract registry
 */
final class SystemController
{
    public function __construct(
        private readonly ChainConfigService      $configService,
        private readonly SystemStatusService      $statusService,
        private readonly ContractRegistryService  $registryService,
    ) {}

    /**
     * GET /api/v1/projects/pangu2/config
     */
    public function config(): \Illuminate\Http\JsonResponse
    {
        return ApiEnvelope::success(
            $this->configService->getConfig(),
            'LIVE',
        );
    }

    /**
     * GET /api/v1/projects/pangu2/system-status
     */
    public function systemStatus(): \Illuminate\Http\JsonResponse
    {
        return ApiEnvelope::success(
            $this->statusService->getStatus(),
            $this->statusService->getDataStatus(),
            $this->statusService->getLatestBlockHint(),
        );
    }

    /**
     * GET /api/v1/projects/pangu2/contracts
     */
    public function contracts(): \Illuminate\Http\JsonResponse
    {
        $entries    = $this->registryService->getAll();
        $dataStatus = $this->contractsDataStatus($entries);

        return ApiEnvelope::success($entries, $dataStatus);
    }

    // -------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------

    /**
     * Determine data_status for the contracts endpoint.
     *
     * If any known contract is UNAVAILABLE → UNAVAILABLE
     * Otherwise delegate to system status service.
     */
    private function contractsDataStatus(array $entries): string
    {
        foreach ($entries as $entry) {
            if (($entry['status'] ?? '') === 'UNAVAILABLE') {
                return 'UNAVAILABLE';
            }
        }

        return $this->statusService->getDataStatus();
    }
}
