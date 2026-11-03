package catalog_test

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"os"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/require"

	"github.com/Evgenius09/vpn-project/backend/internal/db/sqlc"
	"github.com/Evgenius09/vpn-project/backend/internal/domain/catalog"
	"github.com/Evgenius09/vpn-project/backend/internal/domain/profile"
	"github.com/Evgenius09/vpn-project/backend/internal/gen/api"
	"github.com/Evgenius09/vpn-project/backend/internal/panel"
	panelfake "github.com/Evgenius09/vpn-project/backend/internal/panel/fake"
	"github.com/Evgenius09/vpn-project/backend/internal/seed"
	"github.com/Evgenius09/vpn-project/backend/internal/testutil"
)

const (
	seedPath    = "../../../" + seed.DefaultPath
	seedProfile = "../../../../contracts/fixtures/profile/seed.json"
	pepper      = "test-pepper"
)

type env struct {
	pool    *pgxpool.Pool
	data    seed.Data
	panel   *panelfake.Client
	service *catalog.Service
}

// newEnv starts from an empty servers table and a fake panel with the seed
// hosts.
func newEnv(t *testing.T) *env {
	t.Helper()
	data, err := seed.Load(seedPath)
	require.NoError(t, err)

	e := &env{pool: testutil.NewDatabase(t), data: data, panel: panelfake.New()}
	seed.FillPanel(e.panel, data)
	e.service = e.newService(e.panel)
	return e
}

func (e *env) newService(client panel.PanelClient) *catalog.Service {
	return catalog.NewService(catalog.NewPostgresStore(e.pool), client, catalog.Options{
		Logger: slog.New(slog.DiscardHandler),
	})
}

func (e *env) sync(t *testing.T) catalog.Result {
	t.Helper()
	result, err := e.service.Sync(context.Background())
	require.NoError(t, err)
	return result
}

func (e *env) setHosts(hosts []panel.PanelHost) { e.panel.SetHosts(hosts) }

type row struct {
	ID          uuid.UUID
	Group       string
	DisplayName string
	CountryCode string
	City        *string
	Address     string
	Port        int
	Params      string
	Enabled     bool
	SortWeight  int
	ContentHash string
	UpdatedAt   time.Time
}

func (e *env) rows(t *testing.T) map[uuid.UUID]row {
	t.Helper()
	result, err := e.pool.Query(context.Background(), `
		select remnawave_host_uuid, id, grp::text, display_name, country_code, city, address, port,
		       params::text, enabled, sort_weight, content_hash, updated_at
		from servers`)
	require.NoError(t, err)
	defer result.Close()
	rows := map[uuid.UUID]row{}
	for result.Next() {
		var host uuid.UUID
		var r row
		require.NoError(t, result.Scan(&host, &r.ID, &r.Group, &r.DisplayName, &r.CountryCode, &r.City,
			&r.Address, &r.Port, &r.Params, &r.Enabled, &r.SortWeight, &r.ContentHash, &r.UpdatedAt))
		rows[host] = r
	}
	require.NoError(t, result.Err())
	return rows
}

func hostUUID(e *env, index int) uuid.UUID { return e.data.Servers[index].RemnawaveHostUUID }

func TestSyncPublishesTheTaggedHosts(t *testing.T) {
	e := newEnv(t)
	stray := e.data.Servers[0].PanelHost()
	stray.UUID = uuid.New()
	stray.Tags = nil
	e.setHosts(append(e.data.PanelHosts(), stray))

	result := e.sync(t)

	require.Equal(t, catalog.Result{Published: 5, Changed: 5}, result)
	rows := e.rows(t)
	require.Len(t, rows, 5)
	require.NotContains(t, rows, stray.UUID, "a host without a country tag is not published")
	for _, server := range e.data.Servers {
		got := rows[server.RemnawaveHostUUID]
		require.True(t, got.Enabled)
		require.Equal(t, server.Group, got.Group)
		require.Equal(t, server.DisplayName, got.DisplayName)
		require.Equal(t, server.CountryCode, got.CountryCode)
		require.Equal(t, server.City, *got.City)
		require.Equal(t, server.Address, got.Address)
		require.Equal(t, int(server.Port), got.Port)
		require.Equal(t, int(server.SortWeight), got.SortWeight)
		require.JSONEq(t, string(server.Params), got.Params)
	}
}

