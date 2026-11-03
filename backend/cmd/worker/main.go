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

	"github.com/google/uuid"
	"github.com/riverqueue/river"

	"github.com/Evgenius09/vpn-project/backend/internal/app"
	"github.com/Evgenius09/vpn-project/backend/internal/config"
	"github.com/Evgenius09/vpn-project/backend/internal/db/sqlc"
	"github.com/Evgenius09/vpn-project/backend/internal/domain/account"
	"github.com/Evgenius09/vpn-project/backend/internal/domain/auth"
	"github.com/Evgenius09/vpn-project/backend/internal/domain/catalog"
	"github.com/Evgenius09/vpn-project/backend/internal/jobs"
	"github.com/Evgenius09/vpn-project/backend/internal/panel"
	panelfake "github.com/Evgenius09/vpn-project/backend/internal/panel/fake"
	"github.com/Evgenius09/vpn-project/backend/internal/panel/remnawave"
	"github.com/Evgenius09/vpn-project/backend/internal/seed"
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

	panelClient, err := panelFor(runtime.Config, seed.DefaultPath)
	if err != nil {
		return fmt.Errorf("panel client: %w", err)
	}
	service := catalog.NewService(catalog.NewPostgresStore(runtime.Pool), panelClient, catalog.Options{
		Logger: runtime.Logger,
	})
	river.AddWorker(workers, &catalog.SyncWorker{Service: service})
	river.AddWorker(workers, &account.ProvisionWorker{
		Service: account.NewService(runtime.Pool, panelClient, runtime.Config.TrialDays, time.Now),
	})
	periodic := []*river.PeriodicJob{catalog.PeriodicJob()}

	client, err := jobs.NewClient(runtime.Pool, jobs.Options{Logger: runtime.Logger, Workers: workers, Periodic: periodic})
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

// panelFor returns the panel of PANEL_MODE. In dev the fake panel holds the
// seed hosts, so the sync keeps the seeded servers. Elsewhere the seed is off
// limits (it carries a published device token) and the fake stays empty.
func panelFor(cfg config.Config, seedPath string) (panel.PanelClient, error) {
	if cfg.PanelMode == config.PanelRemnawave {
		squad, err := uuid.Parse(cfg.RemnawaveSquadUUID)
		if err != nil {
			return nil, fmt.Errorf("squad: %w", err)
		}
		client, err := remnawave.New(cfg.RemnawaveBaseURL, cfg.RemnawaveAPIToken, squad)
		if err != nil {
			return nil, fmt.Errorf("remnawave: %w", err)
		}
		return client, nil
	}
	client := panelfake.New()
	if cfg.AppEnv == config.EnvDev {
		data, err := seed.Load(seedPath)
		if err != nil {
			return nil, fmt.Errorf("load seed: %w", err)
		}
		seed.FillPanel(client, data)
	}
	return client, nil
}
