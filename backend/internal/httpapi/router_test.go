package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/getkin/kin-openapi/openapi3"
	"github.com/google/uuid"
	"github.com/stretchr/testify/require"

	"github.com/Evgenius09/vpn-project/backend/internal/gen/api"
	"github.com/Evgenius09/vpn-project/backend/internal/testutil"
)

const (
	specPath    = "../../../contracts/openapi.yaml"
	validToken  = "valid-token"
	revokeToken = "revoked-token"
	brokenToken = "broken-token"
)

var pepper = []byte("test-pepper")

type fakeDevices map[string]Device

func (f fakeDevices) FindByTokenHash(_ context.Context, hash []byte) (Device, error) {
	if bytes.Equal(hash, HashToken(brokenToken, pepper)) {
		return Device{}, errors.New("connection refused to 10.0.0.5")
	}
	for token, device := range f {
		if bytes.Equal(hash, HashToken(token, pepper)) {
			return device, nil
		}
	}
	return Device{}, ErrDeviceNotFound
}

type stubHandlers struct {
	Unimplemented
	device *Device
	panics bool
	err    error
}

func (s *stubHandlers) GetProfile(ctx context.Context, _ api.GetProfileRequestObject) (api.GetProfileResponseObject, error) {
	if s.panics {
		panic("secret panic detail")
	}
	if s.err != nil {
		return nil, s.err
	}
	if device, ok := DeviceFromContext(ctx); ok {
		s.device = &device
	}
	return api.GetProfile304Response{}, nil
}

type harness struct {
	spec     *openapi3.T
	router   http.Handler
	metrics  *Metrics
	handlers *stubHandlers
	logs     *bytes.Buffer
}

func newHarness(t *testing.T) *harness {
	t.Helper()
	spec, err := testutil.LoadSpec(context.Background(), specPath)
	require.NoError(t, err)

	h := &harness{spec: spec, metrics: NewMetrics(), handlers: &stubHandlers{}, logs: &bytes.Buffer{}}
	logger := slog.New(slog.NewTextHandler(h.logs, &slog.HandlerOptions{Level: slog.LevelDebug}))
	devices := fakeDevices{
		validToken:  {ID: uuid.New(), AccountID: uuid.New()},
		revokeToken: {ID: uuid.New(), AccountID: uuid.New(), Revoked: true},
	}
	h.router = NewRouter(Deps{
		Handlers: h.handlers, Devices: devices, Pepper: pepper, Logger: logger, Metrics: h.metrics,
	})
	return h
}

func (h *harness) do(method, path, token string, body string) *httptest.ResponseRecorder {
	request := httptest.NewRequest(method, path, strings.NewReader(body))
	if token != "" {
		request.Header.Set("Authorization", "Bearer "+token)
	}
	recorder := httptest.NewRecorder()
	h.router.ServeHTTP(recorder, request)
	return recorder
}

// requireProblem checks a response against the Problem schema of the contract.
func (h *harness) requireProblem(t *testing.T, response *httptest.ResponseRecorder, status int, code string) {
	t.Helper()
	require.Equal(t, status, response.Code)
	require.Equal(t, "application/problem+json", response.Header().Get("Content-Type"))
	var document map[string]any
	require.NoError(t, json.Unmarshal(response.Body.Bytes(), &document))
	require.NoError(t, testutil.ValidateSchema(h.spec, "Problem", document))
	require.Equal(t, code, document["code"])
}

func TestHealthz(t *testing.T) {
	h := newHarness(t)
	response := h.do(http.MethodGet, "/healthz", "", "")
	require.Equal(t, http.StatusOK, response.Code)
}

func TestUnknownRouteIsAProblem(t *testing.T) {
	h := newHarness(t)
	h.requireProblem(t, h.do(http.MethodGet, "/v1/nope", "", ""), http.StatusNotFound, "not_found")
	h.requireProblem(t, h.do(http.MethodDelete, "/healthz", "", ""), http.StatusMethodNotAllowed, "not_found")
}

func TestAuth(t *testing.T) {
	tests := []struct {
		name   string
		token  string
		status int
		code   string
	}{
		{"no token", "", http.StatusUnauthorized, "unauthorized"},
		{"unknown token", "nope", http.StatusUnauthorized, "unauthorized"},
		{"revoked device", revokeToken, http.StatusUnauthorized, "device_revoked"},
		{"store failure", brokenToken, http.StatusInternalServerError, "internal"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			h := newHarness(t)
			h.requireProblem(t, h.do(http.MethodGet, "/v1/profile", tt.token, ""), tt.status, tt.code)
			require.Nil(t, h.handlers.device, "the handler must not run")
		})
	}
}

func TestStoreFailureHidesDetails(t *testing.T) {
	h := newHarness(t)
	response := h.do(http.MethodGet, "/v1/profile", brokenToken, "")
	require.NotContains(t, response.Body.String(), "10.0.0.5")
}

func TestValidTokenReachesTheHandler(t *testing.T) {
	h := newHarness(t)
	response := h.do(http.MethodGet, "/v1/profile", validToken, "")
	require.Equal(t, http.StatusNotModified, response.Code)
	require.NotNil(t, h.handlers.device)
}

