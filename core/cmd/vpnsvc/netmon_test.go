package main

import (
	"sort"
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	"pgregory.net/rapid"

	"github.com/Evgenius09/vpn-project/core/internal/autoswitch"
)

// Interfaces as Windows reports them with internet access and no cost hint.
var (
	wifiAdapter = netInterface{
		Index: 7, Type: ifTypeIEEE80211, Medium: mediumNative80211, Description: "Intel(R) Wi-Fi 6 AX201 160MHz",
		Up: true, HasDefaultRoute: true, Metric: 55, Level: levelInternetAccess, Cost: costUnrestricted,
	}
	ethernetAdapter = netInterface{
		Index: 4, Type: ifTypeEthernet, Medium: mediumUnspecified, Description: "Realtek PCIe GbE Family Controller",
		Up: true, HasDefaultRoute: true, Metric: 35, Level: levelInternetAccess, Cost: costUnrestricted,
	}
	wwanAdapter = netInterface{
		Index: 12, Type: ifTypeWWANPP, Medium: mediumWirelessWAN, Description: "Generic Mobile Broadband Adapter",
		Up: true, HasDefaultRoute: true, Metric: 60, Level: levelInternetAccess, Cost: costUnrestricted,
	}
	// sing-tun creates the adapter with tunnel type "sing-tun", and wintun names
	// the device after it. auto_route gives it the best default route.
	wintunAdapter = netInterface{
		Index: 30, Type: ifTypePropVirtual, Medium: mediumUnspecified, Alias: "tun0", Description: "sing-tun Tunnel",
		Up: true, HasDefaultRoute: true, Metric: 1, Level: levelInternetAccess, Cost: costUnrestricted,
	}
)

func with(base netInterface, change func(*netInterface)) netInterface {
	change(&base)
	return base
}

// The mapping of tech.md 5.7: WWAN or a metered connection is cellular, the
// rest goes by the interface type.
func TestClassifyMapsInterfaceAndCost(t *testing.T) {
	cases := []struct {
		name  string
		iface netInterface
		want  autoswitch.NetType
	}{
		{"unrestricted wifi", wifiAdapter, autoswitch.NetWifi},
		{"unrestricted ethernet", ethernetAdapter, autoswitch.NetEthernet},
		{"wwan", wwanAdapter, autoswitch.NetCellular},
		{"wwan pp2", with(wwanAdapter, func(i *netInterface) { i.Type = ifTypeWWANPP2 }), autoswitch.NetCellular},
		{"wireless wan medium", with(wwanAdapter, func(i *netInterface) { i.Type = ifTypeOther }), autoswitch.NetCellular},
		{"metered wifi hotspot", with(wifiAdapter, func(i *netInterface) { i.Cost = costFixed }), autoswitch.NetCellular},
		{"variable cost wifi", with(wifiAdapter, func(i *netInterface) { i.Cost = costVariable }), autoswitch.NetCellular},
		{"roaming wifi", with(wifiAdapter, func(i *netInterface) { i.Roaming = true }), autoswitch.NetCellular},
		{"metered usb tethering", with(ethernetAdapter, func(i *netInterface) { i.Cost = costFixed }), autoswitch.NetCellular},
		{"roaming ethernet", with(ethernetAdapter, func(i *netInterface) { i.Roaming = true }), autoswitch.NetCellular},
		{"unknown cost wifi", with(wifiAdapter, func(i *netInterface) { i.Cost = costUnknown }), autoswitch.NetWifi},
		{"unknown cost ethernet", with(ethernetAdapter, func(i *netInterface) { i.Cost = costUnknown }), autoswitch.NetEthernet},
		{"wifi with local access only", with(wifiAdapter, func(i *netInterface) { i.Level = levelLocalAccess }), autoswitch.NetWifi},
		{"no connectivity", with(wifiAdapter, func(i *netInterface) { i.Level = levelNone }), autoswitch.NetNone},
		{"metered without connectivity", with(wwanAdapter, func(i *netInterface) { i.Level = levelNone }), autoswitch.NetNone},
		{"ppp", with(ethernetAdapter, func(i *netInterface) { i.Type = ifTypePPP }), autoswitch.NetOther},
		{"tunnel", with(ethernetAdapter, func(i *netInterface) { i.Type = ifTypeTunnel }), autoswitch.NetOther},
		{"other vpn adapter", with(ethernetAdapter, func(i *netInterface) { i.Type = ifTypePropVirtual }), autoswitch.NetOther},
		{"metered unknown type", with(ethernetAdapter, func(i *netInterface) { i.Type = ifTypeTunnel; i.Cost = costVariable }), autoswitch.NetCellular},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			require.Equal(t, tc.want, classify(tc.iface))
		})
	}
}

