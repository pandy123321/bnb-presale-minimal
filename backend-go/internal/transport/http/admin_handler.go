package http

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/pandy123321/bnb-presale-minimal/backend-go/internal/domain"
	"github.com/pandy123321/bnb-presale-minimal/backend-go/internal/store/queries"
)

// DashboardResponse is the response for GET /admin/dashboard.
type DashboardResponse struct {
	SystemStatus         domain.DataStatus `json:"system_status"`
	TradeCount           int64             `json:"trade_count"`
	BuyCount             int64             `json:"buy_count"`
	SellCount            int64             `json:"sell_count"`
	CurrentDividendEpoch *EpochSummary     `json:"current_dividend_epoch"`
	BuybackCount         int64             `json:"buyback_count"`
	ActiveLockerBatches  int64             `json:"active_locker_batches"`
	OpenAnomalies        int64             `json:"open_anomalies"`
}

type EpochSummary struct {
	EpochID    string `json:"epoch_id"`
	State      string `json:"state"`
	MerkleRoot string `json:"merkle_root,omitempty"`
}

// AdminDashboardHandler handles GET /admin-api/v2/projects/binggoplus/dashboard.
func AdminDashboardHandler(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ds, _ := queries.GetActiveDeployment(r.Context(), pool)
		deploySetID := ""
		if ds.ID != "" {
			deploySetID = ds.ID
		}

		status, _ := queries.GetSystemStatus(r.Context(), pool)
		dataStatus := domain.DataStatusLive
		if status != nil {
			dataStatus = status.DataStatus
		}

		stats, _ := queries.GetTradeStats(r.Context(), pool)
		tradeCount := int64(0)
		buyCount := int64(0)
		sellCount := int64(0)
		if stats != nil {
			tradeCount = stats.TradeCount
			buyCount = stats.BuyCount
			sellCount = stats.SellCount
		}

		// Current dividend epoch
		var currentEpoch *EpochSummary
		epoch, err := queries.GetCurrentEpoch(r.Context(), pool)
		if err == nil && epoch != nil {
			epochID := "0"
			if epoch.EpochID != nil {
				epochID = epoch.EpochID.String()
			}
			currentEpoch = &EpochSummary{
				EpochID:    epochID,
				State:      string(epoch.State),
				MerkleRoot: string(epoch.MerkleRoot),
			}
		}

		dashboard := DashboardResponse{
			SystemStatus:         dataStatus,
			TradeCount:           tradeCount,
			BuyCount:             buyCount,
			SellCount:            sellCount,
			CurrentDividendEpoch: currentEpoch,
			BuybackCount:         0,
			ActiveLockerBatches:  0,
			OpenAnomalies:        0,
		}

		meta := BuildMeta(r, dataStatus, deploySetID)
		JSON(w, r, http.StatusOK, dashboard, meta)
	}
}