func TestMalformedAuthorizationHeader(t *testing.T) {
	h := newHarness(t)
	for _, header := range []string{validToken, "Basic " + validToken, "Bearer", "Bearer "} {
		request := httptest.NewRequest(http.MethodGet, "/v1/profile", nil)
		request.Header.Set("Authorization", header)
		recorder := httptest.NewRecorder()
		h.router.ServeHTTP(recorder, request)
		h.requireProblem(t, recorder, http.StatusUnauthorized, "unauthorized")
	}
}

func TestPublicOperationsNeedNoToken(t *testing.T) {
	h := newHarness(t)
	body := `{"username":"seed_user","installId":"11111111-1111-4111-8111-111111111111","model":"Pixel 7"}`
	response := h.do(http.MethodPost, "/v1/auth/telegram/start", "", body)
	h.requireProblem(t, response, http.StatusNotImplemented, "internal")
}

// The allowlist and the security sections of the contract must agree, or a
// secured operation could become public without anyone noticing.
func TestPublicOperationsMatchTheContract(t *testing.T) {
	h := newHarness(t)
	checked := 0
	for _, item := range h.spec.Paths.Map() {
		for _, operation := range item.Operations() {
			name := strings.ToUpper(operation.OperationID[:1]) + operation.OperationID[1:]
			secured := operation.Security != nil && len(*operation.Security) > 0
			require.Equal(t, !secured, publicOperations[name], name)
			checked++
		}
	}
	require.Equal(t, 5, checked)
}

func TestMalformedBodyIsAValidationProblem(t *testing.T) {
	h := newHarness(t)
	response := h.do(http.MethodPost, "/v1/auth/telegram/start", "", "{not json")
	h.requireProblem(t, response, http.StatusBadRequest, "validation_failed")
}

func TestPanicIsAProblem(t *testing.T) {
	h := newHarness(t)
	h.handlers.panics = true
	response := h.do(http.MethodGet, "/v1/profile", validToken, "")
	h.requireProblem(t, response, http.StatusInternalServerError, "internal")
	require.NotContains(t, response.Body.String(), "secret panic detail")
}

func TestHandlerProblemKeepsItsFields(t *testing.T) {
	h := newHarness(t)
	h.handlers.err = &Problem{
		Status: http.StatusNotFound, Code: api.ProblemCodeTelegramUserNotFound, Title: "Open the bot", BotURL: "https://t.me/x",
	}
	response := h.do(http.MethodGet, "/v1/profile", validToken, "")
	h.requireProblem(t, response, http.StatusNotFound, "telegram_user_not_found")
	require.Contains(t, response.Body.String(), "https://t.me/x")
}

func TestLogsCarryNoTokensOrAddresses(t *testing.T) {
	h := newHarness(t)
	h.do(http.MethodGet, "/v1/profile?secret=1", validToken, "")
	require.NotContains(t, h.logs.String(), validToken)
	require.NotContains(t, h.logs.String(), "192.0.2.1", "httptest default client address")
	require.NotContains(t, h.logs.String(), "secret=1")
}

func TestMetricsCountRoutesNotRawPaths(t *testing.T) {
	h := newHarness(t)
	h.do(http.MethodGet, "/healthz", "", "")
	h.do(http.MethodGet, "/random/one", "", "")
	h.do(http.MethodGet, "/random/two", "", "")

	recorder := httptest.NewRecorder()
	h.metrics.Handler().ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/metrics", nil))
	body, err := io.ReadAll(recorder.Body)
	require.NoError(t, err)
	require.Contains(t, string(body), `route="/healthz"`)
	require.Contains(t, string(body), `route="unmatched",status="404"} 2`)
	require.NotContains(t, string(body), "/random/one")
}

func TestMetricsAreNotOnThePublicRouter(t *testing.T) {
	h := newHarness(t)
	h.requireProblem(t, h.do(http.MethodGet, "/metrics", "", ""), http.StatusNotFound, "not_found")
}

func TestHashTokenDependsOnPepper(t *testing.T) {
	require.Equal(t, HashToken("t", pepper), HashToken("t", pepper))
	require.NotEqual(t, HashToken("t", pepper), HashToken("t", []byte("other")))
	require.NotEqual(t, HashToken("t", pepper), HashToken("u", pepper))
	require.Len(t, HashToken("t", pepper), 32)
}

func TestWebhookIsMountedOnlyWhenSet(t *testing.T) {
	h := newHarness(t)
	h.requireProblem(t, h.do(http.MethodPost, "/telegram/webhook", "", ""), http.StatusNotFound, "not_found")

	called := false
	router := NewRouter(Deps{
		Handlers: h.handlers, Devices: fakeDevices{}, Pepper: pepper,
		Logger: slog.New(slog.DiscardHandler), Metrics: NewMetrics(),
		Webhook: http.HandlerFunc(func(http.ResponseWriter, *http.Request) { called = true }),
	})
	router.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(http.MethodPost, "/telegram/webhook", nil))
	require.True(t, called)
}
