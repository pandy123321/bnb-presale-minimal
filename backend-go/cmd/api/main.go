package main

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"

	"github.com/pandy123321/bnb-presale-minimal/backend-go/internal/config"
	"github.com/pandy123321/bnb-presale-minimal/backend-go/internal/store"
	httptransport "github.com/pandy123321/bnb-presale-minimal/backend-go/internal/transport/http"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		slog.Error("failed to load config", "error", err)
		os.Exit(1)
	}

	pool, err := store.NewPool(context.Background(), cfg.DatabaseURL)
	if err != nil {
		slog.Error("failed to create database pool", "error", err)
		os.Exit(1)
	}
	defer pool.Close()

	// Rate limiter: 100 requests per second per IP.
	rateLimiter := httptransport.NewRateLimiter(100, time.Second)
	stopCleanup := make(chan struct{})
	go rateLimiter.CleanupStaleVisitors(5*time.Minute, stopCleanup)
	defer close(stopCleanup)

	r := chi.NewRouter()
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(httptransport.LoggerMiddleware)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Timeout(30 * time.Second))

	httptransport.RegisterRoutes(r, pool, rateLimiter)

	srv := &http.Server{
		Addr:         fmt.Sprintf(":%s", cfg.Port),
		Handler:      r,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		slog.Info("api server starting", "port", cfg.Port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("api server failed", "error", err)
			os.Exit(1)
		}
	}()

	<-stop
	slog.Info("shutting down api server")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		slog.Error("api server forced to shutdown", "error", err)
	}

	slog.Info("api server stopped")
}
