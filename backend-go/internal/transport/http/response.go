package http

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"log/slog"
	"net/http"
	"time"

	"github.com/pandy123321/bnb-presale-minimal/backend-go/internal/domain"
)

// --- Meta envelope (matches OpenAPI BaseEnvelope) ---

type Meta struct {
	RequestID       string              `json:"request_id"`
	Project         string              `json:"project"`
	Environment     string              `json:"environment"`
	ChainID         int64               `json:"chain_id"`
	DeploymentSetID string              `json:"deployment_set_id"`
	DataStatus      domain.DataStatus   `json:"data_status"`
	ObservedBlock   *ObservedBlock      `json:"observed_block"`
	GeneratedAt     time.Time           `json:"generated_at"`
	SchemaVersion   string              `json:"schema_version"`
	NextCursor      *string             `json:"next_cursor,omitempty"`
}

type ObservedBlock struct {
	Number   string `json:"number"`
	Hash     string `json:"hash"`
	Finality string `json:"finality"`
}

// --- Response helpers ---

// Envelope wraps data with meta.
type Envelope struct {
	Data interface{} `json:"data"`
	Meta Meta        `json:"meta"`
}

// ErrorEnvelope wraps an error with meta (matches OpenAPI ErrorEnvelope).
type ErrorEnvelope struct {
	Error APIError `json:"error"`
	Meta  Meta     `json:"meta"`
}

// APIError represents a structured API error.
type APIError struct {
	Code      string      `json:"code"`
	Message   string      `json:"message"`
	Details   interface{} `json:"details,omitempty"`
	Retryable bool        `json:"retryable"`
}

// Error codes — stable, never renumber.
const (
	ErrCodeBadRequest      = "BAD_REQUEST"
	ErrCodeUnauthorized    = "UNAUTHORIZED"
	ErrCodeForbidden       = "FORBIDDEN"
	ErrCodeNotFound        = "NOT_FOUND"
	ErrCodeConflict        = "CONFLICT"
	ErrCodeRateLimited     = "RATE_LIMITED"
	ErrCodeInternal        = "INTERNAL_ERROR"
	ErrCodeServiceDown     = "SERVICE_DOWN"
	ErrCodeChainDown       = "CHAIN_DOWN"
	ErrCodeMainnetRejected = "MAINNET_REJECTED"
	ErrCodeValidation      = "VALIDATION_ERROR"
)

// JSON writes a 200 OK envelope response.
func JSON(w http.ResponseWriter, r *http.Request, statusCode int, data interface{}, meta Meta) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	if err := json.NewEncoder(w).Encode(Envelope{Data: data, Meta: meta}); err != nil {
		slog.Error("failed to encode JSON response", "error", err)
	}
}

// JSONError writes a structured error envelope response.
func JSONError(w http.ResponseWriter, r *http.Request, statusCode int, code string, message string, details interface{}, retryable bool, meta Meta) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	if err := json.NewEncoder(w).Encode(ErrorEnvelope{
		Error: APIError{
			Code:      code,
			Message:   message,
			Details:   details,
			Retryable: retryable,
		},
		Meta: meta,
	}); err != nil {
		slog.Error("failed to encode JSON error response", "error", err)
	}
}

// NoContent writes a 204 No Content response.
func NoContent(w http.ResponseWriter) {
	w.WriteHeader(http.StatusNoContent)
}

// --- Meta builder ---

// BuildMeta creates a Meta struct from request context.
func BuildMeta(r *http.Request, dataStatus domain.DataStatus, deploymentSetID string) Meta {
	requestID := r.Header.Get("X-Request-ID")
	if requestID == "" {
		requestID = newUUID()
	}

	return Meta{
		RequestID:       requestID,
		Project:         "binggoplus",
		Environment:     "bsc_testnet",
		ChainID:         int64(domain.BSCTestnetChainID),
		DeploymentSetID: deploymentSetID,
		DataStatus:      dataStatus,
		GeneratedAt:     time.Now().UTC(),
		SchemaVersion:   "v2",
	}
}

// BuildMetaWithBlock creates a Meta struct including observed block info.
func BuildMetaWithBlock(r *http.Request, dataStatus domain.DataStatus, deploymentSetID string, blockNum int64, blockHash string) Meta {
	meta := BuildMeta(r, dataStatus, deploymentSetID)
	if blockNum > 0 {
		meta.ObservedBlock = &ObservedBlock{
			Number:   formatBlockNum(blockNum),
			Hash:     blockHash,
			Finality: "CONFIRMED",
		}
	}
	return meta
}

// SetCursor sets the next cursor on the Meta if non-empty.
func SetCursor(meta *Meta, cursor string) {
	if cursor != "" {
		meta.NextCursor = &cursor
	}
}

func formatBlockNum(n int64) string {
	return formatBigIntString(n)
}

// newUUID generates a v4 UUID using crypto/rand.
func newUUID() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	b[6] = (b[6] & 0x0f) | 0x40 // version 4
	b[8] = (b[8] & 0x3f) | 0x80 // variant 10
	return hex.EncodeToString(b[:4]) + "-" +
		hex.EncodeToString(b[4:6]) + "-" +
		hex.EncodeToString(b[6:8]) + "-" +
		hex.EncodeToString(b[8:10]) + "-" +
		hex.EncodeToString(b[10:16])
}

func formatBigIntString(n int64) string {
	// Avoid importing math/big — simple formatting
	if n == 0 {
		return "0"
	}
	result := ""
	neg := false
	if n < 0 {
		neg = true
		n = -n
	}
	for n > 0 {
		result = string(rune('0'+n%10)) + result
		n /= 10
	}
	if neg {
		result = "-" + result
	}
	return result
}
