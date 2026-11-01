package runtime

import (
	"context"
	"errors"
	"fmt"
	"sync"

	box "github.com/sagernet/sing-box"
	C "github.com/sagernet/sing-box/constant"
	"github.com/sagernet/sing-box/include"
	"github.com/sagernet/sing-box/option"
)

// BoxEngine runs sing-box in process. vpnsvc and the tests use it. Android uses
// the libbox command server instead, because only that path reaches the
// platform interface.
type BoxEngine struct {
	mu       sync.Mutex
	instance *box.Box
	cancel   context.CancelFunc
}

// NewBoxEngine returns an idle engine.
func NewBoxEngine() *BoxEngine {
	return &BoxEngine{}
}

// Start implements Engine.
func (e *BoxEngine) Start(options option.Options) error {
	e.mu.Lock()
	defer e.mu.Unlock()
	if e.instance != nil {
		return errors.New("box already running")
	}

	ctx, cancel := context.WithCancel(include.Context(context.Background()))
	instance, err := box.New(box.Options{Options: options, Context: ctx})
	if err != nil {
		cancel()
		return fmt.Errorf("create box: %w", err)
	}
	if err := instance.Start(); err != nil {
		cancel()
		_ = instance.Close()
		return fmt.Errorf("start box: %w", err)
	}
	e.instance, e.cancel = instance, cancel
	return nil
}

// Close implements Engine.
func (e *BoxEngine) Close() error {
	e.mu.Lock()
	defer e.mu.Unlock()
	if e.instance == nil {
		return nil
	}
	err := e.instance.Close()
	e.cancel()
	e.instance, e.cancel = nil, nil
	if err != nil {
		return fmt.Errorf("close box: %w", err)
	}
	return nil
}

// directOptions is the skeleton config: one direct outbound and no tunnel.
// S1-01 replaces it with config.BuildOptions.
func directOptions() option.Options {
	return option.Options{
		Log: &option.LogOptions{Disabled: true},
		Outbounds: []option.Outbound{{
			Type:    C.TypeDirect,
			Tag:     "direct",
			Options: &option.DirectOutboundOptions{},
		}},
	}
}
