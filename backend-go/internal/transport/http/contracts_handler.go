package http

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/pandy123321/bnb-presale-minimal/backend-go/internal/domain"
	"github.com/pandy123321/bnb-presale-minimal/backend-go/internal/store/queries"
)

// ContractsHandler returns GET /api/v2/projects/binggoplus/contracts.
func ContractsHandler(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ds, err := queries.GetActiveDeployment(r.Context(), pool)
		deploySetID := ""
		verificationStatus := domain.DeploymentStatusStaticVerified

		var contracts []domain.ContractInstance
		if err != nil {
			// Fall back to baseline if no active deployment in DB
			for _, key := range domain.KnownContractKeys() {
				if ci, ok := domain.BSCTestnetDeploymentBaseline[key]; ok {
					contracts = append(contracts, ci)
				}
			}
		} else {
			deploySetID = ds.ID
			verificationStatus = ds.Status
			contracts, err = queries.ListContractsByDeployment(r.Context(), pool, ds.ID)
			if err != nil {
				contracts = make([]domain.ContractInstance, 0)
			}
		}

		var contractResponses []ContractResponse
		for _, ci := range contracts {
			addr := string(ci.Address)
			blockNum := int64(ci.DeployBlock)
			deployTx := string(ci.DeployTx)
			blockHash := string(ci.DeployBlockHash)

			if addr == "" {
				if baseline, ok := domain.BSCTestnetDeploymentBaseline[ci.Key]; ok {
					addr = string(baseline.Address)
					blockNum = int64(baseline.DeployBlock)
					deployTx = string(baseline.DeployTx)
					blockHash = string(baseline.DeployBlockHash)
				}
			}

			contractResponses = append(contractResponses, ContractResponse{
				ContractKey:        ci.Key,
				EVMName:            ci.Key,
				Address:            addr,
				DeployTxHash:       deployTx,
				DeployBlockNumber:  formatBigIntString(blockNum),
				DeployBlockHash:    blockHash,
				RuntimeCodeHash:    ci.RuntimeCodeHash,
				VerificationStatus: verificationStatus,
			})
		}

		dataStatus := domain.DataStatusLive
		if verificationStatus == domain.DeploymentStatusStaticVerified {
			dataStatus = domain.DataStatusDegraded
		}

		meta := BuildMeta(r, dataStatus, deploySetID)
		JSON(w, r, http.StatusOK, contractResponses, meta)
	}
}
