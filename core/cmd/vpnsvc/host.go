package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/Evgenius09/vpn-project/core/internal/contract"
	"github.com/Evgenius09/vpn-project/core/internal/ipc"
	"github.com/Evgenius09/vpn-project/core/internal/runtime"
)

const lastRequestFile = "last_request.json"

var errURLTestPending = errors.New("url test comes with S1-12")

// hostOptions holds what differs between the real service and the tests.
type hostOptions struct {
	// DataDir is %ProgramData%\vpnclient.
	DataDir string
	// Protect restricts a file to SYSTEM and Administrators.
	Protect func(path string) error
	// ListProcesses returns the raw process list.
	ListProcesses func() ([]ipc.ProcessInfo, error)
}

// backend adds what only the service does to the shared runtime.
type backend struct {
	*runtime.Runtime
	host     hostOptions
	ruleSets *ruleSetStore
	logger   *slog.Logger
}

func newBackend(tunnel *runtime.Runtime, host hostOptions, logger *slog.Logger) *backend {
	return &backend{
		Runtime:  tunnel,
		host:     host,
		ruleSets: newRuleSetStore(filepath.Join(host.DataDir, ruleSetDir), logger),
		logger:   logger,
	}
}

// Start implements ipc.Backend. Only a request the core accepted is kept: it
// will reconnect the tunnel at system start.
func (b *backend) Start(tunnelRequestJSON string) error {
	if err := b.Runtime.Start(tunnelRequestJSON); err != nil {
		return err //nolint:wrapcheck // The server reads the core error code from it.
	}
	b.remember(tunnelRequestJSON)
	return nil
}

// Update implements ipc.Backend.
func (b *backend) Update(tunnelRequestJSON string) error {
	if err := b.Runtime.Update(tunnelRequestJSON); err != nil {
		return err //nolint:wrapcheck // The server reads the core error code from it.
	}
	b.remember(tunnelRequestJSON)
	return nil
}

// remember only logs a failure: the tunnel already runs, and the file matters
// only for the next system start.
func (b *backend) remember(tunnelRequestJSON string) {
	path := filepath.Join(b.host.DataDir, lastRequestFile)
	if err := writeProtected(path, tunnelRequestJSON, b.host.Protect); err != nil {
		b.logger.Warn("keep the last request", "error", err)
	}
}

// writeProtected sets the ACL on an empty file before the secrets arrive, and
// the rename keeps that ACL.
func writeProtected(path, content string, protect func(string) error) error {
	temporary := path + ".tmp"
	if err := os.WriteFile(temporary, nil, 0o600); err != nil {
		return fmt.Errorf("create file: %w", err)
	}
	if err := protect(temporary); err != nil {
		return errors.Join(fmt.Errorf("protect file: %w", err), os.Remove(temporary))
	}
	if err := os.WriteFile(temporary, []byte(content), 0o600); err != nil {
		return fmt.Errorf("write file: %w", err)
	}
	if err := os.Rename(temporary, path); err != nil {
		return fmt.Errorf("replace file: %w", err)
	}
	return nil
}

// URLTest implements ipc.Backend.
func (*backend) URLTest([]string) (string, error) {
	return "", &runtime.Error{Code: contract.CoreErrorCodeInternal, Message: errURLTestPending.Error()}
}

// SyncRuleSets implements ipc.Backend.
func (b *backend) SyncRuleSets(ctx context.Context, ruleSets []contract.RuleSetRef) []string {
	return b.ruleSets.sync(ctx, ruleSets)
}

// ListProcesses implements ipc.Backend.
func (b *backend) ListProcesses() ([]ipc.ProcessInfo, error) {
	processes, err := b.host.ListProcesses()
	if err != nil {
		return nil, fmt.Errorf("list processes: %w", err)
	}
	return uniqueProcesses(processes), nil
}

// uniqueProcesses leaves one entry per program, because perApp selects by name
// and Windows treats names without case.
func uniqueProcesses(processes []ipc.ProcessInfo) []ipc.ProcessInfo {
	seen := make(map[string]struct{}, len(processes))
	unique := make([]ipc.ProcessInfo, 0, len(processes))
	for _, process := range processes {
		key := strings.ToLower(process.Name)
		if _, duplicate := seen[key]; duplicate || key == "" {
			continue
		}
		seen[key] = struct{}{}
		unique = append(unique, process)
	}
	sort.Slice(unique, func(i, j int) bool {
		return strings.ToLower(unique[i].Name) < strings.ToLower(unique[j].Name)
	})
	return unique
}
