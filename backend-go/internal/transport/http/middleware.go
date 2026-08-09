package http

import (
	"log/slog"
	"net/http"
	"sync"
	"time"

	"github.com/go-chi/chi/v5/middleware"
)

// --- Middleware ---

// CORSMiddleware is a simple CORS handler for public API access.
func CORSMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, X-Request-ID, X-CSRF-Token, Idempotency-Key")
		w.Header().Set("Access-Control-Max-Age", "86400")

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}

		next.ServeHTTP(w, r)
	})
}

// RequestIDMiddleware ensures every request has an X-Request-ID header.
func RequestIDMiddleware(next http.Handler) http.Handler {
	return middleware.RequestID(next)
}

// LoggerMiddleware logs structured request info using slog.
func LoggerMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		ww := middleware.NewWrapResponseWriter(w, r.ProtoMajor)

		defer func() {
			slog.Info("http request",
				"method", r.Method,
				"path", r.URL.Path,
				"status", ww.Status(),
				"duration_ms", time.Since(start).Milliseconds(),
				"request_id", r.Header.Get("X-Request-ID"),
			)
		}()

		next.ServeHTTP(ww, r)
	})
}

// --- Rate Limiter ---

// RateLimiter is a token-bucket rate limiter for public endpoints.
// G2 placeholder: basic per-IP tracking. Upgrade in G6+ with Redis-backed implementation.
type RateLimiter struct {
	mu       sync.Mutex
	visitors map[string]*rateBucket
	limit    int
	window   time.Duration
}

type rateBucket struct {
	count    int
	windowStart time.Time
}

// NewRateLimiter creates a rate limiter with the given requests-per-window.
func NewRateLimiter(limit int, window time.Duration) *RateLimiter {
	return &RateLimiter{
		visitors: make(map[string]*rateBucket),
		limit:    limit,
		window:   window,
	}
}

// RateLimitMiddleware applies rate limiting per IP address.
func RateLimitMiddleware(rl *RateLimiter) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ip := r.RemoteAddr
			if forwarded := r.Header.Get("X-Forwarded-For"); forwarded != "" {
				ip = forwarded
			}

			rl.mu.Lock()
			bucket, exists := rl.visitors[ip]
			now := time.Now()

			if !exists || now.Sub(bucket.windowStart) > rl.window {
				rl.visitors[ip] = &rateBucket{count: 1, windowStart: now}
				rl.mu.Unlock()
				next.ServeHTTP(w, r)
				return
			}

			bucket.count++
			rl.mu.Unlock()

			if bucket.count > rl.limit {
				meta := BuildMeta(r, "rate_limited", "")
				JSONError(w, r, http.StatusTooManyRequests, ErrCodeRateLimited, "rate limit exceeded", nil, true, meta)
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

// CleanupStaleVisitors periodically removes expired rate limit entries.
func (rl *RateLimiter) CleanupStaleVisitors(interval time.Duration, stop <-chan struct{}) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			rl.mu.Lock()
			now := time.Now()
			for ip, bucket := range rl.visitors {
				if now.Sub(bucket.windowStart) > rl.window {
					delete(rl.visitors, ip)
				}
			}
			rl.mu.Unlock()
		case <-stop:
			return
		}
	}
}
