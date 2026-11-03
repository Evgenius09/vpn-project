package main

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/sagernet/sing-box/option"
	"github.com/stretchr/testify/require"

	"github.com/Evgenius09/vpn-project/core/internal/autoswitch"
	"github.com/Evgenius09/vpn-project/core/internal/ipc"
	"github.com/Evgenius09/vpn-project/core/internal/runtime"
)

// stubEngine replaces the box, whose TUN needs administrator rights. The
// windows job of app-platforms runs the real one through the installed service.
type stubEngine struct{}

func (stubEngine) Start(option.Options) error { return nil }

func (stubEngine) Close() error { return nil }

func (stubEngine) Select(string, string) error { return nil }

func (stubEngine) Traffic() (up, down int64, ok bool) { return 0, 0, true }

func (stubEngine) URLTest(context.Context, string, string) (uint16, error) { return 12, nil }

const hello = `{"jsonrpc":"2.0","id":1,"method":"hello","params":{"protocolVersion":1,"appVersion":"0.1.0"}}`

func call(t *testing.T, conn net.Conn, reader *bufio.Reader, line string) string {
	t.Helper()
	require.NoError(t, conn.SetDeadline(time.Now().Add(10*time.Second)))
	_, err := fmt.Fprintln(conn, line)
	require.NoError(t, err)
	response, err := reader.ReadString('\n')
	require.NoError(t, err)
	return response
}

func TestServeRunsTheTunnelOverASocket(t *testing.T) {
	raw, err := os.ReadFile("../../../contracts/fixtures/tunnel_request/windows_custom.json")
	require.NoError(t, err)

	listener, err := net.Listen("tcp", "127.0.0.1:0")
	require.NoError(t, err)

	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan error, 1)
	go func() { done <- serve(ctx, listener, stubEngine{}, testHost(t), slog.New(slog.DiscardHandler)) }()

	conn, err := net.Dial("tcp", listener.Addr().String())
	require.NoError(t, err)
	reader := bufio.NewReader(conn)

	require.Contains(t, call(t, conn, reader, hello), `"serviceVersion"`)

	start := fmt.Sprintf(`{"jsonrpc":"2.0","id":2,"method":"start","params":{"tunnelRequest":%s}}`, compact(t, raw))
	require.Contains(t, call(t, conn, reader, start), `"result":{}`)

	state := `{"jsonrpc":"2.0","id":3,"method":"getState","params":{}}`
	require.Contains(t, call(t, conn, reader, state), `"status":"connected"`)

	urlTest := `{"jsonrpc":"2.0","id":4,"method":"urlTest","params":{"serverIds":["11111111-1111-4111-8111-111111111111"]}}`
	require.Contains(t, call(t, conn, reader, urlTest),
		`"results":[{"delayMs":12,"serverId":"11111111-1111-4111-8111-111111111111"}]`)

	cancel()
	require.NoError(t, conn.Close())
	select {
	case err := <-done:
		require.NoError(t, err)
	case <-time.After(10 * time.Second):
		t.Fatal("serve did not stop")
	}
}

func compact(t *testing.T, raw []byte) string {
	t.Helper()
	out := make([]byte, 0, len(raw))
	for _, b := range raw {
		if b != '\n' && b != '\r' {
			out = append(out, b)
		}
	}
	return string(out)
}

func testHost(t *testing.T) hostOptions {
	t.Helper()
	return hostOptions{
		DataDir:       t.TempDir(),
		Protect:       func(string) error { return nil },
		ListProcesses: func() ([]ipc.ProcessInfo, error) { return nil, nil },
	}
}

func TestServeKeepsTheAcceptedRequest(t *testing.T) {
	raw, err := os.ReadFile("../../../contracts/fixtures/tunnel_request/windows_custom.json")
	require.NoError(t, err)
	host := testHost(t)

	listener, err := net.Listen("tcp", "127.0.0.1:0")
	require.NoError(t, err)
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan error, 1)
	go func() { done <- serve(ctx, listener, stubEngine{}, host, slog.New(slog.DiscardHandler)) }()

	conn, err := net.Dial("tcp", listener.Addr().String())
	require.NoError(t, err)
	reader := bufio.NewReader(conn)
	call(t, conn, reader, hello)
	start := fmt.Sprintf(`{"jsonrpc":"2.0","id":2,"method":"start","params":{"tunnelRequest":%s}}`, compact(t, raw))
	require.Contains(t, call(t, conn, reader, start), `"result":{}`)

	stored, err := os.ReadFile(filepath.Join(host.DataDir, lastRequestFile))
	require.NoError(t, err)
	require.JSONEq(t, string(raw), string(stored))

	cancel()
	require.NoError(t, conn.Close())
	require.NoError(t, <-done)
}

