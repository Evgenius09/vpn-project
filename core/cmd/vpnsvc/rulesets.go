package main

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"time"

	"github.com/Evgenius09/vpn-project/core/internal/contract"
)

const (
	ruleSetDir      = "rulesets"
	maxRuleSetBytes = 32 << 20
	fetchTimeout    = 60 * time.Second
)

// ruleSetID keeps a value from the network from choosing where SYSTEM writes.
var ruleSetID = regexp.MustCompile(`^[a-z0-9][a-z0-9_-]{0,63}$`)

// ruleSetStore keeps rule sets where config.LocalRuleSet paths point on Windows.
type ruleSetStore struct {
	dir    string
	client *http.Client
	logger *slog.Logger
}

func newRuleSetStore(dir string, logger *slog.Logger) *ruleSetStore {
	return &ruleSetStore{dir: dir, client: &http.Client{Timeout: fetchTimeout}, logger: logger}
}

// sync fetches each rule set and returns the ones that are ready. One failure
// leaves the others alone, and an old verified file stays in place.
func (s *ruleSetStore) sync(ctx context.Context, ruleSets []contract.RuleSetRef) []string {
	ready := make([]string, 0, len(ruleSets))
	for _, ruleSet := range ruleSets {
		if err := s.fetch(ctx, ruleSet); err != nil {
			s.logger.WarnContext(ctx, "sync rule set", "id", ruleSet.Id, "error", err)
			continue
		}
		ready = append(ready, ruleSet.Id)
	}
	return ready
}

func (s *ruleSetStore) fetch(ctx context.Context, ruleSet contract.RuleSetRef) error {
	if !ruleSetID.MatchString(ruleSet.Id) {
		return errors.New("invalid id")
	}
	want, err := hex.DecodeString(ruleSet.Sha256)
	if err != nil || len(want) != sha256.Size {
		return errors.New("invalid sha256")
	}
	location, err := url.Parse(ruleSet.Url)
	if err != nil || location.Scheme != "https" {
		return errors.New("rule sets come only over https")
	}
	path := filepath.Join(s.dir, ruleSet.Id+".srs")
	if current, err := os.ReadFile(path); err == nil && matches(current, ruleSet.Sha256) {
		return nil
	}

	content, err := s.download(ctx, ruleSet.Url)
	if err != nil {
		return err
	}
	if !matches(content, ruleSet.Sha256) {
		return errors.New("sha256 mismatch")
	}
	if err := os.MkdirAll(s.dir, 0o700); err != nil {
		return fmt.Errorf("create directory: %w", err)
	}
	temporary := path + ".tmp"
	if err := os.WriteFile(temporary, content, 0o600); err != nil {
		return fmt.Errorf("write file: %w", err)
	}
	if err := os.Rename(temporary, path); err != nil {
		return fmt.Errorf("replace file: %w", err)
	}
	return nil
}

func (s *ruleSetStore) download(ctx context.Context, location string) ([]byte, error) {
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, location, http.NoBody)
	if err != nil {
		return nil, fmt.Errorf("build request: %w", err)
	}
	response, err := s.client.Do(request)
	if err != nil {
		return nil, fmt.Errorf("download: %w", err)
	}
	defer func() { _ = response.Body.Close() }()
	if response.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("download: status %d", response.StatusCode)
	}
	content, err := io.ReadAll(io.LimitReader(response.Body, maxRuleSetBytes+1))
	if err != nil {
		return nil, fmt.Errorf("read body: %w", err)
	}
	if len(content) > maxRuleSetBytes {
		return nil, errors.New("rule set is too large")
	}
	return content, nil
}

func matches(content []byte, wantHex string) bool {
	sum := sha256.Sum256(content)
	return hex.EncodeToString(sum[:]) == wantHex
}
