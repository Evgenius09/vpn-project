package telegram

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/Evgenius09/vpn-project/backend/internal/db/sqlc"
	tg "github.com/Evgenius09/vpn-project/backend/internal/telegram"
)

// usernameLock serializes nick changes. Telegram ids are positive, so it cannot
// share a key with lockUser. A per-nick lock would not do: two users swapping
// nicks would lock each other's rows in opposite order.
const usernameLock = -1

var errUserNotFound = errors.New("telegram user not found")

// store is the data access of one transaction.
type store struct {
	queries *sqlc.Queries
}

func newStore(tx pgx.Tx) store {
	return store{queries: sqlc.New(tx)}
}

// lockUser serializes the updates of one user until the transaction ends. A row
// lock would not do, because the first /start has no row yet.
func (s store) lockUser(ctx context.Context, telegramID int64) error {
	if err := s.queries.AdvisoryLock(ctx, telegramID); err != nil {
		return fmt.Errorf("lock user: %w", err)
	}
	return nil
}

func (s store) user(ctx context.Context, telegramID int64) (sqlc.GetTelegramUserRow, error) {
	user, err := s.queries.GetTelegramUser(ctx, telegramID)
	if errors.Is(err, pgx.ErrNoRows) {
		return sqlc.GetTelegramUserRow{}, errUserNotFound
	}
	if err != nil {
		return sqlc.GetTelegramUserRow{}, fmt.Errorf("get user: %w", err)
	}
	return user, nil
}

// createUser creates the account and its Telegram user.
func (s store) createUser(ctx context.Context, update tg.Update) (uuid.UUID, error) {
	accountID, err := s.queries.CreateAccount(ctx)
	if err != nil {
		return uuid.Nil, fmt.Errorf("create account: %w", err)
	}
	username := optional(update.Username)
	if err := s.claimUsername(ctx, update.TelegramID, nil, username); err != nil {
		return uuid.Nil, err
	}
	err = s.queries.InsertTelegramUser(ctx, sqlc.InsertTelegramUserParams{
		TelegramID:   update.TelegramID,
		AccountID:    accountID,
		ChatID:       update.ChatID,
		Username:     username,
		FirstName:    update.FirstName,
		LastUpdateID: update.UpdateID,
	})
	if err != nil {
		return uuid.Nil, fmt.Errorf("insert user: %w", err)
	}
	return accountID, nil
}

// refreshUser brings the stored user up to date with the update.
func (s store) refreshUser(ctx context.Context, user sqlc.GetTelegramUserRow, update tg.Update, blockedAt *time.Time) error {
	username := optional(update.Username)
	if err := s.claimUsername(ctx, update.TelegramID, user.Username, username); err != nil {
		return err
	}
	err := s.queries.UpdateTelegramUser(ctx, sqlc.UpdateTelegramUserParams{
		TelegramID:   update.TelegramID,
		ChatID:       update.ChatID,
		Username:     username,
		FirstName:    update.FirstName,
		BotBlockedAt: blockedAt,
		LastUpdateID: update.UpdateID,
	})
	if err != nil {
		return fmt.Errorf("update user: %w", err)
	}
	return nil
}

// claimUsername takes the nick from whoever held it (tech.md 6). The caller
// writes it to its own row in the same transaction.
func (s store) claimUsername(ctx context.Context, telegramID int64, current, next *string) error {
	if next == nil || (current != nil && strings.EqualFold(*current, *next)) {
		return nil
	}
	if err := s.queries.AdvisoryLock(ctx, usernameLock); err != nil {
		return fmt.Errorf("lock usernames: %w", err)
	}
	err := s.queries.ReleaseTelegramUsername(ctx, sqlc.ReleaseTelegramUsernameParams{Username: next, TelegramID: telegramID})
	if err != nil {
		return fmt.Errorf("release username: %w", err)
	}
	return nil
}

func optional(value string) *string {
	if value == "" {
		return nil
	}
	return &value
}
