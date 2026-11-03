package ipc

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"sync"

	"github.com/Evgenius09/vpn-project/core/internal/contract"
	"github.com/Evgenius09/vpn-project/core/internal/runtime"
)

const pendingEvents = 256

// Backend is the tunnel behind the server.
type Backend interface {
	Start(tunnelRequestJSON string) error
	Update(tunnelRequestJSON string) error
	Stop() error
	SetUserMode(mode string) error
	SelectServer(group, serverID string) error
	// URLTest returns a CoreEvent of type url_test as JSON.
	URLTest(serverIDs []string) (string, error)
	State() string
	// SyncRuleSets returns the identifiers of the rule sets that are ready.
	SyncRuleSets(ctx context.Context, ruleSets []contract.RuleSetRef) []string
	ListProcesses() ([]ProcessInfo, error)
}

// Hub fans core events out to every subscribed connection, so two UI copies
// see the same stream.
type Hub struct {
	mu          sync.Mutex
	subscribers map[chan string]struct{}
}

// NewHub returns an empty hub.
func NewHub() *Hub {
	return &Hub{subscribers: map[chan string]struct{}{}}
}

// Publish sends one CoreEvent JSON to every subscriber. A subscriber that
// stopped reading loses events instead of stalling the tunnel.
func (h *Hub) Publish(event string) {
	h.mu.Lock()
	defer h.mu.Unlock()
	for subscriber := range h.subscribers {
		select {
		case subscriber <- event:
		default:
		}
	}
}

func (h *Hub) subscribe() chan string {
	h.mu.Lock()
	defer h.mu.Unlock()
	subscriber := make(chan string, pendingEvents)
	h.subscribers[subscriber] = struct{}{}
	return subscriber
}

func (h *Hub) unsubscribe(subscriber chan string) {
	h.mu.Lock()
	defer h.mu.Unlock()
	delete(h.subscribers, subscriber)
}

// Server speaks IPC v1 on any byte stream.
type Server struct {
	backend        Backend
	hub            *Hub
	serviceVersion string
	logger         *slog.Logger
}

// NewServer returns a server.
func NewServer(backend Backend, hub *Hub, serviceVersion string, logger *slog.Logger) *Server {
	return &Server{backend: backend, hub: hub, serviceVersion: serviceVersion, logger: logger}
}

type connection struct {
	mu         sync.Mutex
	writer     io.Writer
	helloDone  bool
	subscribed chan string
	done       chan struct{}
}