func TestActiveNetworkPicksTheBestDefaultRoute(t *testing.T) {
	down := func(i *netInterface) { i.Up = false }
	noRoute := func(i *netInterface) { i.HasDefaultRoute = false }
	cases := []struct {
		name   string
		ifaces []netInterface
		want   autoswitch.NetType
	}{
		{"nothing", nil, autoswitch.NetNone},
		{"only wifi", []netInterface{wifiAdapter}, autoswitch.NetWifi},
		{"lower metric wins", []netInterface{wifiAdapter, ethernetAdapter}, autoswitch.NetEthernet},
		{"order does not matter", []netInterface{ethernetAdapter, wifiAdapter}, autoswitch.NetEthernet},
		{"wintun with the default route", []netInterface{wintunAdapter, wifiAdapter}, autoswitch.NetWifi},
		{"wintun over a metered hotspot", []netInterface{wintunAdapter, with(wifiAdapter, func(i *netInterface) { i.Cost = costFixed })}, autoswitch.NetCellular},
		{"wintun over wwan", []netInterface{wwanAdapter, wintunAdapter}, autoswitch.NetCellular},
		{"only wintun", []netInterface{wintunAdapter}, autoswitch.NetNone},
		{"wintun by the old driver name", []netInterface{with(wintunAdapter, func(i *netInterface) { i.Description = "Wintun Userspace Tunnel" }), wifiAdapter}, autoswitch.NetWifi},
		{"wintun by the alias", []netInterface{with(wintunAdapter, func(i *netInterface) { i.Description = "x"; i.Alias = "sing-tun" }), wifiAdapter}, autoswitch.NetWifi},
		{"interface that is down", []netInterface{with(ethernetAdapter, down), wifiAdapter}, autoswitch.NetWifi},
		{"interface without a default route", []netInterface{with(ethernetAdapter, noRoute), wifiAdapter}, autoswitch.NetWifi},
		{"all down", []netInterface{with(ethernetAdapter, down), with(wifiAdapter, noRoute)}, autoswitch.NetNone},
		{"equal metric goes to the lower index", []netInterface{with(wifiAdapter, func(i *netInterface) { i.Metric = 35 }), ethernetAdapter}, autoswitch.NetEthernet},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			require.Equal(t, tc.want, activeNetwork(tc.ifaces))
		})
	}
}

// The wintun adapter never decides the network, wherever it sits.
func TestActiveNetworkNeverDependsOnWintun(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		ifaces := rapid.SliceOfN(interfaceGen(), 0, 5).Draw(t, "interfaces")
		tun := with(wintunAdapter, func(i *netInterface) {
			i.Metric = rapid.Uint32().Draw(t, "tunMetric")
			i.Cost = connectivityCost(rapid.IntRange(0, 3).Draw(t, "tunCost"))
		})
		at := rapid.IntRange(0, len(ifaces)).Draw(t, "position")
		withTun := append(append(append([]netInterface{}, ifaces[:at]...), tun), ifaces[at:]...)
		require.Equal(t, activeNetwork(ifaces), activeNetwork(withTun))
	})
}

func interfaceGen() *rapid.Generator[netInterface] {
	return rapid.Custom(func(t *rapid.T) netInterface {
		return netInterface{
			Index:           rapid.Uint32Range(1, 64).Draw(t, "index"),
			Type:            rapid.SampledFrom([]uint32{ifTypeEthernet, ifTypeIEEE80211, ifTypeWWANPP, ifTypePPP, ifTypeOther}).Draw(t, "type"),
			Up:              rapid.Bool().Draw(t, "up"),
			HasDefaultRoute: rapid.Bool().Draw(t, "route"),
			Metric:          rapid.Uint32Range(0, 100).Draw(t, "metric"),
			Level:           connectivityLevel(rapid.IntRange(0, 5).Draw(t, "level")),
			Cost:            connectivityCost(rapid.IntRange(0, 3).Draw(t, "cost")),
			Roaming:         rapid.Bool().Draw(t, "roaming"),
		}
	})
}

