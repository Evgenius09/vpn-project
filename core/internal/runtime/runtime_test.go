package runtime

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"sync"
	"testing"
	"time"

	"github.com/getkin/kin-openapi/openapi3"
	"github.com/sagernet/sing-box/option"
	"github.com/stretchr/testify/require"

	"github.com/Evgenius09/vpn-project/core/internal/contract"
)

const fixture = "../../../contracts/fixtures/tunnel_request/android_regular.json"

type fakeEngine struct {
	mu        sync.Mutex
	started   int
	closed    int
	startErr  error
	selectErr error
	options   []option.Options
	selects   [][2]string
	up, down  int64
	noTraffic bool
}

func (f *fakeEngine) Start(options option.Options) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.startErr != nil {
		return f.startErr
	}
	f.started++
	f.options = append(f.options, options)
	return nil
}

func (f *fakeEngine) Select(selector, member string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.selectErr != nil {
		return f.selectErr
	}
	f.selects = append(f.selects, [2]string{selector, member})
	return nil
}

func (f *fakeEngine) Traffic() (up, down int64, ok bool) {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.up, f.down, !f.noTraffic
}

func (f *fakeEngine) setTraffic(up, down int64) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.up, f.down = up, down
}

func (f *fakeEngine) Close() error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.closed++
	return nil
}

type recorder struct {
	mu     sync.Mutex
	events []string
}

func (r *recorder) record(event string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.events = append(r.events, event)
}

func (r *recorder) decoded(t *testing.T) []contract.CoreEvent {
	t.Helper()
	r.mu.Lock()
	defer r.mu.Unlock()
	out := make([]contract.CoreEvent, 0, len(r.events))
	for _, raw := range r.events {
		var event contract.CoreEvent
		require.NoError(t, json.Unmarshal([]byte(raw), &event))
		out = append(out, event)
	}
	return out
}

func statuses(events []contract.CoreEvent) []contract.TunnelStatus {
	var out []contract.TunnelStatus
	for _, event := range events {
		if event.State != nil {
			out = append(out, event.State.Status)
		}
	}
	return out
}

func request(t *testing.T) string {
	t.Helper()
	raw, err := os.ReadFile(fixture)
	require.NoError(t, err)
	return string(raw)
}

func newRuntime(engine Engine, events *recorder) *Runtime {
	return New(Options{
		Engine: engine,
		Sink:   events.record,
		Now:    func() time.Time { return time.Date(2026, 11, 1, 10, 0, 0, 0, time.UTC) },
		// No tick arrives unless a test sends one.
		NewTicker: func() (<-chan time.Time, func()) { return nil, func() {} },
	})
}

func TestStartEmitsConnectingThenConnected(t *testing.T) {
	engine, events := &fakeEngine{}, &recorder{}
	r := newRuntime(engine, events)

	require.NoError(t, r.Start(request(t)))

	decoded := events.decoded(t)
	require.Equal(t, []contract.TunnelStatus{
		contract.TunnelStatusConnecting, contract.TunnelStatusConnected,
	}, statuses(decoded))
	last := decoded[len(decoded)-1].State
	require.Equal(t, contract.TunnelModeRegular, last.UserMode)
	require.Equal(t, contract.TunnelModeRegular, last.EffectiveMode)
	require.NotNil(t, last.ConnectedSince)
}

func TestStopEmitsDisconnectingThenDisconnected(t *testing.T) {
	engine, events := &fakeEngine{}, &recorder{}
	r := newRuntime(engine, events)
	require.NoError(t, r.Start(request(t)))

	require.NoError(t, r.Stop())

	require.Equal(t, []contract.TunnelStatus{
		contract.TunnelStatusConnecting, contract.TunnelStatusConnected,
		contract.TunnelStatusDisconnecting, contract.TunnelStatusDisconnected,
	}, statuses(events.decoded(t)))
	require.Equal(t, 1, engine.closed)
}

func TestSecondStartDoesNotCreateASecondBox(t *testing.T) {
	engine, events := &fakeEngine{}, &recorder{}
	r := newRuntime(engine, events)
	require.NoError(t, r.Start(request(t)))
	require.NoError(t, r.Start(request(t)))
	require.Equal(t, 1, engine.started)
}

