package profile

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/Evgenius09/vpn-project/backend/internal/db/sqlc"
)

// ErrAccountNotFound means the device points at no account.
var ErrAccountNotFound = errors.New("profile: account not found")

// Account is the stored state a profile needs.
type Account struct {
	Status            string
	ExpiresAt         *time.Time
	DeviceLimit       int
	TelegramUsername  *string
	VlessUUID         string // secret
	Hysteria2Auth     string // secret
	TrafficLimitBytes int64
	TrafficUsedBytes  int64
}

// Server is a published server without user credentials.
type Server struct {
	ID          uuid.UUID
	Group       string
	Protocol    string
	DisplayName string
	CountryCode string
	City        *string
	Address     string
	Port        int
	Params      json.RawMessage
	SortWeight  int
}

// Store reads profile data.
type Store interface {
	Account(ctx context.Context, accountID uuid.UUID) (Account, error)
	Servers(ctx context.Context) ([]Server, error)
}

// PostgresStore implements Store on sqlc queries.
type PostgresStore struct {
	queries *sqlc.Queries
}

// NewPostgresStore returns a store over queries.
func NewPostgresStore(queries *sqlc.Queries) *PostgresStore {
	return &PostgresStore{queries: queries}
}

// Account implements Store.
func (s *PostgresStore) Account(ctx context.Context, accountID uuid.UUID) (Account, error) {
	row, err := s.queries.GetProfileAccount(ctx, accountID)
	if errors.Is(err, pgx.ErrNoRows) {
		return Account{}, ErrAccountNotFound
	}
	if err != nil {
		return Account{}, fmt.Errorf("get account: %w", err)
	}
	return Account{
		Status:            string(row.Status),
		ExpiresAt:         row.ExpiresAt,
		DeviceLimit:       int(row.DeviceLimit),
		TelegramUsername:  row.Username,
		VlessUUID:         row.VlessUuid.String,
		Hysteria2Auth:     row.Hysteria2Auth.String,
		TrafficLimitBytes: row.TrafficLimitBytes.Int64,
		TrafficUsedBytes:  row.TrafficUsedBytes.Int64,
	}, nil
}

// Servers implements Store.
func (s *PostgresStore) Servers(ctx context.Context) ([]Server, error) {
	rows, err := s.queries.ListEnabledServers(ctx)
	if err != nil {
		return nil, fmt.Errorf("list servers: %w", err)
	}
	servers := make([]Server, 0, len(rows))
	for _, row := range rows {
		servers = append(servers, Server{
			ID:          row.ID,
			Group:       string(row.Grp),
			Protocol:    string(row.Protocol),
			DisplayName: row.DisplayName,
			CountryCode: row.CountryCode,
			City:        row.City,
			Address:     row.Address,
			Port:        int(row.Port),
			Params:      row.Params,
			SortWeight:  int(row.SortWeight),
		})
	}
	return servers, nil
}

// retryAfter is the Retry-After value while an account provisions (tech.md 5.2).
const retryAfter = 2

// RetryAfterHeader returns the header value for tests and logs.
func RetryAfterHeader() string { return strconv.Itoa(retryAfter) }
