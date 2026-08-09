package queries

import (
	"context"
	"math/big"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/pandy123321/bnb-presale-minimal/backend-go/internal/domain"
)

// GetStakingPosition returns a single staking position by account and position ID.
func GetStakingPosition(ctx context.Context, pool *pgxpool.Pool, account domain.Address, positionID *big.Int) (*domain.StakingPosition, error) {
	var sp domain.StakingPosition
	var principalRaw, accruedRewardRaw, posID string
	err := pool.QueryRow(ctx, `
		SELECT position_id, principal_raw, accrued_reward_raw, unlock_time, state
		FROM binggoplus_v2.staking_positions
		WHERE environment_id = (
			SELECT id FROM binggoplus_v2.environments WHERE chain_id = $1 AND project = 'binggoplus' LIMIT 1
		) AND account = $2 AND position_id = $3
	`, domain.BSCTestnetChainID, account, positionID.String()).Scan(
		&posID, &principalRaw, &accruedRewardRaw, &sp.UnlockAt, &sp.State,
	)
	if err != nil {
		return nil, err
	}
	sp.PositionID = new(big.Int)
	sp.PositionID.SetString(posID, 10)
	sp.PrincipalRaw = new(big.Int)
	sp.PrincipalRaw.SetString(principalRaw, 10)
	sp.AccruedRewardRaw = new(big.Int)
	sp.AccruedRewardRaw.SetString(accruedRewardRaw, 10)
	return &sp, nil
}

// ListStakingPositions returns all staking positions for an account.
func ListStakingPositions(ctx context.Context, pool *pgxpool.Pool, account domain.Address) ([]domain.StakingPosition, error) {
	rows, err := pool.Query(ctx, `
		SELECT position_id, principal_raw, accrued_reward_raw, unlock_time, state
		FROM binggoplus_v2.staking_positions
		WHERE environment_id = (
			SELECT id FROM binggoplus_v2.environments WHERE chain_id = $1 AND project = 'binggoplus' LIMIT 1
		) AND account = $2
		ORDER BY position_id DESC
	`, domain.BSCTestnetChainID, account)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var positions []domain.StakingPosition
	for rows.Next() {
		var sp domain.StakingPosition
		var principalRaw, accruedRewardRaw, posID string
		if err := rows.Scan(&posID, &principalRaw, &accruedRewardRaw, &sp.UnlockAt, &sp.State); err != nil {
			return nil, err
		}
		sp.PositionID = new(big.Int)
		sp.PositionID.SetString(posID, 10)
		sp.PrincipalRaw = new(big.Int)
		sp.PrincipalRaw.SetString(principalRaw, 10)
		sp.AccruedRewardRaw = new(big.Int)
		sp.AccruedRewardRaw.SetString(accruedRewardRaw, 10)
		positions = append(positions, sp)
	}
	return positions, rows.Err()
}

// InsertStakingEvent inserts a staking event record.
func InsertStakingEvent(ctx context.Context, pool *pgxpool.Pool, event domain.StakingEvent, environmentID string, sourceRawEventID string, projectorVersion int) error {
	var positionIDStr string
	if event.PositionID != nil {
		positionIDStr = event.PositionID.String()
	}
	_, err := pool.Exec(ctx, `
		INSERT INTO binggoplus_v2.staking_events (
			id, environment_id, account, position_id, event_type,
			principal_raw, reward_raw, penalty_raw,
			projector_version, source_raw_event_id
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
	`,
		event.ID, environmentID, event.Account, positionIDStr, event.EventType,
		event.PrincipalRaw.String(), event.RewardRaw.String(), event.PenaltyRaw.String(),
		projectorVersion, sourceRawEventID,
	)
	return err
}

// GetStakingStatus returns public staking pool status information.
func GetStakingStatus(ctx context.Context, pool *pgxpool.Pool) (*domain.StakingStatus, error) {
	var status domain.StakingStatus
	var rewardRate, maxRewardRate, reserve, liability, totalStaked string
	err := pool.QueryRow(ctx, `
		SELECT
			COALESCE(SUM(CASE WHEN state = 'ACTIVE' THEN principal_raw ELSE 0 END), 0),
			COALESCE(SUM(CASE WHEN state = 'ACTIVE' THEN accrued_reward_raw ELSE 0 END), 0)
		FROM binggoplus_v2.staking_positions
		WHERE environment_id = (
			SELECT id FROM binggoplus_v2.environments WHERE chain_id = $1 AND project = 'binggoplus' LIMIT 1
		)
	`, domain.BSCTestnetChainID).Scan(&totalStaked, &liability)
	if err != nil {
		return nil, err
	}
	status.TotalStakedRaw = new(big.Int)
	status.TotalStakedRaw.SetString(totalStaked, 10)
	status.RewardLiabilityRaw = new(big.Int)
	status.RewardLiabilityRaw.SetString(liability, 10)

	// Staking config defaults — updated by chain reads when available
	status.RewardRateRaw = big.NewInt(0)
	status.MaxRewardRateRaw = big.NewInt(0)
	status.RewardReserveRaw = big.NewInt(0)
	status.EarlyPenaltyBps = domain.StakingEarlyPenaltyBps
	status.MaxLockSeconds = domain.StakingMaxLockSeconds

	_ = rewardRate
	_ = maxRewardRate
	_ = reserve

	return &status, nil
}
