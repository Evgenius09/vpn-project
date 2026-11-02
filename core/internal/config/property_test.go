package config_test

import (
	"encoding/base64"
	"fmt"
	"net/netip"
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"testing"

	"github.com/sagernet/sing-box/option"
	"github.com/stretchr/testify/require"
	"pgregory.net/rapid"

	"github.com/Evgenius09/vpn-project/core/internal/config"
	"github.com/Evgenius09/vpn-project/core/internal/contract"
)

var (
	genMode     = rapid.SampledFrom([]contract.TunnelMode{contract.TunnelModeRegular, contract.TunnelModeWhitelist})
	genPlatform = rapid.SampledFrom([]contract.Platform{contract.PlatformAndroid, contract.PlatformWindows})
	genDomain   = rapid.StringMatching(`[a-z][a-z0-9]{0,8}\.(example|test)\.net`)
	genAddress  = rapid.OneOf(
		genDomain,
		rapid.Custom(func(t *rapid.T) string {
			return netip.AddrFrom4([4]byte{198, 51, rapid.Byte().Draw(t, "c"), rapid.Byte().Draw(t, "d")}).String()
		}),
		rapid.Custom(func(t *rapid.T) string {
			return fmt.Sprintf("2001:db8::%x", rapid.IntRange(1, 0xffff).Draw(t, "host"))
		}),
	)
	genCIDR = rapid.Custom(func(t *rapid.T) string {
		addr := netip.AddrFrom4([4]byte{rapid.ByteRange(1, 223).Draw(t, "a"), 0, 0, 0})
		return netip.PrefixFrom(addr, 8).String()
	})
)

func genVless(t *rapid.T) *contract.VlessRealityParams {
	key := rapid.SliceOfN(rapid.Byte(), 32, 32).Draw(t, "key")
	return &contract.VlessRealityParams{
		Uuid: fmt.Sprintf("%08x-0000-4000-8000-000000000000", rapid.Uint32().Draw(t, "uuid")),
		Flow: rapid.SampledFrom([]contract.VlessRealityParamsFlow{
			contract.VlessRealityParamsFlowVision, contract.VlessRealityParamsFlowNone,
		}).Draw(t, "flow"),
		ServerName: genDomain.Draw(t, "sni"),
		PublicKey:  base64.RawURLEncoding.EncodeToString(key),
		ShortId:    rapid.StringMatching(`([0-9a-f]{2}){0,8}`).Draw(t, "shortId"),
		Fingerprint: rapid.SampledFrom([]contract.UtlsFingerprint{
			contract.UtlsFingerprintChrome, contract.UtlsFingerprintFirefox, contract.UtlsFingerprintSafari,
			contract.UtlsFingerprintIos, contract.UtlsFingerprintAndroid, contract.UtlsFingerprintEdge,
			contract.UtlsFingerprintRandom,
		}).Draw(t, "fingerprint"),
	}
}

func genHysteria(t *rapid.T) *contract.Hysteria2Params {
	params := &contract.Hysteria2Params{
		Password:   "secret-" + rapid.StringMatching(`[a-z0-9]{8,16}`).Draw(t, "password"),
		ServerName: genDomain.Draw(t, "sni"),
	}
	if rapid.Bool().Draw(t, "salamander") {
		password := "secret-" + rapid.StringMatching(`[a-z0-9]{8}`).Draw(t, "salamanderPassword")
		params.ObfsSalamanderPassword = &password
	}
	if rapid.Bool().Draw(t, "hopping") {
		first := rapid.IntRange(1024, 60000).Draw(t, "firstPort")
		last := first + rapid.IntRange(0, 1000).Draw(t, "ports")
		ports := rapid.SampledFrom([]string{
			fmt.Sprintf("%d-%d", first, last), fmt.Sprintf("%d,%d", first, last), fmt.Sprintf("%d", first),
		}).Draw(t, "portsFormat")
		params.PortHopping = &contract.PortHopping{Ports: ports, IntervalSec: rapid.IntRange(5, 600).Draw(t, "interval")}
	}
	return params
}

func genServer(t *rapid.T, index int) contract.ServerNode {
	server := contract.ServerNode{
		Id:         fmt.Sprintf("00000000-0000-4000-8000-%012d", index),
		Group:      genMode.Draw(t, "group"),
		Name:       fmt.Sprintf("server %d", index),
		Protocol:   rapid.SampledFrom([]contract.ServerProtocol{contract.ServerProtocolVlessReality, contract.ServerProtocolHysteria2}).Draw(t, "protocol"),
		Address:    genAddress.Draw(t, "address"),
		Port:       rapid.IntRange(1, 65535).Draw(t, "port"),
		SortWeight: rapid.IntRange(0, 3).Draw(t, "weight"),
	}
	if server.Protocol == contract.ServerProtocolVlessReality {
		server.Vless = genVless(t)
	} else {
		server.Hysteria2 = genHysteria(t)
	}
	return server
}

