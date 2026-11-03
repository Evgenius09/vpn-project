package account_test

import (
	"context"
	"errors"
	"fmt"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/riverqueue/river"
	"github.com/riverqueue/river/rivertype"
	"github.com/stretchr/testify/require"

	"github.com/Evgenius09/vpn-project/backend/internal/db/sqlc"
	"github.com/Evgenius09/vpn-project/backend/internal/domain/account"
	"github.com/Evgenius09/vpn-project/backend/internal/domain/profile"
	"github.com/Evgenius09/vpn-project/backend/internal/jobs"
	"github.com/Evgenius09/vpn-project/backend/internal/panel"
	panelfake "github.com/Evgenius09/vpn-project/backend/internal/panel/fake"
	"github.com/Evgenius09/vpn-project/backend/internal/seed"
	"github.com/Evgenius09/vpn-project/backend/internal/testutil"
)

var now = time.Date(2026, 11, 3, 12, 0, 0, 0, time.UTC)

const trialDays = 3

type env struct {
	pool      *pgxpool.Pool
	panel     *panelfake.Client
	worker    *account.ProvisionWorker
	accountID uuid.UUID
}

func newEnv(t *testing.T) *env {
	t.Helper()
	pool := testutil.NewDatabase(t)
	ctx := context.Background()
	queries := sqlc.New(pool)
	accountID, err := queries.CreateAccount(ctx)
	require.NoError(t, err)
	username := "alice_tg"
	require.NoError(t, queries.InsertTelegramUser(ctx, sqlc.InsertTelegramUserParams{
		TelegramID: 4242, AccountID: accountID, ChatID: 4242, Username: &username, FirstName: "Alice",
	}))
	client := panelfake.New()
	service := account.NewService(pool, client, trialDays, func() time.Time { return now })
	return &env{pool: pool, panel: client, worker: &account.ProvisionWorker{Service: service}, accountID: accountID}
}

func (e *env) work(t *testing.T) error {
	t.Helper()
	return e.worker.Work(context.Background(), &river.Job[jobs.PanelProvisionUserArgs]{
		JobRow: &rivertype.JobRow{}, Args: jobs.PanelProvisionUserArgs{AccountID: e.accountID},
	})
}

type accountRow struct {
	status  string
	expires *time.Time
}

func (e *env) account(t *testing.T) accountRow {
	t.Helper()
	var row accountRow
	require.NoError(t, e.pool.QueryRow(context.Background(),
		`select status::text, expires_at from accounts where id = $1`, e.accountID).Scan(&row.status, &row.expires))
	return row
}

type panelRow struct {
	remnawaveID int64
	vlessUUID   string
	hysteria2   string
}

func (e *env) panelRows(t *testing.T) []panelRow {
	t.Helper()
	rows, err := e.pool.Query(context.Background(),
		`select remnawave_id, vless_uuid, hysteria2_auth from panel_users where account_id = $1`, e.accountID)
	require.NoError(t, err)
	defer rows.Close()
	var out []panelRow
	for rows.Next() {
		var row panelRow
		require.NoError(t, rows.Scan(&row.remnawaveID, &row.vlessUUID, &row.hysteria2))
		out = append(out, row)
	}
	require.NoError(t, rows.Err())
	return out
}

func requireCancelled(t *testing.T, err error) {
	t.Helper()
	var cancel *river.JobCancelError
	require.True(t, errors.As(err, &cancel), "want JobCancel, got %v", err)
}

func TestProvisionCreatesThePanelUserAndStartsTheTrial(t *testing.T) {
	e := newEnv(t)

	require.NoError(t, e.work(t))

	user, err := e.panel.GetUserByUsername(context.Background(), "tg_4242")
	require.NoError(t, err, "username follows tg_<telegram_id>")
	trialEnd := now.Add(trialDays * 24 * time.Hour)
	require.Equal(t, trialEnd, user.ExpiresAt)
	require.Equal(t, []panelRow{{remnawaveID: user.ID, vlessUUID: user.VlessUUID, hysteria2: user.Hysteria2Auth}}, e.panelRows(t))
	row := e.account(t)
	require.Equal(t, "trial", row.status)
	require.NotNil(t, row.expires)
	require.True(t, trialEnd.Equal(*row.expires))
}

func TestProvisionTwiceHasOneEffect(t *testing.T) {
	e := newEnv(t)
	require.NoError(t, e.work(t))
	first := e.account(t)

	require.NoError(t, e.work(t))

	require.Equal(t, 1, e.panel.Calls(panelfake.OpCreateUser))
	require.Len(t, e.panelRows(t), 1)
	require.Equal(t, first, e.account(t))
}

