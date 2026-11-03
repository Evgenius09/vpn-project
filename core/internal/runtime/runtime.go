// Package runtime owns the tunnel lifecycle and turns it into CoreEvent JSON
// (tech.md 5.5, 5.9). Android and vpnsvc share it and differ only in Engine.
package runtime

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"sync"
	"time"

	"github.com/sagernet/sing-box/option"

	"github.com/Evgenius09/vpn-project/core/internal/autoswitch"
	"github.com/Evgenius09/vpn-project/core/internal/config"
	"github.com/Evgenius09/vpn-project/core/internal/contract"
)

const trafficInterval = time.Second

// Error carries the code the host forwards to the app.
type Error = config.Error

// Engine runs one sing-box instance.
type Engine interface {
	Start(options option.Options) error
	Close() error
	// Select points a selector at one of its members without a restart.
	Select(selector, member string) error
	// Traffic returns the byte totals of the running box, or false while it has
	// none.
	Traffic() (up, down int64, ok bool)
	// URLTest requests link through one outbound and returns the delay in
	// milliseconds.
	URLTest(ctx context.Context, outbound, link string) (uint16, error)
}

// Options configures a Runtime.
type Options struct {
	Engine Engine
	// Sink receives each event as JSON.
	Sink func(string)
	// Now is replaceable in tests.
	Now func() time.Time
	// NewTicker is replaceable in tests. It returns the ticks and a stop function.
	NewTicker func() (<-chan time.Time, func())
	// URLTestTimeout bounds the test of one server. Zero means 5 seconds.
	URLTestTimeout time.Duration
}

// Runtime is safe for concurrent use.
type Runtime struct {
	mu             sync.Mutex
	engine         Engine
	sink           func(string)
	now            func() time.Time
	newTicker      func() (<-chan time.Time, func())
	urlTestTimeout time.Duration
	status         contract.TunnelStatus
	auto           autoswitch.State
	connectedSince *time.Time
	request        *contract.TunnelRequest
	selected       map[contract.TunnelMode]string
	stopTraffic    chan struct{}
	lastUp         int64
	lastDown       int64
}

// New returns a disconnected Runtime.
func New(options Options) *Runtime {
	now := options.Now
	if now == nil {
		now = time.Now
	}
	newTicker := options.NewTicker
	if newTicker == nil {
		newTicker = func() (<-chan time.Time, func()) {
			ticker := time.NewTicker(trafficInterval)
			return ticker.C, ticker.Stop
		}
	}
	timeout := options.URLTestTimeout
	if timeout == 0 {
		timeout = urlTestTimeout
	}
	return &Runtime{
		engine:         options.Engine,
		sink:           options.Sink,
		now:            now,
		newTicker:      newTicker,
		urlTestTimeout: timeout,
		status:         contract.TunnelStatusDisconnected,
		auto:           autoswitch.New(contract.TunnelModeRegular, false, false),
	}
}

// Start validates the request and starts the engine. A second Start while
// connected does nothing, so a retrying host cannot create a second box.
func (r *Runtime) Start(requestJSON string) error {
	request, options, err := prepare(requestJSON)
	if err != nil {
		return err
	}

	r.mu.Lock()
	defer r.mu.Unlock()
	if r.status == contract.TunnelStatusConnected || r.status == contract.TunnelStatusConnecting {
		return nil
	}
	// A new tunnel forgets the last network: the host reports it again right
	// after the start (tech.md 19.10).
	auto := autoswitch.New(request.UserMode, request.AutoSwitch.Enabled, holdsGroup(request, contract.TunnelModeWhitelist))
	return r.startEngine(request, options, auto, nil)
}

// Update applies new settings by restarting the box. A request it refuses
// leaves the running tunnel alone. The switch keeps the network and the
// override, and the new box starts on the effective group.
func (r *Runtime) Update(requestJSON string) error {
	request, options, err := prepare(requestJSON)
	if err != nil {
		return err
	}

	r.mu.Lock()
	defer r.mu.Unlock()
	if r.status != contract.TunnelStatusConnected {
		return nil
	}
	auto, modes := carry(r.auto, request)
	if auto.Effective != request.UserMode {
		if options, err = optionsOn(request, auto.Effective); err != nil {
			return err
		}
	}
	r.endTraffic()
	r.connectedSince = nil
	if err := r.engine.Close(); err != nil {
		return r.failStart(fmt.Errorf("close engine: %w", err))
	}
	return r.startEngine(request, options, auto, modes)
}

