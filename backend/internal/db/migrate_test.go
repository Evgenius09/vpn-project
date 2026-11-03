package db_test

import (
	"context"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/jackc/pgx/v5/stdlib"
	"github.com/pressly/goose/v3"
	"github.com/stretchr/testify/require"

	"github.com/Evgenius09/vpn-project/backend/internal/db"
	"github.com/Evgenius09/vpn-project/backend/internal/db/migrations"
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

// 00002 drops the panel user uuid; it must refuse to drop real rows.
func TestPanelUserIDMigrationRefusesRows(t *testing.T) {
	ctx := context.Background()
	pool := testutil.NewEmptyDatabase(t)
	database := stdlib.OpenDBFromPool(pool)
	t.Cleanup(func() { _ = database.Close() })
	migrator, err := goose.NewProvider(goose.DialectPostgres, database, migrations.FS)
	require.NoError(t, err)
	_, err = migrator.UpTo(ctx, 1)
	require.NoError(t, err)
	_, err = pool.Exec(ctx, `
		with a as (insert into accounts default values returning id)
		insert into panel_users (account_id, remnawave_uuid, short_uuid, vless_uuid, hysteria2_auth)
		select id, gen_random_uuid(), 's', 'v', 'h' from a`)
	require.NoError(t, err)

	err = db.Up(ctx, pool)

	require.ErrorContains(t, err, "panel_users is not empty")
	var count int
	require.NoError(t, pool.QueryRow(ctx, `select count(*) from panel_users`).Scan(&count))
	require.Equal(t, 1, count)
}
