package jobs_test

import (
	"bytes"
	"context"
	"log/slog"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/riverqueue/river"
	"github.com/riverqueue/river/rivertype"
	"github.com/stretchr/testify/require"

	"github.com/Evgenius09/vpn-project/backend/internal/jobs"
	"github.com/Evgenius09/vpn-project/backend/internal/testutil"
)

func TestKindsMatchTheContract(t *testing.T) {
	kinds := map[string]river.JobArgs{
		"panel_provision_user": jobs.PanelProvisionUserArgs{},
		"telegram_send_code":   jobs.TelegramSendCodeArgs{},
		"panel_sync_user":      jobs.PanelSyncUserArgs{},
		"catalog_sync":         jobs.CatalogSyncArgs{},
		"account_expire":       jobs.AccountExpireArgs{},
		"demo_echo":            jobs.DemoEchoArgs{},
	}
	for kind, args := range kinds {
		require.Equal(t, kind, args.Kind())
	}
}

func TestRetryLimitsMatchTheContract(t *testing.T) {
	require.Equal(t, 10, jobs.PanelProvisionUserArgs{}.InsertOpts().MaxAttempts)
	require.Equal(t, 3, jobs.TelegramSendCodeArgs{}.InsertOpts().MaxAttempts)
	require.Equal(t, 10, jobs.PanelSyncUserArgs{}.InsertOpts().MaxAttempts)
	require.Equal(t, 3, jobs.CatalogSyncArgs{}.InsertOpts().MaxAttempts)
	require.Equal(t, 3, jobs.AccountExpireArgs{}.InsertOpts().MaxAttempts)
	require.Equal(t, 1, jobs.DemoEchoArgs{}.InsertOpts().MaxAttempts)
}

func TestLoginCodeIsMaskedInLogs(t *testing.T) {
	var out bytes.Buffer
	args := jobs.TelegramSendCodeArgs{LoginID: uuid.New(), Code: "123456"}
	slog.New(slog.NewJSONHandler(&out, nil)).Info("job", "args", args)
	require.NotContains(t, out.String(), "123456")
}

func TestWorkerRunsDemoEcho(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	pool := testutil.NewDatabase(t)

	var logs bytes.Buffer
	workers := river.NewWorkers()
	river.AddWorker(workers, &jobs.DemoEchoWorker{Logger: slog.New(slog.NewTextHandler(&logs, nil))})
	client, err := jobs.NewClient(pool, jobs.Options{Logger: slog.New(slog.DiscardHandler), Workers: workers})
	require.NoError(t, err)

	completed, stop := client.Subscribe(river.EventKindJobCompleted)
	defer stop()

	require.NoError(t, client.Start(ctx))
	t.Cleanup(func() {
		stopCtx, cancelStop := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancelStop()
		require.NoError(t, client.Stop(stopCtx))
	})

	_, err = client.Insert(ctx, jobs.DemoEchoArgs{Message: "hello queue"}, nil)
	require.NoError(t, err)

	select {
	case event := <-completed:
		require.Equal(t, rivertype.JobStateCompleted, event.Job.State)
		require.Equal(t, jobs.KindDemoEcho, event.Job.Kind)
	case <-ctx.Done():
		t.Fatal("demo_echo did not finish")
	}
	require.Contains(t, logs.String(), "hello queue")
}

func TestInsertInsideATransactionRollsBack(t *testing.T) {
	ctx := context.Background()
	pool := testutil.NewDatabase(t)
	client, err := jobs.NewClient(pool, jobs.Options{Logger: slog.New(slog.DiscardHandler)})
	require.NoError(t, err)

	tx, err := pool.Begin(ctx)
	require.NoError(t, err)
	_, err = client.InsertTx(ctx, tx, jobs.DemoEchoArgs{Message: "rolled back"}, nil)
	require.NoError(t, err)
	require.NoError(t, tx.Rollback(ctx))

	var count int
	require.NoError(t, pool.QueryRow(ctx, `select count(*) from river_job`).Scan(&count))
	require.Zero(t, count, "a job leaves with its business record")
}

func TestUniqueProvisioningInsertsOnce(t *testing.T) {
	ctx := context.Background()
	pool := testutil.NewDatabase(t)
	client, err := jobs.NewClient(pool, jobs.Options{Logger: slog.New(slog.DiscardHandler)})
	require.NoError(t, err)

	args := jobs.PanelProvisionUserArgs{AccountID: uuid.New()}
	first, err := client.Insert(ctx, args, nil)
	require.NoError(t, err)
	second, err := client.Insert(ctx, args, nil)
	require.NoError(t, err)
	require.False(t, first.UniqueSkippedAsDuplicate)
	require.True(t, second.UniqueSkippedAsDuplicate)
}
