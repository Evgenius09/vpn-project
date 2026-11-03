package config

import (
	"net/netip"

	C "github.com/sagernet/sing-box/constant"
	"github.com/sagernet/sing-box/option"
	"github.com/sagernet/sing/common/json/badoption"

	"github.com/Evgenius09/vpn-project/core/internal/contract"
)

const dnsPort = 53

var (
	tunIPv4 = netip.MustParsePrefix("172.19.0.1/30")
	tunIPv6 = netip.MustParsePrefix("fdfe:dcba:9876::1/126")
)

func buildRoute(req contract.TunnelRequest) *option.RouteOptions {
	settings := req.Settings
	var rules []option.Rule
	if settings.Net.Sniffing {
		rules = append(rules, sniffRule())
	}
	rules = append(rules, hijackDNSRule())
	if settings.Net.BypassLan {
		rules = append(rules, routeRule(option.RawDefaultRule{IPIsPrivate: true}, tagDirect))
	}
	rules = append(rules, serverAddressRule(req.Servers))

	route := &option.RouteOptions{
		Final: TagProxy,
		// A TUN with auto_route would otherwise send its own connections back
		// into itself.
		AutoDetectInterface: true,
		// Server domains resolve before the tunnel exists.
		DefaultDomainResolver: &option.DomainResolveOptions{Server: dnsDirect},
	}
	if settings.Routing.Enabled {
		for _, rule := range settings.Routing.Rules {
			rules = append(rules, userRule(rule, req.Platform))
			route.FindProcess = route.FindProcess ||
				rule.Match == contract.RuleMatchApp && req.Platform == contract.PlatformWindows
		}
		route.RuleSet = localRuleSets(settings.Routing.RuleSets)
		// S3-02 adds the preset rules here.
	}
	if req.Platform == contract.PlatformWindows {
		rules = appendWindowsPerApp(rules, route, settings.PerApp)
	}
	route.Rules = rules
	return route
}

func sniffRule() option.Rule {
	return defaultRule(option.RawDefaultRule{Inbound: []string{tagTun}}, option.RuleAction{Action: C.RuleActionTypeSniff})
}

// hijackDNSRule matches the port as well, because the protocol is known only
// after sniffing, which the user can turn off.
func hijackDNSRule() option.Rule {
	return option.Rule{
		Type: C.RuleTypeLogical,
		LogicalOptions: option.LogicalRule{
			RawLogicalRule: option.RawLogicalRule{
				Mode: C.LogicalTypeOr,
				Rules: []option.Rule{
					defaultRule(option.RawDefaultRule{Port: []uint16{dnsPort}}, option.RuleAction{}),
					defaultRule(option.RawDefaultRule{Protocol: []string{C.ProtocolDNS}}, option.RuleAction{}),
				},
			},
			RuleAction: option.RuleAction{Action: C.RuleActionTypeHijackDNS},
		},
	}
}

func serverAddressRule(servers []contract.ServerNode) option.Rule {
	var match option.RawDefaultRule
	for _, server := range servers {
		if addr, err := netip.ParseAddr(server.Address); err == nil {
			match.IPCIDR = append(match.IPCIDR, netip.PrefixFrom(addr, addr.BitLen()).String())
		} else {
			match.Domain = append(match.Domain, server.Address)
		}
	}
	return routeRule(match, tagDirect)
}

func userRule(rule contract.RoutingRule, platform contract.Platform) option.Rule {
	var match option.RawDefaultRule
	value := badoption.Listable[string]{rule.Value}
	switch rule.Match {
	case contract.RuleMatchDomain:
		match.Domain = value
	case contract.RuleMatchDomainSuffix:
		match.DomainSuffix = value
	case contract.RuleMatchDomainKeyword:
		match.DomainKeyword = value
	case contract.RuleMatchIpCidr:
		match.IPCIDR = value
	case contract.RuleMatchRuleSet:
		match.RuleSet = value
	case contract.RuleMatchApp:
		if platform == contract.PlatformWindows {
			match.ProcessName = value
		} else {
			match.PackageName = value
		}
	}
	switch rule.Action {
	case contract.RuleActionDirect:
		return routeRule(match, tagDirect)
	case contract.RuleActionBlock:
		return defaultRule(match, option.RuleAction{Action: C.RuleActionTypeReject})
	default:
		return routeRule(match, TagProxy)
	}
}

