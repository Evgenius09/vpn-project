package autoswitch_test

import (
	"testing"

	"pgregory.net/rapid"

	"github.com/Evgenius09/vpn-project/core/internal/autoswitch"
	"github.com/Evgenius09/vpn-project/core/internal/contract"
)

var (
	genMode = rapid.SampledFrom([]contract.TunnelMode{regular, whitelist})
	genNet  = rapid.SampledFrom([]autoswitch.NetType{
		autoswitch.NetWifi, autoswitch.NetCellular, autoswitch.NetEthernet, autoswitch.NetOther, autoswitch.NetNone,
	})
	genEvent = rapid.OneOf(
		rapid.Map(genNet, func(n autoswitch.NetType) autoswitch.Event { return autoswitch.NetChanged{Net: n} }),
		rapid.Map(genMode, func(m contract.TunnelMode) autoswitch.Event { return autoswitch.UserModeSet{Mode: m} }),
		rapid.Map(rapid.Bool(), func(b bool) autoswitch.Event { return autoswitch.AutoSwitchSet{Enabled: b} }),
		rapid.Map(rapid.Bool(), func(b bool) autoswitch.Event { return autoswitch.ServersUpdated{WhitelistAvailable: b} }),
	)
	// genSystemEvent leaves out UserModeSet, the only user event.
	genSystemEvent = rapid.OneOf(
		rapid.Map(genNet, func(n autoswitch.NetType) autoswitch.Event { return autoswitch.NetChanged{Net: n} }),
		rapid.Map(rapid.Bool(), func(b bool) autoswitch.Event { return autoswitch.ServersUpdated{WhitelistAvailable: b} }),
	)
)

func genStart(t *rapid.T) autoswitch.State {
	return autoswitch.New(genMode.Draw(t, "userMode"), rapid.Bool().Draw(t, "autoSwitch"), rapid.Bool().Draw(t, "whitelist"))
}

// rule is the effective mode of tech.md 5.7, written from the spec.
func rule(s autoswitch.State) contract.TunnelMode {
	switch {
	case !s.AutoSwitch, s.Override:
		return s.UserMode
	case s.Net == autoswitch.NetCellular && s.WhitelistAvailable:
		return whitelist
	default:
		return s.UserMode
	}
}

// walk draws a start and events and checks each step against check.
func walk(t *rapid.T, check func(t *rapid.T, before autoswitch.State, event autoswitch.Event, after autoswitch.State, actions []autoswitch.Action)) {
	s := genStart(t)
	for _, event := range rapid.SliceOfN(genEvent, 0, 40).Draw(t, "events") {
		next, actions := autoswitch.Next(s, event)
		check(t, s, event, next, actions)
		s = next
	}
}

func TestEffectiveFollowsTheRule(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		walk(t, func(t *rapid.T, _ autoswitch.State, _ autoswitch.Event, after autoswitch.State, _ []autoswitch.Action) {
			if after.Effective != rule(after) {
				t.Fatalf("effective %s, the rule gives %s in %+v", after.Effective, rule(after), after)
			}
		})
	})
}

func TestActionsReportEveryChange(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		walk(t, func(t *rapid.T, before autoswitch.State, _ autoswitch.Event, after autoswitch.State, actions []autoswitch.Action) {
			var selects []contract.TunnelMode
			var emits []contract.ModePayload
			for _, action := range actions {
				switch a := action.(type) {
				case autoswitch.SelectGroup:
					selects = append(selects, a.Group)
				case autoswitch.Emit:
					emits = append(emits, a.Event)
				}
			}
			if before.Effective == after.Effective {
				if len(selects) != 0 {
					t.Fatalf("select without a change: %v", actions)
				}
				for _, e := range emits {
					if e.Reason != contract.ModeSwitchReasonNoWhitelistServers || e.From != e.To || e.To != after.Effective {
						t.Fatalf("mode event without a change: %+v", e)
					}
				}
				if len(emits) > 1 {
					t.Fatalf("more than one event: %v", actions)
				}
				return
			}
			if len(selects) != 1 || selects[0] != after.Effective {
				t.Fatalf("change %s -> %s selects %v", before.Effective, after.Effective, selects)
			}
			if len(emits) != 1 || emits[0].From != before.Effective || emits[0].To != after.Effective || !emits[0].Reason.Valid() {
				t.Fatalf("change %s -> %s emits %+v", before.Effective, after.Effective, emits)
			}
		})
	})
}

