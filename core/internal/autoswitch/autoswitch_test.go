package autoswitch_test

import (
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/Evgenius09/vpn-project/core/internal/autoswitch"
	"github.com/Evgenius09/vpn-project/core/internal/contract"
)

const (
	regular   = contract.TunnelModeRegular
	whitelist = contract.TunnelModeWhitelist
)

func emit(from, to contract.TunnelMode, reason contract.ModeSwitchReason) autoswitch.Action {
	return autoswitch.Emit{Event: contract.ModePayload{From: from, To: to, Reason: reason}}
}

func switchTo(from, to contract.TunnelMode, reason contract.ModeSwitchReason) []autoswitch.Action {
	return []autoswitch.Action{autoswitch.SelectGroup{Group: to}, emit(from, to, reason)}
}

func run(s autoswitch.State, events ...autoswitch.Event) autoswitch.State {
	for _, event := range events {
		s, _ = autoswitch.Next(s, event)
	}
	return s
}

func net(t autoswitch.NetType) autoswitch.Event { return autoswitch.NetChanged{Net: t} }

func TestStartRunsTheUserModeUntilTheNetworkIsKnown(t *testing.T) {
	for _, mode := range []contract.TunnelMode{regular, whitelist} {
		s := autoswitch.New(mode, true, true)
		require.Equal(t, autoswitch.NetOther, s.Net, "tech.md 19.10")
		require.False(t, s.Override)
		require.Equal(t, mode, s.Effective)
	}
}

