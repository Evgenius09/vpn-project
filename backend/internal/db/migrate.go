// Package db applies the schema: goose first, then River (tech.md 6).
package db

import (
	"context"
	"database/sql"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/jackc/pgx/v5/stdlib"
	"github.com/pressly/goose/v3"
	"github.com/riverqueue/river/riverdriver/riverpgxv5"
	"github.com/riverqueue/river/rivermigrate"

	"github.com/Evgenius09/vpn-project/backend/internal/db/migrations"
)

func provider(pool *pgxpool.Pool) (*goose.Provider, *sql.DB, error) {
	database := stdlib.OpenDBFromPool(pool)
	migrator, err := goose.NewProvider(goose.DialectPostgres, database, migrations.FS)
	if err != nil {
		_ = database.Close()
		return nil, nil, fmt.Errorf("goose provider: %w", err)
	}
	return migrator, database, nil
}

// Up applies every pending migration.
func Up(ctx context.Context, pool *pgxpool.Pool) error {
	migrator, database, err := provider(pool)
	if err != nil {
		return err
	}
	defer func() { _ = database.Close() }()

	if _, err := migrator.Up(ctx); err != nil {
		return fmt.Errorf("goose up: %w", err)
	}
	river, err := rivermigrate.New(riverpgxv5.New(pool), nil)
	if err != nil {
		return fmt.Errorf("river migrator: %w", err)
	}
	if _, err := river.Migrate(ctx, rivermigrate.DirectionUp, nil); err != nil {
		return fmt.Errorf("river up: %w", err)
	}
	return nil
}

// DownAll reverts the goose migrations. Tests use it to prove reversibility.
func DownAll(ctx context.Context, pool *pgxpool.Pool) error {
	migrator, database, err := provider(pool)
	if err != nil {
		return err
	}
	defer func() { _ = database.Close() }()

	if _, err := migrator.DownTo(ctx, 0); err != nil {
		return fmt.Errorf("goose down: %w", err)
	}
	return nil
}
