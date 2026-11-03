//go:build windows

package main

import (
	"log/slog"
	"testing"
	"time"
	"unsafe"

	"github.com/stretchr/testify/require"

	"github.com/Evgenius09/vpn-project/core/internal/autoswitch"
)

// NL_NETWORK_CONNECTIVITY_HINT is two enums and three BOOLEANs, padded.
func TestConnectivityHintLayout(t *testing.T) {
	require.Equal(t, uintptr(12), unsafe.Sizeof(connectivityHint{}))
}

// The runner reaches the internet, so it has an interface with a default route.
func TestListInterfacesFindsTheDefaultRoute(t *testing.T) {
	ifaces, err := listInterfaces()
	require.NoError(t, err)

	found := false
	for _, iface := range ifaces {
		t.Logf("%+v", iface)
		require.True(t, iface.HasDefaultRoute, "only interfaces with a default route are listed")
		if iface.Up {
			found = true
		}
	}
	require.True(t, found, "no interface with a default route is up")
}

func TestDetectNetworkOnThisMachine(t *testing.T) {
	net, err := detectNetwork()
	require.NoError(t, err)

	t.Logf("network type: %s", net)
	require.True(t, net.Valid())
	require.NotEqual(t, autoswitch.NetNone, net, "the runner has a network")
}

func TestWatchNetworkReportsAtOnceAndStops(t *testing.T) {
	observed := make(chan autoswitch.NetType, 16)
	stop, err := watchNetwork(slog.New(slog.DiscardHandler))(func(net autoswitch.NetType) { observed <- net })
	require.NoError(t, err)

	select {
	case net := <-observed:
		require.True(t, net.Valid())
	default:
		t.Fatal("the first detection did not arrive before watchNetwork returned")
	}

	stopped := make(chan struct{})
	go func() {
		stop()
		close(stopped)
	}()
	select {
	case <-stopped:
	case <-time.After(10 * time.Second):
		t.Fatal("stop did not return")
	}
}
