// Package bind is the gomobile surface of the core on Android (tech.md 5.9).
// It exposes only basic types, strings, and interfaces.
package bind

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"

	"github.com/sagernet/sing-box/experimental/libbox"

	"github.com/Evgenius09/vpn-project/core/internal/contract"

	"github.com/Evgenius09/vpn-project/core/internal/runtime"
)

// EventSink receives CoreEvent JSON from the core.
type EventSink interface {
	OnEvent(coreEventJSON string)
}

// Core is one tunnel. Its methods are safe to call from any thread.
type Core struct {
	runtime *runtime.Runtime
	initErr error
}

// NewCore returns a core bound to the host. gomobile constructors cannot
// return an error, so a setup failure surfaces on the first Start.
func NewCore(platform libbox.PlatformInterface, sink EventSink, workDir string) *Core {
	engine, err := newCommandEngine(platform, workDir)
	if err != nil {
		return &Core{initErr: err}
	}
	return newCore(engine, sink)
}

func newCore(engine runtime.Engine, sink EventSink) *Core {
	return &Core{runtime: runtime.New(runtime.Options{Engine: engine, Sink: sink.OnEvent})}
}

// Start begins the tunnel from a JSON TunnelRequest.
func (c *Core) Start(tunnelRequestJSON string) error {
	if c.initErr != nil {
		return c.initErr
	}
	//nolint:wrapcheck // The host reads the core error code from this error.
	return c.runtime.Start(tunnelRequestJSON)
}

// Update applies new settings by restarting the box.
func (c *Core) Update(tunnelRequestJSON string) error {
	if c.initErr != nil {
		return c.initErr
	}
	//nolint:wrapcheck // The host reads the core error code from this error.
	return c.runtime.Update(tunnelRequestJSON)
}

// Stop ends the tunnel.
func (c *Core) Stop() error {
	if c.initErr != nil {
		return c.initErr
	}
	//nolint:wrapcheck // The error already names the failed step.
	return c.runtime.Stop()
}

// SetUserMode changes the user mode without a restart.
func (c *Core) SetUserMode(mode string) error {
	if c.initErr != nil {
		return c.initErr
	}
	//nolint:wrapcheck // The host reads the core error code from this error.
	return c.runtime.SetUserMode(mode)
}

// SelectServer selects a server in a group without a restart.
func (c *Core) SelectServer(group, serverID string) error {
	if c.initErr != nil {
		return c.initErr
	}
	//nolint:wrapcheck // The host reads the core error code from this error.
	return c.runtime.SelectServer(group, serverID)
}

// OnNetworkChanged reports a NetType. S2-02 implements it.
func (c *Core) OnNetworkChanged(string) {}

// URLTest measures the servers of a JSON array of ids and returns a JSON
// CoreEvent of type url_test (tech.md 31.1).
func (c *Core) URLTest(serverIDsJSON string) (string, error) {
	if c.initErr != nil {
		return "", c.initErr
	}
	ids, err := parseIDs(serverIDsJSON)
	if err != nil {
		return "", err
	}
	//nolint:wrapcheck // The host reads the core error code from this error.
	return c.runtime.URLTest(ids)
}

func parseIDs(serverIDsJSON string) ([]string, error) {
	var ids []string
	decoder := json.NewDecoder(bytes.NewReader([]byte(serverIDsJSON)))
	err := decoder.Decode(&ids)
	if err == nil && !errors.Is(decoder.Decode(&struct{}{}), io.EOF) {
		err = errors.New("trailing data")
	}
	if err != nil || ids == nil {
		return nil, &runtime.Error{Code: contract.CoreErrorCodeConfigInvalid, Message: "server ids must be a JSON array of strings"}
	}
	return ids, nil
}

// State returns a JSON CoreEvent of type state.
func (c *Core) State() string {
	if c.initErr != nil {
		return ""
	}
	return c.runtime.State()
}
