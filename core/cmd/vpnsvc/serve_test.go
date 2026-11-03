package main

import (
	"bufio"
	"context"
	"fmt"
	"log/slog"
	"net"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/sagernet/sing-box/option"
	"github.com/stretchr/testify/require"

	"github.com/Evgenius09/vpn-project/core/internal/ipc"
)

// stubEngine replaces the box, whose TUN needs administrator rights. The
// windows job of app-platforms runs the real one through the installed service.
type stubEngine struct{}

func (stubEngine) Start(option.Options) error { return nil }

func (stubEngine) Close() error { return nil }

func (stubEngine) Select(string, string) error { return nil }

func (stubEngine) Traffic() (up, down int64, ok bool) { return 0, 0, true }

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