// Each case starts from New(regular, autoSwitch on, whitelist servers) unless
// it says otherwise, walks the setup events, and checks the last event.
func TestScenarios(t *testing.T) {
	onCellular := []autoswitch.Event{net(autoswitch.NetWifi), net(autoswitch.NetCellular)}
	overridden := append(append([]autoswitch.Event{}, onCellular...), autoswitch.UserModeSet{Mode: regular})

	tests := []struct {
		name       string
		start      autoswitch.State
		setup      []autoswitch.Event
		event      autoswitch.Event
		want       []autoswitch.Action
		effective  contract.TunnelMode
		override   bool
		userMode   contract.TunnelMode
		autoSwitch bool
	}{
		{
			name:      "cellular with whitelist servers switches to whitelist",
			setup:     []autoswitch.Event{net(autoswitch.NetWifi)},
			event:     net(autoswitch.NetCellular),
			want:      switchTo(regular, whitelist, contract.ModeSwitchReasonNetworkCellular),
			effective: whitelist,
		},
		{
			name:      "the first report after start can be cellular",
			event:     net(autoswitch.NetCellular),
			want:      switchTo(regular, whitelist, contract.ModeSwitchReasonNetworkCellular),
			effective: whitelist,
		},
		{
			name:      "wifi after cellular returns to the user mode",
			setup:     onCellular,
			event:     net(autoswitch.NetWifi),
			want:      switchTo(whitelist, regular, contract.ModeSwitchReasonNetworkWifi),
			effective: regular,
		},
		{
			name:      "ethernet counts as wifi",
			setup:     onCellular,
			event:     net(autoswitch.NetEthernet),
			want:      switchTo(whitelist, regular, contract.ModeSwitchReasonNetworkWifi),
			effective: regular,
		},
		{
			name:      "other counts as wifi",
			setup:     onCellular,
			event:     net(autoswitch.NetOther),
			want:      switchTo(whitelist, regular, contract.ModeSwitchReasonNetworkWifi),
			effective: regular,
		},
		{
			name:      "none changes nothing",
			setup:     onCellular,
			event:     net(autoswitch.NetNone),
			effective: whitelist,
		},
		{
			name:      "the same network again changes nothing",
			setup:     onCellular,
			event:     net(autoswitch.NetCellular),
			effective: whitelist,
		},
		{
			name:      "a tap on the regular screen on cellular overrides the switch",
			setup:     onCellular,
			event:     autoswitch.UserModeSet{Mode: regular},
			want:      switchTo(whitelist, regular, contract.ModeSwitchReasonUser),
			effective: regular,
			override:  true,
		},
		{
			name:      "the same tap again changes nothing",
			setup:     overridden,
			event:     autoswitch.UserModeSet{Mode: regular},
			effective: regular,
			override:  true,
		},
		{
			name:      "the override holds while the network stays",
			setup:     overridden,
			event:     autoswitch.ServersUpdated{WhitelistAvailable: true},
			effective: regular,
			override:  true,
		},
		{
			name:      "leaving cellular clears the override",
			setup:     overridden,
			event:     net(autoswitch.NetWifi),
			effective: regular,
		},
		{
			name:      "cellular after the override was cleared switches again",
			setup:     append(append([]autoswitch.Event{}, overridden...), net(autoswitch.NetWifi)),
			event:     net(autoswitch.NetCellular),
			want:      switchTo(regular, whitelist, contract.ModeSwitchReasonNetworkCellular),
			effective: whitelist,
		},
		{
			name:      "none keeps the override",
			setup:     overridden,
			event:     net(autoswitch.NetNone),
			effective: regular,
			override:  true,
		},
		{
			name:       "turning the switch on again clears the override",
			setup:      overridden,
			event:      autoswitch.AutoSwitchSet{Enabled: true},
			want:       switchTo(regular, whitelist, contract.ModeSwitchReasonOverrideCleared),
			effective:  whitelist,
			autoSwitch: true,
		},
		{
			name:      "turning the switch off on cellular returns to the user mode",
			setup:     onCellular,
			event:     autoswitch.AutoSwitchSet{Enabled: false},
			want:      switchTo(whitelist, regular, contract.ModeSwitchReasonUser),
			effective: regular,
		},
		{
			name:       "turning the switch on while on cellular switches to whitelist",
			start:      autoswitch.New(regular, false, true),
			setup:      []autoswitch.Event{net(autoswitch.NetCellular)},
			event:      autoswitch.AutoSwitchSet{Enabled: true},
			want:       switchTo(regular, whitelist, contract.ModeSwitchReasonNetworkCellular),
			effective:  whitelist,
			autoSwitch: true,
		},
		{
			name:      "with the switch off cellular changes nothing",
			start:     autoswitch.New(regular, false, true),
			event:     net(autoswitch.NetCellular),
			effective: regular,
		},
		{
			name:      "with the switch off a tap on cellular sets no override",
			start:     autoswitch.New(regular, false, true),
			setup:     []autoswitch.Event{net(autoswitch.NetCellular)},
			event:     autoswitch.UserModeSet{Mode: whitelist},
			want:      switchTo(regular, whitelist, contract.ModeSwitchReasonUser),
			effective: whitelist,
			userMode:  whitelist,
		},
		{
			name:      "cellular without whitelist servers warns and keeps the group",
			start:     autoswitch.New(regular, true, false),
			setup:     []autoswitch.Event{net(autoswitch.NetWifi)},
			event:     net(autoswitch.NetCellular),
			want:      []autoswitch.Action{emit(regular, regular, contract.ModeSwitchReasonNoWhitelistServers)},
			effective: regular,
		},
		{
			name:      "the warning comes once per network change",
			start:     autoswitch.New(regular, true, false),
			setup:     []autoswitch.Event{net(autoswitch.NetCellular)},
			event:     net(autoswitch.NetCellular),
			effective: regular,
		},
		{
			name:      "losing the whitelist servers on cellular leaves whitelist with the warning",
			setup:     onCellular,
			event:     autoswitch.ServersUpdated{WhitelistAvailable: false},
			want:      switchTo(whitelist, regular, contract.ModeSwitchReasonNoWhitelistServers),
			effective: regular,
		},
		{
			name:      "losing them again changes nothing",
			setup:     append(append([]autoswitch.Event{}, onCellular...), autoswitch.ServersUpdated{WhitelistAvailable: false}),
			event:     autoswitch.ServersUpdated{WhitelistAvailable: false},
			effective: regular,
		},
		{
			name:      "whitelist servers arriving on cellular switch to whitelist",
			start:     autoswitch.New(regular, true, false),
			setup:     []autoswitch.Event{net(autoswitch.NetCellular)},
			event:     autoswitch.ServersUpdated{WhitelistAvailable: true},
			want:      switchTo(regular, whitelist, contract.ModeSwitchReasonNetworkCellular),
			effective: whitelist,
		},
		{
			name:       "turning the switch on without whitelist servers does not warn",
			start:      autoswitch.New(regular, false, false),
			setup:      []autoswitch.Event{net(autoswitch.NetCellular)},
			event:      autoswitch.AutoSwitchSet{Enabled: true},
			effective:  regular,
			autoSwitch: true,
		},
		{
			name:      "the override silences the warning",
			start:     autoswitch.New(regular, true, true),
			setup:     overridden,
			event:     autoswitch.ServersUpdated{WhitelistAvailable: false},
			effective: regular,
			override:  true,
		},
		{
			name:      "a whitelist user on cellular stays without an event",
			start:     autoswitch.New(whitelist, true, true),
			setup:     []autoswitch.Event{net(autoswitch.NetWifi)},
			event:     net(autoswitch.NetCellular),
			effective: whitelist,
			userMode:  whitelist,
		},
		{
			name:      "a whitelist user without whitelist servers gets no warning",
			start:     autoswitch.New(whitelist, true, false),
			event:     net(autoswitch.NetCellular),
			effective: whitelist,
			userMode:  whitelist,
		},
		{
			name:      "choosing whitelist on cellular keeps the group and sets the override",
			setup:     onCellular,
			event:     autoswitch.UserModeSet{Mode: whitelist},
			effective: whitelist,
			override:  true,
			userMode:  whitelist,
		},
		{
			name:      "a tap off cellular switches without an override",
			setup:     []autoswitch.Event{net(autoswitch.NetWifi)},
			event:     autoswitch.UserModeSet{Mode: whitelist},
			want:      switchTo(regular, whitelist, contract.ModeSwitchReasonUser),
			effective: whitelist,
			userMode:  whitelist,
		},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			start := test.start
			if start == (autoswitch.State{}) {
				start = autoswitch.New(regular, true, true)
			}
			before := run(start, test.setup...)

			after, actions := autoswitch.Next(before, test.event)

			require.Equal(t, test.want, actions)
			require.Equal(t, test.effective, after.Effective, "effective")
			require.Equal(t, test.override, after.Override, "override")
			userMode := test.userMode
			if userMode == "" {
				userMode = regular
			}
			require.Equal(t, userMode, after.UserMode, "userMode")
			if _, isSwitch := test.event.(autoswitch.AutoSwitchSet); isSwitch {
				require.Equal(t, test.autoSwitch, after.AutoSwitch, "autoSwitch")
			}
		})
	}
}

func TestNetTypes(t *testing.T) {
	for _, valid := range []autoswitch.NetType{"wifi", "cellular", "ethernet", "other", "none"} {
		require.True(t, valid.Valid(), valid)
	}
	for _, invalid := range []autoswitch.NetType{"", "wwan", "Wifi"} {
		require.False(t, invalid.Valid(), invalid)
	}
}
