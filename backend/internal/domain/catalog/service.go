package catalog

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/Evgenius09/vpn-project/backend/internal/panel"
)

// Options are the values that come from configuration.
type Options struct {
	Logger *slog.Logger
}

// Service runs catalog_sync.
type Service struct {
	store  Store
	panel  panel.PanelClient
	logger *slog.Logger
}

// NewService returns a service.
func NewService(store Store, client panel.PanelClient, options Options) *Service {
	logger := options.Logger
	if logger == nil {
		logger = slog.Default()
	}
	return &Service{store: store, panel: client, logger: logger}
}

// Result counts what a sync did.
type Result struct {
	// Published counts tagged hosts that passed validation, enabled or not.
	Published int
	Changed   int
	Disabled  int
	Skipped   int
}

// Sync reads the panel, then writes the servers table. A failed read leaves the
// catalog as it was.
func (s *Service) Sync(ctx context.Context) (Result, error) {
	hosts, err := s.panel.ListHosts(ctx)
	if err != nil {
		return Result{}, fmt.Errorf("list hosts: %w", err)
	}
	servers, skipped, err := Build(hosts)
	if err != nil {
		return Result{}, err
	}
	for _, skip := range skipped {
		s.logger.WarnContext(ctx, "catalog host skipped", "host", skip.HostUUID.String(), "reason", skip.Err.Error())
	}
	changed, disabled, err := s.store.Apply(ctx, servers)
	if err != nil {
		return Result{}, err //nolint:wrapcheck // The store already names the step.
	}
	result := Result{Published: len(servers), Changed: changed, Disabled: disabled, Skipped: len(skipped)}
	s.logger.InfoContext(ctx, "catalog synced",
		"published", result.Published, "changed", result.Changed, "disabled", result.Disabled, "skipped", result.Skipped)
	return result, nil
}
