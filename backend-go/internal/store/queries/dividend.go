package queries

import (
	"context"
	"math/big"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/pandy123321/bnb-presale-minimal/backend-go/internal/domain"
)

// GetEpoch returns a dividend epoch by epoch ID.
func GetEpoch(ctx context.Context, pool *pgxpool.Pool, epochID *big.Int) (*domain.DividendEpoch, error) {
	var epoch domain.DividendEpoch
	var epochIDStr, totalRewardStr, carryStr, snapshotBlockStr string
	var snapshotBlockHash string

	err := pool.QueryRow(ctx, `
		SELECT id, epoch_id, state,
		       COALESCE(snapshot_block_number::text, ''), COALESCE(snapshot_block_hash, ''),
		       COALESCE(total_reward_raw, '0'), COALESCE(merkle_root, ''),
		       claim_start, claim_end, carry_raw, created_at, updated_at
		FROM binggoplus_v2.dividend_epochs
		WHERE environment_id = (
			SELECT id FROM binggoplus_v2.environments WHERE chain_id = $1 AND project = 'binggoplus' LIMIT 1
		) AND epoch_id = $2
	`, domain.BSCTestnetChainID, epochID.String()).Scan(
		&epoch.ID, &epochIDStr, &epoch.State,
		&snapshotBlockStr, &snapshotBlockHash,
		&totalRewardStr, &epoch.MerkleRoot,
		&epoch.ClaimStart, &epoch.ClaimEnd,
		&carryStr, &epoch.CreatedAt, &epoch.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}

	epoch.EpochID = new(big.Int)
	epoch.EpochID.SetString(epochIDStr, 10)
	epoch.TotalRewardRaw = new(big.Int)
	epoch.TotalRewardRaw.SetString(totalRewardStr, 10)
	epoch.CarryRaw = new(big.Int)
	epoch.CarryRaw.SetString(carryStr, 10)

	if snapshotBlockStr != "" {
		epoch.SnapshotBlockNumber = new(big.Int)
		epoch.SnapshotBlockNumber.SetString(snapshotBlockStr, 10)
	}
	if snapshotBlockHash != "" {
		epoch.SnapshotBlockHash = domain.TxHash(snapshotBlockHash)
	}

	return &epoch, nil
}

// GetCurrentEpoch returns the most recent (highest epoch_id) dividend epoch.
func GetCurrentEpoch(ctx context.Context, pool *pgxpool.Pool) (*domain.DividendEpoch, error) {
	var epochIDStr string
	err := pool.QueryRow(ctx, `
		SELECT COALESCE(MAX(epoch_id), '0')
		FROM binggoplus_v2.dividend_epochs
		WHERE environment_id = (
			SELECT id FROM binggoplus_v2.environments WHERE chain_id = $1 AND project = 'binggoplus' LIMIT 1
		)
	`, domain.BSCTestnetChainID).Scan(&epochIDStr)
	if err != nil {
		return nil, err
	}

	epochID := new(big.Int)
	epochID.SetString(epochIDStr, 10)
	if epochID.Sign() == 0 {
		return nil, nil
	}

	return GetEpoch(ctx, pool, epochID)
}

// CreateEpoch inserts a new dividend epoch.
func CreateEpoch(ctx context.Context, pool *pgxpool.Pool, epoch domain.DividendEpoch, environmentID string) (string, error) {
	var id string
	err := pool.QueryRow(ctx, `
		INSERT INTO binggoplus_v2.dividend_epochs (
			id, environment_id, epoch_id, state,
			snapshot_block_number, snapshot_block_hash,
			total_reward_raw, carry_raw, created_at, updated_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $9)
		RETURNING id
	`,
		epoch.ID, environmentID, epoch.EpochID.String(), string(epoch.State),
		epoch.SnapshotBlockNumber.String(), string(epoch.SnapshotBlockHash),
		epoch.TotalRewardRaw.String(), epoch.CarryRaw.String(),
		time.Now(),
	).Scan(&id)
	if err != nil {
		return "", err
	}
	return id, nil
}