func effectiveMode(t *testing.T, state string) string {
	t.Helper()
	var event struct {
		State struct {
			EffectiveMode string `json:"effectiveMode"`
		} `json:"state"`
	}
	require.NoError(t, json.Unmarshal([]byte(state), &event))
	return event.State.EffectiveMode
}

// The fixture asks for the regular mode with the auto switch on, so only the
// reported network can move the tunnel to whitelist.
func TestServeReportsTheNetworkRightAfterStart(t *testing.T) {
	raw, err := os.ReadFile("../../../contracts/fixtures/tunnel_request/windows_custom.json")
	require.NoError(t, err)
	host := testHost(t)
	stopped := make(chan struct{})
	host.WatchNetwork = func(observe func(autoswitch.NetType)) (func(), error) {
		observe(autoswitch.NetCellular)
		return func() { close(stopped) }, nil
	}

	listener, err := net.Listen("tcp", "127.0.0.1:0")
	require.NoError(t, err)
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan error, 1)
	go func() { done <- serve(ctx, listener, stubEngine{}, host, slog.New(slog.DiscardHandler)) }()

	conn, err := net.Dial("tcp", listener.Addr().String())
	require.NoError(t, err)
	reader := bufio.NewReader(conn)
	call(t, conn, reader, hello)
	start := fmt.Sprintf(`{"jsonrpc":"2.0","id":2,"method":"start","params":{"tunnelRequest":%s}}`, compact(t, raw))
	require.Contains(t, call(t, conn, reader, start), `"result":{}`)
	state := call(t, conn, reader, `{"jsonrpc":"2.0","id":3,"method":"getState","params":{}}`)
	require.Contains(t, state, `"effectiveMode":"whitelist"`)

	cancel()
	require.NoError(t, conn.Close())
	require.NoError(t, <-done)
	select {
	case <-stopped:
	default:
		t.Fatal("serve left the network watch running")
	}
}

// A failed watch leaves the tunnel working without the auto switch.
func TestServeRunsWithoutTheNetworkWatch(t *testing.T) {
	host := testHost(t)
	host.WatchNetwork = func(func(autoswitch.NetType)) (func(), error) { return nil, errors.New("no api") }

	listener, err := net.Listen("tcp", "127.0.0.1:0")
	require.NoError(t, err)
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan error, 1)
	go func() { done <- serve(ctx, listener, stubEngine{}, host, slog.New(slog.DiscardHandler)) }()

	conn, err := net.Dial("tcp", listener.Addr().String())
	require.NoError(t, err)
	require.Contains(t, call(t, conn, bufio.NewReader(conn), hello), `"serviceVersion"`)

	cancel()
	require.NoError(t, conn.Close())
	require.NoError(t, <-done)
}

func newWatchedBackend(t *testing.T) (*backend, *netWatch, *fakeClock) {
	t.Helper()
	tunnel := newBackend(runtime.New(runtime.Options{Engine: stubEngine{}, Sink: func(string) {}}), testHost(t),
		slog.New(slog.DiscardHandler))
	clock := &fakeClock{}
	watch := newNetWatch(netDebounce, clock.afterFunc, tunnel.reportNetwork)
	tunnel.network = watch
	return tunnel, watch, clock
}

func TestStartReportsTheNetworkKnownBefore(t *testing.T) {
	raw, err := os.ReadFile("../../../contracts/fixtures/tunnel_request/windows_custom.json")
	require.NoError(t, err)
	tunnel, watch, _ := newWatchedBackend(t)
	watch.Observe(autoswitch.NetCellular)

	require.NoError(t, tunnel.Start(string(raw)))

	require.Equal(t, "whitelist", effectiveMode(t, tunnel.State()))
}

func TestStartWithoutAKnownNetworkKeepsTheUserMode(t *testing.T) {
	raw, err := os.ReadFile("../../../contracts/fixtures/tunnel_request/windows_custom.json")
	require.NoError(t, err)
	tunnel, _, _ := newWatchedBackend(t)

	require.NoError(t, tunnel.Start(string(raw)))

	require.Equal(t, "regular", effectiveMode(t, tunnel.State()))
}

func TestNetworkChangeReachesTheConnectedTunnel(t *testing.T) {
	raw, err := os.ReadFile("../../../contracts/fixtures/tunnel_request/windows_custom.json")
	require.NoError(t, err)
	tunnel, watch, clock := newWatchedBackend(t)
	watch.Observe(autoswitch.NetWifi)
	require.NoError(t, tunnel.Start(string(raw)))

	watch.Observe(autoswitch.NetCellular)
	require.Equal(t, "regular", effectiveMode(t, tunnel.State()), "the change waits for the debounce")
	clock.advance(netDebounce)
	require.Equal(t, "whitelist", effectiveMode(t, tunnel.State()))

	watch.Observe(autoswitch.NetWifi)
	clock.advance(netDebounce)
	require.Equal(t, "regular", effectiveMode(t, tunnel.State()))
}
