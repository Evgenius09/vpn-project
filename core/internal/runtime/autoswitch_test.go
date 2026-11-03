package runtime

import (
	"encoding/json"
	"errors"
	"testing"

	"github.com/getkin/kin-openapi/openapi3"
	"github.com/sagernet/sing-box/option"
	"github.com/stretchr/testify/require"

	"github.com/Evgenius09/vpn-project/core/internal/contract"
)

func modesOf(t *testing.T, events *recorder) []contract.ModePayload {
	t.Helper()
	var out []contract.ModePayload
	for _, event := range events.decoded(t) {
		if event.Mode != nil {
			out = append(out, *event.Mode)
		}
	}
	return out
}

func requireSchema(t *testing.T, events *recorder) {
	t.Helper()
	spec, err := openapi3.NewLoader().LoadFromFile("../../../contracts/openapi.yaml")
	require.NoError(t, err)
	schema := spec.Components.Schemas["CoreEvent"].Value
	events.mu.Lock()
	defer events.mu.Unlock()
	for _, raw := range events.events {
		var document map[string]any
		require.NoError(t, json.Unmarshal([]byte(raw), &document))
		require.NoError(t, schema.VisitJSON(document, openapi3.EnableJSONSchema2020()), raw)
	}
}

func proxyDefault(t *testing.T, options option.Options) string {
	t.Helper()
	for _, outbound := range options.Outbounds {
		if outbound.Tag == "proxy" {
			selector, ok := outbound.Options.(*option.SelectorOutboundOptions)
			require.True(t, ok)
			return selector.Default
		}
	}
	require.FailNow(t, "no proxy selector")
	return ""
}

// withAutoSwitch returns the request with the switch set.
func withAutoSwitch(t *testing.T, requestJSON string, enabled bool) string {
	t.Helper()
	var req contract.TunnelRequest
	require.NoError(t, json.Unmarshal([]byte(requestJSON), &req))
	req.AutoSwitch.Enabled = enabled
	encoded, err := json.Marshal(req)
	require.NoError(t, err)
	return string(encoded)
}

// onCellular starts both groups with the switch on and reports wifi, then
// cellular, as a host would after the start.
func onCellular(t *testing.T) (*Runtime, *fakeEngine, *recorder) {
	t.Helper()
	engine, events := &fakeEngine{}, &recorder{}
	r := newRuntime(engine, events)
	require.NoError(t, r.Start(withAutoSwitch(t, bothGroups(t), true)))
	require.NoError(t, r.OnNetworkChanged("wifi"))
	require.NoError(t, r.OnNetworkChanged("cellular"))
	return r, engine, events
}

func TestStartRunsTheUserModeUntilTheHostReportsTheNetwork(t *testing.T) {
	engine, events := &fakeEngine{}, &recorder{}
	require.NoError(t, newRuntime(engine, events).Start(withAutoSwitch(t, bothGroups(t), true)))

	require.Equal(t, "grp-regular", proxyDefault(t, engine.options[0]))
	require.Equal(t, contract.TunnelModeRegular, lastState(t, events).EffectiveMode)
	require.Empty(t, modesOf(t, events))
}

func TestCellularSwitchesToWhitelistWithoutARestart(t *testing.T) {
	_, engine, events := onCellular(t)

	require.Equal(t, [][2]string{{"proxy", "grp-whitelist"}}, engine.selects)
	require.Equal(t, 1, engine.started)
	require.Zero(t, engine.closed)
	require.Equal(t, []contract.ModePayload{{
		From: contract.TunnelModeRegular, To: contract.TunnelModeWhitelist, Reason: contract.ModeSwitchReasonNetworkCellular,
	}}, modesOf(t, events))

	state := lastState(t, events)
	require.Equal(t, contract.TunnelModeRegular, state.UserMode)
	require.Equal(t, contract.TunnelModeWhitelist, state.EffectiveMode)
	require.Equal(t, whitelistServer, *state.ActiveServerId)
	requireSchema(t, events)
}

