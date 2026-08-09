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
