package config_test

import (
	"encoding/json"
	"errors"
	"net/netip"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
	"time"

	C "github.com/sagernet/sing-box/constant"
	"github.com/sagernet/sing-box/option"
	"github.com/stretchr/testify/require"

	"github.com/Evgenius09/vpn-project/core/internal/config"
	"github.com/Evgenius09/vpn-project/core/internal/contract"
)

func windows() contract.TunnelRequest { return request(contract.PlatformWindows) }
func android() contract.TunnelRequest { return request(contract.PlatformAndroid) }

func TestFixturesPassTheBox(t *testing.T) {
	paths, err := filepath.Glob(filepath.Join(fixturesDir, "tunnel_request", "*.json"))
	require.NoError(t, err)
	require.NotEmpty(t, paths)
	for _, path := range paths {
		t.Run(filepath.Base(path), func(t *testing.T) {
			raw, err := os.ReadFile(path)
			require.NoError(t, err)
			var req contract.TunnelRequest
			require.NoError(t, json.Unmarshal(raw, &req))
			requireBoxAccepts(t, build(t, req))
		})
	}
}

func TestVlessOutbound(t *testing.T) {
	options := build(t, windows())
	vless := outbound[option.VLESSOutboundOptions](t, options, config.ServerTag(regularVless))

	require.Equal(t, "de.example.net", vless.Server)
	require.EqualValues(t, 443, vless.ServerPort)
	require.Equal(t, vlessSecret, vless.UUID)
	require.Equal(t, "xtls-rprx-vision", vless.Flow)
	require.Equal(t, "xudp", *vless.PacketEncoding)
	require.Nil(t, vless.Multiplex, "tech.md 5.8 never allows multiplex on VLESS")

	tls := vless.TLS
	require.True(t, tls.Enabled)
	require.Equal(t, "www.example.com", tls.ServerName)
	require.True(t, tls.UTLS.Enabled)
	require.Equal(t, "chrome", tls.UTLS.Fingerprint)
	require.True(t, tls.Reality.Enabled)
	require.Equal(t, realityKey, tls.Reality.PublicKey)
	require.Equal(t, "0123456789abcdef", tls.Reality.ShortID)
}

func TestHysteria2Outbound(t *testing.T) {
	salamander := "obfs-secret"
	up, down := 50, 200
	req := windows()
	params := req.Servers[1].Hysteria2
	params.ObfsSalamanderPassword = &salamander
	params.UpMbps, params.DownMbps = &up, &down
	params.PortHopping = &contract.PortHopping{Ports: "20000-30000", IntervalSec: 30}

	options := build(t, req)
	hysteria := outbound[option.Hysteria2OutboundOptions](t, options, config.ServerTag(regularHysteria))

	require.Equal(t, "203.0.113.7", hysteria.Server)
	require.EqualValues(t, 8443, hysteria.ServerPort)
	require.Equal(t, hysteriaSecret, hysteria.Password)
	require.Equal(t, []string{"20000:30000"}, []string(hysteria.ServerPorts))
	require.Equal(t, 30*time.Second, time.Duration(hysteria.HopInterval))
	require.Equal(t, 50, hysteria.UpMbps)
	require.Equal(t, 200, hysteria.DownMbps)
	require.Equal(t, "salamander", hysteria.Obfs.Type)
	require.Equal(t, salamander, hysteria.Obfs.Password)
	require.True(t, hysteria.TLS.Enabled)
	require.Equal(t, "hy.example.com", hysteria.TLS.ServerName)
	requireBoxAccepts(t, options)
}

func TestHysteria2WithoutOptionalParams(t *testing.T) {
	options := build(t, windows())
	hysteria := outbound[option.Hysteria2OutboundOptions](t, options, config.ServerTag(regularHysteria))
	require.Empty(t, hysteria.ServerPorts)
	require.Zero(t, hysteria.HopInterval)
	require.Nil(t, hysteria.Obfs)
}

