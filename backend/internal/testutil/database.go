package testutil

import (
	"context"
	"fmt"
	"os"
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/require"

	"github.com/Evgenius09/vpn-project/backend/internal/db"
)

// NewDatabase creates a migrated throwaway database and drops it after the
// test. TEST_DATABASE_URL points at the server. Without it the test skips,
// unless REQUIRE_POSTGRES is set, which CI does so tests cannot vanish silently.
func NewDatabase(t *testing.T) *pgxpool.Pool {
	t.Helper()
	pool := NewEmptyDatabase(t)
	require.NoError(t, db.Up(context.Background(), pool))
	return pool
}

// NewEmptyDatabase creates a throwaway database without applying migrations.
func NewEmptyDatabase(t *testing.T) *pgxpool.Pool {
	t.Helper()
	url := os.Getenv("TEST_DATABASE_URL")
	if url == "" {
		if os.Getenv("REQUIRE_POSTGRES") != "" {
			t.Fatal("REQUIRE_POSTGRES is set but TEST_DATABASE_URL is empty")
		}
		t.Skip("TEST_DATABASE_URL is not set")
	}

	ctx := context.Background()
	admin, err := pgx.Connect(ctx, url)
	require.NoError(t, err)

	name := "test_" + strings.ReplaceAll(uuid.NewString(), "-", "")
	_, err = admin.Exec(ctx, fmt.Sprintf("create database %s", name))
	require.NoError(t, err)

	config, err := pgxpool.ParseConfig(url)
	require.NoError(t, err)
	config.ConnConfig.Database = name
	pool, err := pgxpool.NewWithConfig(ctx, config)
	require.NoError(t, err)

	t.Cleanup(func() {
		pool.Close()
		_, err := admin.Exec(ctx, fmt.Sprintf("drop database %s with (force)", name))
		require.NoError(t, err)
		require.NoError(t, admin.Close(ctx))
	})
	return pool
}
