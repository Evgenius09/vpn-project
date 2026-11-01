package db_test

import (
	"context"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/require"

	"github.com/Evgenius09/vpn-project/backend/internal/db"
	"github.com/Evgenius09/vpn-project/backend/internal/testutil"
)

var domainTables = []string{"accounts", "telegram_users", "login_codes", "devices", "panel_users", "servers"}

func tableExists(t *testing.T, pool *pgxpool.Pool, name string) bool {
	t.Helper()
	var exists bool
	err := pool.QueryRow(context.Background(),
		`select exists (select 1 from information_schema.tables where table_name = $1)`, name,
	).Scan(&exists)
	require.NoError(t, err)
	return exists
}

func TestUpCreatesDomainAndRiverTables(t *testing.T) {
	pool := testutil.NewDatabase(t)
	for _, table := range domainTables {
		require.True(t, tableExists(t, pool, table), table)
	}
	require.True(t, tableExists(t, pool, "river_job"))
}

func TestUpIsRepeatable(t *testing.T) {
	pool := testutil.NewDatabase(t)
	require.NoError(t, db.Up(context.Background(), pool))
}

func TestDownThenUp(t *testing.T) {
	ctx := context.Background()
	pool := testutil.NewEmptyDatabase(t)
	require.NoError(t, db.Up(ctx, pool))

	require.NoError(t, db.DownAll(ctx, pool))
	for _, table := range domainTables {
		require.False(t, tableExists(t, pool, table), table)
	}

	require.NoError(t, db.Up(ctx, pool))
	require.True(t, tableExists(t, pool, "accounts"))
}

func TestSchemaEnforcesTheContract(t *testing.T) {
	ctx := context.Background()
	pool := testutil.NewDatabase(t)

	_, err := pool.Exec(ctx, `
		insert into servers (remnawave_host_uuid, grp, protocol, display_name, country_code, address, port, content_hash)
		values (gen_random_uuid(), 'regular', 'hysteria2', 'x', 'DE', 'a', 70000, 'h')`)
	require.ErrorContains(t, err, "servers_port_check")

	var accountID string
	require.NoError(t, pool.QueryRow(ctx, `insert into accounts default values returning id`).Scan(&accountID))
	_, err = pool.Exec(ctx, `
		insert into telegram_users (telegram_id, account_id, chat_id, username) values (1, $1, 1, 'Seed_User')`, accountID)
	require.NoError(t, err)

	var other string
	require.NoError(t, pool.QueryRow(ctx, `insert into accounts default values returning id`).Scan(&other))
	_, err = pool.Exec(ctx, `
		insert into telegram_users (telegram_id, account_id, chat_id, username) values (2, $1, 2, 'seed_user')`, other)
	require.ErrorContains(t, err, "telegram_users_username_key", "nicknames are unique ignoring case")
}
