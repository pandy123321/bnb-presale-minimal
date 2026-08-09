package http

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/pandy123321/bnb-presale-minimal/backend-go/internal/domain"
	"github.com/pandy123321/bnb-presale-minimal/backend-go/internal/store/queries"
)

// MarketSummaryResponse is the response for GET /market.
type MarketSummaryResponse struct {
	Price            *PriceResponse `json:"price"`
	TokenReserveRaw  *string        `json:"token_reserve_raw"`
	WBNBReserveRaw   *string        `json:"wbnb_reserve_raw"`
	HolderCount      *int           `json:"holder_count"`
	Volume24hRaw     *string        `json:"volume_24h_raw"`
	High24h          *PriceResponse `json:"high_24h"`
	Low24h           *PriceResponse `json:"low_24h"`
}

type PriceResponse struct {
	NumeratorRaw   string `json:"numerator_raw"`
	DenominatorRaw string `json:"denominator_raw"`
}

// MarketHandler returns GET /api/v2/projects/binggoplus/market.
func MarketHandler(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ds, _ := queries.GetActiveDeployment(r.Context(), pool)
		deploySetID := ""
		if ds.ID != "" {
			deploySetID = ds.ID
		}

		stats, err := queries.GetTradeStats(r.Context(), pool)
		if err != nil {
			stats = &domain.TradeStats{}
		}

		volStr := "0"
		if stats.Volume24h != nil {
			volStr = stats.Volume24h.String()
		}

		// Market price is derived from chain reads (placeholder until chain client is active).
		price := &PriceResponse{
			NumeratorRaw:   "1",
			DenominatorRaw: "1",
		}

		market := MarketSummaryResponse{
			Price:           price,
			TokenReserveRaw: nil,
			WBNBReserveRaw:  nil,
			HolderCount:     nil,
			Volume24hRaw:    &volStr,
			High24h:         nil,
			Low24h:          nil,
		}

		meta := BuildMeta(r, domain.DataStatusLive, deploySetID)
		JSON(w, r, http.StatusOK, market, meta)
	}
}
