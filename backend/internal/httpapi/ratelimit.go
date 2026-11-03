package httpapi

import (
	"context"
	"math"
	"net"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/Evgenius09/vpn-project/backend/internal/gen/api"
)

const rateWindow = time.Minute

// rateLimiter counts requests per key in one shared fixed window. The counters
// live in memory and go away with the window, so the service keeps no client
// addresses (tech.md 9, 25.2).
type rateLimiter struct {
	limit int
	now   func() time.Time

	mu     sync.Mutex
	start  time.Time
	counts map[string]int
}

func newRateLimiter(limit int, now func() time.Time) *rateLimiter {
	return &rateLimiter{limit: limit, now: now, counts: map[string]int{}}
}

// allow counts one request. When it refuses, the first result tells how many
// seconds remain in the window.
func (l *rateLimiter) allow(key string) (int, bool) {
	l.mu.Lock()
	defer l.mu.Unlock()

	now := l.now()
	if now.Sub(l.start) >= rateWindow {
		l.start = now
		clear(l.counts)
	}
	if l.counts[key] >= l.limit {
		return int(math.Ceil(l.start.Add(rateWindow).Sub(now).Seconds())), false
	}
	l.counts[key]++
	return 0, true
}

func rateLimitMiddleware(limit int) api.StrictMiddlewareFunc {
	limiter := newRateLimiter(limit, time.Now)
	return func(next api.StrictHandlerFunc, operationID string) api.StrictHandlerFunc {
		if limit == 0 || !publicOperations[operationID] {
			return next
		}
		return func(ctx context.Context, w http.ResponseWriter, r *http.Request, request any) (any, error) {
			if retryAfter, ok := limiter.allow(clientAddress(r)); !ok {
				return nil, &Problem{
					Status:        http.StatusTooManyRequests,
					Code:          api.ProblemCodeRateLimited,
					Title:         "Too many requests",
					RetryAfterSec: &retryAfter,
				}
			}
			return next(ctx, w, r, request)
		}
	}
}

// clientAddress trusts only the last X-Forwarded-For entry: Caddy appends it,
// and anything before it came from the client.
func clientAddress(r *http.Request) string {
	if values := r.Header.Values("X-Forwarded-For"); len(values) > 0 {
		last := values[len(values)-1]
		return strings.TrimSpace(last[strings.LastIndexByte(last, ',')+1:])
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}
