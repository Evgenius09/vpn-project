// Package app holds the startup code shared by the binaries.
package app

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Evgenius09/vpn-project/backend/internal/config"
)

// Runtime is what every binary needs after startup.
type Runtime struct {
	Config config.Config
	Logger *slog.Logger
	Pool   *pgxpool.Pool
}

// Start loads the config and opens the database.
func Start(ctx context.Context) (Runtime, error) {
	cfg, err := config.Load(os.Getenv)
	if err != nil {
		return Runtime{}, fmt.Errorf("load config: %w", err)
	}
	logger := newLogger(cfg.LogLevel)
	pool, err := pgxpool.New(ctx, cfg.DatabaseURL)
	if err != nil {
		return Runtime{}, fmt.Errorf("open database: %w", err)
	}
	return Runtime{Config: cfg, Logger: logger, Pool: pool}, nil
}

func newLogger(level string) *slog.Logger {
	var parsed slog.Level
	// config.Load already validated the level.
	_ = parsed.UnmarshalText([]byte(strings.ToUpper(level)))
	return slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: parsed}))
}
