package http

import (
	"encoding/json"
	"math/big"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/pandy123321/bnb-presale-minimal/backend-go/internal/domain"
)

// QuoteRequestPayload is the request for /quotes/buy or /quotes/sell.
type QuoteRequestPayload struct {
	Buyer           string `json:"buyer,omitempty"`
	Seller          string `json:"seller,omitempty"`
	BnbInRaw        string `json:"bnb_in_raw,omitempty"`
	TokenInRaw      string `json:"token_in_raw,omitempty"`
	SlippageBps     int    `json:"slippage_bps"`
	DeadlineSeconds int    `json:"deadline_seconds"`
}

// QuoteResponsePayload is the response.
type QuoteResponsePayload struct {
	Direction      string            `json:"direction"`
	AmountInRaw    string            `json:"amount_in_raw"`
	AmountOutRaw   string            `json:"amount_out_raw"`
	MinimumOutRaw  string            `json:"minimum_out_raw"`
	TaxBps         int               `json:"tax_bps"`
	Tax            TaxBreakdownResp  `json:"tax"`
	CostState      string            `json:"cost_state,omitempty"`
	OracleStatus   string            `json:"oracle_status"`
	Deadline       string            `json:"deadline"`
	Router         string            `json:"router"`
}

type TaxBreakdownResp struct {
	TotalRaw    string `json:"total_raw"`
	DividendRaw string `json:"dividend_raw"`
	SupportRaw  string `json:"support_raw"`
	BurnRaw     string `json:"burn_raw"`
}

// PreviewBuyHandler handles POST /api/v2/projects/binggoplus/quotes/buy.
func PreviewBuyHandler(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req QuoteRequestPayload
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			meta := BuildMeta(r, domain.DataStatusLive, "")
			JSONError(w, r, http.StatusBadRequest, ErrCodeBadRequest, "invalid request body", nil, false, meta)
			return
		}

		if req.Buyer == "" || req.BnbInRaw == "" {
			meta := BuildMeta(r, domain.DataStatusLive, "")
			JSONError(w, r, http.StatusBadRequest, ErrCodeValidation, "buyer and bnb_in_raw are required", nil, false, meta)
			return
		}

		if req.SlippageBps < 0 || req.SlippageBps > 300 {
			meta := BuildMeta(r, domain.DataStatusLive, "")
			JSONError(w, r, http.StatusBadRequest, ErrCodeValidation, "slippage_bps must be 0-300", nil, false, meta)
			return
		}

		if req.DeadlineSeconds < 1 || req.DeadlineSeconds > 300 {
			meta := BuildMeta(r, domain.DataStatusLive, "")
			JSONError(w, r, http.StatusBadRequest, ErrCodeValidation, "deadline_seconds must be 1-300", nil, false, meta)
			return
		}

		amountIn, ok := new(big.Int).SetString(req.BnbInRaw, 10)
		if !ok {
			meta := BuildMeta(r, domain.DataStatusLive, "")
			JSONError(w, r, http.StatusBadRequest, ErrCodeValidation, "invalid bnb_in_raw", nil, false, meta)
			return
		}

		// Placeholder quote — full chain read in G3
		taxBps := 3000 // 30% base tax (launch phase)
		taxAmount := new(big.Int).Mul(amountIn, big.NewInt(int64(taxBps)))
		taxAmount.Div(taxAmount, big.NewInt(10000))

		// Simple 1:1 price placeholder
		amountOut := new(big.Int).Sub(amountIn, taxAmount)
		if amountOut.Sign() < 0 {
			amountOut = big.NewInt(0)
		}

		// Calculate minimum with slippage
		slippageFactor := big.NewInt(int64(10000 - req.SlippageBps))
		minimumOut := new(big.Int).Mul(amountOut, slippageFactor)
		minimumOut.Div(minimumOut, big.NewInt(10000))

		deadline := time.Now().UTC().Add(time.Duration(req.DeadlineSeconds) * time.Second)

		resp := QuoteResponsePayload{
			Direction:     "BUY",
			AmountInRaw:   amountIn.String(),
			AmountOutRaw:  amountOut.String(),
			MinimumOutRaw: minimumOut.String(),
			TaxBps:        taxBps,
			Tax: TaxBreakdownResp{
				TotalRaw:    taxAmount.String(),
				DividendRaw: new(big.Int).Div(taxAmount, big.NewInt(3)).String(),
				SupportRaw:  new(big.Int).Div(taxAmount, big.NewInt(3)).String(),
				BurnRaw:     new(big.Int).Div(taxAmount, big.NewInt(3)).String(),
			},
			OracleStatus: string(domain.OracleStateReady),
			Deadline:     deadline.Format(time.RFC3339),
			Router:       string(domain.BSCTestnetDeploymentBaseline[domain.ContractKeyPangu2TradeRouter].Address),
		}

		meta := BuildMeta(r, domain.DataStatusLive, "")
		JSON(w, r, http.StatusOK, resp, meta)
	}
}