func genRules(t *rapid.T, ruleSets []contract.LocalRuleSet) []contract.RoutingRule {
	matches := []contract.RuleMatch{
		contract.RuleMatchDomain, contract.RuleMatchDomainSuffix, contract.RuleMatchDomainKeyword,
		contract.RuleMatchIpCidr, contract.RuleMatchApp,
	}
	if len(ruleSets) > 0 {
		matches = append(matches, contract.RuleMatchRuleSet)
	}
	rules := make([]contract.RoutingRule, rapid.IntRange(0, 5).Draw(t, "rules"))
	for index := range rules {
		match := rapid.SampledFrom(matches).Draw(t, "match")
		value := genDomain.Draw(t, "value")
		switch match {
		case contract.RuleMatchIpCidr:
			value = genCIDR.Draw(t, "cidr")
		case contract.RuleMatchRuleSet:
			value = rapid.SampledFrom(ruleSets).Draw(t, "ruleSet").Id
		}
		rules[index] = contract.RoutingRule{
			Id:     fmt.Sprintf("r%d", index),
			Match:  match,
			Value:  value,
			Action: rapid.SampledFrom([]contract.RuleAction{contract.RuleActionProxy, contract.RuleActionDirect, contract.RuleActionBlock}).Draw(t, "action"),
		}
	}
	return rules
}

// genRequest draws from the whole valid space, including selections that point
// at nothing, because C3 has to hold for them.
var genRequest = rapid.Custom(func(t *rapid.T) contract.TunnelRequest {
	req := request(genPlatform.Draw(t, "platform"))
	req.UserMode = genMode.Draw(t, "userMode")

	req.Servers = make([]contract.ServerNode, rapid.IntRange(1, 6).Draw(t, "servers"))
	for index := range req.Servers {
		req.Servers[index] = genServer(t, index)
	}
	req.Servers[0].Group = req.UserMode

	ids := []string{"missing"}
	for _, server := range req.Servers {
		ids = append(ids, server.Id)
	}
	if rapid.Bool().Draw(t, "selectRegular") {
		id := rapid.SampledFrom(ids).Draw(t, "regular")
		req.Selected.Regular = &id
	}
	if rapid.Bool().Draw(t, "selectWhitelist") {
		id := rapid.SampledFrom(ids).Draw(t, "whitelist")
		req.Selected.Whitelist = &id
	}

	routing := &req.Settings.Routing
	routing.Enabled = rapid.Bool().Draw(t, "routing")
	routing.Preset = rapid.SampledFrom([]contract.RoutingPreset{
		contract.RoutingPresetRuDirect, contract.RoutingPresetAllProxy, contract.RoutingPresetCustom,
	}).Draw(t, "preset")
	if rapid.Bool().Draw(t, "ruleSets") {
		routing.RuleSets = []contract.LocalRuleSet{{Id: "ru-direct", Path: "rulesets/ru-direct.srs"}}
	}
	routing.Rules = genRules(t, routing.RuleSets)

	dns := &req.Settings.Dns
	dns.Remote = rapid.SampledFrom([]string{"https://1.1.1.1/dns-query", "https://dns.google/dns-query", "https://[2606:4700:4700::1111]/dns-query"}).Draw(t, "remote")
	dns.Direct = rapid.SampledFrom([]string{"77.88.8.8", "2a02:6b8::feed:0ff", "https://77.88.8.8/dns-query", "https://dns.yandex.net/dns-query"}).Draw(t, "direct")
	dns.Strategy = rapid.SampledFrom([]contract.DnsStrategy{
		contract.DnsStrategyPreferIpv4, contract.DnsStrategyPreferIpv6, contract.DnsStrategyIpv4Only, contract.DnsStrategyIpv6Only,
	}).Draw(t, "strategy")

	net := &req.Settings.Net
	net.Ipv6 = rapid.Bool().Draw(t, "ipv6")
	net.Sniffing = rapid.Bool().Draw(t, "sniffing")
	net.TlsFragment = contract.TlsFragment{Enabled: rapid.Bool().Draw(t, "fragment"), Record: rapid.Bool().Draw(t, "record")}
	net.Mtu = rapid.IntRange(1280, 9000).Draw(t, "mtu")
	net.TunStack = rapid.SampledFrom([]contract.TunStack{contract.TunStackSystem, contract.TunStackGvisor, contract.TunStackMixed}).Draw(t, "stack")
	net.ExcludeRoutes = rapid.SliceOfN(genCIDR, 0, 3).Draw(t, "excludeRoutes")
	net.BypassLan = rapid.Bool().Draw(t, "bypassLan")

	req.Settings.PerApp.Mode = rapid.SampledFrom([]contract.PerAppMode{contract.PerAppModeOff, contract.PerAppModeInclude, contract.PerAppModeExclude}).Draw(t, "perApp")
	req.Settings.PerApp.Apps = rapid.SliceOfN(genDomain, 1, 3).Draw(t, "apps")
	req.Log.Level = rapid.SampledFrom([]contract.LogLevel{contract.LogLevelWarn, contract.LogLevelInfo, contract.LogLevelDebug}).Draw(t, "logLevel")
	return req
})