func TestPortHoppingFormats(t *testing.T) {
	cases := map[string][]string{
		"20000-30000":     {"20000:30000"},
		"443,8443":        {"443:443", "8443:8443"},
		"443, 8443":       {"443:443", "8443:8443"},
		"443":             {"443:443"},
		"443,20000-20010": {"443:443", "20000:20010"},
	}
	for ports, want := range cases {
		t.Run(ports, func(t *testing.T) {
			req := windows()
			req.Servers[1].Hysteria2.PortHopping = &contract.PortHopping{Ports: ports, IntervalSec: 30}
			options := build(t, req)
			hysteria := outbound[option.Hysteria2OutboundOptions](t, options, config.ServerTag(regularHysteria))
			require.Equal(t, want, []string(hysteria.ServerPorts))
			requireBoxAccepts(t, options)
		})
	}
}

func TestGroupsAndSelectors(t *testing.T) {
	options := build(t, windows())

	regular := outbound[option.SelectorOutboundOptions](t, options, config.GroupTag(contract.TunnelModeRegular))
	require.Equal(t, []string{config.ServerTag(regularVless), config.ServerTag(regularHysteria)}, regular.Outbounds)
	whitelist := outbound[option.SelectorOutboundOptions](t, options, config.GroupTag(contract.TunnelModeWhitelist))
	require.Equal(t, []string{config.ServerTag(whitelistVless)}, whitelist.Outbounds)

	proxy := outbound[option.SelectorOutboundOptions](t, options, config.TagProxy)
	require.Equal(t, []string{"grp-regular", "grp-whitelist"}, proxy.Outbounds)
	require.Equal(t, "grp-regular", proxy.Default)
	require.True(t, proxy.InterruptExistConnections)

	require.True(t, hasOutbound(options, "direct"))
	require.Equal(t, "proxy", options.Route.Final)
}

func TestTagsMatchTheContract(t *testing.T) {
	require.Equal(t, "srv-abc", config.ServerTag("abc"))
	require.Equal(t, "grp-regular", config.GroupTag(contract.TunnelModeRegular))
	require.Equal(t, "grp-whitelist", config.GroupTag(contract.TunnelModeWhitelist))
}

func TestProxyDefaultsToTheUserMode(t *testing.T) {
	req := windows()
	req.UserMode = contract.TunnelModeWhitelist
	proxy := outbound[option.SelectorOutboundOptions](t, build(t, req), config.TagProxy)
	require.Equal(t, "grp-whitelist", proxy.Default)
}

func TestEmptyGroupIsNotCreated(t *testing.T) {
	req := windows()
	req.Servers = req.Servers[:2]
	options := build(t, req)

	require.False(t, hasOutbound(options, "grp-whitelist"))
	proxy := outbound[option.SelectorOutboundOptions](t, options, config.TagProxy)
	require.Equal(t, []string{"grp-regular"}, proxy.Outbounds)
	requireBoxAccepts(t, options)
}

func TestEmptyUserModeGroupFails(t *testing.T) {
	req := windows()
	req.UserMode = contract.TunnelModeWhitelist
	req.Servers = req.Servers[:2]
	requireCode(t, req, contract.CoreErrorCodeNoServersInGroup)
}

func TestSelectedServerIsTheGroupDefault(t *testing.T) {
	selected := regularHysteria
	req := windows()
	req.Selected.Regular = &selected
	regular := outbound[option.SelectorOutboundOptions](t, build(t, req), "grp-regular")
	require.Equal(t, config.ServerTag(regularHysteria), regular.Default)
}

func TestMissingSelectionFallsToTheLowestWeight(t *testing.T) {
	missing := "not-in-the-request"
	otherGroup := whitelistVless
	for name, selected := range map[string]*string{"none": nil, "missing": &missing, "other group": &otherGroup} {
		t.Run(name, func(t *testing.T) {
			req := windows()
			req.Servers[0].SortWeight, req.Servers[1].SortWeight = 20, 10
			req.Selected.Regular = selected
			regular := outbound[option.SelectorOutboundOptions](t, build(t, req), "grp-regular")
			require.Equal(t, config.ServerTag(regularHysteria), regular.Default)
		})
	}
}