// I1: with the switch off the effective mode is the user's.
func TestI1SwitchOffMeansUserMode(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		walk(t, func(t *rapid.T, _ autoswitch.State, _ autoswitch.Event, after autoswitch.State, _ []autoswitch.Action) {
			if !after.AutoSwitch && after.Effective != after.UserMode {
				t.Fatalf("switch off, effective %s, user %s", after.Effective, after.UserMode)
			}
		})
	})
}

// I2: whitelist is never chosen automatically without whitelist servers.
func TestI2NoAutomaticWhitelistWithoutServers(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		walk(t, func(t *rapid.T, _ autoswitch.State, _ autoswitch.Event, after autoswitch.State, actions []autoswitch.Action) {
			if after.WhitelistAvailable || after.UserMode == whitelist {
				return
			}
			if after.Effective == whitelist {
				t.Fatalf("whitelist without servers: %+v", after)
			}
			for _, action := range actions {
				if action == (autoswitch.SelectGroup{Group: whitelist}) {
					t.Fatalf("selected whitelist without servers: %+v", after)
				}
			}
		})
	})
}

// I3: wifi, cellular, wifi without user events ends in the user mode.
func TestI3WifiCellularWifiEndsInTheUserMode(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		s := genStart(t)
		for _, event := range rapid.SliceOfN(genEvent, 0, 20).Draw(t, "prefix") {
			s, _ = autoswitch.Next(s, event)
		}
		path := []autoswitch.NetType{autoswitch.NetWifi, autoswitch.NetCellular, autoswitch.NetWifi}
		for _, netType := range path {
			for _, event := range rapid.SliceOfN(genSystemEvent, 0, 3).Draw(t, "between") {
				// A real network change in between would leave the path.
				if changed, isNet := event.(autoswitch.NetChanged); isNet && changed.Net != autoswitch.NetNone {
					continue
				}
				s, _ = autoswitch.Next(s, event)
			}
			s, _ = autoswitch.Next(s, autoswitch.NetChanged{Net: netType})
		}
		if s.Effective != s.UserMode {
			t.Fatalf("after wifi, cellular, wifi: effective %s, user %s", s.Effective, s.UserMode)
		}
	})
}

// I4: none changes nothing.
func TestI4NoneChangesNothing(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		walk(t, func(t *rapid.T, before autoswitch.State, event autoswitch.Event, after autoswitch.State, actions []autoswitch.Action) {
			if event != (autoswitch.NetChanged{Net: autoswitch.NetNone}) {
				return
			}
			if after != before || len(actions) != 0 {
				t.Fatalf("none changed %+v to %+v with %v", before, after, actions)
			}
		})
	})
}

// I5: the same events give the same states and actions.
func TestI5Deterministic(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		start := genStart(t)
		events := rapid.SliceOfN(genEvent, 0, 40).Draw(t, "events")
		first, second := start, start
		for _, event := range events {
			var a, b []autoswitch.Action
			first, a = autoswitch.Next(first, event)
			second, b = autoswitch.Next(second, event)
			if first != second || len(a) != len(b) {
				t.Fatalf("diverged on %#v", event)
			}
			for index := range a {
				if a[index] != b[index] {
					t.Fatalf("diverged on %#v: %v and %v", event, a, b)
				}
			}
		}
	})
}

// I6: the same event twice in a row acts only once.
func TestI6RepeatedEventDoesNothing(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		walk(t, func(t *rapid.T, _ autoswitch.State, event autoswitch.Event, after autoswitch.State, _ []autoswitch.Action) {
			again, actions := autoswitch.Next(after, event)
			if again != after || len(actions) != 0 {
				t.Fatalf("repeat of %#v changed %+v to %+v with %v", event, after, again, actions)
			}
		})
	})
}

// tech.md 19.10: the warning only on cellular, never twice in a row.
func TestNoWhitelistWarningOnlyOnCellularWithoutServers(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		walk(t, func(t *rapid.T, _ autoswitch.State, _ autoswitch.Event, after autoswitch.State, actions []autoswitch.Action) {
			for _, action := range actions {
				emitted, isEmit := action.(autoswitch.Emit)
				if !isEmit || emitted.Event.Reason != contract.ModeSwitchReasonNoWhitelistServers {
					continue
				}
				if after.Net != autoswitch.NetCellular || after.WhitelistAvailable || !after.AutoSwitch || after.Override {
					t.Fatalf("warning in %+v", after)
				}
			}
		})
	})
}
