package queries

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/pandy123321/bnb-presale-minimal/backend-go/internal/domain"
)

// ChainConfig contains chain-level configuration.
type ChainConfig struct {
	ChainID           int64  `json:"chain_id"`
	RPCAddress        string `json:"rpc_address"`
	ConfirmationDepth int    `json:"confirmation_depth"`
	ReorgLookback     int    `json:"reorg_lookback"`
	TradingOpen       bool   `json:"trading_open"`
}

// SystemStatusInfo holds the system health status and observed block info.
type SystemStatusInfo struct {
	DataStatus        domain.DataStatus `json:"data_status"`
	ObservedBlockNum  int64             `json:"observed_block_number"`
	ObservedBlockHash string            `json:"observed_block_hash"`
}

// GetChainConfig returns the chain configuration for BSC testnet.
func GetChainConfig(ctx context.Context, pool *pgxpool.Pool) (*ChainConfig, error) {
	var cfg ChainConfig
	err := pool.QueryRow(ctx, `
		SELECT env.chain_id, env.rpc_alias,
		       COALESCE(cs.confirmation_depth, 0),
		       COALESCE(cs.reorg_lookback, 0)
		FROM binggoplus_v2.environments env
		LEFT JOIN binggoplus_v2.chain_streams cs ON cs.environment_id = env.id
		WHERE env.chain_id = $1 AND env.project = 'binggoplus'
		LIMIT 1
	`, domain.BSCTestnetChainID).Scan(&cfg.ChainID, &cfg.RPCAddress, &cfg.ConfirmationDepth, &cfg.ReorgLookback)
	if err != nil {
		return nil, err
	}
	return &cfg, nil
}

// GetSystemStatus returns the current system data status and latest observed block.
func GetSystemStatus(ctx context.Context, pool *pgxpool.Pool) (*SystemStatusInfo, error) {
	var info SystemStatusInfo
	err := pool.QueryRow(ctx, `
		SELECT
			CASE
				WHEN MAX(cb.observed_at) > NOW() - INTERVAL '5 minutes' THEN 'LIVE'
				WHEN MAX(cb.observed_at) > NOW() - INTERVAL '30 minutes' THEN 'STALE'
				WHEN MAX(cb.observed_at) IS NOT NULL THEN 'DEGRADED'
				ELSE 'SYNCING'
			END,
			COALESCE(MAX(cb.number), 0),
			COALESCE(MAX(cb.hash), '')
		FROM binggoplus_v2.environments env
		LEFT JOIN binggoplus_v2.chain_blocks cb ON cb.environment_id = env.id AND cb.canonical
		WHERE env.chain_id = $1 AND env.project = 'binggoplus'
	`, domain.BSCTestnetChainID).Scan(&info.DataStatus, &info.ObservedBlockNum, &info.ObservedBlockHash)
	if err != nil {
		return nil, err
	}
	return &info, nil
}