func TestC1EveryValidRequestPassesTheBox(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		requireBoxAccepts(t, build(t, genRequest.Draw(t, "request")))
	})
}

func TestC2EveryServerHasOneOutboundInItsGroup(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		req := genRequest.Draw(t, "request")
		options := build(t, req)
		for _, server := range req.Servers {
			tag := config.ServerTag(server.Id)
			require.Equal(t, 1, countOutbounds(options, tag), tag)
			for _, mode := range []contract.TunnelMode{contract.TunnelModeRegular, contract.TunnelModeWhitelist} {
				members := groupMembers(t, options, mode)
				require.Equal(t, mode == server.Group, slices.Contains(members, tag), "%s in %s", tag, mode)
			}
		}
	})
}

func countOutbounds(options option.Options, tag string) int {
	count := 0
	for _, candidate := range options.Outbounds {
		if candidate.Tag == tag {
			count++
		}
	}
	return count
}

func groupMembers(t *rapid.T, options option.Options, mode contract.TunnelMode) []string {
	tag := config.GroupTag(mode)
	if !hasOutbound(options, tag) {
		return nil
	}
	return outbound[option.SelectorOutboundOptions](t, options, tag).Outbounds
}

func TestEmptyGroupsNeverExist(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		req := genRequest.Draw(t, "request")
		options := build(t, req)
		for _, mode := range []contract.TunnelMode{contract.TunnelModeRegular, contract.TunnelModeWhitelist} {
			inRequest := slices.ContainsFunc(req.Servers, func(server contract.ServerNode) bool { return server.Group == mode })
			require.Equal(t, inRequest, hasOutbound(options, config.GroupTag(mode)), mode)
		}
	})
}

func TestC3SelectionFallsToTheFirstByWeight(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		req := genRequest.Draw(t, "request")
		options := build(t, req)
		for mode, selected := range map[contract.TunnelMode]*string{
			contract.TunnelModeRegular:   req.Selected.Regular,
			contract.TunnelModeWhitelist: req.Selected.Whitelist,
		} {
			if !hasOutbound(options, config.GroupTag(mode)) {
				continue
			}
			group := serversOf(req, mode)
			want := group[0]
			for _, server := range group {
				if server.SortWeight < want.SortWeight {
					want = server
				}
			}
			if selected != nil {
				index := slices.IndexFunc(group, func(server contract.ServerNode) bool { return server.Id == *selected })
				if index >= 0 {
					want = group[index]
				}
			}
			got := outbound[option.SelectorOutboundOptions](t, options, config.GroupTag(mode)).Default
			require.Equal(t, config.ServerTag(want.Id), got)
		}
	})
}

func serversOf(req contract.TunnelRequest, mode contract.TunnelMode) []contract.ServerNode {
	var group []contract.ServerNode
	for _, server := range req.Servers {
		if server.Group == mode {
			group = append(group, server)
		}
	}
	return group
}

func TestC4EveryServerAddressGoesDirect(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		req := genRequest.Draw(t, "request")
		options := build(t, req)
		for _, server := range req.Servers {
			index := routedTo(options, "direct", func(rule option.RawDefaultRule) bool {
				if slices.Contains(rule.Domain, server.Address) {
					return true
				}
				addr, err := netip.ParseAddr(server.Address)
				return err == nil && slices.Contains(rule.IPCIDR, netip.PrefixFrom(addr, addr.BitLen()).String())
			})
			require.NotEqual(t, -1, index, server.Address)
		}
	})
}

func TestC5PlatformsDoNotMix(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		req := genRequest.Draw(t, "request")
		options := build(t, req)
		tun := tunOf(t, options)
		if req.Platform == contract.PlatformWindows {
			require.Empty(t, tun.IncludePackage)
			require.Empty(t, tun.ExcludePackage)
		}
		if req.Platform == contract.PlatformAndroid {
			require.Contains(t, []string(tun.ExcludePackage), config.AndroidPackage)
			require.NotContains(t, []string(tun.IncludePackage), config.AndroidPackage)
			for _, rule := range options.Route.Rules {
				require.Empty(t, rule.DefaultOptions.ProcessName)
			}
		}
	})
}

func TestC6SecretsStayOutOfTheCoreLog(t *testing.T) {
	logPath := filepath.Join(t.TempDir(), "core.log")
	rapid.Check(t, func(t *rapid.T) {
		req := genRequest.Draw(t, "request")
		req.Log.Level = contract.LogLevelDebug
		options := build(t, req)

		require.NoError(t, os.WriteFile(logPath, nil, 0o600))
		options.Log.Output = logPath
		requireNew(t, options)
		written, err := os.ReadFile(logPath)
		require.NoError(t, err)

		for _, server := range req.Servers {
			if server.Vless != nil {
				require.NotContains(t, string(written), server.Vless.Uuid)
			}
			if server.Hysteria2 != nil {
				require.NotContains(t, string(written), server.Hysteria2.Password)
			}
		}
	})
}

func TestBuildIsPure(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		req := genRequest.Draw(t, "request")
		require.True(t, reflect.DeepEqual(build(t, req), build(t, req)))
	})
}