func TestRepeatedSyncChangesNothing(t *testing.T) {
	e := newEnv(t)
	e.sync(t)
	before := e.rows(t)

	result := e.sync(t)

	require.Equal(t, catalog.Result{Published: 5}, result)
	require.Equal(t, before, e.rows(t), "updated_at must stay the same")
}

func TestVanishedHostIsDisabled(t *testing.T) {
	e := newEnv(t)
	e.sync(t)
	before := e.rows(t)
	gone := hostUUID(e, 1)
	e.setHosts(append(e.data.PanelHosts()[:1:1], e.data.PanelHosts()[2:]...))

	result := e.sync(t)

	require.Equal(t, catalog.Result{Published: 4, Disabled: 1}, result)
	after := e.rows(t)
	require.False(t, after[gone].Enabled)
	require.True(t, after[gone].UpdatedAt.After(before[gone].UpdatedAt))
	for host, previous := range before {
		if host != gone {
			require.Equal(t, previous, after[host], "other rows stay untouched")
		}
	}

	require.Equal(t, catalog.Result{Published: 4}, e.sync(t), "a disabled row is not touched again")
	require.Equal(t, after, e.rows(t))
}

func TestHostWithoutTheCountryTagIsDisabled(t *testing.T) {
	e := newEnv(t)
	e.sync(t)
	hosts := e.data.PanelHosts()
	hosts[0].Tags = []string{"PROBE"}
	e.setHosts(hosts)

	result := e.sync(t)

	require.Equal(t, catalog.Result{Published: 4, Disabled: 1}, result)
	require.False(t, e.rows(t)[hostUUID(e, 0)].Enabled)
}

func TestReturningHostIsEnabledAgain(t *testing.T) {
	e := newEnv(t)
	e.sync(t)
	id := e.rows(t)[hostUUID(e, 0)].ID
	e.setHosts(e.data.PanelHosts()[1:])
	e.sync(t)
	e.setHosts(e.data.PanelHosts())

	result := e.sync(t)

	require.Equal(t, catalog.Result{Published: 5, Changed: 1}, result)
	back := e.rows(t)[hostUUID(e, 0)]
	require.True(t, back.Enabled)
	require.Equal(t, id, back.ID, "the server keeps its id, so clients keep their choice")
}

func TestDisabledFlagReachesTheRow(t *testing.T) {
	e := newEnv(t)
	hosts := e.data.PanelHosts()
	hosts[0].Enabled = false
	e.setHosts(hosts)

	result := e.sync(t)

	require.Equal(t, catalog.Result{Published: 5, Changed: 5}, result)
	rows := e.rows(t)
	require.False(t, rows[hostUUID(e, 0)].Enabled, "disabled in the panel")
	require.True(t, rows[hostUUID(e, 1)].Enabled)
}

func TestRenamedHostUpdatesItsRow(t *testing.T) {
	e := newEnv(t)
	e.sync(t)
	hosts := e.data.PanelHosts()
	hosts[0].Remark = "Frankfurt 2"
	hosts[0].Tags = append(hosts[0].Tags, "WHITELIST")
	e.setHosts(hosts)

	result := e.sync(t)

	require.Equal(t, catalog.Result{Published: 5, Changed: 1}, result)
	got := e.rows(t)[hostUUID(e, 0)]
	require.Equal(t, "Frankfurt 2", got.DisplayName)
	require.Equal(t, "whitelist", got.Group)
}

func TestChangedHostUpdatesOnlyItsRow(t *testing.T) {
	e := newEnv(t)
	e.sync(t)
	before := e.rows(t)
	hosts := e.data.PanelHosts()
	hosts[2].Port = 8443
	e.setHosts(hosts)

	result := e.sync(t)

	require.Equal(t, catalog.Result{Published: 5, Changed: 1}, result)
	after := e.rows(t)
	changed := hostUUID(e, 2)
	require.Equal(t, 8443, after[changed].Port)
	require.NotEqual(t, before[changed].ContentHash, after[changed].ContentHash)
	require.Equal(t, before[changed].ID, after[changed].ID)
	for host, previous := range before {
		if host != changed {
			require.Equal(t, previous, after[host])
		}
	}
}

