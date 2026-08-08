package config

import (
	"fmt"
	"os"
)

type Config struct {
	Port        string
	DatabaseURL string
	RPCURL      string
	ChainID     int64
}

func Load() (*Config, error) {
	port := os.Getenv("BGP_API_PORT")
	if port == "" {
		port = "8080"
	}

	dbURL := os.Getenv("BGP_DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://bgp_api:bgp_api@localhost:5432/binggoplus_go?sslmode=disable"
	}

	rpcURL := os.Getenv("BGP_BSC_TESTNET_RPC_PRIMARY")
	if rpcURL == "" {
		return nil, fmt.Errorf("BGP_BSC_TESTNET_RPC_PRIMARY is required")
	}

	return &Config{
		Port:        port,
		DatabaseURL: dbURL,
		RPCURL:      rpcURL,
		ChainID:     97,
	}, nil
}
