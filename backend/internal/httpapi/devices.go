package httpapi

import (
	"context"
	"errors"
	"fmt"
	"log/slog"

	"github.com/jackc/pgx/v5"

	"github.com/Evgenius09/vpn-project/backend/internal/db/sqlc"
)

// PostgresDevices implements DeviceStore on sqlc queries.
type PostgresDevices struct {
	queries *sqlc.Queries
	logger  *slog.Logger
}

// NewPostgresDevices returns a store over queries.
func NewPostgresDevices(queries *sqlc.Queries, logger *slog.Logger) *PostgresDevices {
	return &PostgresDevices{queries: queries, logger: logger}
}

// FindByTokenHash implements DeviceStore. A failed last-seen update does not
// fail the request, because it only feeds the device list.
func (s *PostgresDevices) FindByTokenHash(ctx context.Context, tokenHash []byte) (Device, error) {
	row, err := s.queries.GetDeviceByTokenHash(ctx, tokenHash)
	if errors.Is(err, pgx.ErrNoRows) {
		return Device{}, ErrDeviceNotFound
	}
	if err != nil {
		return Device{}, fmt.Errorf("get device: %w", err)
	}
	if err := s.queries.TouchDevice(ctx, row.ID); err != nil {
		s.logger.WarnContext(ctx, "touch device", "error", err)
	}
	return Device{ID: row.ID, AccountID: row.AccountID, Revoked: row.RevokedAt != nil}, nil
}
