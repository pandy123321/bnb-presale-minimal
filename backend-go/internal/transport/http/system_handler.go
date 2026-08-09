package http

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/pandy123321/bnb-presale-minimal/backend-go/internal/domain"
	"github.com/pandy123321/bnb-presale-minimal/backend-go/internal/store/queries"
)

// SystemStatusResponse is the response for GET /system-status.
type SystemStatusResponse struct {
	Status       domain.DataStatus `json:"status"`
	TradingOpen  bool              `json:"trading_open"`
	Paused       bool              `json:"paused"`
	OracleStatus string            `json:"oracle_status"`
}

// SystemStatusHandler returns GET /api/v2/projects/binggoplus/system-status.
func SystemStatusHandler(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		status, err := queries.GetSystemStatus(r.Context(), pool)
		if err != nil {
			meta := BuildMeta(r, domain.DataStatusUnavailable, "")
			JSONError(w, r, http.StatusServiceUnavailable, ErrCodeInternal, "failed to get system status", nil, true, meta)
			return
		}

		ds, _ := queries.GetActiveDeployment(r.Context(), pool)
		deploySetID := ""
		if ds.ID != "" {
			deploySetID = ds.ID
		}

		resp := SystemStatusResponse{
			Status:       status.DataStatus,
			TradingOpen:  true,
			Paused:       false,
			OracleStatus: string(domain.OracleStateReady),
		}

		meta := BuildMetaWithBlock(r, status.DataStatus, deploySetID, status.ObservedBlockNum, status.ObservedBlockHash)
		JSON(w, r, http.StatusOK, resp, meta)
	}
}