// A run that created the user but died before the commit retries into a
// taken name and must adopt the user the panel already has.
func TestProvisionAdoptsAnExistingPanelUser(t *testing.T) {
	e := newEnv(t)
	existing := panel.PanelUser{
		ID: 77, ShortUUID: "short77", Username: "tg_4242", ExpiresAt: now.Add(time.Hour),
		VlessUUID: "c0000000-0000-4000-8000-000000000077", Hysteria2Auth: "c0000000-0000-4000-8000-000000000077",
	}
	e.panel.AddUser(existing)

	require.NoError(t, e.work(t))

	require.Equal(t, 1, e.panel.Calls(panelfake.OpCreateUser))
	require.Equal(t, 1, e.panel.Calls(panelfake.OpGetUserByUsername))
	require.Equal(t, []panelRow{{remnawaveID: 77, vlessUUID: existing.VlessUUID, hysteria2: existing.Hysteria2Auth}}, e.panelRows(t))
	row := e.account(t)
	require.Equal(t, "trial", row.status)
	require.True(t, existing.ExpiresAt.Equal(*row.expires), "the panel's expiry wins")
}

func TestProvisionRetriesWhileThePanelIsUnavailable(t *testing.T) {
	e := newEnv(t)
	e.panel.FailNext(panelfake.OpCreateUser, fmt.Errorf("%w: 502", panel.ErrUnavailable))

	err := e.work(t)

	require.ErrorIs(t, err, panel.ErrUnavailable)
	var cancel *river.JobCancelError
	require.False(t, errors.As(err, &cancel), "an outage retries")
	require.Empty(t, e.panelRows(t))
	require.Equal(t, "provisioning", e.account(t).status)

	require.NoError(t, e.work(t))
	require.Len(t, e.panelRows(t), 1)
}

func TestProvisionUnavailableWhileAdoptingRetries(t *testing.T) {
	e := newEnv(t)
	e.panel.FailNext(panelfake.OpCreateUser, panel.ErrConflict)
	e.panel.FailNext(panelfake.OpGetUserByUsername, panel.ErrUnavailable)

	err := e.work(t)

	require.ErrorIs(t, err, panel.ErrUnavailable)
	var cancel *river.JobCancelError
	require.False(t, errors.As(err, &cancel))
}

func TestProvisionCancelsOnARejection(t *testing.T) {
	e := newEnv(t)
	e.panel.FailNext(panelfake.OpCreateUser, errors.New("remnawave create user: status 401"))

	requireCancelled(t, e.work(t))
	require.Empty(t, e.panelRows(t))
}

func TestProvisionCancelsForAnUnknownAccount(t *testing.T) {
	e := newEnv(t)
	e.accountID = uuid.New()

	requireCancelled(t, e.work(t))
	require.Zero(t, e.panel.Calls(panelfake.OpCreateUser))
}

func TestProvisionKeepsAStatusTheAccountAlreadyLeft(t *testing.T) {
	e := newEnv(t)
	_, err := e.pool.Exec(context.Background(), `update accounts set status = 'blocked' where id = $1`, e.accountID)
	require.NoError(t, err)

	require.NoError(t, e.work(t))

	require.Len(t, e.panelRows(t), 1)
	require.Equal(t, "blocked", e.account(t).status, "only a provisioning account starts a trial")
}

func TestProfileAfterProvisionServesTheUserCredentials(t *testing.T) {
	e := newEnv(t)
	ctx := context.Background()
	data, err := seed.Load("../../../" + seed.DefaultPath)
	require.NoError(t, err)
	require.NoError(t, seed.Apply(ctx, e.pool, data, []byte("pepper-for-tests-0123456789abcdef")))
	profiles := profile.NewService(profile.NewPostgresStore(sqlc.New(e.pool)), profile.Options{})

	before, err := profiles.Build(ctx, e.accountID)
	require.NoError(t, err)
	require.True(t, before.Provisioning)
	require.Empty(t, before.Profile.Servers)

	require.NoError(t, e.work(t))

	after, err := profiles.Build(ctx, e.accountID)
	require.NoError(t, err)
	require.False(t, after.Provisioning)
	user, err := e.panel.GetUserByUsername(ctx, "tg_4242")
	require.NoError(t, err)
	require.NotEmpty(t, after.Profile.Servers)
	for _, server := range after.Profile.Servers {
		switch {
		case server.Vless != nil:
			require.Equal(t, user.VlessUUID, server.Vless.Uuid)
		case server.Hysteria2 != nil:
			require.Equal(t, user.Hysteria2Auth, server.Hysteria2.Password)
		}
	}
}
