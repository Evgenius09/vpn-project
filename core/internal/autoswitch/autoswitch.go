// Package autoswitch is the whitelist auto switch of tech.md 5.7 and 19.10: a
// pure state machine that the runtime feeds with network, user, and request
// changes.
package autoswitch

import "github.com/Evgenius09/vpn-project/core/internal/contract"

// NetType is the kind of the active network the host reports.
type NetType string

// Network kinds of tech.md 5.7.
const (
	NetWifi     NetType = "wifi"
	NetCellular NetType = "cellular"
	NetEthernet NetType = "ethernet"
	NetOther    NetType = "other"
	NetNone     NetType = "none"
)

// Valid reports whether n is one of the network kinds.
func (n NetType) Valid() bool {
	switch n {
	case NetWifi, NetCellular, NetEthernet, NetOther, NetNone:
		return true
	}
	return false
}

// State is what the switch knows. Effective always follows from the other
// fields.
type State struct {
	Net        NetType
	UserMode   contract.TunnelMode
	AutoSwitch bool
	// Override means the user chose the mode in the current network.
	Override bool
	// WhitelistAvailable means the request holds a whitelist server.
	WhitelistAvailable bool
	Effective          contract.TunnelMode
}

// Event changes the state.
type Event interface{ event() }

// NetChanged reports a new active network.
type NetChanged struct{ Net NetType }

// UserModeSet comes only from a tap on the PowerButton (tech.md 2.1).
type UserModeSet struct{ Mode contract.TunnelMode }

// AutoSwitchSet turns the switch on or off.
type AutoSwitchSet struct{ Enabled bool } //nolint:revive // The event names follow tech.md 5.7.

// ServersUpdated reports whether the request holds a whitelist server.
type ServersUpdated struct{ WhitelistAvailable bool }

func (NetChanged) event()     {}
func (UserModeSet) event()    {}
func (AutoSwitchSet) event()  {}
func (ServersUpdated) event() {}

// Action is what the runtime does after an event.
type Action interface{ action() }

// SelectGroup points the proxy selector at a group.
type SelectGroup struct{ Group contract.TunnelMode }

// Emit sends a mode CoreEvent.
type Emit struct{ Event contract.ModePayload }

func (SelectGroup) action() {}
func (Emit) action()        {}

// New is the state at Start: the network is not known yet, so the tunnel runs
// in the user's mode until the host reports it (tech.md 19.10).
func New(userMode contract.TunnelMode, autoSwitch, whitelistAvailable bool) State {
	return State{
		Net:                NetOther,
		UserMode:           userMode,
		AutoSwitch:         autoSwitch,
		WhitelistAvailable: whitelistAvailable,
		Effective:          userMode,
	}
}

// Next applies one event. A change of the effective mode selects its group and
// emits a mode event. tech.md 19.10 sends no_whitelist_servers only when the
// network became cellular or the whitelist servers went away on cellular, so a
// repeated event stays silent (I6). Losing the servers while the switch holds
// whitelist always changes the effective mode, so that case leaves through the
// change with the warning as its reason.
func Next(s State, e Event) (State, []Action) {
	next := s
	switch e := e.(type) {
	case NetChanged:
		if e.Net == NetNone || e.Net == s.Net {
			return s, nil
		}
		next.Net, next.Override = e.Net, false
	case UserModeSet:
		next.UserMode = e.Mode
		if next.AutoSwitch && next.Net == NetCellular {
			next.Override = true
		}
	case AutoSwitchSet:
		next.AutoSwitch, next.Override = e.Enabled, false
	case ServersUpdated:
		next.WhitelistAvailable = e.WhitelistAvailable
	default:
		return s, nil
	}
	next.Effective = effective(next)

	if next.Effective != s.Effective {
		return next, []Action{
			SelectGroup{Group: next.Effective},
			Emit{Event: contract.ModePayload{From: s.Effective, To: next.Effective, Reason: reason(s, next, e)}},
		}
	}
	if blocked(next) && s.Net != NetCellular {
		return next, []Action{Emit{Event: contract.ModePayload{
			From: next.Effective, To: next.Effective, Reason: contract.ModeSwitchReasonNoWhitelistServers,
		}}}
	}
	return next, nil
}

func effective(s State) contract.TunnelMode {
	if s.AutoSwitch && !s.Override && s.Net == NetCellular && s.WhitelistAvailable {
		return contract.TunnelModeWhitelist
	}
	return s.UserMode
}

// blocked means the switch would pick whitelist on this network but has no
// server for it.
func blocked(s State) bool {
	return s.AutoSwitch && !s.Override && s.Net == NetCellular &&
		s.UserMode != contract.TunnelModeWhitelist && !s.WhitelistAvailable
}

// reason names the cause of a change of the effective mode. Whitelist reached
// automatically is always the cellular network at work.
func reason(before, after State, e Event) contract.ModeSwitchReason {
	automatic := after.Effective == contract.TunnelModeWhitelist && after.UserMode != contract.TunnelModeWhitelist
	switch e := e.(type) {
	case NetChanged:
		if e.Net == NetCellular {
			return contract.ModeSwitchReasonNetworkCellular
		}
		return contract.ModeSwitchReasonNetworkWifi
	case AutoSwitchSet:
		switch {
		case before.Override:
			return contract.ModeSwitchReasonOverrideCleared
		case automatic:
			return contract.ModeSwitchReasonNetworkCellular
		default:
			return contract.ModeSwitchReasonUser
		}
	case ServersUpdated:
		if automatic {
			return contract.ModeSwitchReasonNetworkCellular
		}
		return contract.ModeSwitchReasonNoWhitelistServers
	default:
		return contract.ModeSwitchReasonUser
	}
}