func (c *connection) write(message Message) error {
	message.JSONRPC = JSONRPCVersion
	encoded, err := json.Marshal(message)
	if err != nil {
		return fmt.Errorf("encode message: %w", err)
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if _, err := c.writer.Write(append(encoded, '\n')); err != nil {
		return fmt.Errorf("write message: %w", err)
	}
	return nil
}

// Serve handles one connection until it closes or ctx ends.
func (s *Server) Serve(ctx context.Context, stream io.ReadWriteCloser) error {
	defer func() { _ = stream.Close() }()
	conn := &connection{writer: stream, done: make(chan struct{})}
	defer close(conn.done)

	stop := context.AfterFunc(ctx, func() { _ = stream.Close() })
	defer stop()

	scanner := bufio.NewScanner(stream)
	scanner.Buffer(make([]byte, 0, bufio.MaxScanTokenSize), MaxMessageBytes)
	for scanner.Scan() {
		var request Message
		if err := json.Unmarshal(scanner.Bytes(), &request); err != nil {
			return fmt.Errorf("decode message: %w", err)
		}
		if err := s.handle(ctx, conn, request); err != nil {
			return err
		}
	}
	if conn.subscribed != nil {
		s.hub.unsubscribe(conn.subscribed)
	}
	if err := scanner.Err(); err != nil && !errors.Is(err, io.ErrClosedPipe) {
		return fmt.Errorf("read message: %w", err)
	}
	return nil
}

func (s *Server) handle(ctx context.Context, conn *connection, request Message) error {
	if request.ID == nil {
		return nil
	}
	if !conn.helloDone && request.Method != MethodHello {
		return conn.write(failure(request.ID, contract.CoreErrorCodeIpcVersionMismatch, "hello must come first"))
	}

	switch request.Method {
	case MethodHello:
		return s.hello(conn, request)
	case MethodPrepare:
		return conn.write(success(request.ID, PrepareResult{Result: "granted"}))
	case MethodStart:
		return s.withRequest(conn, request, s.backend.Start)
	case MethodUpdate:
		return s.withRequest(conn, request, s.backend.Update)
	case MethodStop:
		return conn.write(s.outcome(request.ID, s.backend.Stop()))
	case MethodSetUserMode:
		return s.setUserMode(conn, request)
	case MethodSelectServer:
		return s.selectServer(conn, request)
	case MethodURLTest:
		return s.urlTest(conn, request)
	case MethodGetState:
		return conn.write(Message{ID: request.ID, Result: json.RawMessage(s.backend.State())})
	case MethodSyncRuleSets:
		return s.syncRuleSets(ctx, conn, request)
	case MethodListProcesses:
		return s.listProcesses(conn, request)
	case MethodSubscribe:
		s.subscribe(conn)
		return conn.write(success(request.ID, struct{}{}))
	default:
		return conn.write(Message{
			ID:    request.ID,
			Error: &Error{Code: CodeMethodNotFound, Message: "method not found"},
		})
	}
}

func (s *Server) hello(conn *connection, request Message) error {
	var params HelloParams
	if err := json.Unmarshal(request.Params, &params); err != nil || params.ProtocolVersion != ProtocolVersion {
		return conn.write(failure(request.ID, contract.CoreErrorCodeIpcVersionMismatch, "protocol version mismatch"))
	}
	conn.helloDone = true
	return conn.write(success(request.ID, HelloResult{
		ProtocolVersion: ProtocolVersion,
		ServiceVersion:  s.serviceVersion,
	}))
}

// withRequest keeps the request as raw JSON, so the runtime validates exactly
// what the client sent.
func (s *Server) withRequest(conn *connection, request Message, call func(string) error) error {
	var params struct {
		TunnelRequest json.RawMessage `json:"tunnelRequest"`
	}
	if err := json.Unmarshal(request.Params, &params); err != nil {
		return conn.write(malformed(request.ID))
	}
	return conn.write(s.outcome(request.ID, call(string(params.TunnelRequest))))
}

func (s *Server) setUserMode(conn *connection, request Message) error {
	var params SetUserModeParams
	if err := json.Unmarshal(request.Params, &params); err != nil {
		return conn.write(malformed(request.ID))
	}
	return conn.write(s.outcome(request.ID, s.backend.SetUserMode(string(params.Mode))))
}

func (s *Server) selectServer(conn *connection, request Message) error {
	var params SelectServerParams
	if err := json.Unmarshal(request.Params, &params); err != nil {
		return conn.write(malformed(request.ID))
	}
	return conn.write(s.outcome(request.ID, s.backend.SelectServer(string(params.Group), params.ServerID)))
}

func (s *Server) urlTest(conn *connection, request Message) error {
	var params URLTestParams
	if err := json.Unmarshal(request.Params, &params); err != nil {
		return conn.write(malformed(request.ID))
	}
	event, err := s.backend.URLTest(params.ServerIDs)
	if err != nil {
		return conn.write(s.outcome(request.ID, err))
	}
	return conn.write(Message{ID: request.ID, Result: json.RawMessage(event)})
}

func (s *Server) syncRuleSets(ctx context.Context, conn *connection, request Message) error {
	var params SyncRuleSetsParams
	if err := json.Unmarshal(request.Params, &params); err != nil {
		return conn.write(malformed(request.ID))
	}
	ready := s.backend.SyncRuleSets(ctx, params.RuleSets)
	if ready == nil {
		ready = []string{}
	}
	return conn.write(success(request.ID, SyncRuleSetsResult{Ready: ready}))
}

func (s *Server) listProcesses(conn *connection, request Message) error {
	processes, err := s.backend.ListProcesses()
	if err != nil {
		return conn.write(s.outcome(request.ID, err))
	}
	if processes == nil {
		processes = []ProcessInfo{}
	}
	return conn.write(success(request.ID, processes))
}

func (s *Server) subscribe(conn *connection) {
	if conn.subscribed != nil {
		return
	}
	conn.subscribed = s.hub.subscribe()
	go func() {
		for {
			select {
			case event := <-conn.subscribed:
				notification := Message{Method: MethodEvent, Params: json.RawMessage(event)}
				if err := conn.write(notification); err != nil {
					s.logger.Warn("write event", "error", err)
					return
				}
			case <-conn.done:
				return
			}
		}
	}()
}

func (s *Server) outcome(id *int64, err error) Message {
	if err == nil {
		return success(id, struct{}{})
	}
	var coreErr *runtime.Error
	if errors.As(err, &coreErr) {
		return failure(id, coreErr.Code, coreErr.Message)
	}
	s.logger.Error("backend call failed", "error", err)
	return failure(id, contract.CoreErrorCodeInternal, "internal error")
}

// malformed never quotes the params: they can hold server secrets.
func malformed(id *int64) Message {
	return failure(id, contract.CoreErrorCodeConfigInvalid, "malformed params")
}

func success(id *int64, result any) Message {
	encoded, err := json.Marshal(result)
	if err != nil {
		return failure(id, contract.CoreErrorCodeInternal, "encode result")
	}
	return Message{ID: id, Result: encoded}
}

func failure(id *int64, code contract.CoreErrorCode, message string) Message {
	return Message{
		ID:    id,
		Error: &Error{Code: CodeCoreError, Message: message, Data: &ErrorData{Code: code}},
	}
}
