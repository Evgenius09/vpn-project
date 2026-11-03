package bind

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"sync"
	"testing"

	"github.com/sagernet/sing-box/option"
	"github.com/stretchr/testify/require"

	"github.com/Evgenius09/vpn-project/core/internal/contract"
	"github.com/Evgenius09/vpn-project/core/internal/runtime"
)

type sink struct {
	mu     sync.Mutex
	events []string
}

func (s *sink) OnEvent(event string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.events = append(s.events, event)
}

// stubEngine stands in for libbox, which needs a host and a TUN.
type stubEngine struct {
	started int
	closed  int
	selects [][2]string
	probes  []string
}

func (e *stubEngine) Start(option.Options) error {
	e.started++
	return nil
}

func (e *stubEngine) Close() error {
	e.closed++
	return nil
}

func (e *stubEngine) Select(selector, member string) error {
	e.selects = append(e.selects, [2]string{selector, member})
	return nil
}

func (e *stubEngine) Traffic() (up, down int64, ok bool) { return 0, 0, true }

func (e *stubEngine) URLTest(_ context.Context, outbound, _ string) (uint16, error) {
	e.probes = append(e.probes, outbound)
	return 42, nil
}

func request(t *testing.T) string {
	t.Helper()
	raw, err := os.ReadFile("../../contracts/fixtures/tunnel_request/android_regular.json")
	require.NoError(t, err)
	return string(raw)
}

func TestEventsReachTheSinkAsJSON(t *testing.T) {
	events := &sink{}
	core := newCore(&stubEngine{}, events)

	require.NoError(t, core.Start(request(t)))
	require.NoError(t, core.Stop())

	require.Len(t, events.events, 4)
	var last contract.CoreEvent
	require.NoError(t, json.Unmarshal([]byte(events.events[3]), &last))
	require.Equal(t, contract.TunnelStatusDisconnected, last.State.Status)
}

func TestStateIsJSON(t *testing.T) {
	core := newCore(&stubEngine{}, &sink{})
	var event contract.CoreEvent
	require.NoError(t, json.Unmarshal([]byte(core.State()), &event))
	require.Equal(t, contract.CoreEventTypeState, event.Type)
}

func TestCoreErrorCodeSurvivesToTheHost(t *testing.T) {
	core := newCore(&stubEngine{}, &sink{})
	var coreErr *runtime.Error
	require.ErrorAs(t, core.Start("{"), &coreErr)
	require.Equal(t, contract.CoreErrorCodeConfigInvalid, coreErr.Code)
}

func TestSetupFailureSurfacesOnStart(t *testing.T) {
	failed := errors.New("setup failed")
	core := &Core{initErr: failed}
	require.ErrorIs(t, core.Start(request(t)), failed)
	require.ErrorIs(t, core.Stop(), failed)
	require.Empty(t, core.State())
}

func TestEveryMethodReportsASetupFailure(t *testing.T) {
	failed := errors.New("setup failed")
	core := &Core{initErr: failed}
	require.ErrorIs(t, core.Update(request(t)), failed)
	require.ErrorIs(t, core.SetUserMode("regular"), failed)
	require.ErrorIs(t, core.SelectServer("regular", "x"), failed)
}

func TestUpdateReachesTheEngine(t *testing.T) {
	engine := &stubEngine{}
	core := newCore(engine, &sink{})
	require.NoError(t, core.Start(request(t)))

	require.NoError(t, core.Update(request(t)))

	require.Equal(t, 2, engine.started)
	require.Equal(t, 1, engine.closed)
}

func TestSwitchesReachTheEngineWithoutARestart(t *testing.T) {
	engine := &stubEngine{}
	core := newCore(engine, &sink{})
	raw, err := os.ReadFile("../../contracts/fixtures/tunnel_request/windows_custom.json")
	require.NoError(t, err)
	require.NoError(t, core.Start(string(raw)))

	require.NoError(t, core.SetUserMode("whitelist"))
	require.NoError(t, core.SelectServer("regular", "11111111-1111-4111-8111-111111111111"))

	require.Equal(t, [][2]string{
		{"proxy", "grp-whitelist"},
		{"grp-regular", "srv-11111111-1111-4111-8111-111111111111"},
	}, engine.selects)
	require.Equal(t, 1, engine.started)
}

func TestSwitchErrorsKeepTheirCode(t *testing.T) {
	core := newCore(&stubEngine{}, &sink{})
	require.NoError(t, core.Start(request(t)))

	var coreErr *runtime.Error
	require.ErrorAs(t, core.SetUserMode("fast"), &coreErr)
	require.Equal(t, contract.CoreErrorCodeConfigInvalid, coreErr.Code)
}

func TestURLTestTakesAJSONArrayAndAnswersAJSONEvent(t *testing.T) {
	engine := &stubEngine{}
	core := newCore(engine, &sink{})
	require.NoError(t, core.Start(request(t)))

	raw, err := core.URLTest(`["11111111-1111-4111-8111-111111111111"]`)
	require.NoError(t, err)

	var event contract.CoreEvent
	require.NoError(t, json.Unmarshal([]byte(raw), &event))
	require.Equal(t, contract.CoreEventTypeUrlTest, event.Type)
	require.Len(t, event.UrlTest.Results, 1)
	require.Equal(t, 42, *event.UrlTest.Results[0].DelayMs)
	require.Equal(t, []string{"srv-11111111-1111-4111-8111-111111111111"}, engine.probes)
}

func TestURLTestRejectsWhatIsNotAnArrayOfIDs(t *testing.T) {
	core := newCore(&stubEngine{}, &sink{})
	for _, input := range []string{"", "{}", `[1]`, `"id"`, `["a"] trailing`} {
		_, err := core.URLTest(input)
		var coreErr *runtime.Error
		require.ErrorAs(t, err, &coreErr, input)
		require.Equal(t, contract.CoreErrorCodeConfigInvalid, coreErr.Code, input)
	}
}

func TestURLTestReportsASetupFailure(t *testing.T) {
	failed := errors.New("setup failed")
	core := &Core{initErr: failed}
	_, err := core.URLTest(`[]`)
	require.ErrorIs(t, err, failed)
}

func TestOnNetworkChangedWaitsForS2(_ *testing.T) {
	core := newCore(&stubEngine{}, &sink{})
	core.OnNetworkChanged("wifi")
}
