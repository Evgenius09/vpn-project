// Command worker runs River jobs.
package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/riverqueue/river"

	"github.com/Evgenius09/vpn-project/backend/internal/app"
	"github.com/Evgenius09/vpn-project/backend/internal/config"
	"github.com/Evgenius09/vpn-project/backend/internal/db/sqlc"
	"github.com/Evgenius09/vpn-project/backend/internal/domain/auth"
	"github.com/Evgenius09/vpn-project/backend/internal/jobs"
	"github.com/Evgenius09/vpn-project/backend/internal/telegram"
	"github.com/Evgenius09/vpn-project/backend/internal/telegram/botapi"
	"github.com/Evgenius09/vpn-project/backend/internal/telegram/fake"
)

const stopTimeout = 30 * time.Second

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

	bot, err := telegramClient(runtime)
	if err != nil {
		return fmt.Errorf("telegram client: %w", err)
	}

	workers := river.NewWorkers()
	river.AddWorker(workers, &jobs.DemoEchoWorker{Logger: runtime.Logger})
	river.AddWorker(workers, &auth.SendCodeWorker{Queries: sqlc.New(runtime.Pool), Client: bot, Now: time.Now})

	client, err := jobs.NewClient(runtime.Pool, jobs.Options{Logger: runtime.Logger, Workers: workers})
	if err != nil {
		return fmt.Errorf("create client: %w", err)
	}
	if err := client.Start(ctx); err != nil {
		return fmt.Errorf("start client: %w", err)
	}
	runtime.Logger.InfoContext(ctx, "worker started")

	<-ctx.Done()
	stopCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), stopTimeout)
	defer cancel()
	if err := client.Stop(stopCtx); err != nil && !errors.Is(err, context.Canceled) {
		return fmt.Errorf("stop client: %w", err)
	}
	return nil
}

// telegramClient returns the fake in fake mode. The fake logs messages, which is
// how a login code reaches the developer (tech.md 9).
func telegramClient(runtime app.Runtime) (telegram.TelegramClient, error) {
	if runtime.Config.TelegramMode == config.TelegramFake {
		return fake.New(runtime.Logger), nil
	}
	client, err := botapi.New(runtime.Config.TelegramBotToken, runtime.Logger)
	if err != nil {
		return nil, fmt.Errorf("create client: %w", err)
	}
	return client, nil
}
