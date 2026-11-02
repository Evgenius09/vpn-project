package config_test

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"testing"

	box "github.com/sagernet/sing-box"
	"github.com/sagernet/sing-box/common/srs"
	C "github.com/sagernet/sing-box/constant"
	"github.com/sagernet/sing-box/include"
	"github.com/sagernet/sing-box/option"
	"github.com/sagernet/sing/common/json"
	"github.com/stretchr/testify/require"
	"pgregory.net/rapid"

	"github.com/Evgenius09/vpn-project/core/internal/config"
	"github.com/Evgenius09/vpn-project/core/internal/contract"
)

const (
	vlessSecret    = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
	hysteriaSecret = "hysteria2-secret-password"
	realityKey     = "YNSIc4L0W_A9M1wbXF_Gf5Otbun1wovS3NCVIwIPY2A"

	regularVless    = "11111111-1111-4111-8111-111111111111"
	regularHysteria = "22222222-2222-4222-8222-222222222222"
	whitelistVless  = "33333333-3333-4333-8333-333333333333"
)

// fixturesDir is absolute because TestMain leaves the package directory.
var fixturesDir string

// TestMain runs from a directory laid out like the vpnsvc data directory:
// box.New already opens local rule sets, and the fixtures use relative paths.
func TestMain(m *testing.M) {
	if err := enterRuleSetDir(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	os.Exit(m.Run())
}

func enterRuleSetDir() error {
	var err error
	if fixturesDir, err = filepath.Abs("../../../contracts/fixtures"); err != nil {
		return err
	}
	dir, err := os.MkdirTemp("", "config-test")
	if err != nil {
		return err
	}
	if err := os.Mkdir(filepath.Join(dir, "rulesets"), 0o700); err != nil {
		return err
	}
	file, err := os.Create(filepath.Join(dir, "rulesets", "ru-direct.srs"))
	if err != nil {
		return err
	}
	err = srs.Write(file, option.PlainRuleSet{Rules: []option.HeadlessRule{{
		Type:           C.RuleTypeDefault,
		DefaultOptions: option.DefaultHeadlessRule{DomainSuffix: []string{"example.ru"}},
	}}}, C.RuleSetVersionCurrent)
	if closeErr := file.Close(); err == nil {
		err = closeErr
	}
	if err != nil {
		return err
	}
	return os.Chdir(dir)
}

func vlessServer(id string, group contract.TunnelMode, address string, weight int) contract.ServerNode {
	return contract.ServerNode{
		Id:         id,
		Group:      group,
		Name:       id,
		Protocol:   contract.ServerProtocolVlessReality,
		Address:    address,
		Port:       443,
		SortWeight: weight,
		Vless: &contract.VlessRealityParams{
			Uuid:        vlessSecret,
			Flow:        contract.VlessRealityParamsFlowVision,
			ServerName:  "www.example.com",
			PublicKey:   realityKey,
			ShortId:     "0123456789abcdef",
			Fingerprint: contract.UtlsFingerprintChrome,
		},
	}
}

func hysteriaServer(id string, group contract.TunnelMode, address string, weight int) contract.ServerNode {
	return contract.ServerNode{
		Id:         id,
		Group:      group,
		Name:       id,
		Protocol:   contract.ServerProtocolHysteria2,
		Address:    address,
		Port:       8443,
		SortWeight: weight,
		Hysteria2: &contract.Hysteria2Params{
			Password:   hysteriaSecret,
			ServerName: "hy.example.com",
		},
	}
}

// request returns the smallest valid request with both protocols and groups.
func request(platform contract.Platform) contract.TunnelRequest {
	return contract.TunnelRequest{
		SchemaVersion: 1,
		Platform:      platform,
		UserMode:      contract.TunnelModeRegular,
		Servers: []contract.ServerNode{
			vlessServer(regularVless, contract.TunnelModeRegular, "de.example.net", 10),
			hysteriaServer(regularHysteria, contract.TunnelModeRegular, "203.0.113.7", 20),
			vlessServer(whitelistVless, contract.TunnelModeWhitelist, "ru.example.net", 10),
		},
		Settings: contract.TunnelSettings{
			Routing: contract.RoutingSettings{
				Enabled:  true,
				Preset:   contract.RoutingPresetAllProxy,
				Rules:    []contract.RoutingRule{},
				RuleSets: []contract.LocalRuleSet{},
			},
			Dns: contract.DnsSettings{
				Remote:   "https://1.1.1.1/dns-query",
				Direct:   "77.88.8.8",
				Strategy: contract.DnsStrategyPreferIpv4,
			},
			Net: contract.NetSettings{
				Ipv6:          true,
				Sniffing:      true,
				Mtu:           1500,
				TunStack:      contract.TunStackMixed,
				ExcludeRoutes: []string{},
				BypassLan:     true,
			},
			PerApp: contract.PerAppSettings{Mode: contract.PerAppModeOff, Apps: []string{}},
		},
		Log: contract.TunnelLog{Level: contract.LogLevelWarn},
	}
}

func build(t rapid.TB, req contract.TunnelRequest) option.Options {
	t.Helper()
	options, err := config.BuildOptions(req)
	require.NoError(t, err)
	return options
}

func outbound[T any](t rapid.TB, options option.Options, tag string) *T {
	t.Helper()
	for _, candidate := range options.Outbounds {
		if candidate.Tag == tag {
			typed, ok := candidate.Options.(*T)
			require.True(t, ok, "outbound %s has type %T", tag, candidate.Options)
			return typed
		}
	}
	require.FailNow(t, "outbound not found", tag)
	return nil
}

func hasOutbound(options option.Options, tag string) bool {
	for _, candidate := range options.Outbounds {
		if candidate.Tag == tag {
			return true
		}
	}
	return false
}

func tunOf(t rapid.TB, options option.Options) *option.TunInboundOptions {
	t.Helper()
	require.Len(t, options.Inbounds, 1)
	tun, ok := options.Inbounds[0].Options.(*option.TunInboundOptions)
	require.True(t, ok)
	return tun
}

// routedTo returns the index of the first rule accepted by match that sends
// traffic to the outbound, or -1.
func routedTo(options option.Options, outboundTag string, match func(option.RawDefaultRule) bool) int {
	for index, rule := range options.Route.Rules {
		action := rule.DefaultOptions.RuleAction
		if action.Action == "route" && action.RouteOptions.Outbound == outboundTag && match(rule.DefaultOptions.RawDefaultRule) {
			return index
		}
	}
	return -1
}

func indexOfAction(options option.Options, action string) int {
	for index, rule := range options.Route.Rules {
		if rule.DefaultOptions.Action == action || rule.LogicalOptions.Action == action {
			return index
		}
	}
	return -1
}

// requireBoxAccepts is tech.md C1: the equivalent of sing-box check. Android
// passes the options through JSON, so the encoded form has to work as well.
func requireBoxAccepts(t rapid.TB, options option.Options) {
	t.Helper()
	options.Log = &option.LogOptions{Disabled: true}
	requireNew(t, options)

	ctx := include.Context(context.Background())
	encoded, err := json.MarshalContext(ctx, options)
	require.NoError(t, err)
	decoded, err := json.UnmarshalExtendedContext[option.Options](ctx, encoded)
	require.NoError(t, err, string(encoded))
	requireNew(t, decoded)
}

func requireNew(t rapid.TB, options option.Options) {
	t.Helper()
	ctx, cancel := context.WithCancel(include.Context(context.Background()))
	defer cancel()
	instance, err := box.New(box.Options{Options: options, Context: ctx})
	require.NoError(t, err)
	require.NoError(t, instance.Close())
}

var _ rapid.TB = (*testing.T)(nil)