// PreviewSellHandler handles POST /api/v2/projects/binggoplus/quotes/sell.
func PreviewSellHandler(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req QuoteRequestPayload
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			meta := BuildMeta(r, domain.DataStatusLive, "")
			JSONError(w, r, http.StatusBadRequest, ErrCodeBadRequest, "invalid request body", nil, false, meta)
			return
		}

		if req.Seller == "" || req.TokenInRaw == "" {
			meta := BuildMeta(r, domain.DataStatusLive, "")
			JSONError(w, r, http.StatusBadRequest, ErrCodeValidation, "seller and token_in_raw are required", nil, false, meta)
			return
		}

		if req.SlippageBps < 0 || req.SlippageBps > 300 {
			meta := BuildMeta(r, domain.DataStatusLive, "")
			JSONError(w, r, http.StatusBadRequest, ErrCodeValidation, "slippage_bps must be 0-300", nil, false, meta)
			return
		}

		if req.DeadlineSeconds < 1 || req.DeadlineSeconds > 300 {
			meta := BuildMeta(r, domain.DataStatusLive, "")
			JSONError(w, r, http.StatusBadRequest, ErrCodeValidation, "deadline_seconds must be 1-300", nil, false, meta)
			return
		}

		amountIn, ok := new(big.Int).SetString(req.TokenInRaw, 10)
		if !ok {
			meta := BuildMeta(r, domain.DataStatusLive, "")
			JSONError(w, r, http.StatusBadRequest, ErrCodeValidation, "invalid token_in_raw", nil, false, meta)
			return
		}

		// Placeholder quote — full chain read in G3
		taxBps := 3000 // 30% base tax (launch phase)
		taxAmount := new(big.Int).Mul(amountIn, big.NewInt(int64(taxBps)))
		taxAmount.Div(taxAmount, big.NewInt(10000))

		amountOut := new(big.Int).Sub(amountIn, taxAmount)
		if amountOut.Sign() < 0 {
			amountOut = big.NewInt(0)
		}

		slippageFactor := big.NewInt(int64(10000 - req.SlippageBps))
		minimumOut := new(big.Int).Mul(amountOut, slippageFactor)
		minimumOut.Div(minimumOut, big.NewInt(10000))

		deadline := time.Now().UTC().Add(time.Duration(req.DeadlineSeconds) * time.Second)

		resp := QuoteResponsePayload{
			Direction:     "SELL",
			AmountInRaw:   amountIn.String(),
			AmountOutRaw:  amountOut.String(),
			MinimumOutRaw: minimumOut.String(),
			TaxBps:        taxBps,
			Tax: TaxBreakdownResp{
				TotalRaw:    taxAmount.String(),
				DividendRaw: new(big.Int).Div(taxAmount, big.NewInt(3)).String(),
				SupportRaw:  new(big.Int).Div(taxAmount, big.NewInt(3)).String(),
				BurnRaw:     new(big.Int).Div(taxAmount, big.NewInt(3)).String(),
			},
			OracleStatus: string(domain.OracleStateReady),
			Deadline:     deadline.Format(time.RFC3339),
			Router:       string(domain.BSCTestnetDeploymentBaseline[domain.ContractKeyPangu2TradeRouter].Address),
		}

		meta := BuildMeta(r, domain.DataStatusLive, "")
		JSON(w, r, http.StatusOK, resp, meta)
	}
}
