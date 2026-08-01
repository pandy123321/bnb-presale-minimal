<?php

return [
    /*
    |--------------------------------------------------------------------------
    | PANGU2 Configuration
    |--------------------------------------------------------------------------
    */
    'chain_id' => env('PANGU2_CHAIN_ID', 31337),
    'rpc_url' => env('PANGU2_RPC_URL', 'http://127.0.0.1:8545'),
    'operator_address' => env('CHAIN_OPERATOR_ADDRESS', ''),
    'allow_mainnet_writes' => env('ALLOW_MAINNET_WRITES', false),
    'required_confirmations' => (int) env('PANGU2_CONFIRMATIONS', 12),
    'deployment_block' => env('PANGU2_DEPLOYMENT_BLOCK', '0'),
    'token_decimals' => 18,
    'token_symbol' => 'PANGU2',
    'buy_tax_percent' => 4,
    'sell_tax_tiers' => [4, 10],
];
