// Command vpnsvc is the Windows service that owns the tunnel (tech.md 5.6). It
// runs as SYSTEM, because the TUN adapter needs it, and the UI talks to it over
// a named pipe.
package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"sync"

	"github.com/Evgenius09/vpn-project/core/internal/ipc"
	"github.com/Evgenius09/vpn-project/core/internal/runtime"
)

// version is set by the linker for releases.
var version = "0.1.0"

// serve accepts pipe connections until ctx ends.
func serve(ctx context.Context, listener net.Listener, engine runtime.Engine, host hostOptions, logger *slog.Logger) error {
	hub := ipc.NewHub()
	tunnel := newBackend(runtime.New(runtime.Options{Engine: engine, Sink: hub.Publish}), host, logger)
	server := ipc.NewServer(tunnel, hub, version, logger)

	tunnel.network = newNetWatch(netDebounce, timeAfterFunc, tunnel.reportNetwork)
	defer tunnel.network.Close()
	if host.WatchNetwork != nil {
		stopWatch, err := host.WatchNetwork(tunnel.network.Observe)
		if err != nil {
			// The tunnel works without the auto switch, so the service keeps going.
			logger.WarnContext(ctx, "watch network", "error", err)
		} else {
			defer stopWatch()
		}
	}

	stop := context.AfterFunc(ctx, func() { _ = listener.Close() })
	defer stop()

	var connections sync.WaitGroup
	defer connections.Wait()
	for {
		conn, err := listener.Accept()
		if err != nil {
			if ctx.Err() != nil || errors.Is(err, net.ErrClosed) {
				if stopErr := tunnel.Stop(); stopErr != nil {
					return fmt.Errorf("stop tunnel: %w", stopErr)
				}
				return nil
			}
			return fmt.Errorf("accept: %w", err)
		}
		connections.Go(func() {
			if err := server.Serve(ctx, conn); err != nil {
				logger.WarnContext(ctx, "connection ended", "error", err)
			}
		})
	}
}
