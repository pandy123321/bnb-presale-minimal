// Package chain provides a read-only EVM RPC client interface for BSC Testnet.
// G2: interface definitions and placeholder — ethclient integration in G3+.
// MAINNET IS PERMANENTLY REJECTED. eth_sendRawTransaction is never exposed.
package chain

import (
	"context"
	"math/big"

	"github.com/pandy123321/bnb-presale-minimal/backend-go/internal/domain"
)

// RPCClient defines the read-only chain interface.
// All methods use context for cancellation and timeouts.
type RPCClient interface {
	// Call executes eth_call against a contract.
	Call(ctx context.Context, target domain.Address, data []byte, blockNumber *big.Int) ([]byte, error)

	// GetLogs executes eth_getLogs with filter criteria.
	GetLogs(ctx context.Context, address domain.Address, topics [][]domain.TxHash, fromBlock, toBlock *big.Int) ([]Log, error)

	// GetBlockByNumber fetches a block header by number.
	GetBlockByNumber(ctx context.Context, blockNumber *big.Int) (*BlockHeader, error)

	// GetBlockByHash fetches a block header by hash.
	GetBlockByHash(ctx context.Context, blockHash domain.TxHash) (*BlockHeader, error)

	// GetCode executes eth_getCode against an address.
	GetCode(ctx context.Context, address domain.Address, blockNumber *big.Int) ([]byte, error)

	// ChainID returns the connected chain ID (must be 97).
	ChainID(ctx context.Context) (domain.ChainID, error)

	// BlockNumber returns the latest block number.
	BlockNumber(ctx context.Context) (*big.Int, error)

	// Close releases the underlying connection.
	Close()
}

// Log represents a filtered chain log event.
type Log struct {
	Address     domain.Address
	Topics      []domain.TxHash
	Data        []byte
	BlockNumber uint64
	BlockHash   domain.TxHash
	TxHash      domain.TxHash
	TxIndex     uint
	LogIndex    uint
	Removed     bool
}

// BlockHeader represents a minimal block header from eth_getBlockByNumber.
type BlockHeader struct {
	Number     *big.Int
	Hash       domain.TxHash
	ParentHash domain.TxHash
	Timestamp  uint64
}

// NewRPCClient creates a new RPC client connected to the given URL.
// Returns an error if the URL is empty or the connection fails.
// G2 placeholder: returns a no-op implementation. Replace with ethclient.Dial in G3.
func NewRPCClient(rpcURL string) (RPCClient, error) {
	if rpcURL == "" {
		return nil, ErrRPCURLRequired
	}
	// Placeholder: ethclient.Dial in G3+
	return &placeholderClient{}, nil
}

type placeholderClient struct{}

func (c *placeholderClient) Call(ctx context.Context, target domain.Address, data []byte, blockNumber *big.Int) ([]byte, error) {
	return nil, ErrNotImplemented
}

func (c *placeholderClient) GetLogs(ctx context.Context, address domain.Address, topics [][]domain.TxHash, fromBlock, toBlock *big.Int) ([]Log, error) {
	return nil, ErrNotImplemented
}

func (c *placeholderClient) GetBlockByNumber(ctx context.Context, blockNumber *big.Int) (*BlockHeader, error) {
	return nil, ErrNotImplemented
}

func (c *placeholderClient) GetBlockByHash(ctx context.Context, blockHash domain.TxHash) (*BlockHeader, error) {
	return nil, ErrNotImplemented
}

func (c *placeholderClient) GetCode(ctx context.Context, address domain.Address, blockNumber *big.Int) ([]byte, error) {
	return nil, ErrNotImplemented
}

func (c *placeholderClient) ChainID(ctx context.Context) (domain.ChainID, error) {
	return domain.BSCTestnetChainID, nil
}

func (c *placeholderClient) BlockNumber(ctx context.Context) (*big.Int, error) {
	return big.NewInt(0), ErrNotImplemented
}

func (c *placeholderClient) Close() {}

// Sentinel errors.
var (
	ErrRPCURLRequired = &ChainError{Code: "RPC_URL_REQUIRED", Message: "BSC Testnet RPC URL is required"}
	ErrNotImplemented = &ChainError{Code: "NOT_IMPLEMENTED", Message: "chain client not yet implemented (G3+)"}
	ErrMainnetReject  = &ChainError{Code: "MAINNET_REJECTED", Message: "BSC Mainnet is permanently disabled"}
)

// ChainError is a typed chain client error.
type ChainError struct {
	Code    string
	Message string
}

func (e *ChainError) Error() string {
	return e.Code + ": " + e.Message
}
