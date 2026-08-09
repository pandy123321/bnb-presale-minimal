package http

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/pandy123321/bnb-presale-minimal/backend-go/internal/domain"
	"github.com/pandy123321/bnb-presale-minimal/backend-go/internal/store/queries"
)

// BingGoPlusConfigResponse is the response for GET /config.
type BingGoPlusConfigResponse struct {
	Brand        string              `json:"brand"`
	OnChainToken OnChainToken        `json:"on_chain_token"`
	ChainID      int64               `json:"chain_id"`
	TradingOpen  bool                `json:"trading_open"`
	Contracts    []ContractResponse  `json:"contracts"`
	QuoteLimits  QuoteLimits         `json:"quote_limits"`
}

type OnChainToken struct {
	Name     string `json:"name"`
	Symbol   string `json:"symbol"`
	Decimals int    `json:"decimals"`
}

type ContractResponse struct {
	ContractKey        string `json:"contract_key"`
	EVMName            string `json:"evm_name"`
	Address            string `json:"address"`
	DeployTxHash       string `json:"deploy_tx_hash"`
	DeployBlockNumber  string `json:"deploy_block_number"`
	DeployBlockHash    string `json:"deploy_block_hash"`
	RuntimeCodeHash    string `json:"runtime_code_hash,omitempty"`
	VerificationStatus string `json:"verification_status"`
}

type QuoteLimits struct {
	MaxSlippageBps    int `json:"max_slippage_bps"`
	MaxDeadlineSeconds int `json:"max_deadline_seconds"`
}

// ConfigHandler returns GET /api/v2/projects/binggoplus/config.
func ConfigHandler(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ds, err := queries.GetActiveDeployment(r.Context(), pool)
		if err != nil {
			meta := BuildMeta(r, domain.DataStatusUnavailable, "")
			JSONError(w, r, http.StatusServiceUnavailable, ErrCodeInternal, "failed to load deployment config", nil, true, meta)
			return
		}

		contracts, err := queries.ListContractsByDeployment(r.Context(), pool, ds.ID)
		if err != nil {
			contracts = make([]domain.ContractInstance, 0)
		}

		var contractResponses []ContractResponse
		for _, ci := range contracts {
			// Fall back to baseline if DB has no record
			addr := string(ci.Address)
			blockNum := int64(ci.DeployBlock)
			deployTx := string(ci.DeployTx)
			blockHash := string(ci.DeployBlockHash)
			runtimeHash := ci.RuntimeCodeHash

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
				RuntimeCodeHash:    runtimeHash,
				VerificationStatus: ds.Status,
			})
		}

		dataStatus := domain.DataStatusLive
		if ds.Status == domain.DeploymentStatusStaticVerified {
			dataStatus = domain.DataStatusDegraded
		}

		config := BingGoPlusConfigResponse{
			Brand: "BingGoPlus",
			OnChainToken: OnChainToken{
				Name:     "PANGU2",
				Symbol:   "PANGU2",
				Decimals: 18,
			},
			ChainID:     int64(domain.BSCTestnetChainID),
			TradingOpen: true,
			Contracts:   contractResponses,
			QuoteLimits: QuoteLimits{
				MaxSlippageBps:    300,
				MaxDeadlineSeconds: 300,
			},
		}

		meta := BuildMeta(r, dataStatus, ds.ID)
		JSON(w, r, http.StatusOK, config, meta)
	}
}
