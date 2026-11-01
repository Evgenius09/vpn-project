package jobs

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/riverqueue/river"
	"github.com/riverqueue/river/riverdriver/riverpgxv5"
)

const (
	jobTimeout = 30 * time.Second
	// retention also bounds how long a login code stays in a job row.
	retention  = time.Hour
	maxWorkers = 20
)

// Options configures a client.
type Options struct {
	Logger *slog.Logger
	// Workers is nil for an insert-only client, as in the API process.
	Workers  *river.Workers
	Periodic []*river.PeriodicJob
}

// NewClient returns a River client.
func NewClient(pool *pgxpool.Pool, opts Options) (*river.Client[pgx.Tx], error) {
	config := &river.Config{
		Logger:                      opts.Logger,
		JobTimeout:                  jobTimeout,
		CompletedJobRetentionPeriod: retention,
		CancelledJobRetentionPeriod: retention,
		DiscardedJobRetentionPeriod: retention,
		PeriodicJobs:                opts.Periodic,
	}
	if opts.Workers != nil {
		config.Workers = opts.Workers
		config.Queues = map[string]river.QueueConfig{river.QueueDefault: {MaxWorkers: maxWorkers}}
	}
	client, err := river.NewClient(riverpgxv5.New(pool), config)
	if err != nil {
		return nil, fmt.Errorf("river client: %w", err)
	}
	return client, nil
}

// DemoEchoWorker logs its message.
type DemoEchoWorker struct {
	river.WorkerDefaults[DemoEchoArgs]
	Logger *slog.Logger
}

// Work implements river.Worker.
func (w *DemoEchoWorker) Work(ctx context.Context, job *river.Job[DemoEchoArgs]) error {
	w.Logger.InfoContext(ctx, "demo echo", "message", job.Args.Message)
	return nil
}
