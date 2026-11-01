package ipc

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/require"

	"github.com/Evgenius09/vpn-project/core/internal/contract"
	"github.com/Evgenius09/vpn-project/core/internal/runtime"
)

const eventTimeout = 5 * time.Second

type fakeBackend struct {
	mu       sync.Mutex
	state    string
	started  []string
	stopped  int
	startErr error
}

func (b *fakeBackend) Start(request string) error {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.started = append(b.started, request)
	return b.startErr
}

func (b *fakeBackend) Stop() error {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.stopped++
	return nil
}

func (b *fakeBackend) State() string { return b.state }

func fixture(t *testing.T, name string) string {
	t.Helper()
	raw, err := os.ReadFile(filepath.Join("../../../contracts/fixtures/core_event", name))
	require.NoError(t, err)
	return string(raw)
}

type client struct {
	t      *testing.T
	conn   net.Conn
	reader *bufio.Reader
}

func connect(t *testing.T, server *Server) *client {
	t.Helper()
	near, far := net.Pipe()
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		defer close(done)
		_ = server.Serve(ctx, far)
	}()
	t.Cleanup(func() {
		cancel()
		_ = near.Close()
		<-done
	})
	return &client{t: t, conn: near, reader: bufio.NewReader(near)}
}

func (c *client) send(line string) {
	c.t.Helper()
	require.NoError(c.t, c.conn.SetWriteDeadline(time.Now().Add(eventTimeout)))
	_, err := io.WriteString(c.conn, line+"\n")
	require.NoError(c.t, err)
}

func (c *client) receive() string {
	c.t.Helper()
	require.NoError(c.t, c.conn.SetReadDeadline(time.Now().Add(eventTimeout)))
	line, err := c.reader.ReadString('\n')
	require.NoError(c.t, err)
	return strings.TrimSpace(line)
}

func (c *client) hello() {
	c.t.Helper()
	c.send(`{"jsonrpc":"2.0","id":100,"method":"hello","params":{"protocolVersion":1,"appVersion":"0.1.0"}}`)
	c.receive()
}

func newServer(backend Backend, hub *Hub) *Server {
	return NewServer(backend, hub, "0.1.0", slog.New(slog.DiscardHandler))
}

// Replays every recorded session, the contract both sides share (tech.md 10).
func TestRecordedSessions(t *testing.T) {
	for _, path := range sessions(t) {
		t.Run(filepath.Base(path), func(t *testing.T) {
			hub := NewHub()
			backend := &fakeBackend{state: fixture(t, "state_disconnected.json")}
			c := connect(t, newServer(backend, hub))

			var compact struct {
				Dir string          `json:"dir"`
				Msg json.RawMessage `json:"msg"`
			}
			raw, err := os.ReadFile(path)
			require.NoError(t, err)
			for _, line := range strings.Split(strings.TrimSpace(string(raw)), "\n") {
				require.NoError(t, json.Unmarshal([]byte(line), &compact))
				if compact.Dir == "send" {
					c.send(string(compact.Msg))
					continue
				}
				var notification Message
				require.NoError(t, json.Unmarshal(compact.Msg, &notification))
				if notification.Method == MethodEvent {
					hub.Publish(string(notification.Params))
				}
				require.JSONEq(t, string(compact.Msg), c.receive())
			}
		})
	}
}

func TestMethodsBeforeHelloAreRefused(t *testing.T) {
	backend := &fakeBackend{}
	c := connect(t, newServer(backend, NewHub()))

	c.send(`{"jsonrpc":"2.0","id":1,"method":"start","params":{"tunnelRequest":{}}}`)

	var response Message
	require.NoError(t, json.Unmarshal([]byte(c.receive()), &response))
	require.Equal(t, CodeCoreError, response.Error.Code)
	require.Equal(t, contract.CoreErrorCodeIpcVersionMismatch, response.Error.Data.Code)
	require.Empty(t, backend.started)
}

func TestStartPassesTheRequestAndStopReaches(t *testing.T) {
	backend := &fakeBackend{}
	c := connect(t, newServer(backend, NewHub()))
	c.hello()

	c.send(`{"jsonrpc":"2.0","id":1,"method":"start","params":{"tunnelRequest":{"schemaVersion":1}}}`)
	require.JSONEq(t, `{"jsonrpc":"2.0","id":1,"result":{}}`, c.receive())
	require.Equal(t, []string{`{"schemaVersion":1}`}, backend.started)

	c.send(`{"jsonrpc":"2.0","id":2,"method":"stop","params":{}}`)
	require.JSONEq(t, `{"jsonrpc":"2.0","id":2,"result":{}}`, c.receive())
	require.Equal(t, 1, backend.stopped)
}

