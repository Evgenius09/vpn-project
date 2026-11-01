// Package runtime owns the tunnel lifecycle and turns it into CoreEvent JSON
// (tech.md 5.5, 5.9). Android and vpnsvc share it and differ only in Engine.
package runtime

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"sync"
	"time"

	"github.com/sagernet/sing-box/option"

	"github.com/Evgenius09/vpn-project/core/internal/contract"
)

const schemaVersion = 1

// Error carries the code the host forwards to the app.
type Error struct {
	Code    contract.CoreErrorCode
	Message string
}

// Error implements error.
func (e *Error) Error() string {
	return fmt.Sprintf("%s: %s", e.Code, e.Message)
}

// Engine runs one sing-box instance.
type Engine interface {
	Start(options option.Options) error
	Close() error
}

// Options configures a Runtime.
type Options struct {
	Engine Engine
	// Sink receives each event as JSON.
	Sink func(string)
	// Now is replaceable in tests.
	Now func() time.Time
}

// Runtime is safe for concurrent use.
type Runtime struct {
	mu             sync.Mutex
	engine         Engine
	sink           func(string)
	now            func() time.Time
	status         contract.TunnelStatus
	userMode       contract.TunnelMode
	effectiveMode  contract.TunnelMode
	connectedSince *time.Time
}

// New returns a disconnected Runtime.
func New(options Options) *Runtime {
	now := options.Now
	if now == nil {
		now = time.Now
	}
	return &Runtime{
		engine:        options.Engine,
		sink:          options.Sink,
		now:           now,
		status:        contract.TunnelStatusDisconnected,
		userMode:      contract.TunnelModeRegular,
		effectiveMode: contract.TunnelModeRegular,
	}
}

// Start validates the request and starts the engine. A second Start while
// connected does nothing, so a retrying host cannot create a second box.
func (r *Runtime) Start(requestJSON string) error {
	request, err := parseRequest(requestJSON)
	if err != nil {
		return err
	}

	r.mu.Lock()
	defer r.mu.Unlock()
	if r.status == contract.TunnelStatusConnected || r.status == contract.TunnelStatusConnecting {
		return nil
	}

	r.userMode = request.UserMode
	r.effectiveMode = request.UserMode
	r.setStatus(contract.TunnelStatusConnecting)

	if err := r.engine.Start(directOptions()); err != nil {
		startErr := &Error{Code: contract.CoreErrorCodeStartFailed, Message: err.Error()}
		r.setStatus(contract.TunnelStatusError)
		r.emitError(startErr)
		return startErr
	}

	since := r.now().UTC()
	r.connectedSince = &since
	r.setStatus(contract.TunnelStatusConnected)
	return nil
}

// Stop closes the engine.
func (r *Runtime) Stop() error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.status != contract.TunnelStatusConnected {
		return nil
	}

	r.setStatus(contract.TunnelStatusDisconnecting)
	err := r.engine.Close()
	r.connectedSince = nil
	r.setStatus(contract.TunnelStatusDisconnected)
	if err != nil {
		return fmt.Errorf("close engine: %w", err)
	}
	return nil
}

// State returns a CoreEvent of type state as JSON.
func (r *Runtime) State() string {
	r.mu.Lock()
	defer r.mu.Unlock()
	return encode(r.stateEvent())
}

func parseRequest(requestJSON string) (contract.TunnelRequest, error) {
	invalid := func(message string) (contract.TunnelRequest, error) {
		return contract.TunnelRequest{}, &Error{Code: contract.CoreErrorCodeConfigInvalid, Message: message}
	}

	var request contract.TunnelRequest
	decoder := json.NewDecoder(bytes.NewReader([]byte(requestJSON)))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&request); err != nil {
		if errors.Is(err, io.EOF) {
			return invalid("empty request")
		}
		// The decoder error can quote the input, which holds server secrets.
		return invalid("malformed request")
	}
	switch {
	case request.SchemaVersion != schemaVersion:
		return invalid("unsupported schema version")
	case !request.Platform.Valid():
		return invalid("unknown platform")
	case !request.UserMode.Valid():
		return invalid("unknown user mode")
	}
	return request, nil
}

func (r *Runtime) setStatus(status contract.TunnelStatus) {
	r.status = status
	r.sink(encode(r.stateEvent()))
}

func (r *Runtime) stateEvent() contract.CoreEvent {
	return contract.CoreEvent{
		Type: contract.CoreEventTypeState,
		At:   r.now().UTC(),
		State: &contract.StatePayload{
			Status:         r.status,
			UserMode:       r.userMode,
			EffectiveMode:  r.effectiveMode,
			ConnectedSince: r.connectedSince,
		},
	}
}

func (r *Runtime) emitError(err *Error) {
	r.sink(encode(contract.CoreEvent{
		Type:  contract.CoreEventTypeError,
		At:    r.now().UTC(),
		Error: &contract.ErrorPayload{Code: err.Code, Message: err.Message},
	}))
}

func encode(event contract.CoreEvent) string {
	encoded, err := json.Marshal(event)
	if err != nil {
		// CoreEvent holds only strings, numbers, and times, so this cannot fail.
		return `{"type":"error","at":"1970-01-01T00:00:00Z","error":{"code":"internal","message":"encode event"}}`
	}
	return string(encoded)
}
