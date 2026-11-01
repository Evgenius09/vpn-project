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
	mu       sync.Mutex
	started  int
	closed   int
	startErr error
}

func (f *fakeEngine) Start(option.Options) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.startErr != nil {
		return f.startErr
	}
	f.started++
	return nil
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

	r := newRuntime(&fakeEngine{}, events)
	require.NoError(t, r.Start(request(t)))
	require.NoError(t, r.Stop())
	events.record(r.State())

	require.NotEmpty(t, events.events)
	for _, raw := range events.events {
		var document map[string]any
		require.NoError(t, json.Unmarshal([]byte(raw), &document))
		require.NoError(t, schema.VisitJSON(document, openapi3.EnableJSONSchema2020()), raw)
	}
}

func TestRealBoxStartsOnTheDirectConfig(t *testing.T) {
	engine := NewBoxEngine()
	events := &recorder{}
	r := newRuntime(engine, events)

	require.NoError(t, r.Start(request(t)))
	require.NoError(t, r.Stop())

	require.Equal(t, []contract.TunnelStatus{
		contract.TunnelStatusConnecting, contract.TunnelStatusConnected,
		contract.TunnelStatusDisconnecting, contract.TunnelStatusDisconnected,
	}, statuses(events.decoded(t)))
}
