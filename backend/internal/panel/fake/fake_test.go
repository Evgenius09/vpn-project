package fake

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"

	"github.com/Evgenius09/vpn-project/backend/internal/panel"
)

func validInput() panel.CreateUserInput {
	return panel.CreateUserInput{Username: "tg_42", ExpiresAt: time.Now().Add(time.Hour)}
}

func TestCreateThenGet(t *testing.T) {
	client := New()
	created, err := client.CreateUser(context.Background(), validInput())
	require.NoError(t, err)
	require.NotEmpty(t, created.VlessUUID)
	require.NotEmpty(t, created.Hysteria2Auth)

	found, err := client.GetUserByUsername(context.Background(), "tg_42")
	require.NoError(t, err)
	require.Equal(t, created, found)
}

func TestErrorsFollowTheContract(t *testing.T) {
	ctx := context.Background()
	client := New()

	_, err := client.GetUserByUsername(ctx, "tg_1")
	require.ErrorIs(t, err, panel.ErrNotFound)

	_, err = client.UpdateUser(ctx, uuid.New(), panel.UpdateUserInput{ExpiresAt: time.Now()})
	require.ErrorIs(t, err, panel.ErrNotFound)

	_, err = client.CreateUser(ctx, validInput())
	require.NoError(t, err)
	_, err = client.CreateUser(ctx, validInput())
	require.ErrorIs(t, err, panel.ErrConflict)
}

func TestRejectsGarbage(t *testing.T) {
	ctx := context.Background()
	client := New()

	_, err := client.CreateUser(ctx, panel.CreateUserInput{Username: "bob", ExpiresAt: time.Now()})
	require.ErrorIs(t, err, ErrInvalidInput)

	_, err = client.CreateUser(ctx, panel.CreateUserInput{Username: "tg_1"})
	require.ErrorIs(t, err, ErrInvalidInput)

	_, err = client.CreateUser(ctx, panel.CreateUserInput{Username: "tg_1", ExpiresAt: time.Now(), TrafficLimit: -1})
	require.ErrorIs(t, err, ErrInvalidInput)

	_, err = client.GetUserByUsername(ctx, "1; drop table")
	require.ErrorIs(t, err, ErrInvalidInput)
}

func TestFailNextIsOneShotAndOrdered(t *testing.T) {
	ctx := context.Background()
	client := New()
	client.FailNext(OpListHosts, panel.ErrUnavailable)
	client.FailNext(OpListHosts, context.DeadlineExceeded)

	_, err := client.ListHosts(ctx)
	require.ErrorIs(t, err, panel.ErrUnavailable)
	_, err = client.ListHosts(ctx)
	require.ErrorIs(t, err, context.DeadlineExceeded)
	_, err = client.ListHosts(ctx)
	require.NoError(t, err)
	require.Equal(t, 3, client.Calls(OpListHosts))
}

func TestUpdateSetsAbsoluteValues(t *testing.T) {
	ctx := context.Background()
	client := New()
	created, err := client.CreateUser(ctx, validInput())
	require.NoError(t, err)

	expiry := time.Now().Add(48 * time.Hour)
	input := panel.UpdateUserInput{ExpiresAt: expiry, TrafficLimit: 100}
	first, err := client.UpdateUser(ctx, created.UUID, input)
	require.NoError(t, err)
	second, err := client.UpdateUser(ctx, created.UUID, input)
	require.NoError(t, err)
	require.Equal(t, first, second, "a repeated update changes nothing")
	require.Equal(t, int64(100), second.TrafficLimit)
}
