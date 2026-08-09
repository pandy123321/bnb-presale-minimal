package domain

import (
	"math/big"
	"time"
)

// CostBasisState represents the cost basis tracking state for a wallet.
type CostBasisState string

const (
	CostBasisStateNone    CostBasisState = "NONE"
	CostBasisStateKnown   CostBasisState = "KNOWN"
	CostBasisStateUnknown CostBasisState = "UNKNOWN"
)

// TokenBalance represents a wallet's current token balance.
type TokenBalance struct {
	Account     Address
	BalanceRaw  *big.Int
	AsOfBlock   BlockNumber
	AsOfBlockHash TxHash
}

// CostBasisRecord represents a cost basis tracking entry.
type CostBasisRecord struct {
	Account        Address
	State          CostBasisState
	TokenAmountRaw *big.Int
	WBNBCostRaw    *big.Int
	AsOfBlock      BlockNumber
	AsOfBlockHash  TxHash
}

// TaxPhase represents a tax phase (e.g., launch-phase 30%, post-launch).
type TaxPhase struct {
	Name    string
	TaxBps  TaxBps
	Active  bool
}

// TaxSplit breaks down a total tax into component destinations.
type TaxSplit struct {
	TotalBps    TaxBps
	DividendBps TaxBps
	SupportBps  TaxBps
	BurnBps     TaxBps
}

// BalanceLedgerEntry represents a single entry in the token balance ledger.
type BalanceLedgerEntry struct {
	ID           string
	Account      Address
	Counterparty Address
	Direction    string // CREDIT or DEBIT
	AmountRaw    *big.Int
	Reason       string
	CreatedAt    time.Time
}