func TestStopWhileDisconnectedIsANoOp(t *testing.T) {
	engine, events := &fakeEngine{}, &recorder{}
	r := newRuntime(engine, events)
	require.NoError(t, r.Stop())
	require.Zero(t, engine.closed)
	require.Empty(t, events.decoded(t))
}

func TestStartFailureReportsStartFailed(t *testing.T) {
	engine, events := &fakeEngine{startErr: errors.New("tun busy")}, &recorder{}
	r := newRuntime(engine, events)

	err := r.Start(request(t))

	var coreErr *Error
	require.ErrorAs(t, err, &coreErr)
	require.Equal(t, contract.CoreErrorCodeStartFailed, coreErr.Code)

	decoded := events.decoded(t)
	require.Equal(t, []contract.TunnelStatus{
		contract.TunnelStatusConnecting, contract.TunnelStatusError,
	}, statuses(decoded))
	var reported *contract.ErrorPayload
	for _, event := range decoded {
		if event.Error != nil {
			reported = event.Error
		}
	}
	require.NotNil(t, reported)
	require.Equal(t, contract.CoreErrorCodeStartFailed, reported.Code)
}

func TestRestartWorksAfterAFailedStart(t *testing.T) {
	engine, events := &fakeEngine{startErr: errors.New("tun busy")}, &recorder{}
	r := newRuntime(engine, events)
	require.Error(t, r.Start(request(t)))

	engine.mu.Lock()
	engine.startErr = nil
	engine.mu.Unlock()

	require.NoError(t, r.Start(request(t)))
	require.Equal(t, 1, engine.started)
}

func TestInvalidRequestsAreConfigInvalid(t *testing.T) {
	valid := request(t)
	var document map[string]any
	require.NoError(t, json.Unmarshal([]byte(valid), &document))

	mutate := func(change func(map[string]any)) string {
		var copied map[string]any
		require.NoError(t, json.Unmarshal([]byte(valid), &copied))
		change(copied)
		encoded, err := json.Marshal(copied)
		require.NoError(t, err)
		return string(encoded)
	}

	tests := map[string]string{
		"not json":       "{",
		"empty":          "",
		"unknown field":  mutate(func(d map[string]any) { d["surprise"] = true }),
		"newer schema":   mutate(func(d map[string]any) { d["schemaVersion"] = 2 }),
		"bad user mode":  mutate(func(d map[string]any) { d["userMode"] = "fast" }),
		"bad platform":   mutate(func(d map[string]any) { d["platform"] = "ios" }),
		"missing fields": `{"schemaVersion":1}`,
	}
	for name, input := range tests {
		t.Run(name, func(t *testing.T) {
			engine, events := &fakeEngine{}, &recorder{}
			r := newRuntime(engine, events)

			err := r.Start(input)

			var coreErr *Error
			require.ErrorAs(t, err, &coreErr)
			require.Equal(t, contract.CoreErrorCodeConfigInvalid, coreErr.Code)
			require.Zero(t, engine.started, "an invalid request never reaches the engine")
		})
	}
}