func TestRuleOrder(t *testing.T) {
	req := windows()
	req.Settings.Routing.Rules = []contract.RoutingRule{{
		Id: "r1", Match: contract.RuleMatchDomainSuffix, Value: "example.ru", Action: contract.RuleActionDirect,
	}}
	req.Settings.PerApp = contract.PerAppSettings{Mode: contract.PerAppModeExclude, Apps: []string{"steam.exe"}}
	options := build(t, req)

	sniff := indexOfAction(options, C.RuleActionTypeSniff)
	hijack := indexOfAction(options, C.RuleActionTypeHijackDNS)
	lan := routedTo(options, "direct", func(rule option.RawDefaultRule) bool { return rule.IPIsPrivate })
	servers := routedTo(options, "direct", func(rule option.RawDefaultRule) bool {
		return slices.Contains(rule.Domain, "de.example.net")
	})
	user := routedTo(options, "direct", func(rule option.RawDefaultRule) bool {
		return slices.Contains(rule.DomainSuffix, "example.ru")
	})
	perApp := routedTo(options, "direct", func(rule option.RawDefaultRule) bool {
		return slices.Contains(rule.ProcessName, "steam.exe")
	})

	require.True(t, sniff == 0 && sniff < hijack && hijack < lan && lan < servers && servers < user && user < perApp,
		"sniff %d, hijack %d, lan %d, servers %d, user %d, per app %d", sniff, hijack, lan, servers, user, perApp)
}

func TestSniffingAndLanBypassAreOptional(t *testing.T) {
	req := windows()
	req.Settings.Net.Sniffing = false
	req.Settings.Net.BypassLan = false
	options := build(t, req)

	require.Equal(t, -1, indexOfAction(options, C.RuleActionTypeSniff))
	require.Equal(t, -1, routedTo(options, "direct", func(rule option.RawDefaultRule) bool { return rule.IPIsPrivate }))
	require.NotEqual(t, -1, indexOfAction(options, C.RuleActionTypeHijackDNS), "DNS stays hijacked")
}

func TestServerAddressesGoDirect(t *testing.T) {
	req := windows()
	req.Servers = append(req.Servers, vlessServer("v6", contract.TunnelModeRegular, "2001:db8::7", 30))
	options := build(t, req)

	for _, domain := range []string{"de.example.net", "ru.example.net"} {
		require.NotEqual(t, -1, routedTo(options, "direct", func(rule option.RawDefaultRule) bool {
			return slices.Contains(rule.Domain, domain)
		}), domain)
	}
	for _, cidr := range []string{"203.0.113.7/32", "2001:db8::7/128"} {
		require.NotEqual(t, -1, routedTo(options, "direct", func(rule option.RawDefaultRule) bool {
			return slices.Contains(rule.IPCIDR, cidr)
		}), cidr)
	}
	requireBoxAccepts(t, options)
}

func TestUserRules(t *testing.T) {
	cases := []struct {
		name  string
		match contract.RuleMatch
		value string
		field func(option.RawDefaultRule) []string
	}{
		{"domain", contract.RuleMatchDomain, "a.example.ru", func(r option.RawDefaultRule) []string { return r.Domain }},
		{"suffix", contract.RuleMatchDomainSuffix, "example.ru", func(r option.RawDefaultRule) []string { return r.DomainSuffix }},
		{"keyword", contract.RuleMatchDomainKeyword, "ads", func(r option.RawDefaultRule) []string { return r.DomainKeyword }},
		{"cidr", contract.RuleMatchIpCidr, "192.0.2.0/24", func(r option.RawDefaultRule) []string { return r.IPCIDR }},
		{"rule set", contract.RuleMatchRuleSet, "ru-direct", func(r option.RawDefaultRule) []string { return r.RuleSet }},
	}
	for _, testCase := range cases {
		t.Run(testCase.name, func(t *testing.T) {
			req := windows()
			req.Settings.Routing.RuleSets = []contract.LocalRuleSet{{Id: "ru-direct", Path: "rulesets/ru-direct.srs"}}
			req.Settings.Routing.Rules = []contract.RoutingRule{{
				Id: "r1", Match: testCase.match, Value: testCase.value, Action: contract.RuleActionProxy,
			}}
			options := build(t, req)
			require.NotEqual(t, -1, routedTo(options, "proxy", func(rule option.RawDefaultRule) bool {
				return slices.Contains(testCase.field(rule), testCase.value)
			}))
			requireBoxAccepts(t, options)
		})
	}
}

