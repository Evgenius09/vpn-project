package runtime

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"sync"
	"testing"
	"time"

	"github.com/getkin/kin-openapi/openapi3"
	"github.com/stretchr/testify/require"

	"github.com/Evgenius09/vpn-project/core/internal/contract"
)

type probe struct {
	outbound string
	link     string
}

// probeEngine answers URL tests through answer and records each call.
type probeEngine struct {
	fakeEngine
	mu     sync.Mutex
	probes []probe
	answer func(ctx context.Context, outbound string) (uint16, error)
}

func (e *probeEngine) URLTest(ctx context.Context, outbound, link string) (uint16, error) {
	e.mu.Lock()
	e.probes = append(e.probes, probe{outbound: outbound, link: link})
	e.mu.Unlock()
	return e.answer(ctx, outbound)
}

func (e *probeEngine) calls() []probe {
	e.mu.Lock()
	defer e.mu.Unlock()
	return append([]probe(nil), e.probes...)
}

func decodeURLTest(t *testing.T, raw string) []contract.UrlTestResult {
	t.Helper()
	var event contract.CoreEvent
	require.NoError(t, json.Unmarshal([]byte(raw), &event))
	require.Equal(t, contract.CoreEventTypeUrlTest, event.Type)
	require.NotNil(t, event.UrlTest)
	return event.UrlTest.Results
}

func delay(ms int) *int { return &ms }

func word(text string) *string { return &text }

func TestURLTestOutsideConnectedTouchesNoNetwork(t *testing.T) {
	engine := &probeEngine{answer: func(context.Context, string) (uint16, error) { return 1, nil }}
	r := newRuntime(engine, &recorder{})

	raw, err := r.URLTest([]string{regularServer})
	require.NoError(t, err)

	require.Equal(t, []contract.UrlTestResult{
		{ServerId: regularServer, Error: word("not_connected")},
	}, decodeURLTest(t, raw))
	require.Empty(t, engine.calls())
}

func TestURLTestMeasuresEachServerThroughItsOutbound(t *testing.T) {
	delays := map[string]uint16{"srv-" + regularServer: 42, "srv-" + whitelistServer: 7}
	engine := &probeEngine{answer: func(_ context.Context, outbound string) (uint16, error) {
		return delays[outbound], nil
	}}
	r := newRuntime(engine, &recorder{})
	require.NoError(t, r.Start(bothGroups(t)))

	raw, err := r.URLTest([]string{whitelistServer, regularServer})
	require.NoError(t, err)

	require.Equal(t, []contract.UrlTestResult{
		{ServerId: whitelistServer, DelayMs: delay(7)},
		{ServerId: regularServer, DelayMs: delay(42)},
	}, decodeURLTest(t, raw))
	require.ElementsMatch(t, []probe{
		{outbound: "srv-" + regularServer, link: "https://www.gstatic.com/generate_204"},
		{outbound: "srv-" + whitelistServer, link: "https://www.gstatic.com/generate_204"},
	}, engine.calls())
}

func TestURLTestDropsRepeatsAndMarksUnknownServers(t *testing.T) {
	engine := &probeEngine{answer: func(context.Context, string) (uint16, error) { return 5, nil }}
	r := newRuntime(engine, &recorder{})
	require.NoError(t, r.Start(bothGroups(t)))

	raw, err := r.URLTest([]string{regularServer, "missing", regularServer})
	require.NoError(t, err)

	require.Equal(t, []contract.UrlTestResult{
		{ServerId: regularServer, DelayMs: delay(5)},
		{ServerId: "missing", Error: word("unknown_server")},
	}, decodeURLTest(t, raw))
	require.Len(t, engine.calls(), 1)
}

