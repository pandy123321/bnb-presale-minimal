package queries

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/pandy123321/bnb-presale-minimal/backend-go/internal/domain"
)

// CreateCommand inserts a new governance command.
func CreateCommand(ctx context.Context, pool *pgxpool.Pool, cmd domain.GovernanceCommand, environmentID string, deploymentSetID string) (string, error) {
	var id string
	err := pool.QueryRow(ctx, `
		INSERT INTO binggoplus_v2.governance_commands (
			id, environment_id, deployment_set_id, action,
			target_contract_key, target_address, selector, parameters,
			request_hash, requested_by, state, expires_at, created_at, updated_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $13)
		RETURNING id
	`,
		cmd.ID, environmentID, deploymentSetID, cmd.Action,
		cmd.TargetContractKey, string(cmd.TargetAddress), cmd.Selector, cmd.Parameters,
		cmd.RequestHash, cmd.RequestedBy, string(cmd.State),
		cmd.ExpiresAt, time.Now(),
	).Scan(&id)
	if err != nil {
		return "", err
	}
	return id, nil
}

// GetCommand returns a governance command by ID.
func GetCommand(ctx context.Context, pool *pgxpool.Pool, commandID string) (*domain.GovernanceCommand, error) {
	var cmd domain.GovernanceCommand
	var targetAddress string

	err := pool.QueryRow(ctx, `
		SELECT id, action, target_contract_key, target_address, selector,
		       parameters, request_hash, requested_by, state,
		       expires_at, created_at, updated_at
		FROM binggoplus_v2.governance_commands
		WHERE id = $1
	`, commandID).Scan(
		&cmd.ID, &cmd.Action, &cmd.TargetContractKey, &targetAddress, &cmd.Selector,
		&cmd.Parameters, &cmd.RequestHash, &cmd.RequestedBy, &cmd.State,
		&cmd.ExpiresAt, &cmd.CreatedAt, &cmd.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	cmd.TargetAddress = domain.Address(targetAddress)
	return &cmd, nil
}

// InsertApproval inserts an admin approval/rejection for a governance command.
func InsertApproval(ctx context.Context, pool *pgxpool.Pool, approval domain.ApprovalRecord) error {
	_, err := pool.Exec(ctx, `
		INSERT INTO binggoplus_v2.governance_approvals (
			id, command_id, admin_user_id, decision, reason, decided_at
		) VALUES ($1, $2, $3, $4, $5, $6)
		ON CONFLICT (command_id, admin_user_id) DO NOTHING
	`,
		approval.ID, approval.CommandID, approval.AdminUserID,
		approval.Decision, approval.Reason, approval.DecidedAt,
	)
	return err
}

// ListCommands returns paginated governance commands.
func ListCommands(ctx context.Context, pool *pgxpool.Pool, limit int, cursor string) ([]domain.GovernanceCommand, string, error) {
	if limit <= 0 || limit > 100 {
		limit = 25
	}

	rows, err := pool.Query(ctx, `
		SELECT id, action, target_contract_key, target_address, selector,
		       parameters, request_hash, requested_by, state,
		       expires_at, created_at, updated_at
		FROM binggoplus_v2.governance_commands
		WHERE ($1 = '' OR id > $1)
		ORDER BY created_at DESC
		LIMIT $2
	`, cursor, limit+1)
	if err != nil {
		return nil, "", err
	}
	defer rows.Close()

	var commands []domain.GovernanceCommand
	for rows.Next() {
		var cmd domain.GovernanceCommand
		var targetAddress string
		if err := rows.Scan(
			&cmd.ID, &cmd.Action, &cmd.TargetContractKey, &targetAddress, &cmd.Selector,
			&cmd.Parameters, &cmd.RequestHash, &cmd.RequestedBy, &cmd.State,
			&cmd.ExpiresAt, &cmd.CreatedAt, &cmd.UpdatedAt,
		); err != nil {
			return nil, "", err
		}
		cmd.TargetAddress = domain.Address(targetAddress)
		commands = append(commands, cmd)
	}
	if err := rows.Err(); err != nil {
		return nil, "", err
	}

	var nextCursor string
	if len(commands) > limit {
		nextCursor = commands[limit-1].ID
		commands = commands[:limit]
	}

	return commands, nextCursor, nil
}
