package queries

import (
	"context"
	"math/big"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/pandy123321/bnb-presale-minimal/backend-go/internal/domain"
)

// InsertTrade inserts a completed trade record.
func InsertTrade(ctx context.Context, pool *pgxpool.Pool, trade domain.Trade, environmentID string, sourceRawEventID string) error {
	_, err := pool.Exec(ctx, `
		INSERT INTO binggoplus_v2.trades (
			id, environment_id, account, direction, amount_in_raw, amount_out_raw,
			tax_total_raw, tax_dividend_raw, tax_support_raw, tax_burn_raw,
			tax_bps, cost_state, source_raw_event_id, block_time
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
	`,
		trade.ID, environmentID, trade.Account, trade.Direction,
		trade.AmountInRaw.String(), trade.AmountOutRaw.String(),
		trade.TaxTotalRaw.String(), trade.TaxDividendRaw.String(),
		trade.TaxSupportRaw.String(), trade.TaxBurnRaw.String(),
		trade.TaxBps, trade.CostState, sourceRawEventID,
		trade.BlockTime,
	)
	return err
}

// GetTradesByAddress returns paginated trades for a wallet address.
func GetTradesByAddress(ctx context.Context, pool *pgxpool.Pool, account domain.Address, limit int, cursor string) ([]domain.Trade, string, error) {
	if limit <= 0 || limit > 100 {
		limit = 25
	}

	rows, err := pool.Query(ctx, `
		SELECT id, account, direction, amount_in_raw, amount_out_raw,
		       tax_total_raw, tax_dividend_raw, tax_support_raw, tax_burn_raw,
		       tax_bps, COALESCE(cost_state, ''), block_time
		FROM binggoplus_v2.trades
		WHERE environment_id = (
			SELECT id FROM binggoplus_v2.environments WHERE chain_id = $1 AND project = 'binggoplus' LIMIT 1
		) AND account = $2
		AND ($3 = '' OR id > $3)
		ORDER BY id
		LIMIT $4
	`, domain.BSCTestnetChainID, account, cursor, limit+1)
	if err != nil {
		return nil, "", err
	}
	defer rows.Close()

	var trades []domain.Trade
	for rows.Next() {
		var t domain.Trade
		var amountIn, amountOut, taxTotal, taxDividend, taxSupport, taxBurn string
		if err := rows.Scan(
			&t.ID, &t.Account, &t.Direction,
			&amountIn, &amountOut,
			&taxTotal, &taxDividend, &taxSupport, &taxBurn,
			&t.TaxBps, &t.CostState, &t.BlockTime,
		); err != nil {
			return nil, "", err
		}
		t.AmountInRaw = new(big.Int)
		t.AmountInRaw.SetString(amountIn, 10)
		t.AmountOutRaw = new(big.Int)
		t.AmountOutRaw.SetString(amountOut, 10)
		t.TaxTotalRaw = new(big.Int)
		t.TaxTotalRaw.SetString(taxTotal, 10)
		t.TaxDividendRaw = new(big.Int)
		t.TaxDividendRaw.SetString(taxDividend, 10)
		t.TaxSupportRaw = new(big.Int)
		t.TaxSupportRaw.SetString(taxSupport, 10)
		t.TaxBurnRaw = new(big.Int)
		t.TaxBurnRaw.SetString(taxBurn, 10)
		trades = append(trades, t)
	}
	if err := rows.Err(); err != nil {
		return nil, "", err
	}

	var nextCursor string
	if len(trades) > limit {
		nextCursor = trades[limit-1].ID
		trades = trades[:limit]
	}

	return trades, nextCursor, nil
}