func TestUserRulesKeepTheirOrder(t *testing.T) {
	req := windows()
	req.Settings.Routing.Rules = []contract.RoutingRule{
		{Id: "r1", Match: contract.RuleMatchDomain, Value: "b.example", Action: contract.RuleActionDirect},
		{Id: "r2", Match: contract.RuleMatchDomain, Value: "a.example", Action: contract.RuleActionProxy},
	}
	options := build(t, req)
	first := routedTo(options, "direct", func(rule option.RawDefaultRule) bool { return slices.Contains(rule.Domain, "b.example") })
	second := routedTo(options, "proxy", func(rule option.RawDefaultRule) bool { return slices.Contains(rule.Domain, "a.example") })
	require.Less(t, first, second)
}

func TestBlockRejectsInsteadOfUsingAnOutbound(t *testing.T) {
	req := windows()
	req.Settings.Routing.Rules = []contract.RoutingRule{{
		Id: "r1", Match: contract.RuleMatchDomain, Value: "ads.example", Action: contract.RuleActionBlock,
	}}
	options := build(t, req)

	index := indexOfAction(options, C.RuleActionTypeReject)
	require.NotEqual(t, -1, index)
	require.Contains(t, options.Route.Rules[index].DefaultOptions.Domain, "ads.example")
	require.False(t, hasOutbound(options, "block"))
}

func TestAppRuleFollowsThePlatform(t *testing.T) {
	rule := contract.RoutingRule{Id: "r1", Match: contract.RuleMatchApp, Value: "org.telegram", Action: contract.RuleActionProxy}

	req := android()
	req.Settings.Routing.Rules = []contract.RoutingRule{rule}
	options := build(t, req)
	require.NotEqual(t, -1, routedTo(options, "proxy", func(r option.RawDefaultRule) bool {
		return slices.Contains(r.PackageName, "org.telegram")
	}))
	require.False(t, options.Route.FindProcess)

	req = windows()
	req.Settings.Routing.Rules = []contract.RoutingRule{rule}
	options = build(t, req)
	require.NotEqual(t, -1, routedTo(options, "proxy", func(r option.RawDefaultRule) bool {
		return slices.Contains(r.ProcessName, "org.telegram")
	}))
	require.True(t, options.Route.FindProcess, "process_name matches nothing without find_process")
}

func TestDisabledRoutingDropsRulesAndRuleSets(t *testing.T) {
	req := windows()
	req.Settings.Routing.Enabled = false
	req.Settings.Routing.RuleSets = []contract.LocalRuleSet{{Id: "ru-direct", Path: "rulesets/ru-direct.srs"}}
	req.Settings.Routing.Rules = []contract.RoutingRule{{
		Id: "r1", Match: contract.RuleMatchDomain, Value: "user.example", Action: contract.RuleActionBlock,
	}}
	options := build(t, req)

	require.Equal(t, -1, indexOfAction(options, C.RuleActionTypeReject))
	require.Empty(t, options.Route.RuleSet)
	require.Equal(t, "proxy", options.Route.Final)
}

func TestRuleSetsAreLocalBinaryFiles(t *testing.T) {
	req := windows()
	req.Settings.Routing.RuleSets = []contract.LocalRuleSet{{Id: "ru-direct", Path: "rulesets/ru-direct.srs"}}
	options := build(t, req)

	require.Len(t, options.Route.RuleSet, 1)
	ruleSet := options.Route.RuleSet[0]
	require.Equal(t, C.RuleSetTypeLocal, ruleSet.Type)
	require.Equal(t, C.RuleSetFormatBinary, ruleSet.Format)
	require.Equal(t, []string{"ru-direct"}, []string(ruleSet.Tag))
	require.Equal(t, "rulesets/ru-direct.srs", ruleSet.LocalOptions.Path)
}

func TestDNS(t *testing.T) {
	options := build(t, windows())
	require.Equal(t, "dns-remote", options.DNS.Final)
	require.Equal(t, option.DomainStrategy(C.DomainStrategyPreferIPv4), options.DNS.Strategy)
	require.Len(t, options.DNS.Servers, 2)

	remote := options.DNS.Servers[0]
	require.Equal(t, C.DNSTypeHTTPS, remote.Type, "only the 1.12 server format is allowed")
	https, ok := remote.Options.(*option.RemoteHTTPSDNSServerOptions)
	require.True(t, ok)
	require.Equal(t, "1.1.1.1", https.Server)
	require.Equal(t, "/dns-query", https.Path)
	require.Equal(t, "proxy", https.Detour, "the remote server has to stay inside the tunnel")

	direct := options.DNS.Servers[1]
	require.Equal(t, C.DNSTypeUDP, direct.Type)
	udp, ok := direct.Options.(*option.RemoteDNSServerOptions)
	require.True(t, ok)
	require.Equal(t, "77.88.8.8", udp.Server)
	require.Empty(t, udp.Detour, "sing-box refuses a detour to the empty direct outbound")

	require.Equal(t, "dns-direct", options.Route.DefaultDomainResolver.Server,
		"server domains cannot resolve through the tunnel they open")
	require.True(t, options.Route.AutoDetectInterface, "without it a TUN routes its own traffic back into itself")
	requireBoxAccepts(t, options)
}

