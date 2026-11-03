package auth

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/riverqueue/river"

	"github.com/Evgenius09/vpn-project/backend/internal/db/sqlc"
	"github.com/Evgenius09/vpn-project/backend/internal/domain/telegram"
	"github.com/Evgenius09/vpn-project/backend/internal/jobs"
	tg "github.com/Evgenius09/vpn-project/backend/internal/telegram"
)

const retryInterval = 2 * time.Second

// SendCodeWorker delivers login codes (tech.md 7).
type SendCodeWorker struct {
	river.WorkerDefaults[jobs.TelegramSendCodeArgs]
	Queries *sqlc.Queries
	Client  tg.TelegramClient
	Now     func() time.Time
}

// NextRetry implements river.Worker.
func (w *SendCodeWorker) NextRetry(*river.Job[jobs.TelegramSendCodeArgs]) time.Time {
	return w.Now().Add(retryInterval)
}

// Work implements river.Worker.
func (w *SendCodeWorker) Work(ctx context.Context, job *river.Job[jobs.TelegramSendCodeArgs]) error {
	delivery, err := w.Queries.GetLoginCodeDelivery(ctx, job.Args.LoginID)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("get delivery: %w", err)
	}
	now := w.Now()
	if !deliverable(delivery, now) {
		return nil
	}

	_, err = w.Client.SendMessage(ctx, delivery.ChatID, telegram.CodeMessage(job.Args.Code, job.Args.Model), nil)
	switch {
	case errors.Is(err, tg.ErrBotBlocked):
		if err := w.Queries.MarkTelegramBotBlocked(ctx, delivery.TelegramID); err != nil {
			return fmt.Errorf("mark bot blocked: %w", err)
		}
		return river.JobCancel(err) //nolint:wrapcheck // River reads the cancel marker from this exact error.
	case err != nil:
		return fmt.Errorf("send code: %w", err)
	}

	if err := w.Queries.MarkLoginCodeSent(ctx, sqlc.MarkLoginCodeSentParams{ID: job.Args.LoginID, SentAt: &now}); err != nil {
		return fmt.Errorf("mark code sent: %w", err)
	}
	return nil
}

func deliverable(delivery sqlc.GetLoginCodeDeliveryRow, now time.Time) bool {
	return delivery.SentAt == nil &&
		delivery.ConsumedAt == nil &&
		delivery.InvalidatedAt == nil &&
		now.Before(delivery.ExpiresAt)
}
