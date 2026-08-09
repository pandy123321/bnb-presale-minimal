package http

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/pandy123321/bnb-presale-minimal/backend-go/internal/domain"
	"github.com/pandy123321/bnb-presale-minimal/backend-go/internal/store/queries"
)

// StakingPositionResponse is the JSON response for a staking position.
type StakingPositionResponse struct {
	PositionID       string `json:"position_id"`
	PrincipalRaw     string `json:"principal_raw"`
	AccruedRewardRaw string `json:"accrued_reward_raw"`
	UnlockAt         string `json:"unlock_at"`
	State            string `json:"state"`
}

// StakingStatusResponse is the JSON response for GET /staking/status.
type StakingStatusResponse struct {
	RewardRateRaw     string `json:"reward_rate_raw"`
	MaxRewardRateRaw  string `json:"max_reward_rate_raw"`
	RewardReserveRaw  string `json:"reward_reserve_raw"`
	RewardLiabilityRaw string `json:"reward_liability_raw"`
	TotalStakedRaw    string `json:"total_staked_raw"`
	EarlyPenaltyBps   int    `json:"early_penalty_bps"`
	MaxLockSeconds    int64  `json:"max_lock_seconds"`
}

// StakingPositionsHandler handles GET /api/v2/projects/binggoplus/wallets/{address}/staking/positions.
func StakingPositionsHandler(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		address := chi.URLParam(r, "address")
		if address == "" {
			meta := BuildMeta(r, domain.DataStatusLive, "")
			JSONError(w, r, http.StatusBadRequest, ErrCodeValidation, "address is required", nil, false, meta)
			return
		}

		ds, _ := queries.GetActiveDeployment(r.Context(), pool)
		deploySetID := ""
		if ds.ID != "" {
			deploySetID = ds.ID
		}

		positions, err := queries.ListStakingPositions(r.Context(), pool, domain.Address(address))
		if err != nil {
			positions = make([]domain.StakingPosition, 0)
		}

		var resp []StakingPositionResponse
		for _, sp := range positions {
			posID := "0"
			principal := "0"
			reward := "0"
			if sp.PositionID != nil {
				posID = sp.PositionID.String()
			}
			if sp.PrincipalRaw != nil {
				principal = sp.PrincipalRaw.String()
			}
			if sp.AccruedRewardRaw != nil {
				reward = sp.AccruedRewardRaw.String()
			}

			resp = append(resp, StakingPositionResponse{
				PositionID:       posID,
				PrincipalRaw:     principal,
				AccruedRewardRaw: reward,
				UnlockAt:         sp.UnlockAt.Format("2006-01-02T15:04:05Z"),
				State:            string(sp.State),
			})
		}

		meta := BuildMeta(r, domain.DataStatusLive, deploySetID)
		JSON(w, r, http.StatusOK, resp, meta)
	}
}

// StakingStatusHandler handles GET /api/v2/projects/binggoplus/staking/status.
func StakingStatusHandler(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ds, _ := queries.GetActiveDeployment(r.Context(), pool)
		deploySetID := ""
		if ds.ID != "" {
			deploySetID = ds.ID
		}

		status, err := queries.GetStakingStatus(r.Context(), pool)
		if err != nil {
			status = &domain.StakingStatus{}
		}

		rewardRate := "0"
		maxRewardRate := "0"
		reserve := "0"
		liability := "0"
		totalStaked := "0"

		if status.RewardRateRaw != nil {
			rewardRate = status.RewardRateRaw.String()
		}
		if status.MaxRewardRateRaw != nil {
			maxRewardRate = status.MaxRewardRateRaw.String()
		}
		if status.RewardReserveRaw != nil {
			reserve = status.RewardReserveRaw.String()
		}
		if status.RewardLiabilityRaw != nil {
			liability = status.RewardLiabilityRaw.String()
		}
		if status.TotalStakedRaw != nil {
			totalStaked = status.TotalStakedRaw.String()
		}

		resp := StakingStatusResponse{
			RewardRateRaw:     rewardRate,
			MaxRewardRateRaw:  maxRewardRate,
			RewardReserveRaw:  reserve,
			RewardLiabilityRaw: liability,
			TotalStakedRaw:    totalStaked,
			EarlyPenaltyBps:   status.EarlyPenaltyBps,
			MaxLockSeconds:    status.MaxLockSeconds,
		}

		meta := BuildMeta(r, domain.DataStatusLive, deploySetID)
		JSON(w, r, http.StatusOK, resp, meta)
	}
}
