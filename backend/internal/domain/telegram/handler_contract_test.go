package telegram

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/Evgenius09/vpn-project/backend/internal/gen/api"
	"github.com/Evgenius09/vpn-project/backend/internal/httpapi"
)

const (
	webhookPath = "/telegram/webhook"
	secret      = "webhook-secret"

	startBody = `{"update_id":10,"message":{"message_id":1,"date":1,
		"from":{"id":7,"is_bot":false,"first_name":"Ann","username":"Ann"},
		"chat":{"id":7,"type":"private"},"text":"/start"}}`
	groupBody = `{"update_id":11,"message":{"message_id":1,"date":1,
		"from":{"id":7,"is_bot":false,"first_name":"Ann"},
		"chat":{"id":-100,"type":"group"},"text":"/start"}}`
)

func newRouter(t *testing.T, handler http.Handler) http.Handler {
	t.Helper()
	return httpapi.NewRouter(httpapi.Deps{
		Handlers: httpapi.Unimplemented{},
		Logger:   slog.New(slog.DiscardHandler),
		Metrics:  httpapi.NewMetrics(),
		Webhook:  handler,
	})
}

func post(router http.Handler, body string, headers map[string]string) *httptest.ResponseRecorder {
	request := httptest.NewRequest(http.MethodPost, webhookPath, strings.NewReader(body))
	for key, value := range headers {
		request.Header.Set(key, value)
	}
	recorder := httptest.NewRecorder()
	router.ServeHTTP(recorder, request)
	return recorder
}

func signed() map[string]string {
	return map[string]string{SecretHeader: secret}
}

func problemCode(t *testing.T, recorder *httptest.ResponseRecorder) api.ProblemCode {
	t.Helper()
	require.Equal(t, "application/problem+json", recorder.Header().Get("Content-Type"))
	var problem api.Problem
	require.NoError(t, json.Unmarshal(recorder.Body.Bytes(), &problem))
	return problem.Code
}

func TestWebhookRejectsAMissingOrWrongSecret(t *testing.T) {
	cases := map[string]map[string]string{
		"no secret":      nil,
		"wrong secret":   {SecretHeader: "guess"},
		"secret prefix":  {SecretHeader: secret[:len(secret)-1]},
		"empty secret":   {SecretHeader: ""},
		"another header": {"Authorization": "Bearer " + secret},
	}
	for name, headers := range cases {
		t.Run(name, func(t *testing.T) {
			e := newEnv(t)
			router := newRouter(t, NewWebhookHandler(e.service, secret, slog.New(slog.DiscardHandler)))

			recorder := post(router, startBody, headers)

			require.Equal(t, http.StatusUnauthorized, recorder.Code)
			require.Equal(t, api.ProblemCodeUnauthorized, problemCode(t, recorder))
			require.Equal(t, 0, e.count(t, "select count(*) from accounts"))
		})
	}
}

// An unset secret must not turn into "no header matches".
func TestWebhookWithoutAConfiguredSecretRejectsEverything(t *testing.T) {
	e := newEnv(t)
	router := newRouter(t, NewWebhookHandler(e.service, "", slog.New(slog.DiscardHandler)))

	recorder := post(router, startBody, map[string]string{SecretHeader: ""})

	require.Equal(t, http.StatusUnauthorized, recorder.Code)
	require.Equal(t, 0, e.count(t, "select count(*) from accounts"))
}

func TestWebhookAppliesAnUpdate(t *testing.T) {
	e := newEnv(t)
	router := newRouter(t, NewWebhookHandler(e.service, secret, slog.New(slog.DiscardHandler)))

	recorder := post(router, startBody, signed())

	require.Equal(t, http.StatusOK, recorder.Code)
	require.Equal(t, 1, e.count(t, "select count(*) from accounts"))
	require.Equal(t, "ann", *e.username(t, 7))
	require.Len(t, e.client.Sent(), 1)
}

func TestWebhookRedeliveryHasNoEffect(t *testing.T) {
	e := newEnv(t)
	router := newRouter(t, NewWebhookHandler(e.service, secret, slog.New(slog.DiscardHandler)))

	require.Equal(t, http.StatusOK, post(router, startBody, signed()).Code)
	require.Equal(t, http.StatusOK, post(router, startBody, signed()).Code)

	require.Equal(t, 1, e.count(t, "select count(*) from accounts"))
	require.Equal(t, 1, e.count(t, provisionJobs))
	require.Len(t, e.client.Sent(), 1)
}

// Any status but 2xx makes Telegram deliver the update again.
func TestWebhookAcknowledgesUpdatesTheBotDoesNotServe(t *testing.T) {
	e := newEnv(t)
	router := newRouter(t, NewWebhookHandler(e.service, secret, slog.New(slog.DiscardHandler)))

	recorder := post(router, groupBody, signed())

	require.Equal(t, http.StatusOK, recorder.Code)
	require.Equal(t, 0, e.count(t, "select count(*) from accounts"))
	require.Empty(t, e.client.Sent())
}

func TestWebhookRejectsMalformedBodies(t *testing.T) {
	cases := map[string]string{
		"not json":     `{"update_id":`,
		"oversize":     `{"update_id":1,"pad":"` + strings.Repeat("x", maxUpdateBytes) + `"}`,
		"wrong fields": `{"update_id":"one"}`,
	}
	for name, body := range cases {
		t.Run(name, func(t *testing.T) {
			e := newEnv(t)
			router := newRouter(t, NewWebhookHandler(e.service, secret, slog.New(slog.DiscardHandler)))

			recorder := post(router, body, signed())

			require.Equal(t, http.StatusBadRequest, recorder.Code)
			require.Equal(t, api.ProblemCodeValidationFailed, problemCode(t, recorder))
		})
	}
}

func TestWebhookFailureAsksForRedelivery(t *testing.T) {
	e := newEnv(t)
	logger := slog.New(slog.DiscardHandler)
	broken := NewService(e.pool, e.client, brokenQueue{}, logger)

	recorder := post(newRouter(t, NewWebhookHandler(broken, secret, logger)), startBody, signed())

	require.Equal(t, http.StatusInternalServerError, recorder.Code)
	require.Equal(t, api.ProblemCodeInternal, problemCode(t, recorder))
	require.NotContains(t, recorder.Body.String(), "queue is down")

	recorder = post(newRouter(t, NewWebhookHandler(e.service, secret, logger)), startBody, signed())

	require.Equal(t, http.StatusOK, recorder.Code)
	require.Equal(t, 1, e.count(t, "select count(*) from accounts"))
	require.Equal(t, 1, e.count(t, provisionJobs))
	require.Len(t, e.client.Sent(), 1)
}

// Telegram may hang up early. The commit and the reply must still happen,
// because the redelivery will be dropped as a duplicate of a committed update.
func TestWebhookFinishesAfterTheCallerHangsUp(t *testing.T) {
	e := newEnv(t)
	handler := NewWebhookHandler(e.service, secret, slog.New(slog.DiscardHandler))
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	request := httptest.NewRequestWithContext(ctx, http.MethodPost, webhookPath, strings.NewReader(startBody))
	request.Header.Set(SecretHeader, secret)

	handler.ServeHTTP(httptest.NewRecorder(), request)

	require.Equal(t, 1, e.count(t, "select count(*) from accounts"))
	require.Len(t, e.client.Sent(), 1)
}