func TestWifiReturnsToTheUserMode(t *testing.T) {
	r, engine, events := onCellular(t)

	require.NoError(t, r.OnNetworkChanged("wifi"))

	require.Equal(t, [2]string{"proxy", "grp-regular"}, engine.selects[len(engine.selects)-1])
	modes := modesOf(t, events)
	require.Equal(t, contract.ModePayload{
		From: contract.TunnelModeWhitelist, To: contract.TunnelModeRegular, Reason: contract.ModeSwitchReasonNetworkWifi,
	}, modes[len(modes)-1])
	require.Equal(t, contract.TunnelModeRegular, lastState(t, events).EffectiveMode)
	require.Equal(t, regularServer, *lastState(t, events).ActiveServerId)
}

func TestNoneKeepsTheMode(t *testing.T) {
	r, engine, events := onCellular(t)
	before := len(events.decoded(t))

	require.NoError(t, r.OnNetworkChanged("none"))

	require.Len(t, engine.selects, 1)
	require.Len(t, events.decoded(t), before)
}

func TestTapOnTheRegularScreenOnCellularSetsTheOverride(t *testing.T) {
	r, engine, events := onCellular(t)

	// The user mode is already regular: the tap still counts (tech.md 2.1).
	require.NoError(t, r.SetUserMode("regular"))

	require.Equal(t, [2]string{"proxy", "grp-regular"}, engine.selects[len(engine.selects)-1])
	modes := modesOf(t, events)
	require.Equal(t, contract.ModePayload{
		From: contract.TunnelModeWhitelist, To: contract.TunnelModeRegular, Reason: contract.ModeSwitchReasonUser,
	}, modes[len(modes)-1])
	require.Equal(t, contract.TunnelModeRegular, lastState(t, events).EffectiveMode)

	selects := len(engine.selects)
	require.NoError(t, r.OnNetworkChanged("cellular"))
	require.NoError(t, r.SetUserMode("regular"))
	require.Len(t, engine.selects, selects, "the override holds on the same network")

	require.NoError(t, r.OnNetworkChanged("wifi"))
	require.NoError(t, r.OnNetworkChanged("cellular"))
	require.Equal(t, contract.TunnelModeWhitelist, lastState(t, events).EffectiveMode,
		"a new network clears the override")
	require.Equal(t, 1, engine.started)
	requireSchema(t, events)
}

func TestNoWhitelistServersOnCellularWarnsOnce(t *testing.T) {
	engine, events := &fakeEngine{}, &recorder{}
	r := newRuntime(engine, events)
	require.NoError(t, r.Start(withAutoSwitch(t, regularOnly(t), true)))

	require.NoError(t, r.OnNetworkChanged("cellular"))
	require.NoError(t, r.OnNetworkChanged("cellular"))

	require.Empty(t, engine.selects)
	require.Equal(t, []contract.ModePayload{{
		From: contract.TunnelModeRegular, To: contract.TunnelModeRegular, Reason: contract.ModeSwitchReasonNoWhitelistServers,
	}}, modesOf(t, events))
	require.Equal(t, contract.TunnelModeRegular, lastState(t, events).EffectiveMode)
	requireSchema(t, events)
}

func TestSwitchOffIgnoresCellular(t *testing.T) {
	engine, events := &fakeEngine{}, &recorder{}
	r := newRuntime(engine, events)
	require.NoError(t, r.Start(withAutoSwitch(t, bothGroups(t), false)))

	require.NoError(t, r.OnNetworkChanged("cellular"))

	require.Empty(t, engine.selects)
	require.Empty(t, modesOf(t, events))
}

func TestNetworkChangeWhileDisconnectedDoesNothing(t *testing.T) {
	engine, events := &fakeEngine{}, &recorder{}
	r := newRuntime(engine, events)
	require.NoError(t, r.OnNetworkChanged("cellular"))
	require.Empty(t, events.decoded(t))

	require.NoError(t, r.Start(withAutoSwitch(t, bothGroups(t), true)))
	require.NoError(t, r.Stop())
	before := len(events.decoded(t))

	require.NoError(t, r.OnNetworkChanged("cellular"))

	require.Empty(t, engine.selects)
	require.Len(t, events.decoded(t), before)
}

