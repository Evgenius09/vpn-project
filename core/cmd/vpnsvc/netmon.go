package main

import (
	"strings"
	"sync"
	"time"

	"github.com/Evgenius09/vpn-project/core/internal/autoswitch"
)

// netDebounce lets a network switch settle before the core hears of it
// (tech.md 5.7): a Wi-Fi reconnect passes through none and back.
const netDebounce = time.Second

// IANA ifType values that Windows reports in MIB_IF_ROW2.Type.
const (
	ifTypeOther       = 1
	ifTypeEthernet    = 6
	ifTypePPP         = 23
	ifTypePropVirtual = 53
	ifTypeIEEE80211   = 71
	ifTypeTunnel      = 131
	ifTypeWWANPP      = 243
	ifTypeWWANPP2     = 244
)

// NDIS_PHYSICAL_MEDIUM values from MIB_IF_ROW2.PhysicalMediumType.
const (
	mediumUnspecified = 0
	mediumWirelessWAN = 8
	mediumNative80211 = 9
)

// connectivityLevel is NL_NETWORK_CONNECTIVITY_LEVEL_HINT.
type connectivityLevel uint32

const (
	levelUnknown connectivityLevel = iota
	levelNone
	levelLocalAccess
	levelInternetAccess
	levelConstrainedInternetAccess
	levelHidden
)

// connectivityCost is NL_NETWORK_CONNECTIVITY_COST_HINT.
type connectivityCost uint32

const (
	costUnknown connectivityCost = iota
	costUnrestricted
	costFixed
	costVariable
)

// netInterface is what the detection needs to know about one interface.
type netInterface struct {
	Index       uint32
	Type        uint32
	Medium      uint32
	Alias       string
	Description string
	// Up means the interface is operationally up.
	Up bool
	// HasDefaultRoute and Metric describe its best default route: the route
	// metric plus the interface metric, as Windows compares them.
	HasDefaultRoute bool
	Metric          uint32
	// Level, Cost and Roaming come from the connectivity hint of the interface.
	Level   connectivityLevel
	Cost    connectivityCost
	Roaming bool
}

// isWintun recognizes the tunnel adapter. sing-tun creates it with the tunnel
// type "sing-tun", which wintun puts into the device description; older wintun
// drivers call it "Wintun Userspace Tunnel".
func isWintun(iface netInterface) bool {
	for _, name := range []string{iface.Description, iface.Alias} {
		lower := strings.ToLower(name)
		if strings.Contains(lower, "wintun") || strings.Contains(lower, "sing-tun") {
			return true
		}
	}
	return false
}

// classify maps one interface to a NetType (tech.md 5.7). A metered or roaming
// connection counts as cellular, because a phone hotspot looks like Wi-Fi or
// USB ethernet otherwise. An unknown cost is not metered: Windows reports it
// before it learns the network, and treating it as cellular would switch every
// fresh Wi-Fi to whitelist.
func classify(iface netInterface) autoswitch.NetType {
	if iface.Level == levelNone {
		return autoswitch.NetNone
	}
	if iface.Type == ifTypeWWANPP || iface.Type == ifTypeWWANPP2 || iface.Medium == mediumWirelessWAN {
		return autoswitch.NetCellular
	}
	if iface.Cost == costFixed || iface.Cost == costVariable || iface.Roaming {
		return autoswitch.NetCellular
	}
	switch {
	case iface.Type == ifTypeIEEE80211 || iface.Medium == mediumNative80211:
		return autoswitch.NetWifi
	case iface.Type == ifTypeEthernet:
		return autoswitch.NetEthernet
	default:
		return autoswitch.NetOther
	}
}

// activeNetwork picks the interface that carries the traffic outside the
// tunnel: the best default route, without the wintun adapter, which takes the
// default route while the tunnel runs.
func activeNetwork(ifaces []netInterface) autoswitch.NetType {
	var best *netInterface
	for i := range ifaces {
		iface := &ifaces[i]
		if !iface.Up || !iface.HasDefaultRoute || isWintun(*iface) {
			continue
		}
		if best == nil || iface.Metric < best.Metric || (iface.Metric == best.Metric && iface.Index < best.Index) {
			best = iface
		}
	}
	if best == nil {
		return autoswitch.NetNone
	}
	return classify(*best)
}

// afterFunc schedules fire and returns its cancel, like time.AfterFunc.
type afterFunc func(delay time.Duration, fire func()) (stop func() bool)

func timeAfterFunc(delay time.Duration, fire func()) func() bool {
	return time.AfterFunc(delay, fire).Stop
}

// netWatch debounces detections and delivers settled network types. The first
// detection is delivered at once: it is the starting point, not a change.
// Deliveries run under the lock, so Resend cannot race a debounced change.
type netWatch struct {
	mu      sync.Mutex
	delay   time.Duration
	after   afterFunc
	deliver func(autoswitch.NetType)

	current autoswitch.NetType
	known   bool
	pending autoswitch.NetType
	// generation tells a fired timer whether a newer detection replaced it,
	// because a timer may fire after its stop came too late.
	generation uint64
	stop       func() bool
	closed     bool
}

func newNetWatch(delay time.Duration, after afterFunc, deliver func(autoswitch.NetType)) *netWatch {
	return &netWatch{delay: delay, after: after, deliver: deliver}
}

// Observe takes a fresh detection.
func (w *netWatch) Observe(net autoswitch.NetType) {
	w.mu.Lock()
	defer w.mu.Unlock()
	if w.closed {
		return
	}
	if !w.known {
		w.current, w.known = net, true
		w.deliver(net)
		return
	}
	if w.stop != nil {
		w.stop()
	}
	w.generation++
	w.pending = net
	generation := w.generation
	w.stop = w.after(w.delay, func() { w.fire(generation) })
}

func (w *netWatch) fire(generation uint64) {
	w.mu.Lock()
	defer w.mu.Unlock()
	if w.closed || generation != w.generation {
		return
	}
	w.stop = nil
	if w.pending == w.current {
		return
	}
	w.current = w.pending
	w.deliver(w.current)
}

// Resend delivers the settled network again. A new tunnel starts on the
// network "other" and needs it right away (tech.md 19.10).
func (w *netWatch) Resend() {
	w.mu.Lock()
	defer w.mu.Unlock()
	if w.closed || !w.known {
		return
	}
	w.deliver(w.current)
}

// Close drops a pending change and ignores later detections.
func (w *netWatch) Close() {
	w.mu.Lock()
	defer w.mu.Unlock()
	w.closed = true
	if w.stop != nil {
		w.stop()
		w.stop = nil
	}
}
