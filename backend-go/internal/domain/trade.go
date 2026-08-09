package domain

import (
	"math/big"
	"time"
)

// TradeDirection represents buy or sell.
type TradeDirection string

const (
	TradeDirectionBuy  TradeDirection = "BUY"
	TradeDirectionSell TradeDirection = "SELL"
)

// Trade represents a completed buy or sell trade.
type Trade struct {
	ID             string
	Account        Address
	Direction      TradeDirection
	AmountInRaw    *big.Int
	AmountOutRaw   *big.Int
	TaxTotalRaw    *big.Int
	TaxDividendRaw *big.Int
	TaxSupportRaw  *big.Int
	TaxBurnRaw     *big.Int
	TaxBps         TaxBps
	CostState      CostBasisState
	BlockTime      time.Time
}

// QuoteRequest represents a request for a buy or sell quote.
type QuoteRequest struct {
	Buyer           Address `json:"buyer,omitempty"`
	Seller          Address `json:"seller,omitempty"`
	AmountInRaw     *big.Int
	SlippageBps     int
	DeadlineSeconds int
}

// QuoteResponse represents a quote from the chain.
type QuoteResponse struct {
	Direction      TradeDirection
	AmountInRaw    *big.Int
	AmountOutRaw   *big.Int
	MinimumOutRaw  *big.Int
	TaxBps         TaxBps
	Tax            TaxBreakdown
	CostState      CostBasisState
	OracleStatus   OracleState
	Deadline       time.Time
	Router         Address
}

// TaxBreakdown breaks down tax into total, dividend, support, and burn components.
type TaxBreakdown struct {
	TotalRaw    *big.Int `json:"total_raw"`
	DividendRaw *big.Int `json:"dividend_raw"`
	SupportRaw  *big.Int `json:"support_raw"`
	BurnRaw     *big.Int `json:"burn_raw"`
}

// TradeStats represents aggregated trade statistics.
type TradeStats struct {
	TradeCount int64
	BuyCount   int64
	SellCount  int64
	Volume24h  *big.Int
}
