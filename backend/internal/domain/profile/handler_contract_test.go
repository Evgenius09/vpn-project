package profile

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/require"

	"github.com/Evgenius09/vpn-project/backend/internal/db/sqlc"
	"github.com/Evgenius09/vpn-project/backend/internal/gen/api"
	"github.com/Evgenius09/vpn-project/backend/internal/httpapi"
	"github.com/Evgenius09/vpn-project/backend/internal/seed"
	"github.com/Evgenius09/vpn-project/backend/internal/testutil"
)

const (
	specPath    = "../../../../contracts/openapi.yaml"
	seedPath    = "../../../" + seed.DefaultPath
	policyPath  = "../../../config/policy.yaml"
	seedProfile = "../../../../contracts/fixtures/profile/seed.json"
)

var pepper = []byte("test-pepper")

func writeFile(path, content string) error {
	return os.WriteFile(path, []byte(content), 0o600)
}

type handlers struct {
	httpapi.Unimplemented
	profile *Handler
}

func (h handlers) GetProfile(ctx context.Context, request api.GetProfileRequestObject) (api.GetProfileResponseObject, error) {
	return h.profile.GetProfile(ctx, request)
}

type env struct {
	pool   *pgxpool.Pool
	router http.Handler
	token  string
}

func newEnv(t *testing.T) env {
	t.Helper()
	ctx := context.Background()
	pool := testutil.NewDatabase(t)
	data, err := seed.Load(seedPath)
	require.NoError(t, err)
	require.NoError(t, seed.Apply(ctx, pool, data, pepper))

	policy, err := LoadPolicy(policyPath)
	require.NoError(t, err)

	logger := slog.New(slog.DiscardHandler)
	queries := sqlc.New(pool)
	service := NewService(NewPostgresStore(queries), Options{
		Policy:    policy,
		Endpoints: api.ProfileEndpoints{Api: []string{"http://localhost:8080"}, Bot: "https://t.me/vpnclient_dev_bot"},
		Now:       func() time.Time { return time.Date(2026, 11, 1, 10, 0, 0, 0, time.UTC) },
	})
	router := httpapi.NewRouter(httpapi.Deps{
		Handlers: handlers{profile: NewHandler(service)},
		Devices:  httpapi.NewPostgresDevices(queries, logger),
		Pepper:   pepper,
		Logger:   logger,
		Metrics:  httpapi.NewMetrics(),
	})
	return env{pool: pool, router: router, token: data.Device.Token}
}

func (e env) get(t *testing.T, headers map[string]string) *httptest.ResponseRecorder {
	t.Helper()
	request := httptest.NewRequest(http.MethodGet, "/v1/profile", nil)
	request.Header.Set("Authorization", "Bearer "+e.token)
	for key, value := range headers {
		request.Header.Set(key, value)
	}
	recorder := httptest.NewRecorder()
	e.router.ServeHTTP(recorder, request)
	return recorder
}

func validate(t *testing.T, schema string, body []byte) map[string]any {
	t.Helper()
	spec, err := testutil.LoadSpec(context.Background(), specPath)
	require.NoError(t, err)
	var document map[string]any
	require.NoError(t, json.Unmarshal(body, &document))
	require.NoError(t, testutil.ValidateSchema(spec, schema, document), string(body))
	return document
}

func TestProfileMatchesTheContract(t *testing.T) {
	e := newEnv(t)

	response := e.get(t, nil)

	require.Equal(t, http.StatusOK, response.Code)
	require.Equal(t, "application/json", response.Header().Get("Content-Type"))
	require.NotEmpty(t, response.Header().Get("ETag"))
	require.Empty(t, response.Header().Get("Retry-After"))

	document := validate(t, "ProfileV1", response.Body.Bytes())
	require.Len(t, document["servers"], 5)
}

