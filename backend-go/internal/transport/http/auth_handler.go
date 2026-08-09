package http

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/pandy123321/bnb-presale-minimal/backend-go/internal/domain"
)

// --- Auth request/response types ---

type WalletChallengeRequest struct {
	Address string `json:"address"`
	ChainID int64  `json:"chain_id"`
}

type WalletChallengeResponse struct {
	ChallengeID string `json:"challenge_id"`
	Message     string `json:"message"`
	ExpiresAt   string `json:"expires_at"`
}

type WalletVerifyRequest struct {
	ChallengeID string `json:"challenge_id"`
	Address     string `json:"address"`
	Signature   string `json:"signature"`
}

// --- Handlers ---

// IssueNonceHandler handles POST /api/v2/projects/binggoplus/auth/nonce.
func IssueNonceHandler(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req WalletChallengeRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			meta := BuildMeta(r, domain.DataStatusLive, "")
			JSONError(w, r, http.StatusBadRequest, ErrCodeBadRequest, "invalid request body", nil, false, meta)
			return
		}

		// Reject Mainnet
		if req.ChainID == int64(domain.BSCMainnetChainID) {
			meta := BuildMeta(r, domain.DataStatusLive, "")
			JSONError(w, r, http.StatusForbidden, ErrCodeMainnetRejected, "BSC Mainnet is permanently disabled", nil, false, meta)
			return
		}

		if req.ChainID != int64(domain.BSCTestnetChainID) {
			meta := BuildMeta(r, domain.DataStatusLive, "")
			JSONError(w, r, http.StatusBadRequest, ErrCodeValidation, "chain_id must be 97", nil, false, meta)
			return
		}

		if req.Address == "" || len(req.Address) != 42 {
			meta := BuildMeta(r, domain.DataStatusLive, "")
			JSONError(w, r, http.StatusBadRequest, ErrCodeValidation, "invalid address", nil, false, meta)
			return
		}

		// Generate nonce
		nonceBytes := make([]byte, 32)
		if _, err := rand.Read(nonceBytes); err != nil {
			meta := BuildMeta(r, domain.DataStatusUnavailable, "")
			JSONError(w, r, http.StatusInternalServerError, ErrCodeInternal, "failed to generate nonce", nil, true, meta)
			return
		}

		nonce := hex.EncodeToString(nonceBytes)
		challengeID := newUUID()
		message := fmt.Sprintf("Sign this message to authenticate with BingGoPlus: %s", nonce)
		expiresAt := time.Now().UTC().Add(5 * time.Minute)

		// Store challenge in wallet_challenges table
		_, err := pool.Exec(r.Context(), `
			INSERT INTO binggoplus_v2.wallet_challenges (
				id, environment_id, address, nonce_hash, message, chain_id, issued_at, expires_at
			) VALUES (
				$1,
				(SELECT id FROM binggoplus_v2.environments WHERE chain_id = $2 AND project = 'binggoplus' LIMIT 1),
				$3, $4, $5, $6, $7, $8
			)
		`, challengeID, domain.BSCTestnetChainID, req.Address, nonce, message, req.ChainID, time.Now(), expiresAt)

		if err != nil {
			meta := BuildMeta(r, domain.DataStatusUnavailable, "")
			JSONError(w, r, http.StatusInternalServerError, ErrCodeInternal, "failed to create challenge", nil, true, meta)
			return
		}

		meta := BuildMeta(r, domain.DataStatusLive, "")
		JSON(w, r, http.StatusCreated, WalletChallengeResponse{
			ChallengeID: challengeID,
			Message:     message,
			ExpiresAt:   expiresAt.Format(time.RFC3339),
		}, meta)
	}
}

