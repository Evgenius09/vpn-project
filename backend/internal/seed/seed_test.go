package seed

import (
	"context"
	"log/slog"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/require"

	"github.com/Evgenius09/vpn-project/backend/internal/db/sqlc"
	"github.com/Evgenius09/vpn-project/backend/internal/domain/catalog"
	"github.com/Evgenius09/vpn-project/backend/internal/httpapi"
	"github.com/Evgenius09/vpn-project/backend/internal/panel"
	panelfake "github.com/Evgenius09/vpn-project/backend/internal/panel/fake"
	"github.com/Evgenius09/vpn-project/backend/internal/telegram"
	"github.com/Evgenius09/vpn-project/backend/internal/testutil"
)

const path = "../../" + DefaultPath

var pepper = []byte("test-pepper")

func load(t *testing.T) Data {
	t.Helper()
	data, err := Load(path)
	require.NoError(t, err)
	return data
}

func count(t *testing.T, pool *pgxpool.Pool, query string, args ...any) int {
	t.Helper()
	var value int
	require.NoError(t, pool.QueryRow(context.Background(), query, args...).Scan(&value))
	return value
}

func TestCompositionMatchesTheContract(t *testing.T) {
	data := load(t)

	var regular, whitelist, vless, hysteria int
	for _, server := range data.Servers {
		switch server.Group {
		case "regular":
			regular++
			switch server.Protocol {
			case "vless_reality":
				vless++
			case "hysteria2":
				hysteria++
				require.Contains(t, string(server.Params), "portHopping")
			}
		case "whitelist":
			whitelist++
		}
	}
	require.Equal(t, 3, regular)
	require.Equal(t, 2, whitelist)
	require.Equal(t, 2, vless, "regular servers")
	require.Equal(t, 1, hysteria, "regular servers")
	require.Equal(t, "trial", data.Account.Status)
	require.Equal(t, "seed_user", data.TelegramUser.Username)
	require.NotEmpty(t, data.Device.Token)
}

func TestApplyFillsEveryTable(t *testing.T) {
	ctx := context.Background()
	pool := testutil.NewDatabase(t)
	data := load(t)

	require.NoError(t, Apply(ctx, pool, data, pepper))

	require.Equal(t, 1, count(t, pool, `select count(*) from accounts`))
	require.Equal(t, 1, count(t, pool, `select count(*) from telegram_users where username = 'seed_user'`))
	require.Equal(t, 1, count(t, pool, `select count(*) from devices`))
	require.Equal(t, 1, count(t, pool, `select count(*) from panel_users`))
	require.Equal(t, 3, count(t, pool, `select count(*) from servers where grp = 'regular'`))
	require.Equal(t, 2, count(t, pool, `select count(*) from servers where grp = 'whitelist'`))
}

func TestApplyIsRepeatable(t *testing.T) {
	ctx := context.Background()
	pool := testutil.NewDatabase(t)
	data := load(t)

	require.NoError(t, Apply(ctx, pool, data, pepper))
	require.NoError(t, Apply(ctx, pool, data, pepper))

	require.Equal(t, 1, count(t, pool, `select count(*) from accounts`))
	require.Equal(t, 5, count(t, pool, `select count(*) from servers`))
}

func TestApplyRestoresARevokedDevice(t *testing.T) {
	ctx := context.Background()
	pool := testutil.NewDatabase(t)
	data := load(t)
	require.NoError(t, Apply(ctx, pool, data, pepper))
	_, err := pool.Exec(ctx, `update devices set revoked_at = now()`)
	require.NoError(t, err)

	require.NoError(t, Apply(ctx, pool, data, pepper))

	require.Zero(t, count(t, pool, `select count(*) from devices where revoked_at is not null`))
}

func TestDevTokenAuthenticates(t *testing.T) {
	ctx := context.Background()
	pool := testutil.NewDatabase(t)
	data := load(t)
	require.NoError(t, Apply(ctx, pool, data, pepper))

	store := httpapi.NewPostgresDevices(sqlc.New(pool), slog.New(slog.DiscardHandler))
	device, err := store.FindByTokenHash(ctx, httpapi.HashToken(data.Device.Token, pepper))

	require.NoError(t, err)
	require.Equal(t, data.Device.ID, device.ID)
	require.Equal(t, data.Account.ID, device.AccountID)
}

func TestFakePanelServesTheSameData(t *testing.T) {
	ctx := context.Background()
	data := load(t)
	client := panelfake.New()
	FillPanel(client, data)

	user, err := client.GetUserByUsername(ctx, data.PanelUsername())
	require.NoError(t, err)
	require.Equal(t, data.PanelUser.VlessUUID, user.VlessUUID)
	require.Equal(t, data.PanelUser.RemnawaveID, user.ID)

	hosts, err := client.ListHosts(ctx)
	require.NoError(t, err)
	require.Len(t, hosts, len(data.Servers))
	require.Equal(t, data.Servers[0].RemnawaveHostUUID, hosts[0].UUID)

	_, err = client.CreateUser(ctx, panel.CreateUserInput{Username: data.PanelUsername(), ExpiresAt: data.Account.ExpiresAt})
	require.ErrorIs(t, err, panel.ErrConflict, "the seed user already exists")
}

// The dev catalog must describe the seed servers, or the first catalog_sync of
// make dev would disable or rewrite them.
func TestCatalogFixtureMatchesTheSeed(t *testing.T) {
	data := load(t)

	entries, err := catalog.LoadEntries("../../" + DefaultCatalogPath)

	require.NoError(t, err)
	want := data.CatalogEntries()
	enabled := true
	for index := range want {
		want[index].Enabled = &enabled
	}
	require.Equal(t, want, entries)
}

func TestStartUpdateIsTheSeedUser(t *testing.T) {
	data := load(t)
	update := data.StartUpdate(7)
	require.Equal(t, telegram.UpdateMessage, update.Kind)
	require.Equal(t, int64(7), update.UpdateID)
	require.Equal(t, data.TelegramUser.TelegramID, update.TelegramID)
	require.Equal(t, "seed_user", update.Username)
}
