package queries

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/pandy123321/bnb-presale-minimal/backend-go/internal/domain"
)

// --- Deployment queries ---

// InsertDeploymentSet inserts a new deployment set and returns its ID.
func InsertDeploymentSet(ctx context.Context, pool *pgxpool.Pool, ds domain.DeploymentSet) (string, error) {
	var id string
	err := pool.QueryRow(ctx, `
		INSERT INTO binggoplus_v2.deployment_sets (
			id, environment_id, version, source_commit, abi_manifest_hash, status, created_at, updated_at
		) VALUES (
			$1,
			(SELECT id FROM binggoplus_v2.environments WHERE chain_id = $2 AND project = 'binggoplus' LIMIT 1),
			$3, $4, $5, $6, $7, $7
		) RETURNING id
	`, ds.ID, domain.BSCTestnetChainID, ds.ID, ds.SourceCommit, ds.ABIHash, ds.Status, time.Now()).Scan(&id)
	if err != nil {
		return "", err
	}
	return id, nil
}

// GetActiveDeployment returns the current ACTIVE deployment set for the BSC testnet environment.
func GetActiveDeployment(ctx context.Context, pool *pgxpool.Pool) (domain.DeploymentSet, error) {
	var ds domain.DeploymentSet
	err := pool.QueryRow(ctx, `
		SELECT ds.id, ds.source_commit, COALESCE(ds.abi_manifest_hash, ''), ds.status, ds.activated_at
		FROM binggoplus_v2.deployment_sets ds
		JOIN binggoplus_v2.environments env ON env.id = ds.environment_id
		WHERE env.chain_id = $1 AND env.project = 'binggoplus' AND ds.status = 'ACTIVE'
		ORDER BY ds.activated_at DESC NULLS LAST
		LIMIT 1
	`, domain.BSCTestnetChainID).Scan(&ds.ID, &ds.SourceCommit, &ds.ABIHash, &ds.Status, &ds.ActivatedAt)
	if err != nil {
		return domain.DeploymentSet{}, err
	}
	return ds, nil
}

// GetContractInstance returns a single contract instance by deployment set and key.
func GetContractInstance(ctx context.Context, pool *pgxpool.Pool, deploymentSetID string, contractKey string) (domain.ContractInstance, error) {
	var ci domain.ContractInstance
	err := pool.QueryRow(ctx, `
		SELECT contract_key, address, deploy_block_number, deploy_tx_hash, deploy_block_hash,
		       COALESCE(runtime_code_hash, '')
		FROM binggoplus_v2.contract_instances
		WHERE deployment_set_id = $1 AND contract_key = $2
	`, deploymentSetID, contractKey).Scan(
		&ci.Key, &ci.Address, &ci.DeployBlock, &ci.DeployTx, &ci.DeployBlockHash, &ci.RuntimeCodeHash,
	)
	if err != nil {
		return domain.ContractInstance{}, err
	}
	return ci, nil
}

// ListContractsByDeployment returns all contract instances for a deployment set.
func ListContractsByDeployment(ctx context.Context, pool *pgxpool.Pool, deploymentSetID string) ([]domain.ContractInstance, error) {
	rows, err := pool.Query(ctx, `
		SELECT contract_key, address, deploy_block_number, deploy_tx_hash, deploy_block_hash,
		       COALESCE(runtime_code_hash, '')
		FROM binggoplus_v2.contract_instances
		WHERE deployment_set_id = $1
		ORDER BY deploy_block_number, deploy_log_index NULLS FIRST
	`, deploymentSetID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var instances []domain.ContractInstance
	for rows.Next() {
		var ci domain.ContractInstance
		if err := rows.Scan(&ci.Key, &ci.Address, &ci.DeployBlock, &ci.DeployTx, &ci.DeployBlockHash, &ci.RuntimeCodeHash); err != nil {
			return nil, err
		}
		instances = append(instances, ci)
	}
	return instances, rows.Err()
}
