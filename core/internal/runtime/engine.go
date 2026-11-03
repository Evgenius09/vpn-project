package runtime

import (
	"context"
	"errors"
	"fmt"
	"sync"

	box "github.com/sagernet/sing-box"
	"github.com/sagernet/sing-box/adapter"
	"github.com/sagernet/sing-box/common/trafficcontrol"
	"github.com/sagernet/sing-box/common/urltest"
	"github.com/sagernet/sing-box/include"
	"github.com/sagernet/sing-box/log"
	"github.com/sagernet/sing-box/option"
	"github.com/sagernet/sing-box/protocol/group"
	"github.com/sagernet/sing/service"
)

// BoxEngine runs sing-box in process. vpnsvc and the tests use it. Android uses
// the libbox command server instead, because only that path reaches the
// platform interface.
type BoxEngine struct {
	mu       sync.Mutex
	instance *box.Box
	ctx      context.Context //nolint:containedctx // Selectors and counters live in the box context.
	cancel   context.CancelFunc
}

var errNotRunning = errors.New("box is not running")

// silentWriter exists because sing-box keeps traffic counters only when a
// platform writer is set. Logs still go to the configured output.
type silentWriter struct{}

func (silentWriter) WriteMessage(log.Level, string) {}

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
	instance, err := box.New(box.Options{Options: options, Context: ctx, PlatformLogWriter: silentWriter{}})
	if err != nil {
		cancel()
		return fmt.Errorf("create box: %w", err)
	}
	if err := instance.Start(); err != nil {
		cancel()
		_ = instance.Close()
		return fmt.Errorf("start box: %w", err)
	}
	e.instance, e.ctx, e.cancel = instance, ctx, cancel
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
	e.instance, e.ctx, e.cancel = nil, nil, nil
	if err != nil {
		return fmt.Errorf("close box: %w", err)
	}
	return nil
}

// Select implements Engine.
func (e *BoxEngine) Select(selector, member string) error {
	e.mu.Lock()
	defer e.mu.Unlock()
	if e.instance == nil {
		return errNotRunning
	}
	outbound, found := service.FromContext[adapter.OutboundManager](e.ctx).Outbound(selector)
	if !found {
		return fmt.Errorf("selector %s not found", selector)
	}
	target, isSelector := outbound.(*group.Selector)
	if !isSelector {
		return fmt.Errorf("outbound %s is not a selector", selector)
	}
	if !target.SelectOutbound(member) {
		return fmt.Errorf("selector %s has no member %s", selector, member)
	}
	return nil
}

// Traffic implements Engine.
func (e *BoxEngine) Traffic() (up, down int64, ok bool) {
	e.mu.Lock()
	defer e.mu.Unlock()
	if e.instance == nil {
		return 0, 0, false
	}
	manager := service.PtrFromContext[trafficcontrol.Manager](e.ctx)
	if manager == nil {
		return 0, 0, false
	}
	up, down = manager.Total()
	return up, down, true
}

// URLTest implements Engine.
func (e *BoxEngine) URLTest(ctx context.Context, outbound, link string) (uint16, error) {
	e.mu.Lock()
	if e.instance == nil {
		e.mu.Unlock()
		return 0, errNotRunning
	}
	outbounds := e.instance.Outbound()
	e.mu.Unlock()
	return URLTestOutbound(ctx, outbounds, outbound, link)
}

// URLTestOutbound requests link through the outbound tagged tag. The Android
// engine shares it, because both reach the same outbound manager.
func URLTestOutbound(ctx context.Context, outbounds adapter.OutboundManager, tag, link string) (uint16, error) {
	outbound, found := outbounds.Outbound(tag)
	if !found {
		return 0, fmt.Errorf("outbound %s not found", tag)
	}
	delay, err := urltest.URLTest(ctx, link, outbound)
	if err != nil {
		return 0, fmt.Errorf("url test %s: %w", tag, err)
	}
	return delay, nil
}
