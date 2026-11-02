//go:build windows

package main

import (
	"context"
	"flag"
	"fmt"
	"log/slog"
	"os"
	"os/signal"

	"github.com/Microsoft/go-winio"
	"golang.org/x/sys/windows/svc"
)

const (
	serviceName = "vpnclient"
	pipeName    = `\\.\pipe\vpnclient-core`
	// SYSTEM and Administrators get full access, Authenticated Users read and
	// write (tech.md 5.6).
	pipeSecurity = "D:P(A;;GA;;;SY)(A;;GA;;;BA)(A;;GRGW;;;AU)"
)

func main() {
	console := flag.Bool("console", false, "run in the foreground instead of under the service manager")
	flag.Parse()

	var err error
	if *console {
		err = runConsole()
	} else {
		err = svc.Run(serviceName, handler{})
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func runConsole() error {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()
	return run(ctx)
}

func run(ctx context.Context) error {
	listener, err := winio.ListenPipe(pipeName, &winio.PipeConfig{SecurityDescriptor: pipeSecurity})
	if err != nil {
		return fmt.Errorf("listen on pipe: %w", err)
	}
	return serve(ctx, listener, newLogger())
}

func newLogger() *slog.Logger {
	return slog.New(slog.NewJSONHandler(os.Stderr, nil))
}

type handler struct{}

// Execute implements svc.Handler.
func (handler) Execute(_ []string, requests <-chan svc.ChangeRequest, status chan<- svc.Status) (bool, uint32) {
	status <- svc.Status{State: svc.StartPending}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	done := make(chan error, 1)
	go func() { done <- run(ctx) }()

	status <- svc.Status{State: svc.Running, Accepts: svc.AcceptStop | svc.AcceptShutdown}
	for {
		select {
		case request := <-requests:
			switch request.Cmd {
			case svc.Interrogate:
				status <- request.CurrentStatus
			case svc.Stop, svc.Shutdown:
				status <- svc.Status{State: svc.StopPending}
				cancel()
				<-done
				return false, 0
			}
		case err := <-done:
			if err != nil {
				newLogger().Error("service failed", "error", err)
				return false, 1
			}
			return false, 0
		}
	}
}
