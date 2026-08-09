package http

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// RegisterRoutes sets up all public and admin API routes on the chi router.
func RegisterRoutes(r chi.Router, pool *pgxpool.Pool, rateLimiter *RateLimiter) {
	// Health endpoints (no rate limit)
	RegisterHealthRoutes(r, pool)

	// Public API v2
	r.Route("/api/v2/projects/binggoplus", func(r chi.Router) {
		r.Use(CORSMiddleware)
		r.Use(RateLimitMiddleware(rateLimiter))

		// System
		r.Get("/config", ConfigHandler(pool))
		r.Get("/system-status", SystemStatusHandler(pool))
		r.Get("/contracts", ContractsHandler(pool))
		r.Get("/market", MarketHandler(pool))

		// Auth
		r.Post("/auth/nonce", IssueNonceHandler(pool))
		r.Post("/auth/verify", VerifyWalletHandler(pool))
		r.Post("/auth/logout", LogoutWalletHandler(pool))

		// Quotes
		r.Post("/quotes/buy", PreviewBuyHandler(pool))
		r.Post("/quotes/sell", PreviewSellHandler(pool))

		// Wallet
		r.Get("/wallets/{address}/summary", WalletSummaryHandler(pool))
		r.Get("/wallets/{address}/transactions", WalletTransactionsHandler(pool))

		// Staking
		r.Get("/wallets/{address}/staking/positions", StakingPositionsHandler(pool))
		r.Get("/staking/status", StakingStatusHandler(pool))
	})

	// Admin API v2 (placeholder routes)
	r.Route("/admin-api/v2/projects/binggoplus", func(r chi.Router) {
		r.Use(CORSMiddleware)
		r.Get("/dashboard", AdminDashboardHandler(pool))
	})
}