func TestDNSAcceptsDoHForDirect(t *testing.T) {
	req := windows()
	req.Settings.Dns.Direct = "https://77.88.8.8:8443/custom"
	options := build(t, req)

	https, ok := options.DNS.Servers[1].Options.(*option.RemoteHTTPSDNSServerOptions)
	require.True(t, ok)
	require.Equal(t, "77.88.8.8", https.Server)
	require.EqualValues(t, 8443, https.ServerPort)
	require.Equal(t, "/custom", https.Path)
	require.Empty(t, https.Detour)
	requireBoxAccepts(t, options)
}

func TestDNSWithDomainsHasABootstrap(t *testing.T) {
	req := windows()
	req.Settings.Dns.Remote = "https://dns.google/dns-query"
	req.Settings.Dns.Direct = "https://dns.yandex.net/dns-query"
	requireBoxAccepts(t, build(t, req))
}

func TestStrategies(t *testing.T) {
	cases := map[contract.DnsStrategy]uint8{
		contract.DnsStrategyPreferIpv4: C.DomainStrategyPreferIPv4,
		contract.DnsStrategyPreferIpv6: C.DomainStrategyPreferIPv6,
		contract.DnsStrategyIpv4Only:   C.DomainStrategyIPv4Only,
		contract.DnsStrategyIpv6Only:   C.DomainStrategyIPv6Only,
	}
	for strategy, want := range cases {
		t.Run(string(strategy), func(t *testing.T) {
			req := windows()
			req.Settings.Dns.Strategy = strategy
			require.Equal(t, option.DomainStrategy(want), build(t, req).DNS.Strategy)

			req.Settings.Net.Ipv6 = false
			require.Equal(t, option.DomainStrategy(C.DomainStrategyIPv4Only), build(t, req).DNS.Strategy,
				"net.ipv6 = false forces ipv4_only")
		})
	}
}

func TestTun(t *testing.T) {
	req := windows()
	req.Settings.Net.Mtu = 1400
	req.Settings.Net.TunStack = contract.TunStackGvisor
	req.Settings.Net.ExcludeRoutes = []string{"10.0.0.0/8"}
	tun := tunOf(t, build(t, req))

	require.Equal(t, []netip.Prefix{
		netip.MustParsePrefix("172.19.0.1/30"), netip.MustParsePrefix("fdfe:dcba:9876::1/126"),
	}, []netip.Prefix(tun.Address))
	require.EqualValues(t, 1400, tun.MTU)
	require.Equal(t, "gvisor", tun.Stack)
	require.True(t, tun.AutoRoute)
	require.True(t, tun.StrictRoute)
	require.Equal(t, []netip.Prefix{netip.MustParsePrefix("10.0.0.0/8")}, []netip.Prefix(tun.RouteExcludeAddress))
}

func TestTunWithoutIPv6(t *testing.T) {
	req := windows()
	req.Settings.Net.Ipv6 = false
	require.Equal(t, []netip.Prefix{netip.MustParsePrefix("172.19.0.1/30")}, []netip.Prefix(tunOf(t, build(t, req)).Address))
}

