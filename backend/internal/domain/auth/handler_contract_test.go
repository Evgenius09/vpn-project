package auth

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/getkin/kin-openapi/openapi3"
	"github.com/google/uuid"
	"github.com/stretchr/testify/require"

	"github.com/Evgenius09/vpn-project/backend/internal/db/sqlc"
	"github.com/Evgenius09/vpn-project/backend/internal/gen/api"
	"github.com/Evgenius09/vpn-project/backend/internal/httpapi"
	"github.com/Evgenius09/vpn-project/backend/internal/testutil"
)

const specPath = "../../../../contracts/openapi.yaml"

type handlers struct {
	httpapi.Unimplemented
	auth *Handler
}

func (h handlers) StartTelegramLogin(ctx context.Context, request api.StartTelegramLoginRequestObject) (api.StartTelegramLoginResponseObject, error) {
	return h.auth.StartTelegramLogin(ctx, request)
}

func (h handlers) VerifyTelegramLogin(ctx context.Context, request api.VerifyTelegramLoginRequestObject) (api.VerifyTelegramLoginResponseObject, error) {
	return h.auth.VerifyTelegramLogin(ctx, request)
}

func (h handlers) Logout(ctx context.Context, request api.LogoutRequestObject) (api.LogoutResponseObject, error) {
	return h.auth.Logout(ctx, request)
}

type server struct {
	*env
	spec   *openapi3.T
	router http.Handler
}

func newServer(t *testing.T) *server {
	t.Helper()
	spec, err := testutil.LoadSpec(context.Background(), specPath)
	require.NoError(t, err)
	e := newEnv(t)
	logger := slog.New(slog.DiscardHandler)
	return &server{env: e, spec: spec, router: httpapi.NewRouter(httpapi.Deps{
		Handlers: handlers{auth: NewHandler(e.service)},
		Devices:  httpapi.NewPostgresDevices(sqlc.New(e.pool), logger),
		Pepper:   pepper,
		Logger:   logger,
		Metrics:  httpapi.NewMetrics(),
	})}
}

func (s *server) post(path, token, body string) *httptest.ResponseRecorder {
	request := httptest.NewRequest(http.MethodPost, path, strings.NewReader(body))
	request.Header.Set("Content-Type", "application/json")
	if token != "" {
		request.Header.Set("Authorization", "Bearer "+token)
	}
	recorder := httptest.NewRecorder()
	s.router.ServeHTTP(recorder, request)
	return recorder
}

func (s *server) requireBody(t *testing.T, response *httptest.ResponseRecorder, status int, schema string) map[string]any {
	t.Helper()
	require.Equal(t, status, response.Code, response.Body.String())
	var document map[string]any
	require.NoError(t, json.Unmarshal(response.Body.Bytes(), &document))
	require.NoError(t, testutil.ValidateSchema(s.spec, schema, document))
	return document
}

func (s *server) requireProblem(t *testing.T, response *httptest.ResponseRecorder, status int, code string) map[string]any {
	t.Helper()
	require.Equal(t, "application/problem+json", response.Header().Get("Content-Type"))
	document := s.requireBody(t, response, status, "Problem")
	require.Equal(t, code, document["code"])
	return document
}

func startBody(username string, installID uuid.UUID) string {
	return fmt.Sprintf(`{"username":%q,"installId":%q,"model":"Pixel 7"}`, username, installID)
}

func verifyBody(loginID, installID uuid.UUID, code string) string {
	return fmt.Sprintf(`{"loginId":%q,"code":%q,"installId":%q,"platform":"windows","model":"Pixel 7","appVersion":"1.2.3"}`,
		loginID, code, installID)
}

const (
	startPath  = "/v1/auth/telegram/start"
	verifyPath = "/v1/auth/telegram/verify"
	logoutPath = "/v1/auth/logout"
)

func (s *server) challenge(t *testing.T, installID uuid.UUID) uuid.UUID {
	t.Helper()
	document := s.requireBody(t, s.post(startPath, "", startBody("seed_user", installID)), http.StatusOK, "TelegramLoginChallenge")
	loginID, err := uuid.Parse(document["loginId"].(string))
	require.NoError(t, err)
	return loginID
}

func TestStartAnswersByTheContract(t *testing.T) {
	s := newServer(t)

	document := s.requireBody(t, s.post(startPath, "", startBody("@Seed_User", uuid.New())), http.StatusOK, "TelegramLoginChallenge")

	require.Equal(t, float64(60), document["resendAfterSec"])
	require.Equal(t, botURL, document["botUrl"])
}

func TestStartWithAMalformedNick(t *testing.T) {
	s := newServer(t)

	s.requireProblem(t, s.post(startPath, "", startBody("no spaces please", uuid.New())), http.StatusBadRequest, "validation_failed")
}