// fakeClock runs the debounce timers only when a test advances it.
type fakeClock struct {
	mu     sync.Mutex
	now    time.Duration
	timers []*fakeTimer
}

type fakeTimer struct {
	at      time.Duration
	fire    func()
	stopped bool
}

func (c *fakeClock) afterFunc(delay time.Duration, fire func()) func() bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	timer := &fakeTimer{at: c.now + delay, fire: fire}
	c.timers = append(c.timers, timer)
	return func() bool {
		c.mu.Lock()
		defer c.mu.Unlock()
		wasPending := !timer.stopped
		timer.stopped = true
		return wasPending
	}
}

func (c *fakeClock) advance(by time.Duration) {
	c.mu.Lock()
	target := c.now + by
	c.mu.Unlock()
	for {
		c.mu.Lock()
		sort.SliceStable(c.timers, func(i, j int) bool { return c.timers[i].at < c.timers[j].at })
		var next *fakeTimer
		for _, timer := range c.timers {
			if !timer.stopped && timer.at <= target {
				next = timer
				break
			}
		}
		if next == nil {
			c.now = target
			c.mu.Unlock()
			return
		}
		next.stopped = true
		c.now = next.at
		c.mu.Unlock()
		next.fire()
	}
}

type delivery struct {
	at  time.Duration
	net autoswitch.NetType
}

func newTestWatch() (*netWatch, *fakeClock, *[]delivery) {
	clock := &fakeClock{}
	var delivered []delivery
	watch := newNetWatch(netDebounce, clock.afterFunc, func(net autoswitch.NetType) {
		delivered = append(delivered, delivery{at: clock.now, net: net})
	})
	return watch, clock, &delivered
}

func nets(deliveries []delivery) []autoswitch.NetType {
	out := make([]autoswitch.NetType, 0, len(deliveries))
	for _, d := range deliveries {
		out = append(out, d.net)
	}
	return out
}

func TestNetDebounceIsOneSecond(t *testing.T) {
	require.Equal(t, time.Second, netDebounce)
}

// The first detection is the starting point, not a change, so it does not wait.
func TestNetWatchKnowsTheFirstNetworkAtOnce(t *testing.T) {
	watch, _, delivered := newTestWatch()

	watch.Observe(autoswitch.NetWifi)

	require.Equal(t, []delivery{{at: 0, net: autoswitch.NetWifi}}, *delivered)
}

func TestNetWatchDeliversAChangeAfterOneQuietSecond(t *testing.T) {
	watch, clock, delivered := newTestWatch()
	watch.Observe(autoswitch.NetWifi)

	watch.Observe(autoswitch.NetCellular)
	clock.advance(999 * time.Millisecond)
	require.Equal(t, []autoswitch.NetType{autoswitch.NetWifi}, nets(*delivered))

	clock.advance(time.Millisecond)
	require.Equal(t, []delivery{{0, autoswitch.NetWifi}, {time.Second, autoswitch.NetCellular}}, *delivered)
}

func TestNetWatchDeliversTheLastValueOfABurst(t *testing.T) {
	watch, clock, delivered := newTestWatch()
	watch.Observe(autoswitch.NetWifi)

	watch.Observe(autoswitch.NetNone)
	clock.advance(400 * time.Millisecond)
	watch.Observe(autoswitch.NetEthernet)
	clock.advance(400 * time.Millisecond)
	watch.Observe(autoswitch.NetCellular)
	clock.advance(999 * time.Millisecond)
	require.Equal(t, []autoswitch.NetType{autoswitch.NetWifi}, nets(*delivered))

	clock.advance(time.Millisecond)
	require.Equal(t, []delivery{{0, autoswitch.NetWifi}, {1800 * time.Millisecond, autoswitch.NetCellular}}, *delivered)
}

// A Wi-Fi reconnect that ends on the same network is not a change.
func TestNetWatchIgnoresABurstThatReturns(t *testing.T) {
	watch, clock, delivered := newTestWatch()
	watch.Observe(autoswitch.NetWifi)

	watch.Observe(autoswitch.NetNone)
	clock.advance(300 * time.Millisecond)
	watch.Observe(autoswitch.NetWifi)
	clock.advance(5 * time.Second)

	require.Equal(t, []autoswitch.NetType{autoswitch.NetWifi}, nets(*delivered))
}

