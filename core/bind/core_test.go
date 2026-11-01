package bind

import (
	"encoding/json"
	"errors"
	"os"
	"sync"
	"testing"

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

func request(t *testing.T) string {
	t.Helper()
	raw, err := os.ReadFile("../../contracts/fixtures/tunnel_request/android_regular.json")
	require.NoError(t, err)
	return string(raw)
}

func TestEventsReachTheSinkAsJSON(t *testing.T) {
	events := &sink{}
	core := newCore(runtime.NewBoxEngine(), events)

	require.NoError(t, core.Start(request(t)))
	require.NoError(t, core.Stop())

	require.Len(t, events.events, 4)
	var last contract.CoreEvent
	require.NoError(t, json.Unmarshal([]byte(events.events[3]), &last))
	require.Equal(t, contract.TunnelStatusDisconnected, last.State.Status)
}

func TestStateIsJSON(t *testing.T) {
	core := newCore(runtime.NewBoxEngine(), &sink{})
	var event contract.CoreEvent
	require.NoError(t, json.Unmarshal([]byte(core.State()), &event))
	require.Equal(t, contract.CoreEventTypeState, event.Type)
}

func TestCoreErrorCodeSurvivesToTheHost(t *testing.T) {
	core := newCore(runtime.NewBoxEngine(), &sink{})
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

func TestLaterSliceMethodsFailClearly(t *testing.T) {
	core := newCore(runtime.NewBoxEngine(), &sink{})
	require.Error(t, core.Update("{}"))
	require.Error(t, core.SetUserMode("regular"))
	require.Error(t, core.SelectServer("regular", "x"))
	_, err := core.URLTest("[]")
	require.Error(t, err)
	core.OnNetworkChanged("wifi")
}
