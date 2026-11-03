package catalog_test

import (
	"context"
	"errors"
	"log/slog"
	"testing"
	"time"

	"github.com/riverqueue/river"
	"github.com/riverqueue/river/rivertype"
	"github.com/stretchr/testify/require"

	"github.com/Evgenius09/vpn-project/backend/internal/domain/catalog"
	"github.com/Evgenius09/vpn-project/backend/internal/jobs"
	"github.com/Evgenius09/vpn-project/backend/internal/panel"
	panelfake "github.com/Evgenius09/vpn-project/backend/internal/panel/fake"
)

func TestWorkerRetriesWhileThePanelIsUnavailable(t *testing.T) {
	e := newEnv(t)
	e.panel.FailNext(panelfake.OpListHosts, panel.ErrUnavailable)
	worker := &catalog.SyncWorker{Service: e.service}

	err := worker.Work(context.Background(), &river.Job[jobs.CatalogSyncArgs]{JobRow: &rivertype.JobRow{}})

	require.ErrorIs(t, err, panel.ErrUnavailable)
	var cancel *river.JobCancelError
	require.False(t, errors.As(err, &cancel), "the job must retry, not cancel")
	require.Empty(t, e.rows(t))

	require.NoError(t, worker.Work(context.Background(), &river.Job[jobs.CatalogSyncArgs]{JobRow: &rivertype.JobRow{}}))
	require.Len(t, e.rows(t), 5, "the retry syncs")
}

func TestSyncRunsEveryFiveMinutes(t *testing.T) {
	require.Equal(t, 5*time.Minute, catalog.SyncInterval)
}

// The worker binary registers the periodic job; a client with it fills the
// catalog right after start, without waiting for the first interval.
func TestPeriodicJobRunsAtStart(t *testing.T) {
	e := newEnv(t)
	workers := river.NewWorkers()
	river.AddWorker(workers, &catalog.SyncWorker{Service: e.service})
	client, err := jobs.NewClient(e.pool, jobs.Options{
		Logger:   slog.New(slog.DiscardHandler),
		Workers:  workers,
		Periodic: []*river.PeriodicJob{catalog.PeriodicJob()},
	})
	require.NoError(t, err)
	ctx := context.Background()
	require.NoError(t, client.Start(ctx))
	t.Cleanup(func() { require.NoError(t, client.Stop(ctx)) })

	require.Eventually(t, func() bool {
		var count int
		require.NoError(t, e.pool.QueryRow(ctx, `select count(*) from servers where enabled`).Scan(&count))
		return count == 5
	}, 20*time.Second, 100*time.Millisecond)
}
