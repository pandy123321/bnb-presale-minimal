<?php

return [
    'chain_id' => (int) env('PANGU2_CHAIN_ID', env('CHAIN_EXPECTED_ID', 31337)),
    'chain_name' => env('PANGU2_CHAIN_NAME', 'Anvil'),
    'rpc_url' => env('PANGU2_RPC_URL', 'http://127.0.0.1:8545'),
    'backup_rpc_url' => env('PANGU2_BACKUP_RPC_URL', ''),
    'operator_address' => env('CHAIN_OPERATOR_ADDRESS', ''),
    'allow_mainnet_writes' => (bool) env('ALLOW_MAINNET_WRITES', false),
    'required_confirmations' => (int) env('PANGU2_CONFIRMATIONS', 12),
    'deployment_block' => env('PANGU2_DEPLOYMENT_BLOCK', '0'),
    'token_decimals' => 18,
    'token_symbol' => 'PANGU2',
    'token_address' => env('PANGU2_TOKEN_ADDRESS', ''),
    'trade_router_address' => env('PANGU2_TRADE_ROUTER_ADDRESS', ''),
    'dividend_distributor_address' => env('PANGU2_DIVIDEND_DISTRIBUTOR_ADDRESS', ''),
    'support_pool_address' => env('PANGU2_SUPPORT_POOL_ADDRESS', ''),
    'buyback_locker_address' => env('PANGU2_BUYBACK_LOCKER_ADDRESS', ''),
    'fee_vault_address' => env('PANGU2_FEE_VAULT_ADDRESS', ''),
    'cost_basis_manager_address' => env('PANGU2_COST_BASIS_MANAGER_ADDRESS', ''),
    'staking_address' => env('PANGU2_STAKING_ADDRESS', ''),
    'staking_mock_enabled' => (bool) env('PANGU2_STAKING_MOCK_ENABLED', false),
    'wbnb_address' => env('PANGU2_WBNB_ADDRESS', '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c'),

    'auth_domain' => env('PANGU2_AUTH_DOMAIN', 'localhost'),
    'nonce_ttl_minutes' => (int) env('PANGU2_NONCE_TTL', 5),
    'session_ttl_minutes' => (int) env('PANGU2_SESSION_TTL', 120),

    'supported_networks' => array_map(
        'intval',
        explode(',', env('PANGU2_SUPPORTED_NETWORKS', '31337,97'))
    ),

    'freshness_stale_blocks' => (int) env('PANGU2_STALE_BLOCKS', 20),
    'freshness_degraded_blocks' => (int) env('PANGU2_DEGRADED_BLOCKS', 200),
];
