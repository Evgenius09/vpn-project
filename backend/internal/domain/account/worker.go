package account

import (
	"context"
	"errors"
	"fmt"

	"github.com/riverqueue/river"

	"github.com/Evgenius09/vpn-project/backend/internal/jobs"
)

// ProvisionWorker runs panel_provision_user. A panel outage and database
// errors retry; a rejection or a missing account cancels (tech.md 7).
type ProvisionWorker struct {
	river.WorkerDefaults[jobs.PanelProvisionUserArgs]
	Service *Service
}

// Work implements river.Worker.
func (w *ProvisionWorker) Work(ctx context.Context, job *river.Job[jobs.PanelProvisionUserArgs]) error {
	err := w.Service.Provision(ctx, job.Args.AccountID)
	if errors.Is(err, ErrAccountNotFound) || errors.Is(err, ErrPanelRejected) {
		return river.JobCancel(err)
	}
	if err != nil {
		return fmt.Errorf("provision: %w", err)
	}
	return nil
}
