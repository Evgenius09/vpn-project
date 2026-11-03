package auth

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/Evgenius09/vpn-project/backend/internal/db/sqlc"
)

var errLoginNotFound = errors.New("login not found")

// store is the data access of one transaction.
type store struct {
	queries *sqlc.Queries
}

func newStore(tx pgx.Tx) store {
	return store{queries: sqlc.New(tx)}
}

// reachableUser finds the bot user a code can be sent to. A user who blocked
// the bot counts as missing, because the bot cannot write to them (tech.md 5.2).
func (s store) reachableUser(ctx context.Context, username string) (int64, error) {
	user, err := s.queries.GetTelegramUserByUsername(ctx, &username)
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, ErrUserNotFound
	}
	if err != nil {
		return 0, fmt.Errorf("find user: %w", err)
	}
	if user.BotBlockedAt != nil {
		return 0, ErrUserNotFound
	}
	return user.TelegramID, nil
}

// lockUser shares its key with the bot's updates of the same user.
func (s store) lockUser(ctx context.Context, telegramID int64) error {
	if err := s.queries.AdvisoryLock(ctx, telegramID); err != nil {
		return fmt.Errorf("lock user: %w", err)
	}
	return nil
}

func (s store) recentCodes(ctx context.Context, telegramID int64, since time.Time) ([]time.Time, error) {
	sent, err := s.queries.ListRecentLoginCodes(ctx, sqlc.ListRecentLoginCodesParams{TelegramID: telegramID, CreatedAt: since})
	if err != nil {
		return nil, fmt.Errorf("list codes: %w", err)
	}
	return sent, nil
}

// replaceCode invalidates the open codes of this install and adds a new one.
func (s store) replaceCode(ctx context.Context, telegramID int64, installID uuid.UUID, codeHash []byte, now time.Time) (uuid.UUID, error) {
	err := s.queries.InvalidateLoginCodes(ctx, sqlc.InvalidateLoginCodesParams{
		TelegramID: telegramID, InstallID: installID, InvalidatedAt: &now,
	})
	if err != nil {
		return uuid.Nil, fmt.Errorf("invalidate codes: %w", err)
	}
	id, err := s.queries.InsertLoginCode(ctx, sqlc.InsertLoginCodeParams{
		TelegramID: telegramID,
		InstallID:  installID,
		CodeHash:   codeHash,
		ExpiresAt:  now.Add(codeTTL),
		CreatedAt:  now,
	})
	if err != nil {
		return uuid.Nil, fmt.Errorf("insert code: %w", err)
	}
	return id, nil
}

func (s store) loginForUpdate(ctx context.Context, id uuid.UUID) (sqlc.GetLoginCodeForUpdateRow, error) {
	login, err := s.queries.GetLoginCodeForUpdate(ctx, id)
	if errors.Is(err, pgx.ErrNoRows) {
		return sqlc.GetLoginCodeForUpdateRow{}, errLoginNotFound
	}
	if err != nil {
		return sqlc.GetLoginCodeForUpdateRow{}, fmt.Errorf("get code: %w", err)
	}
	return login, nil
}

func (s store) setAttempts(ctx context.Context, id uuid.UUID, attempts int32) error {
	err := s.queries.SetLoginCodeAttempts(ctx, sqlc.SetLoginCodeAttemptsParams{ID: id, Attempts: attempts})
	if err != nil {
		return fmt.Errorf("set attempts: %w", err)
	}
	return nil
}

func (s store) consumeCode(ctx context.Context, id uuid.UUID, now time.Time) error {
	err := s.queries.ConsumeLoginCode(ctx, sqlc.ConsumeLoginCodeParams{ID: id, ConsumedAt: &now})
	if err != nil {
		return fmt.Errorf("consume code: %w", err)
	}
	return nil
}

// bindDevice applies tech.md 19.9 and writes nothing when the limit refuses. The
// account lock comes first, so two logins cannot both take the last slot.
func (s store) bindDevice(ctx context.Context, accountID uuid.UUID, input VerifyInput, tokenHash []byte) (uuid.UUID, error) {
	limit, err := s.queries.GetDeviceLimitForUpdate(ctx, accountID)
	if err != nil {
		return uuid.Nil, fmt.Errorf("lock account: %w", err)
	}
	device, err := s.queries.GetDeviceByInstallIDForUpdate(ctx, input.InstallID)
	found := err == nil
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return uuid.Nil, fmt.Errorf("get device: %w", err)
	}

	holdsSlot := found && device.AccountID == accountID && device.RevokedAt == nil
	if !holdsSlot {
		active, err := s.queries.CountActiveDevices(ctx, accountID)
		if err != nil {
			return uuid.Nil, fmt.Errorf("count devices: %w", err)
		}
		if active >= int64(limit) {
			return uuid.Nil, ErrDeviceLimit
		}
	}

	platform := sqlc.Platform(input.Platform)
	if found {
		err := s.queries.RebindDevice(ctx, sqlc.RebindDeviceParams{
			ID:         device.ID,
			AccountID:  accountID,
			Platform:   platform,
			Model:      input.Model,
			AppVersion: input.AppVersion,
			TokenHash:  tokenHash,
		})
		if err != nil {
			return uuid.Nil, fmt.Errorf("rebind device: %w", err)
		}
		return device.ID, nil
	}
	id, err := s.queries.InsertDevice(ctx, sqlc.InsertDeviceParams{
		AccountID:  accountID,
		InstallID:  input.InstallID,
		Platform:   platform,
		Model:      input.Model,
		AppVersion: input.AppVersion,
		TokenHash:  tokenHash,
	})
	if err != nil {
		return uuid.Nil, fmt.Errorf("insert device: %w", err)
	}
	return id, nil
}