func TestCoreErrorsKeepTheirCode(t *testing.T) {
	backend := &fakeBackend{startErr: &runtime.Error{Code: contract.CoreErrorCodeStartFailed, Message: "busy"}}
	c := connect(t, newServer(backend, NewHub()))
	c.hello()

	c.send(`{"jsonrpc":"2.0","id":1,"method":"start","params":{"tunnelRequest":{}}}`)
	require.JSONEq(t,
		`{"jsonrpc":"2.0","id":1,"error":{"code":-32000,"message":"busy","data":{"code":"start_failed"}}}`,
		c.receive())
}

func TestOtherErrorsHideTheirDetails(t *testing.T) {
	backend := &fakeBackend{startErr: errors.New("secret path C:\\ProgramData")}
	c := connect(t, newServer(backend, NewHub()))
	c.hello()

	c.send(`{"jsonrpc":"2.0","id":1,"method":"start","params":{"tunnelRequest":{}}}`)
	response := c.receive()
	require.Contains(t, response, `"code":"internal"`)
	require.NotContains(t, response, "ProgramData")
}

func TestPrepareGrants(t *testing.T) {
	c := connect(t, newServer(&fakeBackend{}, NewHub()))
	c.hello()
	c.send(`{"jsonrpc":"2.0","id":1,"method":"prepare","params":{}}`)
	require.JSONEq(t, `{"jsonrpc":"2.0","id":1,"result":{"result":"granted"}}`, c.receive())
}

func TestTwoClientsSeeTheSameEvents(t *testing.T) {
	hub := NewHub()
	server := newServer(&fakeBackend{}, hub)
	first, second := connect(t, server), connect(t, server)
	for id, c := range []*client{first, second} {
		c.hello()
		c.send(fmt.Sprintf(`{"jsonrpc":"2.0","id":%d,"method":"subscribe","params":{}}`, id))
		c.receive()
	}

	event := fixture(t, "traffic.json")
	hub.Publish(event)

	want := fmt.Sprintf(`{"jsonrpc":"2.0","method":"event","params":%s}`, event)
	require.JSONEq(t, want, first.receive())
	require.JSONEq(t, want, second.receive())
}

func TestNoEventsWithoutSubscribe(t *testing.T) {
	hub := NewHub()
	c := connect(t, newServer(&fakeBackend{state: `{}`}, hub))
	c.hello()

	hub.Publish(`{"type":"state"}`)
	c.send(`{"jsonrpc":"2.0","id":1,"method":"getState","params":{}}`)
	require.JSONEq(t, `{"jsonrpc":"2.0","id":1,"result":{}}`, c.receive())
}

func TestPublishNeverBlocksOnASlowClient(t *testing.T) {
	hub := NewHub()
	hub.subscribe()

	done := make(chan struct{})
	go func() {
		defer close(done)
		for range pendingEvents * 2 {
			hub.Publish("event")
		}
	}()
	select {
	case <-done:
	case <-time.After(eventTimeout):
		t.Fatal("Publish blocked")
	}
}

func TestOversizedMessageClosesTheConnection(t *testing.T) {
	near, far := net.Pipe()
	result := make(chan error, 1)
	go func() {
		result <- newServer(&fakeBackend{}, NewHub()).Serve(context.Background(), far)
	}()
	go func() {
		_, _ = near.Write([]byte(strings.Repeat("x", MaxMessageBytes+1)))
	}()

	select {
	case err := <-result:
		require.ErrorIs(t, err, bufio.ErrTooLong)
	case <-time.After(eventTimeout):
		t.Fatal("the server kept reading")
	}
	require.NoError(t, near.Close())
}

func TestContextEndClosesTheConnection(t *testing.T) {
	near, far := net.Pipe()
	ctx, cancel := context.WithCancel(context.Background())
	result := make(chan error, 1)
	go func() { result <- newServer(&fakeBackend{}, NewHub()).Serve(ctx, far) }()

	cancel()
	select {
	case err := <-result:
		require.NoError(t, err)
	case <-time.After(eventTimeout):
		t.Fatal("Serve did not stop")
	}
	require.NoError(t, near.Close())
}
