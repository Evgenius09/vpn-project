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
	mu        sync.Mutex
	state     string
	started   []string
	updated   []string
	modes     []string
	selected  [][2]string
	tested    [][]string
	synced    []contract.RuleSetRef
	stopped   int
	startErr  error
	failure   error
	urlTest   string
	ready     []string
	processes []ProcessInfo
}

func (b *fakeBackend) Update(request string) error {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.updated = append(b.updated, request)
	return b.failure
}

func (b *fakeBackend) SetUserMode(mode string) error {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.modes = append(b.modes, mode)
	return b.failure
}

func (b *fakeBackend) SelectServer(group, serverID string) error {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.selected = append(b.selected, [2]string{group, serverID})
	return b.failure
}

func (b *fakeBackend) URLTest(serverIDs []string) (string, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.tested = append(b.tested, serverIDs)
	return b.urlTest, b.failure
}

func (b *fakeBackend) SyncRuleSets(_ context.Context, ruleSets []contract.RuleSetRef) []string {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.synced = append(b.synced, ruleSets...)
	return b.ready
}

func (b *fakeBackend) ListProcesses() ([]ProcessInfo, error) {
	return b.processes, b.failure
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
			backend := &fakeBackend{
				state:     fixture(t, "state_disconnected.json"),
				urlTest:   fixture(t, "url_test.json"),
				ready:     []string{"ru-direct"},
				processes: []ProcessInfo{{Name: "steam.exe", Path: `C:\Games\steam.exe`}},
			}
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

func call(t *testing.T, backend Backend, method, params string) string {
	t.Helper()
	c := connect(t, newServer(backend, NewHub()))
	c.hello()
	c.send(`{"jsonrpc":"2.0","id":1,"method":"` + method + `","params":` + params + `}`)
	return c.receive()
}

func TestUpdateReachesTheBackendAsSent(t *testing.T) {
	backend := &fakeBackend{}
	response := call(t, backend, MethodUpdate, `{"tunnelRequest":{"schemaVersion":1}}`)
	require.JSONEq(t, `{"jsonrpc":"2.0","id":1,"result":{}}`, response)
	require.Equal(t, []string{`{"schemaVersion":1}`}, backend.updated)
}

func TestSetUserModeReachesTheBackend(t *testing.T) {
	backend := &fakeBackend{}
	call(t, backend, MethodSetUserMode, `{"mode":"whitelist"}`)
	require.Equal(t, []string{"whitelist"}, backend.modes)
}

func TestSelectServerReachesTheBackend(t *testing.T) {
	backend := &fakeBackend{}
	call(t, backend, MethodSelectServer, `{"group":"regular","serverId":"s1"}`)
	require.Equal(t, [][2]string{{"regular", "s1"}}, backend.selected)
}

func TestURLTestReturnsTheEventAsResult(t *testing.T) {
	event := fixture(t, "url_test.json")
	backend := &fakeBackend{urlTest: event}
	response := call(t, backend, MethodURLTest, `{"serverIds":["s1","s2"]}`)

	var message Message
	require.NoError(t, json.Unmarshal([]byte(response), &message))
	require.JSONEq(t, event, string(message.Result))
	require.Equal(t, [][]string{{"s1", "s2"}}, backend.tested)
}

func TestSyncRuleSetsReportsWhatIsReady(t *testing.T) {
	backend := &fakeBackend{ready: []string{"ads"}}
	response := call(t, backend, MethodSyncRuleSets,
		`{"ruleSets":[{"id":"ads","url":"https://a/ads.srs","sha256":"aa"},{"id":"ru","url":"https://a/ru.srs","sha256":"bb"}]}`)

	require.JSONEq(t, `{"jsonrpc":"2.0","id":1,"result":{"ready":["ads"]}}`, response)
	require.Len(t, backend.synced, 2)
}

func TestNoReadyRuleSetIsAnEmptyList(t *testing.T) {
	response := call(t, &fakeBackend{}, MethodSyncRuleSets, `{"ruleSets":[]}`)
	require.JSONEq(t, `{"jsonrpc":"2.0","id":1,"result":{"ready":[]}}`, response,
		"the app reads ready as a list, never null")
}

func TestListProcessesReturnsAnArray(t *testing.T) {
	backend := &fakeBackend{processes: []ProcessInfo{{Name: "a.exe", Path: `C:\a.exe`}}}
	response := call(t, backend, MethodListProcesses, `{}`)
	require.JSONEq(t, `{"jsonrpc":"2.0","id":1,"result":[{"name":"a.exe","path":"C:\\a.exe"}]}`, response)
}

func TestNoProcessesIsAnEmptyList(t *testing.T) {
	response := call(t, &fakeBackend{}, MethodListProcesses, `{}`)
	require.JSONEq(t, `{"jsonrpc":"2.0","id":1,"result":[]}`, response)
}

func TestEveryNewMethodKeepsTheCoreErrorCode(t *testing.T) {
	failure := &runtime.Error{Code: contract.CoreErrorCodeNoServersInGroup, Message: "empty"}
	calls := map[string]string{
		MethodUpdate:        `{"tunnelRequest":{}}`,
		MethodSetUserMode:   `{"mode":"regular"}`,
		MethodSelectServer:  `{"group":"regular","serverId":"s"}`,
		MethodURLTest:       `{"serverIds":[]}`,
		MethodListProcesses: `{}`,
	}
	for method, params := range calls {
		t.Run(method, func(t *testing.T) {
			response := call(t, &fakeBackend{failure: failure}, method, params)
			var message Message
			require.NoError(t, json.Unmarshal([]byte(response), &message))
			require.Equal(t, CodeCoreError, message.Error.Code)
			require.Equal(t, contract.CoreErrorCodeNoServersInGroup, message.Error.Data.Code)
		})
	}
}

func TestMalformedParamsNeverQuoteTheirContent(t *testing.T) {
	const secret = "visible-secret-value"
	for _, method := range []string{MethodUpdate, MethodSetUserMode, MethodSelectServer, MethodURLTest, MethodSyncRuleSets} {
		t.Run(method, func(t *testing.T) {
			response := call(t, &fakeBackend{}, method, `"`+secret+`"`)
			var message Message
			require.NoError(t, json.Unmarshal([]byte(response), &message))
			require.Equal(t, contract.CoreErrorCodeConfigInvalid, message.Error.Data.Code)
			require.NotContains(t, response, secret)
		})
	}
}

func TestEveryProtocolMethodIsImplemented(t *testing.T) {
	for _, method := range Methods {
		if method == MethodHello {
			continue
		}
		t.Run(method, func(t *testing.T) {
			response := call(t, &fakeBackend{state: `{}`, urlTest: `{}`}, method, `{}`)
			var message Message
			require.NoError(t, json.Unmarshal([]byte(response), &message))
			if message.Error != nil {
				require.NotEqual(t, CodeMethodNotFound, message.Error.Code)
			}
		})
	}
}
