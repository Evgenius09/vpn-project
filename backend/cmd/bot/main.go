// Command bot receives Telegram updates by long polling. Staging and prod use
// the webhook of cmd/api instead.
package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/Evgenius09/vpn-project/backend/internal/app"
	"github.com/Evgenius09/vpn-project/backend/internal/config"
	"github.com/Evgenius09/vpn-project/backend/internal/domain/telegram"
	"github.com/Evgenius09/vpn-project/backend/internal/jobs"
	"github.com/Evgenius09/vpn-project/backend/internal/telegram/botapi"
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

	if runtime.Config.TelegramMode != config.TelegramPolling {
		return errors.New("bot needs TELEGRAM_MODE=polling")
	}
	client, err := botapi.New(runtime.Config.TelegramBotToken, runtime.Logger)
	if err != nil {
		return fmt.Errorf("create client: %w", err)
	}
	queue, err := jobs.NewClient(runtime.Pool, jobs.Options{Logger: runtime.Logger})
	if err != nil {
		return fmt.Errorf("create queue: %w", err)
	}
	service := telegram.NewService(runtime.Pool, client, queue, runtime.Logger)

	runtime.Logger.InfoContext(ctx, "bot started")
	client.Poll(ctx, service.HandleUpdate)
	return nil
}
