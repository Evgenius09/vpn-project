package auth

import (
	"context"
	"errors"
	"log/slog"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/riverqueue/river"
	"github.com/riverqueue/river/rivertype"
	"github.com/stretchr/testify/require"

	"github.com/Evgenius09/vpn-project/backend/internal/db/sqlc"
	"github.com/Evgenius09/vpn-project/backend/internal/jobs"
	tg "github.com/Evgenius09/vpn-project/backend/internal/telegram"
	"github.com/Evgenius09/vpn-project/backend/internal/telegram/fake"
)

type delivery struct {
	*env
	client *fake.Client
	worker *SendCodeWorker
}

func newDelivery(t *testing.T) delivery {
	t.Helper()
	e := newEnv(t)
	client := fake.New(nil)
	return delivery{env: e, client: client, worker: &SendCodeWorker{
		Queries: sqlc.New(e.pool), Client: client, Now: e.clock.Now,
	}}
}

func (d delivery) job(t *testing.T, challenge Challenge) *river.Job[jobs.TelegramSendCodeArgs] {
	t.Helper()
	return &river.Job[jobs.TelegramSendCodeArgs]{
		JobRow: &rivertype.JobRow{},
		Args:   jobs.TelegramSendCodeArgs{LoginID: challenge.LoginID, Code: d.code(t, challenge.LoginID), Model: "Pixel 7"},
	}
}

func (d delivery) sentAt(t *testing.T, loginID uuid.UUID) *time.Time {
	t.Helper()
	var at *time.Time
	require.NoError(t, d.pool.QueryRow(context.Background(), "select sent_at from login_codes where id = $1", loginID).Scan(&at))
	return at
}

func TestWorkerSendsTheCode(t *testing.T) {
	d := newDelivery(t)
	challenge := d.start(t, uuid.New())
	job := d.job(t, challenge)

	require.NoError(t, d.worker.Work(context.Background(), job))

	sent := d.client.Sent()
	require.Len(t, sent, 1)
	require.Equal(t, d.data.TelegramUser.ChatID, sent[0].ChatID)
	require.Contains(t, sent[0].Text, job.Args.Code)
	require.Contains(t, sent[0].Text, "Pixel 7")
	require.Contains(t, sent[0].Text, "проигнорируйте")
	require.NotNil(t, d.sentAt(t, challenge.LoginID))
}

func TestWorkerRunTwiceSendsOneMessage(t *testing.T) {
	d := newDelivery(t)
	job := d.job(t, d.start(t, uuid.New()))

	require.NoError(t, d.worker.Work(context.Background(), job))
	sentAt := d.sentAt(t, job.Args.LoginID)
	require.NoError(t, d.worker.Work(context.Background(), job))

	require.Len(t, d.client.Sent(), 1)
	require.Equal(t, sentAt, d.sentAt(t, job.Args.LoginID))
}

func TestWorkerSkipsAnInvalidatedCode(t *testing.T) {
	d := newDelivery(t)
	installID := uuid.New()
	job := d.job(t, d.start(t, installID))
	d.clock.advance(time.Minute)
	d.start(t, installID)

	require.NoError(t, d.worker.Work(context.Background(), job))

	require.Empty(t, d.client.Sent())
}

func TestWorkerSkipsAnExpiredCode(t *testing.T) {
	d := newDelivery(t)
	job := d.job(t, d.start(t, uuid.New()))
	d.clock.advance(5 * time.Minute)

	require.NoError(t, d.worker.Work(context.Background(), job))

	require.Empty(t, d.client.Sent())
}

func TestWorkerSkipsAConsumedCode(t *testing.T) {
	d := newDelivery(t)
	installID := uuid.New()
	challenge := d.start(t, installID)
	job := d.job(t, challenge)
	_, err := d.service.Verify(context.Background(), verifyInput(challenge.LoginID, installID, job.Args.Code))
	require.NoError(t, err)

	require.NoError(t, d.worker.Work(context.Background(), job))

	require.Empty(t, d.client.Sent())
}

func TestWorkerSkipsAMissingLogin(t *testing.T) {
	d := newDelivery(t)
	job := &river.Job[jobs.TelegramSendCodeArgs]{
		JobRow: &rivertype.JobRow{},
		Args:   jobs.TelegramSendCodeArgs{LoginID: uuid.New(), Code: "123456"},
	}

	require.NoError(t, d.worker.Work(context.Background(), job))

	require.Empty(t, d.client.Sent())
}

func TestWorkerCancelsWhenTheBotIsBlocked(t *testing.T) {
	d := newDelivery(t)
	job := d.job(t, d.start(t, uuid.New()))
	d.client.FailNext(fake.OpSendMessage, tg.ErrBotBlocked)

	err := d.worker.Work(context.Background(), job)

	var cancel *river.JobCancelError
	require.ErrorAs(t, err, &cancel)
	require.Equal(t, 1, d.count(t, "select count(*) from telegram_users where bot_blocked_at is not null"))
	require.Nil(t, d.sentAt(t, job.Args.LoginID))
}

func TestWorkerRetriesAnOutage(t *testing.T) {
	d := newDelivery(t)
	job := d.job(t, d.start(t, uuid.New()))
	d.client.FailNext(fake.OpSendMessage, tg.ErrUnavailable)

	err := d.worker.Work(context.Background(), job)

	require.ErrorIs(t, err, tg.ErrUnavailable)
	var cancel *river.JobCancelError
	require.NotErrorAs(t, err, &cancel)
	require.Nil(t, d.sentAt(t, job.Args.LoginID))

	require.NoError(t, d.worker.Work(context.Background(), job))
	require.Len(t, d.client.Sent(), 1)
}

func TestWorkerErrorsCarryNoCode(t *testing.T) {
	d := newDelivery(t)
	job := d.job(t, d.start(t, uuid.New()))
	d.client.FailNext(fake.OpSendMessage, errors.New("telegram said no"))

	err := d.worker.Work(context.Background(), job)

	require.Error(t, err)
	require.NotContains(t, err.Error(), job.Args.Code)
}

func TestWorkerRetriesAfterTwoSeconds(t *testing.T) {
	d := newDelivery(t)
	job := d.job(t, d.start(t, uuid.New()))

	require.WithinDuration(t, d.clock.Now().Add(2*time.Second), d.worker.NextRetry(job), 0)
}

func TestCodeTravelsFromStartToTheBot(t *testing.T) {
	d := newDelivery(t)
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	workers := river.NewWorkers()
	river.AddWorker(workers, d.worker)
	client, err := jobs.NewClient(d.pool, jobs.Options{Logger: slog.New(slog.DiscardHandler), Workers: workers})
	require.NoError(t, err)
	completed, stop := client.Subscribe(river.EventKindJobCompleted)
	defer stop()
	require.NoError(t, client.Start(ctx))
	defer func() { require.NoError(t, client.Stop(context.WithoutCancel(ctx))) }()

	challenge := d.start(t, uuid.New())

	select {
	case <-completed:
	case <-ctx.Done():
		t.Fatal("the job did not complete")
	}
	sent := d.client.Sent()
	require.Len(t, sent, 1)
	require.Contains(t, sent[0].Text, d.code(t, challenge.LoginID))
}