func TestStartForgetsThePreviousNetwork(t *testing.T) {
	r, engine, events := onCellular(t)
	require.NoError(t, r.Stop())

	require.NoError(t, r.Start(withAutoSwitch(t, bothGroups(t), true)))
	require.Equal(t, "grp-regular", proxyDefault(t, engine.options[1]))
	require.Equal(t, contract.TunnelModeRegular, lastState(t, events).EffectiveMode)

	// The host reports the network again after the start (tech.md 19.10).
	require.NoError(t, r.OnNetworkChanged("cellular"))
	require.Equal(t, contract.TunnelModeWhitelist, lastState(t, events).EffectiveMode)
}

func TestUnknownNetworkIsConfigInvalid(t *testing.T) {
	r, engine, _ := onCellular(t)
	requireCode(t, r.OnNetworkChanged("wwan"), contract.CoreErrorCodeConfigInvalid)
	require.Len(t, engine.selects, 1)
}

func TestFailedSwitchKeepsTheState(t *testing.T) {
	engine, events := &fakeEngine{}, &recorder{}
	r := newRuntime(engine, events)
	require.NoError(t, r.Start(withAutoSwitch(t, bothGroups(t), true)))
	engine.mu.Lock()
	engine.selectErr = errors.New("no selector")
	engine.mu.Unlock()

	requireCode(t, r.OnNetworkChanged("cellular"), contract.CoreErrorCodeInternal)

	require.Empty(t, modesOf(t, events))
	require.Equal(t, contract.TunnelModeRegular, lastState(t, events).EffectiveMode)

	engine.mu.Lock()
	engine.selectErr = nil
	engine.mu.Unlock()
	require.NoError(t, r.OnNetworkChanged("cellular"))
	require.Equal(t, contract.TunnelModeWhitelist, lastState(t, events).EffectiveMode,
		"the same report again retries the switch")
}

func TestUpdateKeepsTheNetworkAndStartsOnTheEffectiveGroup(t *testing.T) {
	r, engine, events := onCellular(t)
	modes := len(modesOf(t, events))

	require.NoError(t, r.Update(withAutoSwitch(t, bothGroups(t), true)))

	require.Equal(t, 2, engine.started)
	require.Equal(t, "grp-whitelist", proxyDefault(t, engine.options[1]))
	require.Len(t, modesOf(t, events), modes, "nothing changed for the switch")
	state := lastState(t, events)
	require.Equal(t, contract.TunnelStatusConnected, state.Status)
	require.Equal(t, contract.TunnelModeWhitelist, state.EffectiveMode)
	require.Equal(t, whitelistServer, *state.ActiveServerId)
}

func TestUpdateKeepsTheOverride(t *testing.T) {
	r, engine, events := onCellular(t)
	require.NoError(t, r.SetUserMode("regular"))
	modes := len(modesOf(t, events))

	require.NoError(t, r.Update(withAutoSwitch(t, bothGroups(t), true)))

	require.Equal(t, "grp-regular", proxyDefault(t, engine.options[1]))
	require.Len(t, modesOf(t, events), modes)
	require.Equal(t, contract.TunnelModeRegular, lastState(t, events).EffectiveMode)
}

func TestUpdateTurningTheSwitchOffReturnsToTheUserMode(t *testing.T) {
	r, engine, events := onCellular(t)

	require.NoError(t, r.Update(withAutoSwitch(t, bothGroups(t), false)))

	require.Equal(t, "grp-regular", proxyDefault(t, engine.options[1]))
	modes := modesOf(t, events)
	require.Equal(t, contract.ModePayload{
		From: contract.TunnelModeWhitelist, To: contract.TunnelModeRegular, Reason: contract.ModeSwitchReasonUser,
	}, modes[len(modes)-1])
	require.Equal(t, contract.TunnelModeRegular, lastState(t, events).EffectiveMode)
	requireSchema(t, events)
}

