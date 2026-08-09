package queries

import (
	"context"
	"math/big"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/pandy123321/bnb-presale-minimal/backend-go/internal/domain"
)

// GetTokenBalance returns the current token balance for an account.
func GetTokenBalance(ctx context.Context, pool *pgxpool.Pool, account domain.Address) (*domain.TokenBalance, error) {
	var tb domain.TokenBalance
	var balanceRaw string
	err := pool.QueryRow(ctx, `
		SELECT account, balance_raw, as_of_block_number, as_of_block_hash
		FROM binggoplus_v2.token_balances_current
		WHERE environment_id = (
			SELECT id FROM binggoplus_v2.environments WHERE chain_id = $1 AND project = 'binggoplus' LIMIT 1
		) AND account = $2
	`, domain.BSCTestnetChainID, account).Scan(&tb.Account, &balanceRaw, &tb.AsOfBlock, &tb.AsOfBlockHash)
	if err != nil {
		return nil, err
	}
	tb.BalanceRaw = new(big.Int)
	tb.BalanceRaw.SetString(balanceRaw, 10)
	return &tb, nil
}

// GetBalanceLedger returns paginated balance ledger entries for an account.
func GetBalanceLedger(ctx context.Context, pool *pgxpool.Pool, account domain.Address, limit int, cursor string) ([]domain.BalanceLedgerEntry, string, error) {
	if limit <= 0 || limit > 100 {
		limit = 25
	}

	rows, err := pool.Query(ctx, `
		SELECT id, account, COALESCE(counterparty, ''), direction, amount_raw, reason, created_at
		FROM binggoplus_v2.token_balance_ledger
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

	var entries []domain.BalanceLedgerEntry
	for rows.Next() {
		var e domain.BalanceLedgerEntry
		var amountRaw string
		if err := rows.Scan(&e.ID, &e.Account, &e.Counterparty, &e.Direction, &amountRaw, &e.Reason, &e.CreatedAt); err != nil {
			return nil, "", err
		}
		e.AmountRaw = new(big.Int)
		e.AmountRaw.SetString(amountRaw, 10)
		entries = append(entries, e)
	}
	if err := rows.Err(); err != nil {
		return nil, "", err
	}

	var nextCursor string
	if len(entries) > limit {
		nextCursor = entries[limit-1].ID
		entries = entries[:limit]
	}

	return entries, nextCursor, nil
}

// InsertBalanceLedger inserts a new balance ledger entry.
func InsertBalanceLedger(ctx context.Context, pool *pgxpool.Pool, entry domain.BalanceLedgerEntry, environmentID string, sourceRawEventID string, projectorVersion int) error {
	_, err := pool.Exec(ctx, `
		INSERT INTO binggoplus_v2.token_balance_ledger (
			id, environment_id, account, counterparty, direction, amount_raw, reason,
			projector_version, source_raw_event_id, created_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
	`,
		entry.ID, environmentID, entry.Account, entry.Counterparty, entry.Direction,
		entry.AmountRaw.String(), entry.Reason, projectorVersion, sourceRawEventID,
		time.Now(),
	)
	return err
}
