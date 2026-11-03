package runtime

import (
	"context"
	"errors"
	"sync"
	"time"

	"github.com/Evgenius09/vpn-project/core/internal/config"
	"github.com/Evgenius09/vpn-project/core/internal/contract"
)

// The request carries no ping.url or ping.timeoutMs yet, so the core uses the
// seed policy values (tech.md 31.1).
const (
	urlTestLink     = "https://www.gstatic.com/generate_204"
	urlTestTimeout  = 5 * time.Second
	urlTestParallel = 8
)

// Fixed words stand in for the sing-box error text, which can quote options.
const (
	urlTestTimedOut      = "timeout"
	urlTestFailed        = "failed"
	urlTestUnknownServer = "unknown_server"
	urlTestNotConnected  = "not_connected"
)

// URLTest measures each server through its own outbound and returns a CoreEvent
// of type url_test as JSON. It holds the runtime only to read the request, so
// a slow test never blocks a stop or a switch.
func (r *Runtime) URLTest(serverIDs []string) (string, error) {
	r.mu.Lock()
	connected := r.status == contract.TunnelStatusConnected
	known := map[string]bool{}
	if connected {
		for _, server := range r.request.Servers {
			known[server.Id] = true
		}
	}
	r.mu.Unlock()

	ids := unique(serverIDs)
	results := make([]contract.UrlTestResult, len(ids))
	slots := make(chan struct{}, urlTestParallel)
	var wait sync.WaitGroup
	for index, id := range ids {
		results[index].ServerId = id
		switch {
		case !connected:
			results[index].Error = textOf(urlTestNotConnected)
		case !known[id]:
			results[index].Error = textOf(urlTestUnknownServer)
		default:
			wait.Add(1)
			slots <- struct{}{}
			go func(result *contract.UrlTestResult) {
				defer func() { <-slots; wait.Done() }()
				r.probe(result)
			}(&results[index])
		}
	}
	wait.Wait()

	return encode(contract.CoreEvent{
		Type:    contract.CoreEventTypeUrlTest,
		At:      r.now().UTC(),
		UrlTest: &contract.UrlTestPayload{Results: results},
	}), nil
}

func (r *Runtime) probe(result *contract.UrlTestResult) {
	ctx, cancel := context.WithTimeout(context.Background(), r.urlTestTimeout)
	defer cancel()
	delay, err := r.engine.URLTest(ctx, config.ServerTag(result.ServerId), urlTestLink)
	switch {
	case err == nil:
		ms := int(delay)
		result.DelayMs = &ms
	case errors.Is(err, context.DeadlineExceeded) || ctx.Err() != nil:
		result.Error = textOf(urlTestTimedOut)
	default:
		result.Error = textOf(urlTestFailed)
	}
}

func unique(ids []string) []string {
	seen := make(map[string]bool, len(ids))
	out := make([]string, 0, len(ids))
	for _, id := range ids {
		if !seen[id] {
			seen[id] = true
			out = append(out, id)
		}
	}
	return out
}

func textOf(text string) *string { return &text }