func TestURLTestReportsTimeoutAndFailureWithoutTheirText(t *testing.T) {
	engine := &probeEngine{answer: func(ctx context.Context, outbound string) (uint16, error) {
		if outbound == "srv-"+regularServer {
			<-ctx.Done()
			return 0, fmt.Errorf("dial: %w", ctx.Err())
		}
		return 0, errors.New("dial 203.0.113.9: fixture-hysteria2-password refused")
	}}
	r := New(Options{
		Engine:         engine,
		Sink:           func(string) {},
		NewTicker:      func() (<-chan time.Time, func()) { return nil, func() {} },
		URLTestTimeout: 50 * time.Millisecond,
	})
	require.NoError(t, r.Start(bothGroups(t)))

	raw, err := r.URLTest([]string{regularServer, whitelistServer})
	require.NoError(t, err)

	require.Equal(t, []contract.UrlTestResult{
		{ServerId: regularServer, Error: word("timeout")},
		{ServerId: whitelistServer, Error: word("failed")},
	}, decodeURLTest(t, raw))
	require.NotContains(t, raw, "fixture-hysteria2-password")
	require.NotContains(t, raw, "203.0.113.9")
}

// manyServers has count regular servers.
func manyServers(t *testing.T, count int) (string, []string) {
	t.Helper()
	ids := make([]string, count)
	encoded := rewrite(t, func(req *contract.TunnelRequest) {
		template := req.Servers[0]
		req.Servers = nil
		for index := range count {
			server := template
			server.Id = fmt.Sprintf("00000000-0000-4000-8000-%012d", index)
			server.SortWeight = index
			ids[index] = server.Id
			req.Servers = append(req.Servers, server)
		}
		req.Selected = contract.SelectedServers{}
	})
	return encoded, ids
}

func TestURLTestRunsAtMostEightAtOnce(t *testing.T) {
	request, ids := manyServers(t, 20)
	gate := make(chan struct{})
	var mu sync.Mutex
	inFlight, peak := 0, 0
	engine := &probeEngine{answer: func(context.Context, string) (uint16, error) {
		mu.Lock()
		inFlight++
		peak = max(peak, inFlight)
		mu.Unlock()
		<-gate
		mu.Lock()
		inFlight--
		mu.Unlock()
		return 3, nil
	}}
	r := newRuntime(engine, &recorder{})
	require.NoError(t, r.Start(request))

	done := make(chan string)
	go func() {
		raw, err := r.URLTest(ids)
		if err != nil {
			raw = err.Error()
		}
		done <- raw
	}()

	current := func() int {
		mu.Lock()
		defer mu.Unlock()
		return inFlight
	}
	require.Eventually(t, func() bool { return current() == urlTestParallel }, time.Second, time.Millisecond)
	// Give a ninth probe the chance to start before the gate opens.
	time.Sleep(50 * time.Millisecond)
	require.Equal(t, urlTestParallel, current())
	require.Contains(t, r.State(), `"connected"`, "a running test must not hold the runtime")

	close(gate)
	results := decodeURLTest(t, <-done)
	require.Len(t, results, len(ids))
	for index, result := range results {
		require.Equal(t, ids[index], result.ServerId)
		require.Equal(t, delay(3), result.DelayMs)
	}
	require.Equal(t, 8, peak)
}

func TestURLTestEventsMatchTheSchemaAndStayOffTheStream(t *testing.T) {
	loader := openapi3.NewLoader()
	spec, err := loader.LoadFromFile("../../../contracts/openapi.yaml")
	require.NoError(t, err)
	schema := spec.Components.Schemas["CoreEvent"].Value

	events := &recorder{}
	engine := &probeEngine{answer: func(_ context.Context, outbound string) (uint16, error) {
		if outbound == "srv-"+whitelistServer {
			return 0, errors.New("refused")
		}
		return 0, nil
	}}
	r := newRuntime(engine, events)

	idle, err := r.URLTest([]string{regularServer})
	require.NoError(t, err)
	require.NoError(t, r.Start(bothGroups(t)))
	running, err := r.URLTest([]string{regularServer, whitelistServer, "missing"})
	require.NoError(t, err)
	empty, err := r.URLTest(nil)
	require.NoError(t, err)

	for _, raw := range []string{idle, running, empty} {
		var document map[string]any
		require.NoError(t, json.Unmarshal([]byte(raw), &document))
		require.NoError(t, schema.VisitJSON(document, openapi3.EnableJSONSchema2020()), raw)
	}
	for _, event := range events.decoded(t) {
		require.NotEqual(t, contract.CoreEventTypeUrlTest, event.Type)
	}
}
