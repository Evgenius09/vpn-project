package ipc

import (
	"bufio"
	"encoding/json"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
)

type frame struct {
	Dir string  `json:"dir"`
	Msg Message `json:"msg"`
}

func readSession(t *testing.T, path string) []frame {
	t.Helper()
	file, err := os.Open(path)
	require.NoError(t, err)
	defer func() { require.NoError(t, file.Close()) }()

	var frames []frame
	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 0, 64*1024), MaxMessageBytes)
	for scanner.Scan() {
		var f frame
		decoder := json.NewDecoder(strings.NewReader(scanner.Text()))
		decoder.DisallowUnknownFields()
		require.NoError(t, decoder.Decode(&f), scanner.Text())
		frames = append(frames, f)
	}
	require.NoError(t, scanner.Err())
	return frames
}

func sessions(t *testing.T) []string {
	t.Helper()
	paths, err := filepath.Glob("../../../contracts/fixtures/ipc/*.jsonl")
	require.NoError(t, err)
	require.NotEmpty(t, paths)
	return paths
}

func TestSessionsStartWithHello(t *testing.T) {
	for _, path := range sessions(t) {
		t.Run(filepath.Base(path), func(t *testing.T) {
			frames := readSession(t, path)
			require.Equal(t, "send", frames[0].Dir)
			require.Equal(t, MethodHello, frames[0].Msg.Method)
		})
	}
}

func TestSessionFramesAreWellFormed(t *testing.T) {
	for _, path := range sessions(t) {
		t.Run(filepath.Base(path), func(t *testing.T) {
			pending := map[int64]bool{}
			for _, f := range readSession(t, path) {
				require.Equal(t, JSONRPCVersion, f.Msg.JSONRPC)
				switch f.Dir {
				case "send":
					require.NotNil(t, f.Msg.ID, "a client request needs an id")
					pending[*f.Msg.ID] = true
				case "recv":
					if f.Msg.ID == nil {
						require.Equal(t, MethodEvent, f.Msg.Method)
						continue
					}
					require.True(t, pending[*f.Msg.ID], "a response needs a request")
					delete(pending, *f.Msg.ID)
					require.NotEqual(t, f.Msg.Result == nil, f.Msg.Error == nil,
						"a response has exactly one of result and error")
				default:
					require.Failf(t, "unknown direction", "%q", f.Dir)
				}
			}
			require.Empty(t, pending, "every request gets a response")
		})
	}
}

func TestSessionErrorCodes(t *testing.T) {
	tests := []struct {
		session string
		code    int
		data    string
	}{
		{"version_mismatch.jsonl", CodeCoreError, "ipc_version_mismatch"},
		{"unknown_method.jsonl", CodeMethodNotFound, ""},
	}
	for _, tt := range tests {
		t.Run(tt.session, func(t *testing.T) {
			path := filepath.Join("../../../contracts/fixtures/ipc", tt.session)
			frames := readSession(t, path)
			last := frames[len(frames)-1].Msg
			require.NotNil(t, last.Error)
			require.Equal(t, tt.code, last.Error.Code)
			if tt.data == "" {
				require.Nil(t, last.Error.Data)
				return
			}
			require.Equal(t, tt.data, string(last.Error.Data.Code))
		})
	}
}

func TestMethodsMatchTheContractTable(t *testing.T) {
	require.Len(t, Methods, 12)
	require.True(t, slices.Contains(Methods, MethodSyncRuleSets))
	require.False(t, slices.Contains(Methods, MethodEvent), "event is a notification")
}