// carry feeds the switch only what the new request changed. A repeat of the
// switch value would clear the user's override on every settings change.
func carry(auto autoswitch.State, request contract.TunnelRequest) (autoswitch.State, []contract.ModePayload) {
	var events []autoswitch.Event
	if request.AutoSwitch.Enabled != auto.AutoSwitch {
		events = append(events, autoswitch.AutoSwitchSet{Enabled: request.AutoSwitch.Enabled})
	}
	if available := holdsGroup(request, contract.TunnelModeWhitelist); available != auto.WhitelistAvailable {
		events = append(events, autoswitch.ServersUpdated{WhitelistAvailable: available})
	}
	if request.UserMode != auto.UserMode {
		events = append(events, autoswitch.UserModeSet{Mode: request.UserMode})
	}

	var modes []contract.ModePayload
	for _, event := range events {
		var actions []autoswitch.Action
		auto, actions = autoswitch.Next(auto, event)
		// SelectGroup needs no call: the new box starts on the effective group.
		for _, action := range actions {
			if emitted, ok := action.(autoswitch.Emit); ok {
				modes = append(modes, emitted.Event)
			}
		}
	}
	return auto, modes
}

// optionsOn builds the options with the proxy selector on group, because
// BuildOptions puts it on the user mode (tech.md 21.2).
func optionsOn(request contract.TunnelRequest, group contract.TunnelMode) (option.Options, error) {
	request.UserMode = group
	options, err := config.BuildOptions(request)
	if err != nil {
		//nolint:wrapcheck // The host reads the code from the start of the message.
		return option.Options{}, err
	}
	return options, nil
}

func holdsGroup(request contract.TunnelRequest, mode contract.TunnelMode) bool {
	_, ok := config.SelectedServer(request, mode)
	return ok
}

func prepare(requestJSON string) (contract.TunnelRequest, option.Options, error) {
	request, err := parseRequest(requestJSON)
	if err != nil {
		return contract.TunnelRequest{}, option.Options{}, err
	}
	options, err := config.BuildOptions(request)
	if err != nil {
		//nolint:wrapcheck // The host reads the code from the start of the message.
		return contract.TunnelRequest{}, option.Options{}, err
	}
	return request, options, nil
}

func (r *Runtime) startEngine(
	request contract.TunnelRequest, options option.Options, auto autoswitch.State, modes []contract.ModePayload,
) error {
	r.request = &request
	r.auto = auto
	r.selected = map[contract.TunnelMode]string{}
	for _, mode := range []contract.TunnelMode{contract.TunnelModeRegular, contract.TunnelModeWhitelist} {
		if server, ok := config.SelectedServer(request, mode); ok {
			r.selected[mode] = server
		}
	}
	r.setStatus(contract.TunnelStatusConnecting)

	if err := r.engine.Start(options); err != nil {
		return r.failStart(err)
	}

	since := r.now().UTC()
	r.connectedSince = &since
	r.setStatus(contract.TunnelStatusConnected)
	for _, mode := range modes {
		r.emitMode(mode)
	}
	r.beginTraffic()
	return nil
}

func (r *Runtime) failStart(cause error) error {
	startErr := &Error{Code: contract.CoreErrorCodeStartFailed, Message: cause.Error()}
	r.connectedSince = nil
	r.setStatus(contract.TunnelStatusError)
	r.emitError(startErr)
	return startErr
}

// Stop closes the engine.
func (r *Runtime) Stop() error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.status != contract.TunnelStatusConnected {
		return nil
	}

	r.setStatus(contract.TunnelStatusDisconnecting)
	r.endTraffic()
	err := r.engine.Close()
	r.connectedSince = nil
	r.setStatus(contract.TunnelStatusDisconnected)
	if err != nil {
		return fmt.Errorf("close engine: %w", err)
	}
	return nil
}

// SetUserMode reports a PowerButton tap. Connections move to the new group,
// the box keeps running. A tap on the current user mode still counts: on
// cellular it overrides the switch (tech.md 2.1).
func (r *Runtime) SetUserMode(mode string) error {
	target := contract.TunnelMode(mode)
	if !target.Valid() {
		return &Error{Code: contract.CoreErrorCodeConfigInvalid, Message: "unknown mode"}
	}

	r.mu.Lock()
	defer r.mu.Unlock()
	if r.status != contract.TunnelStatusConnected {
		return nil
	}
	if _, ok := r.selected[target]; !ok {
		return &Error{
			Code:    contract.CoreErrorCodeNoServersInGroup,
			Message: fmt.Sprintf("no servers in group %s", target),
		}
	}
	return r.apply(autoswitch.UserModeSet{Mode: target})
}