// The shared Dart fixture must stay equal to what the backend really returns.
func TestSeedProfileFixtureIsCurrent(t *testing.T) {
	e := newEnv(t)
	body := e.get(t, nil).Body.Bytes()

	if os.Getenv("UPDATE_FIXTURES") != "" {
		var pretty map[string]any
		require.NoError(t, json.Unmarshal(body, &pretty))
		encoded, err := json.MarshalIndent(pretty, "", "  ")
		require.NoError(t, err)
		require.NoError(t, os.MkdirAll(filepath.Dir(seedProfile), 0o750))
		require.NoError(t, os.WriteFile(seedProfile, append(encoded, '\n'), 0o600))
	}

	want, err := os.ReadFile(seedProfile)
	require.NoError(t, err)
	require.JSONEq(t, string(want), string(body))
}

func TestMatchingETagReturnsNotModified(t *testing.T) {
	e := newEnv(t)
	etag := e.get(t, nil).Header().Get("ETag")

	response := e.get(t, map[string]string{"If-None-Match": etag})

	require.Equal(t, http.StatusNotModified, response.Code)
	require.Empty(t, response.Body.Bytes())
}

func TestStaleETagReturnsTheProfile(t *testing.T) {
	e := newEnv(t)
	response := e.get(t, map[string]string{"If-None-Match": `"stale"`})
	require.Equal(t, http.StatusOK, response.Code)
}

func TestServerChangeMovesTheETag(t *testing.T) {
	e := newEnv(t)
	before := e.get(t, nil).Header().Get("ETag")

	_, err := e.pool.Exec(context.Background(), `update servers set display_name = 'Renamed' where sort_weight = 10`)
	require.NoError(t, err)

	response := e.get(t, map[string]string{"If-None-Match": before})
	require.Equal(t, http.StatusOK, response.Code)
	require.NotEqual(t, before, response.Header().Get("ETag"))
}

func TestDisabledServersStayOut(t *testing.T) {
	e := newEnv(t)
	_, err := e.pool.Exec(context.Background(), `update servers set enabled = false where grp = 'whitelist'`)
	require.NoError(t, err)

	document := validate(t, "ProfileV1", e.get(t, nil).Body.Bytes())
	require.Len(t, document["servers"], 3)
}

func TestProvisioningAsksTheClientToRetry(t *testing.T) {
	e := newEnv(t)
	_, err := e.pool.Exec(context.Background(), `update accounts set status = 'provisioning'`)
	require.NoError(t, err)

	response := e.get(t, nil)

	require.Equal(t, http.StatusOK, response.Code)
	require.Equal(t, RetryAfterHeader(), response.Header().Get("Retry-After"))
	document := validate(t, "ProfileV1", response.Body.Bytes())
	require.Empty(t, document["servers"])
}

func TestExpiredAccountGetsNoServers(t *testing.T) {
	e := newEnv(t)
	_, err := e.pool.Exec(context.Background(), `update accounts set status = 'expired'`)
	require.NoError(t, err)

	document := validate(t, "ProfileV1", e.get(t, nil).Body.Bytes())
	require.Empty(t, document["servers"])
}

func TestRevokedDeviceIsRefused(t *testing.T) {
	e := newEnv(t)
	_, err := e.pool.Exec(context.Background(), `update devices set revoked_at = now()`)
	require.NoError(t, err)

	response := e.get(t, nil)

	require.Equal(t, http.StatusUnauthorized, response.Code)
	document := validate(t, "Problem", response.Body.Bytes())
	require.Equal(t, "device_revoked", document["code"])
}

func TestDatabaseFailureIsAProblem(t *testing.T) {
	e := newEnv(t)
	e2 := e
	logger := slog.New(slog.DiscardHandler)
	broken := NewService(failingStore{}, Options{})
	e2.router = httpapi.NewRouter(httpapi.Deps{
		Handlers: handlers{profile: NewHandler(broken)},
		Devices:  httpapi.NewPostgresDevices(sqlc.New(e.pool), logger),
		Pepper:   pepper,
		Logger:   logger,
		Metrics:  httpapi.NewMetrics(),
	})

	response := e2.get(t, nil)

	require.Equal(t, http.StatusInternalServerError, response.Code)
	document := validate(t, "Problem", response.Body.Bytes())
	require.Equal(t, "internal", document["code"])
}

type failingStore struct{}

func (failingStore) Account(context.Context, uuid.UUID) (Account, error) {
	return Account{}, errors.New("database down")
}

func (failingStore) Servers(context.Context) ([]Server, error) {
	return nil, errors.New("database down")
}