func TestAndroidPerApp(t *testing.T) {
	own := config.AndroidPackage
	require.Equal(t, "com.vpnclient.app", own)
	cases := []struct {
		name    string
		mode    contract.PerAppMode
		apps    []string
		include []string
		exclude []string
	}{
		{"off", contract.PerAppModeOff, []string{"org.ignored"}, nil, []string{own}},
		{"include", contract.PerAppModeInclude, []string{"org.a", "org.b"}, []string{"org.a", "org.b"}, []string{own}},
		{"include drops the app itself", contract.PerAppModeInclude, []string{own, "org.a"}, []string{"org.a"}, []string{own}},
		{"exclude", contract.PerAppModeExclude, []string{"org.a"}, nil, []string{"org.a", own}},
		{"exclude keeps one copy", contract.PerAppModeExclude, []string{own}, nil, []string{own}},
	}
	for _, testCase := range cases {
		t.Run(testCase.name, func(t *testing.T) {
			req := android()
			req.Settings.PerApp = contract.PerAppSettings{Mode: testCase.mode, Apps: testCase.apps}
			options := build(t, req)
			tun := tunOf(t, options)
			require.Equal(t, testCase.include, []string(tun.IncludePackage))
			require.Equal(t, testCase.exclude, []string(tun.ExcludePackage))
			require.Equal(t, "proxy", options.Route.Final)
			require.False(t, options.Route.FindProcess)
			requireBoxAccepts(t, options)
		})
	}
}

func TestWindowsPerAppInclude(t *testing.T) {
	req := windows()
	req.Settings.PerApp = contract.PerAppSettings{Mode: contract.PerAppModeInclude, Apps: []string{"telegram.exe"}}
	options := build(t, req)

	require.Equal(t, "direct", options.Route.Final)
	require.True(t, options.Route.FindProcess)
	require.NotEqual(t, -1, routedTo(options, "proxy", func(rule option.RawDefaultRule) bool {
		return slices.Contains(rule.ProcessName, "telegram.exe")
	}))
	requireBoxAccepts(t, options)
}

func TestWindowsPerAppExclude(t *testing.T) {
	req := windows()
	req.Settings.PerApp = contract.PerAppSettings{Mode: contract.PerAppModeExclude, Apps: []string{"steam.exe"}}
	options := build(t, req)

	require.Equal(t, "proxy", options.Route.Final)
	require.True(t, options.Route.FindProcess)
	require.NotEqual(t, -1, routedTo(options, "direct", func(rule option.RawDefaultRule) bool {
		return slices.Contains(rule.ProcessName, "steam.exe")
	}))
}

func TestWindowsPerAppExcludeWithoutAppsAddsNoCatchAll(t *testing.T) {
	req := windows()
	req.Settings.PerApp = contract.PerAppSettings{Mode: contract.PerAppModeExclude, Apps: []string{}}
	options := build(t, req)
	for _, rule := range options.Route.Rules {
		if rule.Type == C.RuleTypeDefault {
			require.True(t, ruleHasCondition(rule.DefaultOptions.RawDefaultRule), "a rule without conditions matches everything")
		}
	}
}

func ruleHasCondition(rule option.RawDefaultRule) bool {
	return len(rule.Inbound)+len(rule.Domain)+len(rule.DomainSuffix)+len(rule.DomainKeyword)+len(rule.IPCIDR)+
		len(rule.ProcessName)+len(rule.PackageName)+len(rule.RuleSet) > 0 || rule.IPIsPrivate
}

func TestWindowsPerAppOffLeavesFindProcessOff(t *testing.T) {
	require.False(t, build(t, windows()).Route.FindProcess)
}

func TestTLSFragment(t *testing.T) {
	req := windows()
	options := build(t, req)
	tls := outbound[option.VLESSOutboundOptions](t, options, config.ServerTag(regularVless)).TLS
	require.False(t, tls.Fragment)
	require.False(t, tls.RecordFragment)

	req.Settings.Net.TlsFragment = contract.TlsFragment{Enabled: true, Record: true}
	options = build(t, req)
	tls = outbound[option.VLESSOutboundOptions](t, options, config.ServerTag(regularVless)).TLS
	require.True(t, tls.Fragment)
	require.True(t, tls.RecordFragment)
	requireBoxAccepts(t, options)
}

func TestRecordFragmentIsIndependent(t *testing.T) {
	req := windows()
	req.Settings.Net.TlsFragment = contract.TlsFragment{Record: true}
	tls := outbound[option.VLESSOutboundOptions](t, build(t, req), config.ServerTag(regularVless)).TLS
	require.False(t, tls.Fragment)
	require.True(t, tls.RecordFragment)
}

func TestCacheFileAndLog(t *testing.T) {
	req := windows()
	req.Log.Level = contract.LogLevelDebug
	options := build(t, req)
	require.True(t, options.Experimental.CacheFile.Enabled)
	require.Equal(t, "debug", options.Log.Level)
}