// GetAllocations returns the dividend allocations for a given epoch and account.
func GetAllocations(ctx context.Context, pool *pgxpool.Pool, epochID string, account domain.Address) (*domain.DividendAllocation, error) {
	var alloc domain.DividendAllocation
	var effectiveBalanceRaw, allocationRaw, leafHash, rankStr, tierStr string

	err := pool.QueryRow(ctx, `
		SELECT a.account, a.rank, a.tier,
		       a.effective_balance_raw, a.allocation_raw, a.leaf_hash, a.proof
		FROM binggoplus_v2.dividend_allocations a
		JOIN binggoplus_v2.dividend_artifacts art ON art.id = a.artifact_id
		JOIN binggoplus_v2.dividend_epochs e ON e.id = art.dividend_epoch_id
		WHERE e.id = $1 AND a.account = $2
		ORDER BY art.artifact_revision DESC
		LIMIT 1
	`, epochID, account).Scan(
		&alloc.Account, &rankStr, &tierStr,
		&effectiveBalanceRaw, &allocationRaw, &leafHash, &alloc.Proof,
	)
	if err != nil {
		return nil, err
	}

	alloc.EffectiveBalanceRaw = new(big.Int)
	alloc.EffectiveBalanceRaw.SetString(effectiveBalanceRaw, 10)
	alloc.AllocationRaw = new(big.Int)
	alloc.AllocationRaw.SetString(allocationRaw, 10)
	alloc.LeafHash = domain.TxHash(leafHash)

	return &alloc, nil
}

// ListEpochs returns paginated dividend epochs.
func ListEpochs(ctx context.Context, pool *pgxpool.Pool, limit int, cursor string) ([]domain.DividendEpoch, string, error) {
	if limit <= 0 || limit > 100 {
		limit = 25
	}

	rows, err := pool.Query(ctx, `
		SELECT id, epoch_id, state,
		       COALESCE(snapshot_block_number::text, ''), COALESCE(snapshot_block_hash, ''),
		       COALESCE(total_reward_raw, '0'), COALESCE(merkle_root, ''),
		       claim_start, claim_end, carry_raw, created_at, updated_at
		FROM binggoplus_v2.dividend_epochs
		WHERE environment_id = (
			SELECT id FROM binggoplus_v2.environments WHERE chain_id = $1 AND project = 'binggoplus' LIMIT 1
		)
		AND ($2 = '' OR id > $2)
		ORDER BY epoch_id DESC
		LIMIT $3
	`, domain.BSCTestnetChainID, cursor, limit+1)
	if err != nil {
		return nil, "", err
	}
	defer rows.Close()

	var epochs []domain.DividendEpoch
	for rows.Next() {
		var e domain.DividendEpoch
		var epochIDStr, totalRewardStr, carryStr, snapshotBlockStr, snapshotBlockHash string
		if err := rows.Scan(
			&e.ID, &epochIDStr, &e.State,
			&snapshotBlockStr, &snapshotBlockHash,
			&totalRewardStr, &e.MerkleRoot,
			&e.ClaimStart, &e.ClaimEnd,
			&carryStr, &e.CreatedAt, &e.UpdatedAt,
		); err != nil {
			return nil, "", err
		}
		e.EpochID = new(big.Int)
		e.EpochID.SetString(epochIDStr, 10)
		e.TotalRewardRaw = new(big.Int)
		e.TotalRewardRaw.SetString(totalRewardStr, 10)
		e.CarryRaw = new(big.Int)
		e.CarryRaw.SetString(carryStr, 10)
		if snapshotBlockStr != "" {
			e.SnapshotBlockNumber = new(big.Int)
			e.SnapshotBlockNumber.SetString(snapshotBlockStr, 10)
		}
		if snapshotBlockHash != "" {
			e.SnapshotBlockHash = domain.TxHash(snapshotBlockHash)
		}
		epochs = append(epochs, e)
	}
	if err := rows.Err(); err != nil {
		return nil, "", err
	}

	var nextCursor string
	if len(epochs) > limit {
		nextCursor = epochs[limit-1].ID
		epochs = epochs[:limit]
	}

	return epochs, nextCursor, nil
}
