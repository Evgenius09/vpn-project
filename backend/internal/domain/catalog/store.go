package catalog

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Evgenius09/vpn-project/backend/internal/db/sqlc"
)

// Store writes the catalog.
type Store interface {
	// Apply upserts servers and disables every other enabled row in one
	// transaction. It reports how many rows changed and how many it disabled.
	Apply(ctx context.Context, servers []Server) (changed, disabled int, err error)
}

// PostgresStore implements Store on sqlc queries.
type PostgresStore struct {
	pool *pgxpool.Pool
}

// NewPostgresStore returns a store over pool.
func NewPostgresStore(pool *pgxpool.Pool) *PostgresStore {
	return &PostgresStore{pool: pool}
}

// Apply implements Store.
func (s *PostgresStore) Apply(ctx context.Context, servers []Server) (changed, disabled int, err error) {
	err = pgx.BeginFunc(ctx, s.pool, func(tx pgx.Tx) error {
		queries := sqlc.New(tx)
		// Two syncs that saw different panels would lock the same rows in
		// opposite order and deadlock, so they take turns.
		if err := queries.LockCatalog(ctx); err != nil {
			return fmt.Errorf("lock catalog: %w", err)
		}
		listed := make([]uuid.UUID, 0, len(servers))
		for _, server := range servers {
			rows, err := queries.UpsertCatalogServer(ctx, upsertParams(server))
			if err != nil {
				return fmt.Errorf("upsert host %s: %w", server.HostUUID, err)
			}
			changed += int(rows)
			listed = append(listed, server.HostUUID)
		}
		rows, err := queries.DisableUnlistedServers(ctx, listed)
		if err != nil {
			return fmt.Errorf("disable unlisted: %w", err)
		}
		disabled = int(rows)
		return nil
	})
	if err != nil {
		return 0, 0, fmt.Errorf("apply catalog: %w", err)
	}
	return changed, disabled, nil
}

func upsertParams(server Server) sqlc.UpsertCatalogServerParams {
	return sqlc.UpsertCatalogServerParams{
		RemnawaveHostUuid: server.HostUUID,
		Grp:               sqlc.ServerGroup(server.Group),
		Protocol:          sqlc.ServerProtocol(server.Protocol),
		DisplayName:       server.DisplayName,
		CountryCode:       server.CountryCode,
		City:              server.City,
		Address:           server.Address,
		//nolint:gosec // Build keeps the port within 1..65535.
		Port:    int32(server.Port),
		Params:  server.Params,
		Enabled: server.Enabled,
		//nolint:gosec // Build keeps the weight within int32.
		SortWeight:  int32(server.SortWeight),
		ContentHash: server.ContentHash(),
	}
}
