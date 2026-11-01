package httpapi

import (
	"context"
	"log/slog"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/require"

	"github.com/Evgenius09/vpn-project/backend/internal/db/sqlc"
	"github.com/Evgenius09/vpn-project/backend/internal/testutil"
)

func insertDevice(t *testing.T, pool *pgxpool.Pool, hash []byte) (deviceID, accountID uuid.UUID) {
	t.Helper()
	ctx := context.Background()
	require.NoError(t, pool.QueryRow(ctx, `insert into accounts default values returning id`).Scan(&accountID))
	require.NoError(t, pool.QueryRow(ctx, `
		insert into devices (account_id, install_id, platform, app_version, token_hash, last_seen_at)
		values ($1, gen_random_uuid(), 'android', '0.1.0', $2, now() - interval '1 hour')
		returning id`, accountID, hash).Scan(&deviceID))
	return deviceID, accountID
}

func TestPostgresDevices(t *testing.T) {
	ctx := context.Background()
	pool := testutil.NewDatabase(t)
	store := NewPostgresDevices(sqlc.New(pool), slog.New(slog.DiscardHandler))
	hash := HashToken("token", pepper)
	deviceID, accountID := insertDevice(t, pool, hash)

	_, err := store.FindByTokenHash(ctx, HashToken("other", pepper))
	require.ErrorIs(t, err, ErrDeviceNotFound)

	device, err := store.FindByTokenHash(ctx, hash)
	require.NoError(t, err)
	require.Equal(t, Device{ID: deviceID, AccountID: accountID}, device)

	var lastSeen time.Time
	require.NoError(t, pool.QueryRow(ctx, `select last_seen_at from devices where id = $1`, deviceID).Scan(&lastSeen))
	require.WithinDuration(t, time.Now(), lastSeen, time.Minute, "the lookup refreshes last_seen_at")

	_, err = pool.Exec(ctx, `update devices set revoked_at = now() where id = $1`, deviceID)
	require.NoError(t, err)
	device, err = store.FindByTokenHash(ctx, hash)
	require.NoError(t, err)
	require.True(t, device.Revoked)
}