// VerifyWalletHandler handles POST /api/v2/projects/binggoplus/auth/verify.
func VerifyWalletHandler(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req WalletVerifyRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			meta := BuildMeta(r, domain.DataStatusLive, "")
			JSONError(w, r, http.StatusBadRequest, ErrCodeBadRequest, "invalid request body", nil, false, meta)
			return
		}

		if req.ChallengeID == "" || req.Address == "" || req.Signature == "" {
			meta := BuildMeta(r, domain.DataStatusLive, "")
			JSONError(w, r, http.StatusBadRequest, ErrCodeValidation, "challenge_id, address, and signature are required", nil, false, meta)
			return
		}

		// Verify the challenge exists and hasn't expired
		var issuedAt, expiresAt time.Time
		var consumedAt *time.Time
		err := pool.QueryRow(r.Context(), `
			SELECT issued_at, expires_at, consumed_at
			FROM binggoplus_v2.wallet_challenges
			WHERE id = $1 AND address = $2
		`, req.ChallengeID, req.Address).Scan(&issuedAt, &expiresAt, &consumedAt)
		if err != nil {
			meta := BuildMeta(r, domain.DataStatusLive, "")
			JSONError(w, r, http.StatusNotFound, ErrCodeNotFound, "challenge not found", nil, false, meta)
			return
		}

		if consumedAt != nil {
			meta := BuildMeta(r, domain.DataStatusLive, "")
			JSONError(w, r, http.StatusConflict, ErrCodeConflict, "challenge already used", nil, false, meta)
			return
		}

		if time.Now().UTC().After(expiresAt) {
			meta := BuildMeta(r, domain.DataStatusLive, "")
			JSONError(w, r, http.StatusBadRequest, ErrCodeBadRequest, "challenge expired", nil, false, meta)
			return
		}

		// Signature verification placeholder — full ECDSA recovery in G3+
		// Mark challenge as consumed
		_, _ = pool.Exec(r.Context(), `
			UPDATE binggoplus_v2.wallet_challenges
			SET consumed_at = $1
			WHERE id = $2
		`, time.Now(), req.ChallengeID)

		// Create wallet session
		sessionID := newUUID()
		sessionToken := hex.EncodeToString(make([]byte, 32))
		sessionExpires := time.Now().UTC().Add(24 * time.Hour)

		_, err = pool.Exec(r.Context(), `
			INSERT INTO binggoplus_v2.wallet_sessions (
				id, environment_id, address, token_hash, created_at, expires_at
			) VALUES (
				$1,
				(SELECT id FROM binggoplus_v2.environments WHERE chain_id = $2 AND project = 'binggoplus' LIMIT 1),
				$3, $4, $5, $6
			)
		`, sessionID, domain.BSCTestnetChainID, req.Address, sessionToken, time.Now(), sessionExpires)

		if err != nil {
			meta := BuildMeta(r, domain.DataStatusUnavailable, "")
			JSONError(w, r, http.StatusInternalServerError, ErrCodeInternal, "failed to create session", nil, true, meta)
			return
		}

		// Set session cookie
		http.SetCookie(w, &http.Cookie{
			Name:     "__Host-bgp-wallet",
			Value:    sessionToken,
			Path:     "/",
			Expires:  sessionExpires,
			HttpOnly: true,
			Secure:   true,
			SameSite: http.SameSiteLaxMode,
		})

		_ = sessionID
		NoContent(w)
	}
}

// LogoutWalletHandler handles POST /api/v2/projects/binggoplus/auth/logout.
func LogoutWalletHandler(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		cookie, err := r.Cookie("__Host-bgp-wallet")
		if err != nil {
			NoContent(w)
			return
		}

		_, _ = pool.Exec(r.Context(), `
			UPDATE binggoplus_v2.wallet_sessions
			SET revoked_at = $1
			WHERE token_hash = $2 AND revoked_at IS NULL
		`, time.Now(), cookie.Value)

		http.SetCookie(w, &http.Cookie{
			Name:     "__Host-bgp-wallet",
			Value:    "",
			Path:     "/",
			Expires:  time.Unix(0, 0),
			HttpOnly: true,
			Secure:   true,
			SameSite: http.SameSiteLaxMode,
		})

		NoContent(w)
	}
}
