// Package account provisions panel users for bot accounts (tech.md 7, S1-10).
package account

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Evgenius09/vpn-project/backend/internal/db/sqlc"
	"github.com/Evgenius09/vpn-project/backend/internal/panel"
)

// Errors a retry cannot fix.
var (
	ErrAccountNotFound = errors.New("account: not found")
	ErrPanelRejected   = errors.New("account: panel rejected the user")
)

// Service provisions panel users.
type Service struct {
	pool      *pgxpool.Pool
	panel     panel.PanelClient
	trialDays int
	now       func() time.Time
}

// NewService returns a Service. trialDays is TRIAL_DAYS.
func NewService(pool *pgxpool.Pool, client panel.PanelClient, trialDays int, now func() time.Time) *Service {
	return &Service{pool: pool, panel: client, trialDays: trialDays, now: now}
}

// Provision creates or adopts the panel user of an account, stores it and
// starts the trial. A provisioned account is a no-op, so a repeat has one
// effect.
func (s *Service) Provision(ctx context.Context, accountID uuid.UUID) error {
	queries := sqlc.New(s.pool)
	target, err := queries.GetProvisionTarget(ctx, accountID)
	if errors.Is(err, pgx.ErrNoRows) {
		return fmt.Errorf("%w: %s", ErrAccountNotFound, accountID)
	}
	if err != nil {
		return fmt.Errorf("load account: %w", err)
	}
	if target.Provisioned {
		return nil
	}

	username := fmt.Sprintf("tg_%d", target.TelegramID)
	user, err := s.panel.CreateUser(ctx, panel.CreateUserInput{
		Username:  username,
		ExpiresAt: s.now().Add(time.Duration(s.trialDays) * 24 * time.Hour),
	})
	if errors.Is(err, panel.ErrConflict) {
		// An earlier attempt created the user and died before the commit.
		user, err = s.panel.GetUserByUsername(ctx, username)
	}
	if err != nil {
		if errors.Is(err, panel.ErrUnavailable) {
			return fmt.Errorf("panel user: %w", err)
		}
		return fmt.Errorf("%w: %w", ErrPanelRejected, err)
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	txQueries := queries.WithTx(tx)
	if _, err := txQueries.InsertPanelUser(ctx, sqlc.InsertPanelUserParams{
		AccountID:         accountID,
		RemnawaveID:       user.ID,
		ShortUuid:         user.ShortUUID,
		VlessUuid:         user.VlessUUID,
		Hysteria2Auth:     user.Hysteria2Auth,
		TrafficLimitBytes: user.TrafficLimit,
		TrafficUsedBytes:  user.TrafficUsed,
	}); err != nil {
		return fmt.Errorf("store panel user: %w", err)
	}
	// The panel's expiry wins, so an adopted user keeps the date it has there.
	expires := user.ExpiresAt
	if err := txQueries.StartTrial(ctx, sqlc.StartTrialParams{ID: accountID, ExpiresAt: &expires}); err != nil {
		return fmt.Errorf("start trial: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit: %w", err)
	}
	return nil
}