func TestSecretsStayOutOfEvents(t *testing.T) {
	engine, events := &fakeEngine{startErr: errors.New("boom")}, &recorder{}
	r := newRuntime(engine, events)
	require.Error(t, r.Start(request(t)))

	for _, raw := range events.events {
		require.NotContains(t, raw, "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
		require.NotContains(t, raw, "fixture-hysteria2-password")
	}
}

func TestStateReportsTheCurrentStatus(t *testing.T) {
	engine, events := &fakeEngine{}, &recorder{}
	r := newRuntime(engine, events)

	var event contract.CoreEvent
	require.NoError(t, json.Unmarshal([]byte(r.State()), &event))
	require.Equal(t, contract.CoreEventTypeState, event.Type)
	require.Equal(t, contract.TunnelStatusDisconnected, event.State.Status)

	require.NoError(t, r.Start(request(t)))
	require.NoError(t, json.Unmarshal([]byte(r.State()), &event))
	require.Equal(t, contract.TunnelStatusConnected, event.State.Status)
}

func TestEveryEmittedEventMatchesTheSchema(t *testing.T) {
	loader := openapi3.NewLoader()
	spec, err := loader.LoadFromFile("../../../contracts/openapi.yaml")
	require.NoError(t, err)
	require.NoError(t, spec.Validate(context.Background()))
	schema := spec.Components.Schemas["CoreEvent"].Value

	failing, events := &fakeEngine{startErr: errors.New("boom")}, &recorder{}
	require.Error(t, newRuntime(failing, events).Start(request(t)))

	ticks := make(chan time.Time)
	engine := &fakeEngine{up: 10, down: 20}
	r := withTicks(engine, events, ticks)
	require.NoError(t, r.Start(request(t)))
	tick(t, ticks, events, 1)
	require.NoError(t, r.SelectServer(string(contract.TunnelModeRegular), regularServer))
	require.NoError(t, r.Stop())
	events.record(r.State())

	withWhitelist := newRuntime(&fakeEngine{}, events)
	require.NoError(t, withWhitelist.Start(bothGroups(t)))
	require.NoError(t, withWhitelist.SetUserMode(string(contract.TunnelModeWhitelist)))

	require.NotEmpty(t, events.events)
	for _, raw := range events.events {
		var document map[string]any
		require.NoError(t, json.Unmarshal([]byte(raw), &document))
		require.NoError(t, schema.VisitJSON(document, openapi3.EnableJSONSchema2020()), raw)
	}
}

const (
	regularServer   = "11111111-1111-4111-8111-111111111111"
	secondRegular   = "33333333-3333-4333-8333-333333333333"
	whitelistServer = "22222222-2222-4222-8222-222222222222"
)

func withTicks(engine Engine, events *recorder, ticks chan time.Time) *Runtime {
	return New(Options{
		Engine:    engine,
		Sink:      events.record,
		NewTicker: func() (<-chan time.Time, func()) { return ticks, func() {} },
	})
}

// tick waits for the event, because the runtime handles the tick on its own
// goroutine.
func tick(t *testing.T, ticks chan time.Time, events *recorder, wantTraffic int) {
	t.Helper()
	ticks <- time.Now()
	require.Eventually(t, func() bool {
		return len(trafficOf(events.decoded(t))) == wantTraffic
	}, time.Second, time.Millisecond)
}

func trafficOf(events []contract.CoreEvent) []contract.TrafficPayload {
	var out []contract.TrafficPayload
	for _, event := range events {
		if event.Traffic != nil {
			out = append(out, *event.Traffic)
		}
	}
	return out
}

// rewrite changes the fixture request and returns it as JSON.
func rewrite(t *testing.T, change func(*contract.TunnelRequest)) string {
	t.Helper()
	var req contract.TunnelRequest
	require.NoError(t, json.Unmarshal([]byte(request(t)), &req))
	change(&req)
	encoded, err := json.Marshal(req)
	require.NoError(t, err)
	return string(encoded)
}

// bothGroups has two regular servers and one whitelist server.
func bothGroups(t *testing.T) string {
	t.Helper()
	return rewrite(t, func(req *contract.TunnelRequest) {
		first := req.Servers[0]
		first.Id = regularServer
		first.Group = contract.TunnelModeRegular
		first.SortWeight = 1

		second := first
		second.Id = secondRegular
		second.SortWeight = 2

		whitelist := first
		whitelist.Id = whitelistServer
		whitelist.Group = contract.TunnelModeWhitelist

		req.Servers = []contract.ServerNode{first, second, whitelist}
		req.Selected = contract.SelectedServers{}
		req.UserMode = contract.TunnelModeRegular
	})
}

func lastState(t *testing.T, events *recorder) contract.StatePayload {
	t.Helper()
	decoded := events.decoded(t)
	for index := len(decoded) - 1; index >= 0; index-- {
		if decoded[index].State != nil {
			return *decoded[index].State
		}
	}
	require.FailNow(t, "no state event")
	return contract.StatePayload{}
}

func requireCode(t *testing.T, err error, code contract.CoreErrorCode) {
	t.Helper()
	var coreErr *Error
	require.ErrorAs(t, err, &coreErr)
	require.Equal(t, code, coreErr.Code)
}

func outboundTags(options option.Options) []string {
	tags := make([]string, len(options.Outbounds))
	for index, outbound := range options.Outbounds {
		tags[index] = outbound.Tag
	}
	return tags
}

func TestStartBuildsTheOptionsOfTheRequest(t *testing.T) {
	engine := &fakeEngine{}
	require.NoError(t, newRuntime(engine, &recorder{}).Start(bothGroups(t)))

	require.Len(t, engine.options, 1)
	tags := outboundTags(engine.options[0])
	require.Contains(t, tags, "srv-"+regularServer)
	require.Contains(t, tags, "srv-"+whitelistServer)
	require.Contains(t, tags, "proxy")
}

func TestStartReportsTheActiveServer(t *testing.T) {
	events := &recorder{}
	require.NoError(t, newRuntime(&fakeEngine{}, events).Start(bothGroups(t)))
	state := lastState(t, events)
	require.Equal(t, regularServer, *state.ActiveServerId, "the lowest weight without a selection")
}

func TestStartHonoursTheSelection(t *testing.T) {
	selected := secondRegular
	req := rewrite(t, func(req *contract.TunnelRequest) {
		var both contract.TunnelRequest
		require.NoError(t, json.Unmarshal([]byte(bothGroups(t)), &both))
		*req = both
		req.Selected.Regular = &selected
	})
	events := &recorder{}
	require.NoError(t, newRuntime(&fakeEngine{}, events).Start(req))
	require.Equal(t, secondRegular, *lastState(t, events).ActiveServerId)
}

// regularOnly has no whitelist server.
func regularOnly(t *testing.T) string {
	t.Helper()
	return rewrite(t, func(req *contract.TunnelRequest) {
		var kept []contract.ServerNode
		for _, server := range req.Servers {
			if server.Group == contract.TunnelModeRegular {
				kept = append(kept, server)
			}
		}
		req.Servers = kept
		req.Selected = contract.SelectedServers{}
		req.UserMode = contract.TunnelModeRegular
	})
}

func TestEmptyGroupKeepsItsCode(t *testing.T) {
	req := rewrite(t, func(req *contract.TunnelRequest) {
		var regular contract.TunnelRequest
		require.NoError(t, json.Unmarshal([]byte(regularOnly(t)), &regular))
		*req = regular
		req.UserMode = contract.TunnelModeWhitelist
	})
	engine := &fakeEngine{}

	requireCode(t, newRuntime(engine, &recorder{}).Start(req), contract.CoreErrorCodeNoServersInGroup)
	require.Zero(t, engine.started)
}

func TestUpdateRebuildsAndRestarts(t *testing.T) {
	engine, events := &fakeEngine{}, &recorder{}
	r := newRuntime(engine, events)
	require.NoError(t, r.Start(request(t)))

	require.NoError(t, r.Update(bothGroups(t)))

	require.Equal(t, 2, engine.started)
	require.Equal(t, 1, engine.closed)
	require.Contains(t, outboundTags(engine.options[1]), "srv-"+whitelistServer)
	require.Equal(t, []contract.TunnelStatus{
		contract.TunnelStatusConnecting, contract.TunnelStatusConnected,
		contract.TunnelStatusConnecting, contract.TunnelStatusConnected,
	}, statuses(events.decoded(t)))
}

func TestUpdateWhileDisconnectedStartsNothing(t *testing.T) {
	engine, events := &fakeEngine{}, &recorder{}
	require.NoError(t, newRuntime(engine, events).Update(request(t)))
	require.Zero(t, engine.started)
	require.Empty(t, events.decoded(t))
}

func TestInvalidUpdateKeepsTheTunnelRunning(t *testing.T) {
	engine, events := &fakeEngine{}, &recorder{}
	r := newRuntime(engine, events)
	require.NoError(t, r.Start(request(t)))

	requireCode(t, r.Update("{"), contract.CoreErrorCodeConfigInvalid)

	require.Equal(t, 1, engine.started)
	require.Zero(t, engine.closed)
	require.Equal(t, contract.TunnelStatusConnected, lastState(t, events).Status)
}

func TestFailedUpdateReportsStartFailed(t *testing.T) {
	engine, events := &fakeEngine{}, &recorder{}
	r := newRuntime(engine, events)
	require.NoError(t, r.Start(request(t)))
	engine.mu.Lock()
	engine.startErr = errors.New("tun busy")
	engine.mu.Unlock()

	requireCode(t, r.Update(request(t)), contract.CoreErrorCodeStartFailed)

	state := lastState(t, events)
	require.Equal(t, contract.TunnelStatusError, state.Status)
	require.Nil(t, state.ConnectedSince)
}

func TestSelectServerSwitchesWithoutARestart(t *testing.T) {
	engine, events := &fakeEngine{}, &recorder{}
	r := newRuntime(engine, events)
	require.NoError(t, r.Start(bothGroups(t)))

	require.NoError(t, r.SelectServer("regular", secondRegular))

	require.Equal(t, [][2]string{{"grp-regular", "srv-" + secondRegular}}, engine.selects)
	require.Equal(t, 1, engine.started)
	require.Zero(t, engine.closed)
	require.Equal(t, secondRegular, *lastState(t, events).ActiveServerId)
}

func TestSelectServerInTheOtherGroupKeepsTheActiveServer(t *testing.T) {
	engine, events := &fakeEngine{}, &recorder{}
	r := newRuntime(engine, events)
	require.NoError(t, r.Start(bothGroups(t)))

	require.NoError(t, r.SelectServer("whitelist", whitelistServer))

	require.Equal(t, [][2]string{{"grp-whitelist", "srv-" + whitelistServer}}, engine.selects)
	require.Equal(t, regularServer, *lastState(t, events).ActiveServerId)
}

func TestSelectServerRejectsWhatTheRequestDoesNotHold(t *testing.T) {
	engine := &fakeEngine{}
	r := newRuntime(engine, &recorder{})
	require.NoError(t, r.Start(bothGroups(t)))

	requireCode(t, r.SelectServer("regular", "unknown"), contract.CoreErrorCodeConfigInvalid)
	requireCode(t, r.SelectServer("regular", whitelistServer), contract.CoreErrorCodeConfigInvalid)
	requireCode(t, r.SelectServer("fast", regularServer), contract.CoreErrorCodeConfigInvalid)
	require.Empty(t, engine.selects)
}

func TestSelectServerWhileDisconnectedDoesNothing(t *testing.T) {
	engine := &fakeEngine{}
	require.NoError(t, newRuntime(engine, &recorder{}).SelectServer("regular", regularServer))
	require.Empty(t, engine.selects)
}

func TestEngineFailureOnSelectIsInternal(t *testing.T) {
	engine, events := &fakeEngine{}, &recorder{}
	r := newRuntime(engine, events)
	require.NoError(t, r.Start(bothGroups(t)))
	engine.mu.Lock()
	engine.selectErr = errors.New("no selector")
	engine.mu.Unlock()

	requireCode(t, r.SelectServer("regular", secondRegular), contract.CoreErrorCodeInternal)
	require.Equal(t, regularServer, *lastState(t, events).ActiveServerId)
}

func TestSetUserModeSwitchesWithoutARestart(t *testing.T) {
	engine, events := &fakeEngine{}, &recorder{}
	r := newRuntime(engine, events)
	require.NoError(t, r.Start(bothGroups(t)))

	require.NoError(t, r.SetUserMode("whitelist"))

	require.Equal(t, [][2]string{{"proxy", "grp-whitelist"}}, engine.selects)
	require.Equal(t, 1, engine.started)
	require.Zero(t, engine.closed)

	state := lastState(t, events)
	require.Equal(t, contract.TunnelModeWhitelist, state.UserMode)
	require.Equal(t, contract.TunnelModeWhitelist, state.EffectiveMode)
	require.Equal(t, whitelistServer, *state.ActiveServerId)

	var mode *contract.ModePayload
	for _, event := range events.decoded(t) {
		if event.Mode != nil {
			mode = event.Mode
		}
	}
	require.NotNil(t, mode)
	require.Equal(t, contract.TunnelModeRegular, mode.From)
	require.Equal(t, contract.TunnelModeWhitelist, mode.To)
	require.Equal(t, contract.ModeSwitchReasonUser, mode.Reason)
}

func TestSetUserModeToTheCurrentModeDoesNothing(t *testing.T) {
	engine, events := &fakeEngine{}, &recorder{}
	r := newRuntime(engine, events)
	require.NoError(t, r.Start(bothGroups(t)))
	before := len(events.decoded(t))

	require.NoError(t, r.SetUserMode("regular"))

	require.Empty(t, engine.selects)
	require.Len(t, events.decoded(t), before)
}

func TestSetUserModeToAnEmptyGroupFails(t *testing.T) {
	engine, events := &fakeEngine{}, &recorder{}
	r := newRuntime(engine, events)
	require.NoError(t, r.Start(regularOnly(t)))

	requireCode(t, r.SetUserMode("whitelist"), contract.CoreErrorCodeNoServersInGroup)

	require.Empty(t, engine.selects)
	require.Equal(t, contract.TunnelModeRegular, lastState(t, events).UserMode)
}

func TestSetUserModeRejectsAnUnknownMode(t *testing.T) {
	r := newRuntime(&fakeEngine{}, &recorder{})
	require.NoError(t, r.Start(bothGroups(t)))
	requireCode(t, r.SetUserMode("fast"), contract.CoreErrorCodeConfigInvalid)
}

func TestSetUserModeWhileDisconnectedDoesNothing(t *testing.T) {
	engine, events := &fakeEngine{}, &recorder{}
	require.NoError(t, newRuntime(engine, events).SetUserMode("whitelist"))
	require.Empty(t, engine.selects)
	require.Empty(t, events.decoded(t))
}

func TestSelectionSurvivesAModeRoundTrip(t *testing.T) {
	engine, events := &fakeEngine{}, &recorder{}
	r := newRuntime(engine, events)
	require.NoError(t, r.Start(bothGroups(t)))
	require.NoError(t, r.SelectServer("regular", secondRegular))

	require.NoError(t, r.SetUserMode("whitelist"))
	require.NoError(t, r.SetUserMode("regular"))

	require.Equal(t, secondRegular, *lastState(t, events).ActiveServerId,
		"the server stays selected for each group, tech.md 2.1")
}

func TestTrafficReportsTotalsAndRates(t *testing.T) {
	ticks := make(chan time.Time)
	engine, events := &fakeEngine{}, &recorder{}
	r := withTicks(engine, events, ticks)
	require.NoError(t, r.Start(request(t)))

	engine.setTraffic(100, 400)
	tick(t, ticks, events, 1)
	engine.setTraffic(150, 1000)
	tick(t, ticks, events, 2)

	require.Equal(t, []contract.TrafficPayload{
		{UpBps: 100, DownBps: 400, UpTotal: 100, DownTotal: 400},
		{UpBps: 50, DownBps: 600, UpTotal: 150, DownTotal: 1000},
	}, trafficOf(events.decoded(t)))
	require.NoError(t, r.Stop())
}

func TestTrafficStopsWithTheTunnel(t *testing.T) {
	stopped := make(chan struct{})
	ticks := make(chan time.Time)
	events := &recorder{}
	r := New(Options{
		Engine: &fakeEngine{},
		Sink:   events.record,
		NewTicker: func() (<-chan time.Time, func()) {
			return ticks, func() { close(stopped) }
		},
	})
	require.NoError(t, r.Start(request(t)))

	require.NoError(t, r.Stop())

	select {
	case <-stopped:
	case <-time.After(time.Second):
		t.Fatal("the ticker is still running")
	}
	require.Empty(t, trafficOf(events.decoded(t)))
}

func TestTrafficDoesNotRunAfterAFailedStart(t *testing.T) {
	started := false
	r := New(Options{
		Engine: &fakeEngine{startErr: errors.New("boom")},
		Sink:   func(string) {},
		NewTicker: func() (<-chan time.Time, func()) {
			started = true
			return nil, func() {}
		},
	})
	require.Error(t, r.Start(request(t)))
	require.False(t, started)
}

func TestRestartedBoxStartsItsCountersFromZero(t *testing.T) {
	ticks := make(chan time.Time)
	engine, events := &fakeEngine{}, &recorder{}
	r := withTicks(engine, events, ticks)
	require.NoError(t, r.Start(request(t)))
	engine.setTraffic(1000, 1000)
	tick(t, ticks, events, 1)

	require.NoError(t, r.Update(request(t)))
	engine.setTraffic(10, 20)
	tick(t, ticks, events, 2)

	last := trafficOf(events.decoded(t))[1]
	require.Equal(t, contract.TrafficPayload{UpBps: 10, DownBps: 20, UpTotal: 10, DownTotal: 20}, last,
		"a rate must never go negative")
	require.NoError(t, r.Stop())
}

func TestTrafficSkipsWhileCountersAreUnavailable(t *testing.T) {
	ticks := make(chan time.Time)
	engine, events := &fakeEngine{noTraffic: true}, &recorder{}
	r := withTicks(engine, events, ticks)
	require.NoError(t, r.Start(request(t)))

	ticks <- time.Now()
	engine.mu.Lock()
	engine.noTraffic = false
	engine.mu.Unlock()
	tick(t, ticks, events, 1)
	require.NoError(t, r.Stop())
}