// OnNetworkChanged reports the active network (tech.md 5.7). Outside connected
// it does nothing: Start resets the network and the host reports it again.
func (r *Runtime) OnNetworkChanged(netType string) error {
	network := autoswitch.NetType(netType)
	if !network.Valid() {
		return &Error{Code: contract.CoreErrorCodeConfigInvalid, Message: "unknown network type"}
	}

	r.mu.Lock()
	defer r.mu.Unlock()
	if r.status != contract.TunnelStatusConnected {
		return nil
	}
	return r.apply(autoswitch.NetChanged{Net: network})
}

// apply runs one event through the switch. A failed switch keeps the old
// state, so the same event can retry it.
func (r *Runtime) apply(event autoswitch.Event) error {
	next, actions := autoswitch.Next(r.auto, event)
	var modes []contract.ModePayload
	for _, action := range actions {
		switch action := action.(type) {
		case autoswitch.SelectGroup:
			if err := r.engine.Select(config.TagProxy, config.GroupTag(action.Group)); err != nil {
				return &Error{Code: contract.CoreErrorCodeInternal, Message: err.Error()}
			}
		case autoswitch.Emit:
			modes = append(modes, action.Event)
		}
	}

	visible := next.UserMode != r.auto.UserMode || next.Effective != r.auto.Effective
	r.auto = next
	for _, mode := range modes {
		r.emitMode(mode)
	}
	if visible {
		r.emitState()
	}
	return nil
}

// SelectServer changes the server of a group without a restart.
func (r *Runtime) SelectServer(group, serverID string) error {
	mode := contract.TunnelMode(group)
	if !mode.Valid() {
		return &Error{Code: contract.CoreErrorCodeConfigInvalid, Message: "unknown group"}
	}

	r.mu.Lock()
	defer r.mu.Unlock()
	if r.status != contract.TunnelStatusConnected {
		return nil
	}
	if !r.holds(mode, serverID) {
		return &Error{Code: contract.CoreErrorCodeConfigInvalid, Message: "server is not in the group"}
	}
	if err := r.engine.Select(config.GroupTag(mode), config.ServerTag(serverID)); err != nil {
		return &Error{Code: contract.CoreErrorCodeInternal, Message: err.Error()}
	}
	r.selected[mode] = serverID
	r.emitState()
	return nil
}

func (r *Runtime) holds(mode contract.TunnelMode, serverID string) bool {
	for _, server := range r.request.Servers {
		if server.Id == serverID && server.Group == mode {
			return true
		}
	}
	return false
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
	return request, nil
}

// beginTraffic counts from zero, because every box has new counters.
func (r *Runtime) beginTraffic() {
	stop := make(chan struct{})
	r.stopTraffic = stop
	r.lastUp, r.lastDown = 0, 0
	ticks, stopTicks := r.newTicker()
	go func() {
		defer stopTicks()
		for {
			select {
			case <-stop:
				return
			case <-ticks:
				r.emitTraffic(stop)
			}
		}
	}()
}

func (r *Runtime) endTraffic() {
	if r.stopTraffic != nil {
		close(r.stopTraffic)
		r.stopTraffic = nil
	}
}

// emitTraffic ignores a tick that raced with endTraffic: stop is then no longer
// the current channel.
func (r *Runtime) emitTraffic(stop chan struct{}) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.stopTraffic != stop {
		return
	}
	up, down, ok := r.engine.Traffic()
	if !ok {
		return
	}
	event := contract.TrafficPayload{
		UpBps:     up - r.lastUp,
		DownBps:   down - r.lastDown,
		UpTotal:   up,
		DownTotal: down,
	}
	r.lastUp, r.lastDown = up, down
	r.sink(encode(contract.CoreEvent{Type: contract.CoreEventTypeTraffic, At: r.now().UTC(), Traffic: &event}))
}

func (r *Runtime) setStatus(status contract.TunnelStatus) {
	r.status = status
	r.emitState()
}

func (r *Runtime) emitState() {
	r.sink(encode(r.stateEvent()))
}

func (r *Runtime) stateEvent() contract.CoreEvent {
	state := &contract.StatePayload{
		Status:         r.status,
		UserMode:       r.auto.UserMode,
		EffectiveMode:  r.auto.Effective,
		ConnectedSince: r.connectedSince,
	}
	if server, ok := r.selected[r.auto.Effective]; ok && r.status == contract.TunnelStatusConnected {
		state.ActiveServerId = &server
	}
	return contract.CoreEvent{Type: contract.CoreEventTypeState, At: r.now().UTC(), State: state}
}

func (r *Runtime) emitMode(mode contract.ModePayload) {
	r.sink(encode(contract.CoreEvent{Type: contract.CoreEventTypeMode, At: r.now().UTC(), Mode: &mode}))
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
