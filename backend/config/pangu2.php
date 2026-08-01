<?php

return [
    /*
    |--------------------------------------------------------------------------
    | PANGU2 Configuration
    |--------------------------------------------------------------------------
    */
    'chain_id' => (int) env('PANGU2_CHAIN_ID', 31337),
    'chain_name' => env('PANGU2_CHAIN_NAME', 'Anvil'),
    'rpc_url' => env('PANGU2_RPC_URL', 'http://127.0.0.1:8545'),
    'backup_rpc_url' => env('PANGU2_BACKUP_RPC_URL', ''),
    'operator_address' => env('CHAIN_OPERATOR_ADDRESS', ''),
    'allow_mainnet_writes' => (bool) env('ALLOW_MAINNET_WRITES', false),
    'required_confirmations' => (int) env('PANGU2_CONFIRMATIONS', 12),
    'deployment_block' => env('PANGU2_DEPLOYMENT_BLOCK', '0'),
    'token_decimals' => 18,
    'token_symbol' => 'PANGU2',
    'buy_tax_percent' => 4,
    'sell_tax_tiers' => [4, 10],

    /*
    |--------------------------------------------------------------------------
    | Wallet Authentication
    |--------------------------------------------------------------------------
    | The trusted auth domain is the only domain accepted for wallet login.
    | This prevents phishing attacks that forge login messages with fake domains.
    */
    'auth_domain' => env('PANGU2_AUTH_DOMAIN', 'localhost'),
    'nonce_ttl_minutes' => (int) env('PANGU2_NONCE_TTL', 5),
    'session_ttl_minutes' => (int) env('PANGU2_SESSION_TTL', 120),

    /*
    |--------------------------------------------------------------------------
    | Supported Networks
    |--------------------------------------------------------------------------
    | Chain IDs that are supported across all environments.
    | Used by the /config endpoint to advertise available networks.
    */
    'supported_networks' => array_map(
        'intval',
        explode(',', env('PANGU2_SUPPORTED_NETWORKS', '31337,97,56'))
    ),

    /*
    |--------------------------------------------------------------------------
    | Data Freshness Thresholds
    |--------------------------------------------------------------------------
    | Maximum allowed block lag before data is considered STALE (in blocks).
    */
    'freshness_stale_blocks' => (int) env('PANGU2_STALE_BLOCKS', 20),
    'freshness_degraded_blocks' => (int) env('PANGU2_DEGRADED_BLOCKS', 200),
];