func localRuleSets(ruleSets []contract.LocalRuleSet) []option.RuleSet {
	result := make([]option.RuleSet, len(ruleSets))
	for index, ruleSet := range ruleSets {
		result[index] = option.RuleSet{
			Type:         C.RuleSetTypeLocal,
			Tag:          []string{ruleSet.Id},
			Format:       C.RuleSetFormatBinary,
			LocalOptions: option.LocalRuleSet{Path: ruleSet.Path},
		}
	}
	return result
}

// appendWindowsPerApp stands in for the package lists of Android. Windows has
// no per-app TUN, so the choice happens in routing. The rule comes last: with
// include it is the other half of final = direct (tech.md 21.2).
func appendWindowsPerApp(rules []option.Rule, route *option.RouteOptions, perApp contract.PerAppSettings) []option.Rule {
	switch perApp.Mode {
	case contract.PerAppModeInclude:
		route.Final = tagDirect
		route.FindProcess = true
		return append(rules, routeRule(option.RawDefaultRule{ProcessName: perApp.Apps}, TagProxy))
	case contract.PerAppModeExclude:
		route.FindProcess = true
		// A rule without conditions would match every connection.
		if len(perApp.Apps) > 0 {
			return append(rules, routeRule(option.RawDefaultRule{ProcessName: perApp.Apps}, tagDirect))
		}
	}
	return rules
}

func routeRule(match option.RawDefaultRule, outbound string) option.Rule {
	return defaultRule(match, option.RuleAction{
		Action:       C.RuleActionTypeRoute,
		RouteOptions: option.RouteActionOptions{Outbound: outbound},
	})
}

func defaultRule(match option.RawDefaultRule, action option.RuleAction) option.Rule {
	return option.Rule{
		Type:           C.RuleTypeDefault,
		DefaultOptions: option.DefaultRule{RawDefaultRule: match, RuleAction: action},
	}
}

func buildTun(req contract.TunnelRequest) (option.Inbound, error) {
	net := req.Settings.Net
	address := []netip.Prefix{tunIPv4}
	if net.Ipv6 {
		address = append(address, tunIPv6)
	}
	excluded := make([]netip.Prefix, len(net.ExcludeRoutes))
	for index, route := range net.ExcludeRoutes {
		prefix, err := netip.ParsePrefix(route)
		if err != nil {
			return option.Inbound{}, invalid("invalid exclude route")
		}
		excluded[index] = prefix
	}
	tun := &option.TunInboundOptions{
		Address:             address,
		MTU:                 uint32(net.Mtu),
		AutoRoute:           true,
		StrictRoute:         true,
		Stack:               string(net.TunStack),
		RouteExcludeAddress: excluded,
	}
	if req.Platform == contract.PlatformAndroid {
		tun.IncludePackage, tun.ExcludePackage = androidPackages(req.Settings.PerApp)
		// The system TCP stack answers from a socket of this app, which sits
		// outside its own VPN, so the reply misses tun0 (tech.md 40.1).
		tun.Stack = string(contract.TunStackGvisor)
	}
	return option.Inbound{Type: C.TypeTun, Tag: tagTun, Options: tun}, nil
}

// androidPackages keeps the app itself out of the tunnel in every mode. The
// host has to drop the exclude list when an include list is present, because
// VpnService.Builder accepts only one of them.
func androidPackages(perApp contract.PerAppSettings) (include, exclude []string) {
	for _, app := range perApp.Apps {
		if app == AndroidPackage {
			continue
		}
		switch perApp.Mode {
		case contract.PerAppModeInclude:
			include = append(include, app)
		case contract.PerAppModeExclude:
			exclude = append(exclude, app)
		}
	}
	return include, append(exclude, AndroidPackage)
}
