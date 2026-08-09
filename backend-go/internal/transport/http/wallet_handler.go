package http

import (
	"math/big"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/pandy123321/bnb-presale-minimal/backend-go/internal/domain"
	"github.com/pandy123321/bnb-presale-minimal/backend-go/internal/store/queries"
)

// WalletSummaryResponse is the response for GET /wallets/{address}/summary.
type WalletSummaryResponse struct {
	Address               string  `json:"address"`
	TokenBalanceRaw       string  `json:"token_balance_raw"`
	BNBBalanceRaw         string  `json:"bnb_balance_raw"`
	StakedPrincipalRaw    string  `json:"staked_principal_raw"`
	AccruedRewardRaw      string  `json:"accrued_reward_raw"`
	EffectiveBalanceRaw   *string `json:"effective_balance_raw"`
	DividendRank          *int    `json:"dividend_rank"`
	ClaimableDividendRaw  *string `json:"claimable_dividend_raw"`
}

// WalletSummaryHandler handles GET /api/v2/projects/binggoplus/wallets/{address}/summary.
func WalletSummaryHandler(pool *pgxpool.Pool) http.HandlerFunc {
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

		// Get token balance
		tokenBal := "0"
		tb, err := queries.GetTokenBalance(r.Context(), pool, domain.Address(address))
		if err == nil && tb != nil && tb.BalanceRaw != nil {
			tokenBal = tb.BalanceRaw.String()
		}

		// Get staking positions (aggregate principal + rewards)
		stakedPrincipal := "0"
		accruedReward := "0"
		positions, err := queries.ListStakingPositions(r.Context(), pool, domain.Address(address))
		if err == nil {
			totalPrincipal := new(big.Int)
			totalReward := new(big.Int)
			for _, sp := range positions {
				if sp.PrincipalRaw != nil {
					totalPrincipal.Add(totalPrincipal, sp.PrincipalRaw)
				}
				if sp.AccruedRewardRaw != nil {
					totalReward.Add(totalReward, sp.AccruedRewardRaw)
				}
			}
			stakedPrincipal = totalPrincipal.String()
			accruedReward = totalReward.String()
		}

		summary := WalletSummaryResponse{
			Address:             address,
			TokenBalanceRaw:     tokenBal,
			BNBBalanceRaw:       "0",
			StakedPrincipalRaw:  stakedPrincipal,
			AccruedRewardRaw:    accruedReward,
			EffectiveBalanceRaw: nil,
			DividendRank:        nil,
			ClaimableDividendRaw: nil,
		}

		meta := BuildMeta(r, domain.DataStatusLive, deploySetID)
		JSON(w, r, http.StatusOK, summary, meta)
	}
}

// WalletTransactionsHandler handles GET /api/v2/projects/binggoplus/wallets/{address}/transactions.
func WalletTransactionsHandler(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		address := chi.URLParam(r, "address")
		if address == "" {
			meta := BuildMeta(r, domain.DataStatusLive, "")
			JSONError(w, r, http.StatusBadRequest, ErrCodeValidation, "address is required", nil, false, meta)
			return
		}

		limit := 25
		if l := r.URL.Query().Get("limit"); l != "" {
			if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 && parsed <= 100 {
				limit = parsed
			}
		}
		cursor := r.URL.Query().Get("cursor")

		ds, _ := queries.GetActiveDeployment(r.Context(), pool)
		deploySetID := ""
		if ds.ID != "" {
			deploySetID = ds.ID
		}

		activities, nextCursor, err := queries.GetTradeActivity(r.Context(), pool, domain.Address(address), limit, cursor)
		if err != nil {
			activities = make([]queries.ActivityEntry, 0)
		}

		meta := BuildMeta(r, domain.DataStatusLive, deploySetID)
		SetCursor(&meta, nextCursor)
		JSON(w, r, http.StatusOK, activities, meta)
	}
}
