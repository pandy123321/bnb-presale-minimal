// Package domain contains pure value objects and domain type definitions.
// G1: type definitions only — no business logic, no repository interfaces, no service implementations.
//
// Business logic will be added in G2+.
package domain

import "math/big"

// Wei represents a token amount in wei (10^-18 precision).
// All financial calculations MUST use Wei, never float64.
type Wei struct {
	Value *big.Int
}

// TokenAmount represents a display-level token amount with decimals.
type TokenAmount struct {
	Value    *big.Int
	Decimals uint8
}

// Address is an Ethereum address (20 bytes).
type Address string

// TxHash is a transaction hash (32 bytes).
type TxHash string

// Role represents an AccessControl role identifier.
type Role string

// ChainID identifies a blockchain network.
type ChainID int64

// BlockNumber is an Ethereum block number.
type BlockNumber int64

// EpochID identifies a dividend epoch.
type EpochID struct {
	Value *big.Int
}

// BatchID identifies a locker batch.
type BatchID struct {
	Value *big.Int
}

// CommandID is a UUID for governance commands.
type CommandID string

// Nonce is an Ethereum address nonce.
type Nonce uint64

// Signature is an ECDSA signature (65 bytes hex).
type Signature string

// TaxBps represents tax basis points (0-10000).
type TaxBps uint16

// PauseState indicates whether a contract is paused.
type PauseState string

const (
	PauseStatePaused   PauseState = "PAUSED"
	PauseStateUnpaused PauseState = "UNPAUSED"
)

// OracleState represents the TWAP oracle readiness state.
type OracleState string

const (
	OracleStateUninitialized OracleState = "UNINITIALIZED"
	OracleStateAccumulating  OracleState = "ACCUMULATING"
	OracleStateReady         OracleState = "READY"
	OracleStateLiquidityLow  OracleState = "LIQUIDITY_LOW"
)

// DataStatus represents data freshness/availability.
type DataStatus string

const (
	DataStatusSyncing     DataStatus = "SYNCING"
	DataStatusLive        DataStatus = "LIVE"
	DataStatusStale       DataStatus = "STALE"
	DataStatusDegraded    DataStatus = "DEGRADED"
	DataStatusUnavailable DataStatus = "UNAVAILABLE"
)

// NewWei creates a Wei from an int64.
func NewWei(v int64) Wei {
	return Wei{Value: big.NewInt(v)}
}

// NewWeiFromBig creates Wei from a big.Int.
func NewWeiFromBig(v *big.Int) Wei {
	if v == nil {
		return Wei{Value: new(big.Int)}
	}
	return Wei{Value: new(big.Int).Set(v)}
}

// String returns the decimal string representation.
func (w Wei) String() string {
	if w.Value == nil {
		return "0"
	}
	return w.Value.String()
}

// IsZero returns true if the Wei value is zero or nil.
func (w Wei) IsZero() bool {
	return w.Value == nil || w.Value.Sign() == 0
}