func TestUpdateTurningTheSwitchOnOnCellularSwitches(t *testing.T) {
	engine, events := &fakeEngine{}, &recorder{}
	r := newRuntime(engine, events)
	require.NoError(t, r.Start(withAutoSwitch(t, bothGroups(t), false)))
	require.NoError(t, r.OnNetworkChanged("cellular"))

	require.NoError(t, r.Update(withAutoSwitch(t, bothGroups(t), true)))

	require.Equal(t, "grp-whitelist", proxyDefault(t, engine.options[1]))
	require.Empty(t, engine.selects, "the new box starts on the group")
	require.Equal(t, []contract.ModePayload{{
		From: contract.TunnelModeRegular, To: contract.TunnelModeWhitelist, Reason: contract.ModeSwitchReasonNetworkCellular,
	}}, modesOf(t, events))
	require.Equal(t, contract.TunnelModeWhitelist, lastState(t, events).EffectiveMode)
}

func TestUpdateWithoutWhitelistServersOnCellularLeavesWhitelist(t *testing.T) {
	r, engine, events := onCellular(t)

	require.NoError(t, r.Update(withAutoSwitch(t, regularOnly(t), true)))

	require.Equal(t, "grp-regular", proxyDefault(t, engine.options[1]))
	modes := modesOf(t, events)
	require.Equal(t, contract.ModePayload{
		From: contract.TunnelModeWhitelist, To: contract.TunnelModeRegular, Reason: contract.ModeSwitchReasonNoWhitelistServers,
	}, modes[len(modes)-1])
	state := lastState(t, events)
	require.Equal(t, contract.TunnelModeRegular, state.EffectiveMode)
	require.Equal(t, regularServer, *state.ActiveServerId)
	requireSchema(t, events)
}

func TestUpdateWithWhitelistServersOnCellularSwitches(t *testing.T) {
	engine, events := &fakeEngine{}, &recorder{}
	r := newRuntime(engine, events)
	require.NoError(t, r.Start(withAutoSwitch(t, regularOnly(t), true)))
	require.NoError(t, r.OnNetworkChanged("cellular"))

	require.NoError(t, r.Update(withAutoSwitch(t, bothGroups(t), true)))

	require.Equal(t, "grp-whitelist", proxyDefault(t, engine.options[1]))
	modes := modesOf(t, events)
	require.Equal(t, contract.ModePayload{
		From: contract.TunnelModeRegular, To: contract.TunnelModeWhitelist, Reason: contract.ModeSwitchReasonNetworkCellular,
	}, modes[len(modes)-1])
}

func TestModeEventsComeAfterTheRestartedBoxIsConnected(t *testing.T) {
	r, _, events := onCellular(t)
	before := len(events.decoded(t))

	require.NoError(t, r.Update(withAutoSwitch(t, bothGroups(t), false)))

	var kinds []contract.CoreEventType
	for _, event := range events.decoded(t)[before:] {
		kinds = append(kinds, event.Type)
	}
	require.Equal(t, []contract.CoreEventType{
		contract.CoreEventTypeState, contract.CoreEventTypeState, contract.CoreEventTypeMode,
	}, kinds)
	require.Equal(t, contract.TunnelStatusConnected, lastState(t, events).Status)
}

func TestUpdateWithAnotherUserModeCountsAsATap(t *testing.T) {
	engine, events := &fakeEngine{}, &recorder{}
	r := newRuntime(engine, events)
	require.NoError(t, r.Start(withAutoSwitch(t, bothGroups(t), true)))
	require.NoError(t, r.OnNetworkChanged("wifi"))

	request := rewrite(t, func(req *contract.TunnelRequest) {
		require.NoError(t, json.Unmarshal([]byte(withAutoSwitch(t, bothGroups(t), true)), req))
		req.UserMode = contract.TunnelModeWhitelist
	})
	require.NoError(t, r.Update(request))

	require.Equal(t, "grp-whitelist", proxyDefault(t, engine.options[1]))
	require.Equal(t, []contract.ModePayload{{
		From: contract.TunnelModeRegular, To: contract.TunnelModeWhitelist, Reason: contract.ModeSwitchReasonUser,
	}}, modesOf(t, events))
	state := lastState(t, events)
	require.Equal(t, contract.TunnelModeWhitelist, state.UserMode)
	require.Equal(t, contract.TunnelModeWhitelist, state.EffectiveMode)
}
