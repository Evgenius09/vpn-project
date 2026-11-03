package runtime

import (
	"context"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"

	C "github.com/sagernet/sing-box/constant"
	"github.com/sagernet/sing-box/option"
	"github.com/stretchr/testify/require"
)

// selectorOptions needs no TUN, so the real box runs without root.
func selectorOptions() option.Options {
	direct := func(tag string) option.Outbound {
		return option.Outbound{Type: C.TypeDirect, Tag: tag, Options: &option.DirectOutboundOptions{}}
	}
	return option.Options{
		Log: &option.LogOptions{Disabled: true},
		Outbounds: []option.Outbound{
			direct("first"),
			direct("second"),
			{
				Type:    C.TypeSelector,
				Tag:     "proxy",
				Options: &option.SelectorOutboundOptions{Outbounds: []string{"first", "second"}},
			},
		},
	}
}

// newBoxEngine leaves the package directory, because a box with a platform
// writer always keeps a cache file in its working directory.
func newBoxEngine(t *testing.T) *BoxEngine {
	t.Helper()
	t.Chdir(t.TempDir())
	return NewBoxEngine()
}

func TestBoxEngineRunsAndCloses(t *testing.T) {
	engine := newBoxEngine(t)
	require.NoError(t, engine.Start(selectorOptions()))
	require.Error(t, engine.Start(selectorOptions()), "a second box must not start")
	require.NoError(t, engine.Close())
	require.NoError(t, engine.Close(), "closing twice is harmless")
	require.NoError(t, engine.Start(selectorOptions()), "the engine restarts after a close")
	require.NoError(t, engine.Close())
}

func TestBoxEngineSelectsAMember(t *testing.T) {
	engine := newBoxEngine(t)
	require.NoError(t, engine.Start(selectorOptions()))
	defer func() { require.NoError(t, engine.Close()) }()

	require.NoError(t, engine.Select("proxy", "second"))
	require.Error(t, engine.Select("proxy", "unknown"))
	require.Error(t, engine.Select("missing", "first"))
	require.Error(t, engine.Select("first", "second"), "a direct outbound is not a selector")
}

func TestBoxEngineCountsTraffic(t *testing.T) {
	engine := newBoxEngine(t)
	require.NoError(t, engine.Start(selectorOptions()))
	defer func() { require.NoError(t, engine.Close()) }()

	up, down, ok := engine.Traffic()
	require.True(t, ok)
	require.Zero(t, up)
	require.Zero(t, down)
}

func TestIdleBoxEngineRefuses(t *testing.T) {
	engine := NewBoxEngine()
	require.Error(t, engine.Select("proxy", "first"))
	_, _, ok := engine.Traffic()
	require.False(t, ok)
	_, err := engine.URLTest(context.Background(), "first", "http://127.0.0.1:1")
	require.Error(t, err)
}

func TestBoxEngineURLTestsThroughAnOutbound(t *testing.T) {
	var heads atomic.Int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodHead {
			heads.Add(1)
		}
		w.WriteHeader(http.StatusNoContent)
	}))
	defer server.Close()

	engine := newBoxEngine(t)
	require.NoError(t, engine.Start(selectorOptions()))
	defer func() { require.NoError(t, engine.Close()) }()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_, err := engine.URLTest(ctx, "first", server.URL+"/generate_204")
	require.NoError(t, err)
	require.Equal(t, int32(1), heads.Load())

	_, err = engine.URLTest(ctx, "missing", server.URL)
	require.Error(t, err)
}

func TestBoxEngineURLTestFailsOnAClosedPort(t *testing.T) {
	server := httptest.NewServer(http.NotFoundHandler())
	closed := server.URL
	server.Close()

	engine := newBoxEngine(t)
	require.NoError(t, engine.Start(selectorOptions()))
	defer func() { require.NoError(t, engine.Close()) }()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_, err := engine.URLTest(ctx, "first", closed)
	require.Error(t, err)
}
