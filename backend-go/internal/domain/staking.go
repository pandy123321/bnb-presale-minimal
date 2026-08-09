package domain

import (
	"math/big"
	"time"
)

// StakeState represents the state of a staking position.
type StakeState string

const (
	StakeStateActive        StakeState = "ACTIVE"
	StakeStateWithdrawn     StakeState = "WITHDRAWN"
	StakeStateEarlyWithdrawn StakeState = "EARLY_WITHDRAWN"
)

// StakingPosition represents a single staking position.
type StakingPosition struct {
	PositionID       *big.Int
	PrincipalRaw     *big.Int
	AccruedRewardRaw *big.Int
	UnlockAt         time.Time
	State            StakeState
}

// StakingEvent represents a staking-related chain event.
type StakingEvent struct {
	ID           string
	Account      Address
	PositionID   *big.Int
	EventType    string
	PrincipalRaw *big.Int
	RewardRaw    *big.Int
	PenaltyRaw   *big.Int
}

// StakingStatus represents public staking pool status.
type StakingStatus struct {
	RewardRateRaw    *big.Int
	MaxRewardRateRaw *big.Int
	RewardReserveRaw *big.Int
	RewardLiabilityRaw *big.Int
	TotalStakedRaw   *big.Int
	EarlyPenaltyBps  int
	MaxLockSeconds   int64
}

// StakingConfig holds staking configuration constants.
const (
	StakingEarlyPenaltyBps = 1000   // 10%
	StakingMaxLockSeconds  = 63072000 // 2 years
)
