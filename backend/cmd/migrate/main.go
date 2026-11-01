// Command migrate applies goose and River migrations in the deploy step.
package main

import (
	"context"
	"fmt"
	"os"

	"github.com/Evgenius09/vpn-project/backend/internal/app"
	"github.com/Evgenius09/vpn-project/backend/internal/db"
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

	if err := db.Up(ctx, runtime.Pool); err != nil {
		return fmt.Errorf("migrate: %w", err)
	}
	runtime.Logger.InfoContext(ctx, "migrations applied")
	return nil
}
