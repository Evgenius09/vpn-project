package bind

import (
	"context"
	"errors"
	"fmt"
	"path/filepath"

	"github.com/sagernet/sing-box/experimental/libbox"
	"github.com/sagernet/sing-box/include"
	"github.com/sagernet/sing-box/option"
	"github.com/sagernet/sing/common/json"
)

// commandEngine drives libbox on Android. Only libbox can adapt the Kotlin
// PlatformInterface to the one sing-box expects, and its command server is the
// exported way in. That path takes JSON, so the typed options are encoded here.
type commandEngine struct {
	server *libbox.CommandServer
}

func newCommandEngine(platform libbox.PlatformInterface, workDir string) (*commandEngine, error) {
	err := libbox.Setup(&libbox.SetupOptions{
		BasePath:    workDir,
		WorkingPath: workDir,
		TempPath:    filepath.Join(workDir, "tmp"),
	})
	if err != nil {
		return nil, fmt.Errorf("set up libbox: %w", err)
	}
	server, err := libbox.NewCommandServer(hostHandler{}, platform)
	if err != nil {
		return nil, fmt.Errorf("create command server: %w", err)
	}
	return &commandEngine{server: server}, nil
}

// Start implements runtime.Engine.
func (e *commandEngine) Start(options option.Options) error {
	encoded, err := json.MarshalContext(include.Context(context.Background()), options)
	if err != nil {
		return fmt.Errorf("encode options: %w", err)
	}
	if err := e.server.StartOrReloadService(string(encoded), &libbox.OverrideOptions{}); err != nil {
		return fmt.Errorf("start service: %w", err)
	}
	return nil
}

// Close implements runtime.Engine.
func (e *commandEngine) Close() error {
	if err := e.server.CloseService(); err != nil {
		return fmt.Errorf("close service: %w", err)
	}
	return nil
}

var errHostFeature = errors.New("core: host feature is not used")

// hostHandler refuses the libbox features this client does not use: the app
// drives the core directly, not through the command protocol.
type hostHandler struct{}

func (hostHandler) ServiceStop() error { return errHostFeature }

func (hostHandler) ServiceReload() error { return errHostFeature }

func (hostHandler) GetSystemProxyStatus() (*libbox.SystemProxyStatus, error) {
	return nil, errHostFeature
}

func (hostHandler) SetSystemProxyEnabled(bool) error { return errHostFeature }

func (hostHandler) TriggerNativeCrash() error { return errHostFeature }

func (hostHandler) WriteDebugMessage(string) {}

func (hostHandler) ConnectSSHAgent() (int32, error) { return 0, errHostFeature }