func TestStartForAnUnknownNickPointsAtTheBot(t *testing.T) {
	s := newServer(t)

	document := s.requireProblem(t, s.post(startPath, "", startBody("nobody", uuid.New())), http.StatusNotFound, "telegram_user_not_found")

	require.Equal(t, botURL, document["botUrl"])
}

func TestStartRateLimit(t *testing.T) {
	s := newServer(t)
	s.challenge(t, uuid.New())

	document := s.requireProblem(t, s.post(startPath, "", startBody("seed_user", uuid.New())), http.StatusTooManyRequests, "rate_limited")

	require.Equal(t, float64(60), document["retryAfterSec"])
}

func TestVerifyAnswersByTheContract(t *testing.T) {
	s := newServer(t)
	installID := uuid.New()
	loginID := s.challenge(t, installID)

	document := s.requireBody(t, s.post(verifyPath, "", verifyBody(loginID, installID, s.code(t, loginID))), http.StatusOK, "AuthResult")

	require.Equal(t, s.data.Account.ID.String(), document["accountId"])
}

func TestWrongCodeReportsTheAttemptsLeft(t *testing.T) {
	s := newServer(t)
	installID := uuid.New()
	loginID := s.challenge(t, installID)

	document := s.requireProblem(t, s.post(verifyPath, "", verifyBody(loginID, installID, wrongCode(s.code(t, loginID)))),
		http.StatusBadRequest, "code_invalid")

	require.Equal(t, float64(4), document["attemptsLeft"])
}

func TestExpiredCode(t *testing.T) {
	s := newServer(t)
	installID := uuid.New()
	loginID := s.challenge(t, installID)
	s.clock.advance(5 * time.Minute)

	s.requireProblem(t, s.post(verifyPath, "", verifyBody(loginID, installID, s.code(t, loginID))), http.StatusGone, "code_expired")
}

func TestDeviceLimitAnswer(t *testing.T) {
	s := newServer(t)
	s.setDeviceLimit(t, 1)
	installID := uuid.New()
	loginID := s.challenge(t, installID)

	s.requireProblem(t, s.post(verifyPath, "", verifyBody(loginID, installID, s.code(t, loginID))), http.StatusConflict, "device_limit_reached")
}

func TestVerifyWithAnUnknownPlatform(t *testing.T) {
	s := newServer(t)
	installID := uuid.New()
	loginID := s.challenge(t, installID)
	body := strings.Replace(verifyBody(loginID, installID, s.code(t, loginID)), "windows", "ios", 1)

	s.requireProblem(t, s.post(verifyPath, "", body), http.StatusBadRequest, "validation_failed")
}

func TestTheIssuedTokenOpensSecuredRoutes(t *testing.T) {
	s := newServer(t)
	installID := uuid.New()
	loginID := s.challenge(t, installID)
	document := s.requireBody(t, s.post(verifyPath, "", verifyBody(loginID, installID, s.code(t, loginID))), http.StatusOK, "AuthResult")
	token := document["token"].(string)

	response := s.post(logoutPath, token, "")

	require.Equal(t, http.StatusNoContent, response.Code)
	require.Empty(t, response.Body.String())
}

func TestLogoutEndsTheToken(t *testing.T) {
	s := newServer(t)

	require.Equal(t, http.StatusNoContent, s.post(logoutPath, s.data.Device.Token, "").Code)

	s.requireProblem(t, s.post(logoutPath, s.data.Device.Token, ""), http.StatusUnauthorized, "device_revoked")
}

func TestLogoutNeedsAToken(t *testing.T) {
	s := newServer(t)

	s.requireProblem(t, s.post(logoutPath, "", ""), http.StatusUnauthorized, "unauthorized")
}

func TestARotatedTokenStopsWorking(t *testing.T) {
	s := newServer(t)
	installID := s.data.Device.InstallID
	loginID := s.challenge(t, installID)
	s.requireBody(t, s.post(verifyPath, "", verifyBody(loginID, installID, s.code(t, loginID))), http.StatusOK, "AuthResult")

	s.requireProblem(t, s.post(logoutPath, s.data.Device.Token, ""), http.StatusUnauthorized, "unauthorized")
}

func TestInternalFailureHidesDetails(t *testing.T) {
	s := newServer(t)
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	request := httptest.NewRequestWithContext(ctx, http.MethodPost, startPath, strings.NewReader(startBody("seed_user", uuid.New())))
	request.Header.Set("Content-Type", "application/json")
	recorder := httptest.NewRecorder()

	s.router.ServeHTTP(recorder, request)

	document := s.requireProblem(t, recorder, http.StatusInternalServerError, "internal")
	require.NotContains(t, document, "detail")
}