// GetTradeStats returns aggregated trade statistics.
func GetTradeStats(ctx context.Context, pool *pgxpool.Pool) (*domain.TradeStats, error) {
	var stats domain.TradeStats
	var volume24h string
	err := pool.QueryRow(ctx, `
		SELECT
			COUNT(*)::bigint,
			COUNT(*) FILTER (WHERE direction = 'BUY')::bigint,
			COUNT(*) FILTER (WHERE direction = 'SELL')::bigint,
			COALESCE(SUM(
				CASE WHEN block_time > NOW() - INTERVAL '24 hours'
				THEN amount_in_raw ELSE 0 END
			), 0)
		FROM binggoplus_v2.trades
		WHERE environment_id = (
			SELECT id FROM binggoplus_v2.environments WHERE chain_id = $1 AND project = 'binggoplus' LIMIT 1
		)
	`, domain.BSCTestnetChainID).Scan(&stats.TradeCount, &stats.BuyCount, &stats.SellCount, &volume24h)
	if err != nil {
		return nil, err
	}
	stats.Volume24h = new(big.Int)
	stats.Volume24h.SetString(volume24h, 10)
	return &stats, nil
}

// GetTradeActivity returns unified trade + transfer activity for wallet transactions view.
func GetTradeActivity(ctx context.Context, pool *pgxpool.Pool, account domain.Address, limit int, cursor string) ([]ActivityEntry, string, error) {
	if limit <= 0 || limit > 100 {
		limit = 25
	}

	rows, err := pool.Query(ctx, `
		SELECT t.id, 'TRADE' as activity_type, t.direction AS activity_subtype,
		       t.amount_in_raw, t.amount_out_raw, t.tax_bps, t.block_time, ''::text AS tx_hash, 0 AS log_index, 0::bigint AS block_number, ''::text AS block_hash
		FROM binggoplus_v2.trades t
		WHERE t.environment_id = (
			SELECT id FROM binggoplus_v2.environments WHERE chain_id = $1 AND project = 'binggoplus' LIMIT 1
		) AND t.account = $2
		AND ($3 = '' OR t.id > $3)

		UNION ALL

		SELECT l.id, CASE WHEN l.direction = 'CREDIT' THEN 'TRANSFER_IN' ELSE 'TRANSFER_OUT' END,
		       l.reason, l.amount_raw, '0', NULL::integer, l.created_at,
		       ''::text, 0, 0::bigint, ''::text
		FROM binggoplus_v2.token_balance_ledger l
		WHERE l.environment_id = (
			SELECT id FROM binggoplus_v2.environments WHERE chain_id = $1 AND project = 'binggoplus' LIMIT 1
		) AND l.account = $2
		AND l.reason IN ('TRANSFER', 'MINT', 'BURN')
		AND ($3 = '' OR l.id > $3)

		ORDER BY block_time DESC, id
		LIMIT $4
	`, domain.BSCTestnetChainID, account, cursor, limit+1)
	if err != nil {
		return nil, "", err
	}
	defer rows.Close()

	var activities []ActivityEntry
	for rows.Next() {
		var a ActivityEntry
		var amountIn, amountOut string
		if err := rows.Scan(&a.ID, &a.ActivityType, &a.Direction, &amountIn, &amountOut, &a.TaxBps, &a.OccurredAt, &a.TxHash, &a.LogIndex, &a.BlockNumber, &a.BlockHash); err != nil {
			return nil, "", err
		}
		a.AmountInRaw = new(big.Int)
		a.AmountInRaw.SetString(amountIn, 10)
		a.AmountOutRaw = new(big.Int)
		a.AmountOutRaw.SetString(amountOut, 10)
		activities = append(activities, a)
	}
	if err := rows.Err(); err != nil {
		return nil, "", err
	}

	var nextCursor string
	if len(activities) > limit {
		nextCursor = activities[limit-1].ID
		activities = activities[:limit]
	}

	return activities, nextCursor, nil
}

// ActivityEntry represents a unified activity record for wallet transaction list.
type ActivityEntry struct {
	ID           string     `json:"-"`
	ActivityType string     `json:"activity_type"`
	Direction    string     `json:"-"`
	AmountInRaw  *big.Int   `json:"amount_in_raw,omitempty"`
	AmountOutRaw *big.Int   `json:"amount_out_raw,omitempty"`
	TaxBps       *int       `json:"tax_bps,omitempty"`
	OccurredAt   time.Time  `json:"occurred_at"`
	TxHash       string     `json:"tx_hash"`
	LogIndex     int        `json:"log_index"`
	BlockNumber  int64      `json:"block_number"`
	BlockHash    string     `json:"block_hash"`
}
