// Command seed fills the local database with the shared seed data.
package main

import (
	"context"
	"errors"
	"fmt"
	"os"

	"github.com/Evgenius09/vpn-project/backend/internal/app"
	"github.com/Evgenius09/vpn-project/backend/internal/config"
	"github.com/Evgenius09/vpn-project/backend/internal/seed"
)

func main() {
	if err := run(context.Background()); err != nil {
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

	// The seed device has a published token.
	if runtime.Config.AppEnv != config.EnvDev {
		return errors.New("seed runs only with APP_ENV=dev")
	}

	data, err := seed.Load(seed.DefaultPath)
	if err != nil {
		return fmt.Errorf("load: %w", err)
	}
	if err := seed.Apply(ctx, runtime.Pool, data, []byte(runtime.Config.TokenPepper)); err != nil {
		return fmt.Errorf("apply: %w", err)
	}
	runtime.Logger.InfoContext(ctx, "seed applied", "servers", len(data.Servers))
	return nil
}
