<?php

declare(strict_types=1);

namespace App\Http;

use Illuminate\Http\JsonResponse;

/**
 * PANGU2 Unified API Envelope.
 *
 * Every API response MUST use this envelope.
 */
final class ApiEnvelope
{
    private function __construct() {}

    public static function success(
        mixed $data,
        string $dataStatus = 'MOCK_DATA',
        ?string $blockNumber = null,
        array $extraMeta = [],
    ): JsonResponse {
        return response()->json([
            'success' => true,
            'data'    => $data,
            'meta'    => array_merge([
                'project'        => 'PANGU2',
                'project_id'     => 'pangu2',
                'environment'    => config('app.env', 'LOCAL'),
                'chain_id'       => (int) config('pangu2.chain_id', 31337),
                'data_status'    => $dataStatus,
                'block_number'   => $blockNumber,
                'generated_at'   => now()->toIso8601String(),
                'schema_version' => '1.0.0',
            ], $extraMeta),
            'error' => null,
        ]);
    }

    public static function paginated(
        mixed $data,
        int $currentPage,
        int $perPage,
        int $total,
        string $dataStatus = 'MOCK_DATA',
        ?string $blockNumber = null,
    ): JsonResponse {
        return self::success($data, $dataStatus, $blockNumber, [
            'current_page' => $currentPage,
            'per_page'     => $perPage,
            'total'        => $total,
            'last_page'    => (int) ceil($total / max($perPage, 1)),
        ]);
    }

    public static function error(
        string $code,
        string $message,
        bool $retryable = false,
        array $details = [],
        int $httpStatus = 400,
    ): JsonResponse {
        return response()->json([
            'success' => false,
            'data'    => null,
            'meta'    => [
                'project'        => 'PANGU2',
                'project_id'     => 'pangu2',
                'environment'    => config('app.env', 'LOCAL'),
                'chain_id'       => (int) config('pangu2.chain_id', 31337),
                'data_status'    => 'UNAVAILABLE',
                'block_number'   => null,
                'generated_at'   => now()->toIso8601String(),
                'schema_version' => '1.0.0',
            ],
            'error' => [
                'code'      => $code,
                'message'   => $message,
                'retryable' => $retryable,
                'details'   => $details,
            ],
        ], $httpStatus);
    }
}
