package catalog

import (
	"context"
	"fmt"
	"time"

	"github.com/riverqueue/river"

	"github.com/Evgenius09/vpn-project/backend/internal/jobs"
)

// SyncInterval is the period of catalog_sync (tech.md 7).
const SyncInterval = 5 * time.Minute

// SyncWorker runs catalog_sync. Every error retries: a panel outage passes,
// and once the attempts run out the next periodic run takes over.
type SyncWorker struct {
	river.WorkerDefaults[jobs.CatalogSyncArgs]
	Service *Service
}

// Work implements river.Worker.
func (w *SyncWorker) Work(ctx context.Context, _ *river.Job[jobs.CatalogSyncArgs]) error {
	if _, err := w.Service.Sync(ctx); err != nil {
		return fmt.Errorf("catalog sync: %w", err)
	}
	return nil
}

// PeriodicJob schedules catalog_sync every SyncInterval and once at start.
func PeriodicJob() *river.PeriodicJob {
	return river.NewPeriodicJob(
		river.PeriodicInterval(SyncInterval),
		func() (river.JobArgs, *river.InsertOpts) { return jobs.CatalogSyncArgs{}, nil },
		&river.PeriodicJobOpts{RunOnStart: true},
	)
}
