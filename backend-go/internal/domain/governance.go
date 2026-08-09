package domain

import (
	"time"
)

// CommandState represents the state machine state of a governance command.
type CommandState string

const (
	CommandStateCreated          CommandState = "CREATED"
	CommandStateValidated        CommandState = "VALIDATED"
	CommandStatePendingApproval  CommandState = "PENDING_APPROVAL"
	CommandStateApproved         CommandState = "APPROVED"
	CommandStateQueued           CommandState = "QUEUED"
	CommandStateSigning          CommandState = "SIGNING"
	CommandStateSubmitted        CommandState = "SUBMITTED"
	CommandStateConfirmed        CommandState = "CONFIRMED"
	CommandStateFinalized        CommandState = "FINALIZED"
	CommandStateRejected         CommandState = "REJECTED"
	CommandStateCancelled        CommandState = "CANCELLED"
	CommandStateFailed           CommandState = "FAILED"
	CommandStateExpired          CommandState = "EXPIRED"
)

// GovernanceCommand represents an immutable governance action command.
type GovernanceCommand struct {
	ID                           string
	Action                       string
	TargetContractKey            string
	TargetAddress                Address
	Selector                     string
	Parameters                   map[string]interface{}
	RequestHash                  string
	RequestedBy                  string
	State                        CommandState
	ExpiresAt                    *time.Time
	CreatedAt                    time.Time
	UpdatedAt                    time.Time
	DividendPublishPreflightID   string
	DividendArtifactID           string
	DividendArtifactSHA256       string
	DividendExpectedMerkleRoot   TxHash
	DividendExpectedTotalRewardRaw string
}

// ApprovalRecord represents an admin approval/rejection of a governance command.
type ApprovalRecord struct {
	ID          string
	CommandID   string
	AdminUserID string
	Decision    string // APPROVE or REJECT
	Reason      string
	DecidedAt   time.Time
}
