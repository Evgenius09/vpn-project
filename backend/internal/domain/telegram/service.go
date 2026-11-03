// Package telegram handles bot updates: it issues accounts on /start and keeps
// the Telegram user in step with every update (tech.md 2.2, 5.10).
package telegram

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"time"
	"unicode"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/riverqueue/river"
	"github.com/riverqueue/river/rivertype"

	"github.com/Evgenius09/vpn-project/backend/internal/db/sqlc"
	"github.com/Evgenius09/vpn-project/backend/internal/jobs"
	tg "github.com/Evgenius09/vpn-project/backend/internal/telegram"
)

const (
	startCommand  = "/start"
	handleTimeout = 10 * time.Second
)

// Queue inserts a job inside the caller's transaction.
type Queue interface {
	InsertTx(ctx context.Context, tx pgx.Tx, args river.JobArgs, opts *river.InsertOpts) (*rivertype.JobInsertResult, error)
}

// Service handles updates from the webhook and from long polling.
type Service struct {
	pool   *pgxpool.Pool
	client tg.TelegramClient
	queue  Queue
	logger *slog.Logger
}

// NewService returns a service.
func NewService(pool *pgxpool.Pool, client tg.TelegramClient, queue Queue, logger *slog.Logger) *Service {
	return &Service{pool: pool, client: client, queue: queue, logger: logger}
}

// HandleUpdate applies one update. An error means nothing was committed, so the
// update is safe to deliver again.
func (s *Service) HandleUpdate(ctx context.Context, update tg.Update) error {
	ctx, cancel := context.WithTimeout(ctx, handleTimeout)
	defer cancel()

	var answer string
	err := pgx.BeginFunc(ctx, s.pool, func(tx pgx.Tx) error {
		var err error
		answer, err = s.apply(ctx, tx, update)
		return err
	})
	if err != nil {
		return fmt.Errorf("apply update %d: %w", update.UpdateID, err)
	}
	if answer == "" {
		return nil
	}
	return s.reply(ctx, update, answer)
}

// apply records the update and returns the text to send once it is committed.
func (s *Service) apply(ctx context.Context, tx pgx.Tx, update tg.Update) (string, error) {
	store := newStore(tx)
	if err := store.lockUser(ctx, update.TelegramID); err != nil {
		return "", err
	}
	command := update.Kind == tg.UpdateMessage && isStart(update.Text)

	user, err := store.user(ctx, update.TelegramID)
	switch {
	case errors.Is(err, errUserNotFound):
		if !command {
			return "", nil
		}
		if err := s.issueAccount(ctx, tx, store, update); err != nil {
			return "", err
		}
	case err != nil:
		return "", err
	case user.LastUpdateID == update.UpdateID:
		// Only an exact match is a redelivery: Telegram restarts ids at a random
		// value after a quiet week, so a lower id can be a new update.
		return "", nil
	default:
		if err := store.refreshUser(ctx, user, update, blockedAt(update.Kind, user.BotBlockedAt, time.Now())); err != nil {
			return "", err
		}
	}

	if !command {
		return "", nil
	}
	if update.Username == "" {
		return messageNoUsername, nil
	}
	return startMessage(update.Username), nil
}

func (s *Service) issueAccount(ctx context.Context, tx pgx.Tx, store store, update tg.Update) error {
	accountID, err := store.createUser(ctx, update)
	if err != nil {
		return err
	}
	if _, err := s.queue.InsertTx(ctx, tx, jobs.PanelProvisionUserArgs{AccountID: accountID}, nil); err != nil {
		return fmt.Errorf("queue provisioning: %w", err)
	}
	return nil
}

// reply runs after the commit. A lost reply stays lost, because a redelivery is
// dropped as a duplicate; the user gets the next one on another /start.
func (s *Service) reply(ctx context.Context, update tg.Update, text string) error {
	_, err := s.client.SendMessage(ctx, update.ChatID, text, nil)
	switch {
	case err == nil:
		return nil
	case errors.Is(err, tg.ErrBotBlocked):
		if err := sqlc.New(s.pool).MarkTelegramBotBlocked(ctx, update.TelegramID); err != nil {
			return fmt.Errorf("mark bot blocked: %w", err)
		}
		return nil
	default:
		s.logger.WarnContext(ctx, "bot reply failed", "updateId", update.UpdateID, "error", err)
		return nil
	}
}

// blockedAt follows tech.md 19.8: only a message or an unblock clears the mark.
func blockedAt(kind tg.UpdateKind, current *time.Time, now time.Time) *time.Time {
	switch kind {
	case tg.UpdateMessage, tg.UpdateBotUnblocked:
		return nil
	case tg.UpdateBotBlocked:
		return &now
	default:
		return current
	}
}

// isStart reports whether text is the /start command, with or without a bot
// name and a deep link payload.
func isStart(text string) bool {
	head := text
	if end := strings.IndexFunc(text, unicode.IsSpace); end >= 0 {
		head = text[:end]
	}
	head, _, _ = strings.Cut(head, "@")
	return head == startCommand
}
