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
	"github.com/Evgenius09/vpn-project/backend/internal/config"
	"github.com/Evgenius09/vpn-project/backend/internal/db/sqlc"
	"github.com/Evgenius09/vpn-project/backend/internal/domain/auth"
	"github.com/Evgenius09/vpn-project/backend/internal/domain/profile"
	"github.com/Evgenius09/vpn-project/backend/internal/domain/telegram"
	"github.com/Evgenius09/vpn-project/backend/internal/gen/api"
	"github.com/Evgenius09/vpn-project/backend/internal/httpapi"
	"github.com/Evgenius09/vpn-project/backend/internal/jobs"
	"github.com/Evgenius09/vpn-project/backend/internal/telegram/botapi"
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

	queries := sqlc.New(runtime.Pool)
	policy, err := profile.LoadPolicy(runtime.Config.PolicyFile)
	if err != nil {
		return fmt.Errorf("load policy: %w", err)
	}
	endpoints := api.ProfileEndpoints{Api: runtime.Config.PublicAPIURLs, Bot: runtime.Config.BotURL()}
	if url := runtime.Config.SupportURL; url != "" {
		endpoints.Support = &url
	}
	if url := runtime.Config.WebURL; url != "" {
		endpoints.Web = &url
	}
	service := profile.NewService(profile.NewPostgresStore(queries), profile.Options{Policy: policy, Endpoints: endpoints})

	queue, err := jobs.NewClient(runtime.Pool, jobs.Options{Logger: runtime.Logger})
	if err != nil {
		return fmt.Errorf("create queue: %w", err)
	}
	login := auth.NewService(runtime.Pool, queue, auth.Options{
		Pepper: []byte(runtime.Config.TokenPepper),
		BotURL: runtime.Config.BotURL(),
	})
	webhook, err := telegramWebhook(runtime, queue)
	if err != nil {
		return fmt.Errorf("telegram webhook: %w", err)
	}

	metrics := httpapi.NewMetrics()
	router := httpapi.NewRouter(httpapi.Deps{
		Handlers:       handlers{profile: profile.NewHandler(service), auth: auth.NewHandler(login)},
		Devices:        httpapi.NewPostgresDevices(queries, runtime.Logger),
		Pepper:         []byte(runtime.Config.TokenPepper),
		Logger:         runtime.Logger,
		Metrics:        metrics,
		Webhook:        webhook,
		AuthRatePerMin: runtime.Config.AuthRatePerMin,
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

// telegramWebhook returns nil outside webhook mode, which leaves the route out.
func telegramWebhook(runtime app.Runtime, queue telegram.Queue) (http.Handler, error) {
	cfg := runtime.Config
	if cfg.TelegramMode != config.TelegramWebhook {
		return nil, nil
	}
	client, err := botapi.New(cfg.TelegramBotToken, runtime.Logger)
	if err != nil {
		return nil, fmt.Errorf("create client: %w", err)
	}
	service := telegram.NewService(runtime.Pool, client, queue, runtime.Logger)
	return telegram.NewWebhookHandler(service, cfg.TelegramWebhookSecret, runtime.Logger), nil
}

// handlers composes the domain slices. Operations without a slice stay
// unimplemented.
type handlers struct {
	httpapi.Unimplemented
	profile *profile.Handler
	auth    *auth.Handler
}

func (h handlers) GetProfile(ctx context.Context, request api.GetProfileRequestObject) (api.GetProfileResponseObject, error) {
	return h.profile.GetProfile(ctx, request) //nolint:wrapcheck // The handler already returns a problem or a wrapped error.
}

func (h handlers) StartTelegramLogin(ctx context.Context, request api.StartTelegramLoginRequestObject) (api.StartTelegramLoginResponseObject, error) {
	return h.auth.StartTelegramLogin(ctx, request) //nolint:wrapcheck // The handler already returns a problem or a wrapped error.
}

func (h handlers) VerifyTelegramLogin(ctx context.Context, request api.VerifyTelegramLoginRequestObject) (api.VerifyTelegramLoginResponseObject, error) {
	return h.auth.VerifyTelegramLogin(ctx, request) //nolint:wrapcheck // The handler already returns a problem or a wrapped error.
}

func (h handlers) Logout(ctx context.Context, request api.LogoutRequestObject) (api.LogoutResponseObject, error) {
	return h.auth.Logout(ctx, request) //nolint:wrapcheck // The handler already returns a problem or a wrapped error.
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