func TestNetWatchResendRepeatsTheCurrentNetwork(t *testing.T) {
	watch, clock, delivered := newTestWatch()
	watch.Resend()
	require.Empty(t, *delivered, "nothing is known yet")

	watch.Observe(autoswitch.NetEthernet)
	watch.Observe(autoswitch.NetCellular)
	watch.Resend()
	require.Equal(t, []autoswitch.NetType{autoswitch.NetEthernet, autoswitch.NetEthernet}, nets(*delivered),
		"a pending change is not settled yet")

	clock.advance(time.Second)
	watch.Resend()
	require.Equal(t, []autoswitch.NetType{
		autoswitch.NetEthernet, autoswitch.NetEthernet, autoswitch.NetCellular, autoswitch.NetCellular,
	}, nets(*delivered))
}

func TestNetWatchStopsAfterClose(t *testing.T) {
	watch, clock, delivered := newTestWatch()
	watch.Observe(autoswitch.NetWifi)
	watch.Observe(autoswitch.NetCellular)

	watch.Close()
	clock.advance(5 * time.Second)
	watch.Observe(autoswitch.NetEthernet)
	watch.Resend()
	clock.advance(5 * time.Second)

	require.Equal(t, []autoswitch.NetType{autoswitch.NetWifi}, nets(*delivered))
}

// Against a model: a change lands exactly one quiet second after the last
// observation, carries its value, and never repeats the previous delivery.
func TestNetWatchDebounceProperties(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		watch, clock, delivered := newTestWatch()
		netGen := rapid.SampledFrom([]autoswitch.NetType{
			autoswitch.NetWifi, autoswitch.NetCellular, autoswitch.NetEthernet, autoswitch.NetOther, autoswitch.NetNone,
		})

		var lastObserved autoswitch.NetType
		var lastObservedAt time.Duration
		observed := false
		steps := rapid.IntRange(1, 40).Draw(t, "steps")
		for range steps {
			if rapid.Bool().Draw(t, "observe") {
				lastObserved = netGen.Draw(t, "net")
				lastObservedAt = clock.now
				observed = true
				watch.Observe(lastObserved)
				continue
			}
			before := len(*delivered)
			clock.advance(time.Duration(rapid.IntRange(1, 1500).Draw(t, "ms")) * time.Millisecond)
			for _, d := range (*delivered)[before:] {
				require.Equal(t, lastObserved, d.net, "a delivery carries the last observation")
				require.Equal(t, lastObservedAt+netDebounce, d.at, "a delivery comes one quiet second after it")
			}
		}
		clock.advance(netDebounce)

		for i := 1; i < len(*delivered); i++ {
			require.NotEqual(t, (*delivered)[i-1].net, (*delivered)[i].net, "no delivery repeats the previous one")
		}
		if observed {
			require.Equal(t, lastObserved, (*delivered)[len(*delivered)-1].net, "the watch settles on the last observation")
		}
	})
}

// A timer can fire after its stop came too late. The stale fire must not
// deliver the newer detection early.
func TestNetWatchIgnoresAStaleTimer(t *testing.T) {
	clock := &fakeClock{}
	var delivered []delivery
	lateStop := func(delay time.Duration, fire func()) func() bool {
		clock.afterFunc(delay, fire)
		return func() bool { return false }
	}
	watch := newNetWatch(netDebounce, lateStop, func(net autoswitch.NetType) {
		delivered = append(delivered, delivery{at: clock.now, net: net})
	})
	watch.Observe(autoswitch.NetWifi)

	watch.Observe(autoswitch.NetCellular)
	clock.advance(500 * time.Millisecond)
	watch.Observe(autoswitch.NetEthernet)
	clock.advance(2 * time.Second)

	require.Equal(t, []delivery{{0, autoswitch.NetWifi}, {1500 * time.Millisecond, autoswitch.NetEthernet}}, delivered)
}

// A burst of route changes keeps one timer, not one per change.
func TestNetWatchKeepsOneTimer(t *testing.T) {
	watch, clock, _ := newTestWatch()
	watch.Observe(autoswitch.NetWifi)
	for range 10 {
		watch.Observe(autoswitch.NetCellular)
	}

	pending := 0
	for _, timer := range clock.timers {
		if !timer.stopped {
			pending++
		}
	}
	require.Equal(t, 1, pending)
}
