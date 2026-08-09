package domain

import (
	"math/big"
	"time"
)

// EpochState represents the state machine state of a dividend epoch.
type EpochState string

const (
	EpochStateDraft            EpochState = "DRAFT"
	EpochStateSnapshotBuilding EpochState = "SNAPSHOT_BUILDING"
	EpochStateSnapshotReady    EpochState = "SNAPSHOT_READY"
	EpochStateApprovalPending  EpochState = "APPROVAL_PENDING"
	EpochStateApproved         EpochState = "APPROVED"
	EpochStatePublishQueued    EpochState = "PUBLISH_QUEUED"
	EpochStateClaimOpen        EpochState = "CLAIM_OPEN"
	EpochStateCloseQueued      EpochState = "CLOSE_QUEUED"
	EpochStateClosed           EpochState = "CLOSED"
	EpochStateCancelled        EpochState = "CANCELLED"
	EpochStateFailed           EpochState = "FAILED"
)

// DividendEpoch represents a dividend distribution epoch.
type DividendEpoch struct {
	ID                     string
	EpochID                *big.Int
	State                  EpochState
	SnapshotBlockNumber    *big.Int
	SnapshotBlockHash      TxHash
	TotalRewardRaw         *big.Int
	MerkleRoot             TxHash
	ClaimStart             *time.Time
	ClaimEnd               *time.Time
	CarryRaw               *big.Int
	CreatedAt              time.Time
	UpdatedAt              time.Time
}

// DividendAllocation represents a single account's allocation in a dividend artifact.
type DividendAllocation struct {
	Account             Address
	Rank                int
	Tier                int
	EffectiveBalanceRaw *big.Int
	AllocationRaw       *big.Int
	LeafHash            TxHash
	Proof               []TxHash
}

// Top100Tier returns the tier for a given rank (1-based).
// Tier1 (1-10): 35%, Tier2 (11-30): 25%, Tier3 (31-60): 25%, Tier4 (61-100): 15%.
func Top100Tier(rank int) int {
	switch {
	case rank >= 1 && rank <= 10:
		return 1
	case rank >= 11 && rank <= 30:
		return 2
	case rank >= 31 && rank <= 60:
		return 3
	case rank >= 61 && rank <= 100:
		return 4
	default:
		return 0
	}
}

// TierShareBps returns the share in basis points for a given tier.
func TierShareBps(tier int) int {
	switch tier {
	case 1:
		return 3500 // 35%
	case 2:
		return 2500 // 25%
	case 3:
		return 2500 // 25%
	case 4:
		return 1500 // 15%
	default:
		return 0
	}
}
