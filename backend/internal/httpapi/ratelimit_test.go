package httpapi

import (
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

const loginBody = `{"username":"seed_user","installId":"11111111-1111-4111-8111-111111111111","model":"Pixel 7"}`

func newLimitedHarness(t *testing.T, limit int) *harness {
	t.Helper()
	h := newHarness(t)
	logger := slog.New(slog.NewTextHandler(h.logs, &slog.HandlerOptions{Level: slog.LevelDebug}))
	h.router = NewRouter(Deps{
		Handlers: h.handlers, Devices: fakeDevices{}, Pepper: pepper, Logger: logger,
		Metrics: h.metrics, AuthRatePerMin: limit,
	})
	return h
}

func (h *harness) login(forwarded, remote string) *httptest.ResponseRecorder {
	request := httptest.NewRequest(http.MethodPost, "/v1/auth/telegram/start", strings.NewReader(loginBody))
	if forwarded != "" {
		request.Header.Set("X-Forwarded-For", forwarded)
	}
	request.RemoteAddr = remote
	recorder := httptest.NewRecorder()
	h.router.ServeHTTP(recorder, request)
	return recorder
}

func TestAuthLimitAnswersWithAProblem(t *testing.T) {
	h := newLimitedHarness(t, 2)

	h.requireProblem(t, h.login("203.0.113.1", "10.0.0.1:1"), http.StatusNotImplemented, "internal")
	h.requireProblem(t, h.login("203.0.113.1", "10.0.0.1:1"), http.StatusNotImplemented, "internal")

	response := h.login("203.0.113.1", "10.0.0.1:1")
	h.requireProblem(t, response, http.StatusTooManyRequests, "rate_limited")
	require.Contains(t, response.Body.String(), `"retryAfterSec":`)
}

func TestAuthLimitCountsEachAddress(t *testing.T) {
	h := newLimitedHarness(t, 1)

	h.requireProblem(t, h.login("203.0.113.1", "10.0.0.1:1"), http.StatusNotImplemented, "internal")
	h.requireProblem(t, h.login("203.0.113.2", "10.0.0.1:1"), http.StatusNotImplemented, "internal")
	h.requireProblem(t, h.login("203.0.113.1", "10.0.0.1:1"), http.StatusTooManyRequests, "rate_limited")
}

// Caddy appends the real address, so everything before it is client input.
func TestAuthLimitIgnoresAddressesTheClientAdded(t *testing.T) {
	h := newLimitedHarness(t, 1)

	h.requireProblem(t, h.login("198.51.100.1, 203.0.113.1", "10.0.0.1:1"), http.StatusNotImplemented, "internal")
	h.requireProblem(t, h.login("198.51.100.2, 203.0.113.1", "10.0.0.1:1"), http.StatusTooManyRequests, "rate_limited")
}

func TestAuthLimitUsesTheRemoteAddressWithoutAProxy(t *testing.T) {
	h := newLimitedHarness(t, 1)

	h.requireProblem(t, h.login("", "203.0.113.1:1000"), http.StatusNotImplemented, "internal")
	h.requireProblem(t, h.login("", "203.0.113.1:2000"), http.StatusTooManyRequests, "rate_limited")
	h.requireProblem(t, h.login("", "203.0.113.2:1000"), http.StatusNotImplemented, "internal")
}

func TestAuthLimitLeavesSecuredOperationsAlone(t *testing.T) {
	h := newLimitedHarness(t, 1)

	for range 3 {
		h.requireProblem(t, h.do(http.MethodGet, "/v1/profile", "", ""), http.StatusUnauthorized, "unauthorized")
	}
}

func TestZeroLimitTurnsTheLimiterOff(t *testing.T) {
	h := newLimitedHarness(t, 0)

	for range 3 {
		h.requireProblem(t, h.login("203.0.113.1", "10.0.0.1:1"), http.StatusNotImplemented, "internal")
	}
}

func TestAuthLimitLogsNoAddresses(t *testing.T) {
	h := newLimitedHarness(t, 1)

	h.login("203.0.113.1", "10.0.0.1:1")
	h.login("203.0.113.1", "10.0.0.1:1")

	require.NotContains(t, h.logs.String(), "203.0.113.1")
}

func TestLimiterWindow(t *testing.T) {
	now := time.Date(2026, 11, 3, 10, 0, 0, 0, time.UTC)
	limiter := newRateLimiter(2, func() time.Time { return now })

	_, ok := limiter.allow("a")
	require.True(t, ok)
	_, ok = limiter.allow("a")
	require.True(t, ok)

	now = now.Add(45 * time.Second)
	retryAfter, ok := limiter.allow("a")
	require.False(t, ok)
	require.Equal(t, 15, retryAfter)

	now = now.Add(15 * time.Second)
	_, ok = limiter.allow("a")
	require.True(t, ok, "a new window starts empty")
}

func TestLimiterRetryAfterIsNeverZero(t *testing.T) {
	now := time.Date(2026, 11, 3, 10, 0, 0, 0, time.UTC)
	limiter := newRateLimiter(1, func() time.Time { return now })
	limiter.allow("a")

	now = now.Add(59*time.Second + 900*time.Millisecond)
	retryAfter, ok := limiter.allow("a")

	require.False(t, ok)
	require.Equal(t, 1, retryAfter)
}

// Addresses must not pile up in memory: the service keeps no client addresses.
func TestLimiterForgetsAddressesWithTheWindow(t *testing.T) {
	now := time.Date(2026, 11, 3, 10, 0, 0, 0, time.UTC)
	limiter := newRateLimiter(1, func() time.Time { return now })
	limiter.allow("a")
	limiter.allow("b")

	now = now.Add(time.Minute)
	limiter.allow("c")

	require.Len(t, limiter.counts, 1)
}

func TestLimiterCountsConcurrentRequests(t *testing.T) {
	limiter := newRateLimiter(10, time.Now)

	var group sync.WaitGroup
	allowed := make([]bool, 50)
	for i := range allowed {
		group.Go(func() { _, allowed[i] = limiter.allow("a") })
	}
	group.Wait()

	count := 0
	for _, ok := range allowed {
		if ok {
			count++
		}
	}
	require.Equal(t, 10, count)
}
