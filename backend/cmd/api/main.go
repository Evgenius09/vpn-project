// Command api serves the public HTTP API and the internal metrics port.
package main

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"golang.org/x/sync/errgroup"

	"github.com/Evgenius09/vpn-project/backend/internal/app"
	"github.com/Evgenius09/vpn-project/backend/internal/db/sqlc"
	"github.com/Evgenius09/vpn-project/backend/internal/httpapi"
)

const (
	headerTimeout = 5 * time.Second
	stopTimeout   = 10 * time.Second
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	err := run(ctx)
	stop()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run(ctx context.Context) error {
	runtime, err := app.Start(ctx)
	if err != nil {
		return fmt.Errorf("start: %w", err)
	}
	defer runtime.Pool.Close()

	metrics := httpapi.NewMetrics()
	router := httpapi.NewRouter(httpapi.Deps{
		Handlers: httpapi.Unimplemented{},
		Devices:  httpapi.NewPostgresDevices(sqlc.New(runtime.Pool), runtime.Logger),
		Pepper:   []byte(runtime.Config.TokenPepper),
		Logger:   runtime.Logger,
		Metrics:  metrics,
	})

	group, ctx := errgroup.WithContext(ctx)
	serve(ctx, group, &http.Server{Addr: runtime.Config.HTTPAddr, Handler: router, ReadHeaderTimeout: headerTimeout})
	serve(ctx, group, &http.Server{Addr: runtime.Config.MetricsAddr, Handler: metricsMux(metrics), ReadHeaderTimeout: headerTimeout})
	runtime.Logger.InfoContext(ctx, "api started", "config", runtime.Config)

	if err := group.Wait(); err != nil {
		return fmt.Errorf("serve: %w", err)
	}
	return nil
}

func metricsMux(metrics *httpapi.Metrics) http.Handler {
	mux := http.NewServeMux()
	mux.Handle("GET /metrics", metrics.Handler())
	return mux
}

func serve(ctx context.Context, group *errgroup.Group, server *http.Server) {
	group.Go(func() error {
		if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			return fmt.Errorf("listen %s: %w", server.Addr, err)
		}
		return nil
	})
	group.Go(func() error {
		<-ctx.Done()
		stopCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), stopTimeout)
		defer cancel()
		if err := server.Shutdown(stopCtx); err != nil {
			return fmt.Errorf("shut down %s: %w", server.Addr, err)
		}
		return nil
	})
}