func TestInvalidHostIsSkippedAndItsRowDisabled(t *testing.T) {
	e := newEnv(t)
	e.sync(t)
	hosts := e.data.PanelHosts()
	hosts[0].Params = json.RawMessage(`{"flow":"xtls-rprx-vision","serverName":"s","publicKey":"short","shortId":"","fingerprint":"chrome"}`)
	e.setHosts(hosts)

	result := e.sync(t)

	require.Equal(t, catalog.Result{Published: 4, Disabled: 1, Skipped: 1}, result)
	require.False(t, e.rows(t)[hostUUID(e, 0)].Enabled)
}

func TestPanelFailureLeavesTheCatalogUntouched(t *testing.T) {
	for _, failure := range []error{panel.ErrUnavailable, context.DeadlineExceeded} {
		t.Run(failure.Error(), func(t *testing.T) {
			e := newEnv(t)
			e.sync(t)
			before := e.rows(t)
			e.setHosts(nil)
			e.panel.FailNext(panelfake.OpListHosts, failure)

			_, err := e.service.Sync(context.Background())

			require.ErrorIs(t, err, failure)
			require.Equal(t, before, e.rows(t), "an empty answer after a failure must not disable everything")
		})
	}
}

func TestDuplicateHostsLeaveTheCatalogUntouched(t *testing.T) {
	e := newEnv(t)
	e.sync(t)
	before := e.rows(t)
	hosts := e.data.PanelHosts()
	e.setHosts(append(hosts, hosts[0]))

	_, err := e.service.Sync(context.Background())

	require.ErrorIs(t, err, catalog.ErrInvalidPanel)
	require.Equal(t, before, e.rows(t))
}

func TestSeedRowsAlreadyMatchASync(t *testing.T) {
	e := newEnv(t)
	require.NoError(t, seed.Apply(context.Background(), e.pool, e.data, []byte(pepper)))
	before := e.rows(t)

	result := e.sync(t)

	require.Equal(t, catalog.Result{Published: 5}, result, "make dev must not rewrite the seed rows")
	require.Equal(t, before, e.rows(t))
}

// The profile of S0-08 serves what the sync wrote.
func TestProfileServesTheSyncedServers(t *testing.T) {
	e := newEnv(t)
	ctx := context.Background()
	require.NoError(t, seed.Apply(ctx, e.pool, e.data, []byte(pepper)))
	_, err := e.pool.Exec(ctx, `delete from servers`)
	require.NoError(t, err)
	e.sync(t)

	built, err := profile.NewService(profile.NewPostgresStore(sqlc.New(e.pool)), profile.Options{}).Build(ctx, e.data.Account.ID)
	require.NoError(t, err)

	raw, err := os.ReadFile(seedProfile)
	require.NoError(t, err)
	var want api.ProfileV1
	require.NoError(t, json.Unmarshal(raw, &want))
	require.Len(t, built.Profile.Servers, len(want.Servers))
	for index := range want.Servers {
		got := built.Profile.Servers[index]
		require.NotEmpty(t, got.Id)
		got.Id = want.Servers[index].Id
		require.Equal(t, want.Servers[index], got, "server %d", index)
	}
}

// Two syncs that see different panels touch the same rows in opposite order.
// They must queue up instead of deadlocking.
func TestOverlappingSyncsDoNotDeadlock(t *testing.T) {
	e := newEnv(t)
	e.sync(t)
	hosts := e.data.PanelHosts()
	first, second := panelfake.New(), panelfake.New()
	first.SetHosts(hosts[:3])
	second.SetHosts(hosts[2:])
	services := []*catalog.Service{e.newService(first), e.newService(second)}

	for round := range 20 {
		errs := race(t, e.pool, 6, func(i int) error {
			_, err := services[i%2].Sync(context.Background())
			return err
		})
		require.NoError(t, errors.Join(errs...), "round %d", round)
	}
}

// race runs fn from n goroutines released together, over connections that
// already exist, so the transactions overlap instead of running in turn.
func race(t *testing.T, pool *pgxpool.Pool, n int, fn func(i int) error) []error {
	t.Helper()
	conns := make([]*pgxpool.Conn, 0, n)
	for range min(n, int(pool.Config().MaxConns)) {
		conn, err := pool.Acquire(context.Background())
		require.NoError(t, err)
		conns = append(conns, conn)
	}
	for _, conn := range conns {
		conn.Release()
	}

	gate := make(chan struct{})
	var group sync.WaitGroup
	errs := make([]error, n)
	for i := range errs {
		group.Go(func() {
			<-gate
			errs[i] = fn(i)
		})
	}
	close(gate)
	group.Wait()
	return errs
}