func requireCode(t *testing.T, req contract.TunnelRequest, code contract.CoreErrorCode) {
	t.Helper()
	_, err := config.BuildOptions(req)
	require.Error(t, err)
	var configError *config.Error
	require.True(t, errors.As(err, &configError), "%T", err)
	require.Equal(t, code, configError.Code)
	require.NotEmpty(t, configError.Message)
}

func TestInvalidRequests(t *testing.T) {
	longKey := strings.Repeat("a", 44)
	cases := map[string]func(*contract.TunnelRequest){
		"schema version":        func(r *contract.TunnelRequest) { r.SchemaVersion = 2 },
		"platform":              func(r *contract.TunnelRequest) { r.Platform = "ios" },
		"user mode":             func(r *contract.TunnelRequest) { r.UserMode = "fast" },
		"log level":             func(r *contract.TunnelRequest) { r.Log.Level = "trace" },
		"no servers":            func(r *contract.TunnelRequest) { r.Servers = nil },
		"blank server id":       func(r *contract.TunnelRequest) { r.Servers[0].Id = "" },
		"duplicate server id":   func(r *contract.TunnelRequest) { r.Servers[1].Id = r.Servers[0].Id },
		"server group":          func(r *contract.TunnelRequest) { r.Servers[0].Group = "other" },
		"blank address":         func(r *contract.TunnelRequest) { r.Servers[0].Address = " " },
		"port zero":             func(r *contract.TunnelRequest) { r.Servers[0].Port = 0 },
		"port too big":          func(r *contract.TunnelRequest) { r.Servers[0].Port = 65536 },
		"protocol":              func(r *contract.TunnelRequest) { r.Servers[0].Protocol = "wireguard" },
		"vless params missing":  func(r *contract.TunnelRequest) { r.Servers[0].Vless = nil },
		"vless uuid":            func(r *contract.TunnelRequest) { r.Servers[0].Vless.Uuid = "not-a-uuid" },
		"vless flow":            func(r *contract.TunnelRequest) { r.Servers[0].Vless.Flow = "xtls-rprx-direct" },
		"vless server name":     func(r *contract.TunnelRequest) { r.Servers[0].Vless.ServerName = "" },
		"reality key":           func(r *contract.TunnelRequest) { r.Servers[0].Vless.PublicKey = "short" },
		"reality key length":    func(r *contract.TunnelRequest) { r.Servers[0].Vless.PublicKey = longKey },
		"reality short id hex":  func(r *contract.TunnelRequest) { r.Servers[0].Vless.ShortId = "zz" },
		"reality short id odd":  func(r *contract.TunnelRequest) { r.Servers[0].Vless.ShortId = "abc" },
		"reality short id long": func(r *contract.TunnelRequest) { r.Servers[0].Vless.ShortId = "0123456789abcdef00" },
		"fingerprint":           func(r *contract.TunnelRequest) { r.Servers[0].Vless.Fingerprint = "opera" },
		"hysteria2 missing":     func(r *contract.TunnelRequest) { r.Servers[1].Hysteria2 = nil },
		"hysteria2 password":    func(r *contract.TunnelRequest) { r.Servers[1].Hysteria2.Password = "" },
		"hysteria2 server name": func(r *contract.TunnelRequest) { r.Servers[1].Hysteria2.ServerName = "" },
		"hop ports": func(r *contract.TunnelRequest) {
			r.Servers[1].Hysteria2.PortHopping = &contract.PortHopping{Ports: "a-b", IntervalSec: 30}
		},
		"hop range reversed": func(r *contract.TunnelRequest) {
			r.Servers[1].Hysteria2.PortHopping = &contract.PortHopping{Ports: "3000-2000", IntervalSec: 30}
		},
		"hop port zero": func(r *contract.TunnelRequest) {
			r.Servers[1].Hysteria2.PortHopping = &contract.PortHopping{Ports: "0-10", IntervalSec: 30}
		},
		"hop interval": func(r *contract.TunnelRequest) {
			r.Servers[1].Hysteria2.PortHopping = &contract.PortHopping{Ports: "443", IntervalSec: 0}
		},
		"preset": func(r *contract.TunnelRequest) { r.Settings.Routing.Preset = "other" },
		"rule match": func(r *contract.TunnelRequest) {
			r.Settings.Routing.Rules = []contract.RoutingRule{rule("regex", "x", "proxy")}
		},
		"rule action": func(r *contract.TunnelRequest) {
			r.Settings.Routing.Rules = []contract.RoutingRule{rule("domain", "x", "drop")}
		},
		"blank rule value": func(r *contract.TunnelRequest) {
			r.Settings.Routing.Rules = []contract.RoutingRule{rule("domain", " ", "proxy")}
		},
		"rule cidr": func(r *contract.TunnelRequest) {
			r.Settings.Routing.Rules = []contract.RoutingRule{rule("ip_cidr", "999.0.0.0/8", "proxy")}
		},
		"unknown rule set": func(r *contract.TunnelRequest) {
			r.Settings.Routing.Rules = []contract.RoutingRule{rule("rule_set", "nope", "proxy")}
		},
		"blank rule set id": func(r *contract.TunnelRequest) {
			r.Settings.Routing.RuleSets = []contract.LocalRuleSet{{Path: "a.srs"}}
		},
		"blank rule set path": func(r *contract.TunnelRequest) {
			r.Settings.Routing.RuleSets = []contract.LocalRuleSet{{Id: "a"}}
		},
		"duplicate rule set": func(r *contract.TunnelRequest) {
			r.Settings.Routing.RuleSets = []contract.LocalRuleSet{{Id: "a", Path: "a.srs"}, {Id: "a", Path: "b.srs"}}
		},
		"remote not https": func(r *contract.TunnelRequest) { r.Settings.Dns.Remote = "http://1.1.1.1/dns-query" },
		"remote not a url": func(r *contract.TunnelRequest) { r.Settings.Dns.Remote = "1.1.1.1" },
		"direct garbage":   func(r *contract.TunnelRequest) { r.Settings.Dns.Direct = "not an address" },
		"direct blank":     func(r *contract.TunnelRequest) { r.Settings.Dns.Direct = "" },
		"dns strategy":     func(r *contract.TunnelRequest) { r.Settings.Dns.Strategy = "as_is" },
		"mtu low":          func(r *contract.TunnelRequest) { r.Settings.Net.Mtu = 1279 },
		"mtu high":         func(r *contract.TunnelRequest) { r.Settings.Net.Mtu = 9001 },
		"tun stack":        func(r *contract.TunnelRequest) { r.Settings.Net.TunStack = "lwip" },
		"exclude route":    func(r *contract.TunnelRequest) { r.Settings.Net.ExcludeRoutes = []string{"10.0.0.0"} },
		"per app mode":     func(r *contract.TunnelRequest) { r.Settings.PerApp.Mode = "all" },
		"blank per app": func(r *contract.TunnelRequest) {
			r.Settings.PerApp = contract.PerAppSettings{Mode: contract.PerAppModeExclude, Apps: []string{" "}}
		},
		"include no apps": func(r *contract.TunnelRequest) {
			r.Settings.PerApp = contract.PerAppSettings{Mode: contract.PerAppModeInclude, Apps: []string{}}
		},
	}
	for name, spoil := range cases {
		t.Run(name, func(t *testing.T) {
			req := windows()
			spoil(&req)
			requireCode(t, req, contract.CoreErrorCodeConfigInvalid)
		})
	}
}

func TestAndroidIncludeOfOnlyItselfFails(t *testing.T) {
	req := android()
	req.Settings.PerApp = contract.PerAppSettings{Mode: contract.PerAppModeInclude, Apps: []string{config.AndroidPackage}}
	requireCode(t, req, contract.CoreErrorCodeConfigInvalid)
}

func rule(match contract.RuleMatch, value string, action contract.RuleAction) contract.RoutingRule {
	return contract.RoutingRule{Id: "r", Match: match, Value: value, Action: action}
}

// TestEverySpoiledSecretStaysOutOfTheError covers C6 for the rejection path:
// the error reaches the app and the log.
func TestEverySpoiledSecretStaysOutOfTheError(t *testing.T) {
	const secret = "visible-secret-value"

	req := windows()
	req.Servers[0].Vless.Uuid = secret
	_, err := config.BuildOptions(req)
	require.Error(t, err)
	require.NotContains(t, err.Error(), secret)

	req = windows()
	req.Servers[0].Vless.PublicKey = secret
	_, err = config.BuildOptions(req)
	require.Error(t, err)
	require.NotContains(t, err.Error(), secret)
}
