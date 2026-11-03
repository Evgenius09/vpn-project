package main

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/Evgenius09/vpn-project/core/internal/contract"
	"github.com/Evgenius09/vpn-project/core/internal/ipc"
)

const ruleSetBody = "rule set content"

func digest(content string) string {
	sum := sha256.Sum256([]byte(content))
	return hex.EncodeToString(sum[:])
}

// ruleSetServer counts requests, so a test can prove nothing was downloaded.
func ruleSetServer(t *testing.T, body string) (*ruleSetStore, *httptest.Server, *atomic.Int32) {
	t.Helper()
	var requests atomic.Int32
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		requests.Add(1)
		_, _ = w.Write([]byte(body))
	}))
	t.Cleanup(server.Close)
	store := newRuleSetStore(filepath.Join(t.TempDir(), ruleSetDir), slog.New(slog.DiscardHandler))
	store.client = server.Client()
	return store, server, &requests
}

func ref(id, url, sha string) contract.RuleSetRef {
	return contract.RuleSetRef{Id: id, Url: url, Sha256: sha}
}

func TestRuleSetLandsWhereTheConfigLooks(t *testing.T) {
	store, server, _ := ruleSetServer(t, ruleSetBody)

	ready := store.sync(context.Background(), []contract.RuleSetRef{ref("ru-direct", server.URL, digest(ruleSetBody))})

	require.Equal(t, []string{"ru-direct"}, ready)
	content, err := os.ReadFile(filepath.Join(store.dir, "ru-direct.srs"))
	require.NoError(t, err)
	require.Equal(t, ruleSetBody, string(content))
}

func TestWrongHashLeavesNoFile(t *testing.T) {
	store, server, _ := ruleSetServer(t, ruleSetBody)

	ready := store.sync(context.Background(), []contract.RuleSetRef{ref("ads", server.URL, digest("other"))})

	require.Empty(t, ready)
	require.NoFileExists(t, filepath.Join(store.dir, "ads.srs"))
}

func TestWrongHashKeepsTheVerifiedFile(t *testing.T) {
	store, server, _ := ruleSetServer(t, "tampered")
	require.NoError(t, os.MkdirAll(store.dir, 0o700))
	path := filepath.Join(store.dir, "ads.srs")
	require.NoError(t, os.WriteFile(path, []byte(ruleSetBody), 0o600))

	ready := store.sync(context.Background(), []contract.RuleSetRef{ref("ads", server.URL, digest("newer"))})

	require.Empty(t, ready, "the requested version is not there")
	content, err := os.ReadFile(path)
	require.NoError(t, err)
	require.Equal(t, ruleSetBody, string(content))
}

func TestAMatchingFileIsNotDownloaded(t *testing.T) {
	store, server, requests := ruleSetServer(t, ruleSetBody)
	sets := []contract.RuleSetRef{ref("ads", server.URL, digest(ruleSetBody))}

	require.Equal(t, []string{"ads"}, store.sync(context.Background(), sets))
	require.Equal(t, []string{"ads"}, store.sync(context.Background(), sets))

	require.EqualValues(t, 1, requests.Load())
}

func TestOneFailureLeavesTheOthersReady(t *testing.T) {
	store, server, _ := ruleSetServer(t, ruleSetBody)

	ready := store.sync(context.Background(), []contract.RuleSetRef{
		ref("bad", server.URL, digest("other")),
		ref("good", server.URL, digest(ruleSetBody)),
	})

	require.Equal(t, []string{"good"}, ready)
}

func TestRuleSetRefusals(t *testing.T) {
	store, server, requests := ruleSetServer(t, ruleSetBody)
	good := digest(ruleSetBody)
	plain := strings.Replace(server.URL, "https://", "http://", 1)

	cases := map[string]contract.RuleSetRef{
		"parent directory": ref("../../evil", server.URL, good),
		"separator":        ref(`a\b`, server.URL, good),
		"absolute path":    ref("/etc/passwd", server.URL, good),
		"empty id":         ref("", server.URL, good),
		"plain http":       ref("ads", plain, good),
		"hash not hex":     ref("ads", server.URL, "zz"),
		"short hash":       ref("ads", server.URL, "aa"),
	}
	for name, ruleSet := range cases {
		t.Run(name, func(t *testing.T) {
			require.Empty(t, store.sync(context.Background(), []contract.RuleSetRef{ruleSet}))
		})
	}
	require.Zero(t, requests.Load(), "nothing refused may reach the network")
}

func TestServerErrorIsNotReady(t *testing.T) {
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusBadGateway)
	}))
	t.Cleanup(server.Close)
	store := newRuleSetStore(t.TempDir(), slog.New(slog.DiscardHandler))
	store.client = server.Client()

	require.Empty(t, store.sync(context.Background(), []contract.RuleSetRef{ref("ads", server.URL, digest(""))}))
}

func TestOversizedRuleSetIsRefused(t *testing.T) {
	body := strings.Repeat("a", maxRuleSetBytes+1)
	store, server, _ := ruleSetServer(t, body)

	require.Empty(t, store.sync(context.Background(), []contract.RuleSetRef{ref("ads", server.URL, digest(body))}))
}

func TestWriteProtectedSetsTheACLBeforeTheContent(t *testing.T) {
	path := filepath.Join(t.TempDir(), lastRequestFile)
	var sizeWhenProtected int64 = -1

	err := writeProtected(path, "secret", func(target string) error {
		info, err := os.Stat(target)
		require.NoError(t, err)
		sizeWhenProtected = info.Size()
		return nil
	})

	require.NoError(t, err)
	require.Zero(t, sizeWhenProtected, "secrets must not exist before the ACL does")
	content, err := os.ReadFile(path)
	require.NoError(t, err)
	require.Equal(t, "secret", string(content))
	require.NoFileExists(t, path+".tmp")
}

func TestFailedProtectionKeepsTheSecretOffTheDisk(t *testing.T) {
	path := filepath.Join(t.TempDir(), lastRequestFile)

	err := writeProtected(path, "secret", func(string) error { return errors.New("denied") })

	require.Error(t, err)
	require.NoFileExists(t, path)
	require.NoFileExists(t, path+".tmp")
}

func TestUniqueProcesses(t *testing.T) {
	unique := uniqueProcesses([]ipc.ProcessInfo{
		{Name: "steam.exe", Path: `C:\a\steam.exe`},
		{Name: "Code.exe", Path: `C:\b\Code.exe`},
		{Name: "STEAM.EXE", Path: `C:\c\steam.exe`},
		{Name: "", Path: ""},
	})

	require.Equal(t, []ipc.ProcessInfo{
		{Name: "Code.exe", Path: `C:\b\Code.exe`},
		{Name: "steam.exe", Path: `C:\a\steam.exe`},
	}, unique)
}

func TestNoProcessesStaysAnEmptyList(t *testing.T) {
	require.NotNil(t, uniqueProcesses(nil), "the protocol result is an array")
}
