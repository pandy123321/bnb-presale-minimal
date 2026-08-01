<?php

return [

    'default' => env('QUEUE_CONNECTION', 'redis'),

    'connections' => [
        'redis' => [
            'driver' => 'redis',
            'connection' => 'default',
            'queue' => env('REDIS_QUEUE', 'default'),
            'retry_after' => 90,
            'block_for' => null,
            'after_commit' => true,
        ],
    ],

    'batching' => [
        'database' => 'pgsql',
        'table' => 'job_batches',
    ],

    'failed' => [
        'driver' => 'database',
        'database' => 'pgsql',
        'table' => 'failed_jobs',
    ],

];
