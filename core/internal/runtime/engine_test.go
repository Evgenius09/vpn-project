package runtime

import (
	"testing"

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
}
