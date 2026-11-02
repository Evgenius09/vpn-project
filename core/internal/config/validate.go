package config

import (
	"encoding/base64"
	"encoding/hex"
	"net/netip"
	"strings"

	"github.com/gofrs/uuid/v5"

	"github.com/Evgenius09/vpn-project/core/internal/contract"
)

const (
	schemaVersion   = 1
	minMTU          = 1280
	maxMTU          = 9000
	maxPort         = 65535
	realityKeyBytes = 32
	maxShortIDBytes = 8
)

func validate(req contract.TunnelRequest) *Error {
	switch {
	case req.SchemaVersion != schemaVersion:
		return invalid("unsupported schemaVersion %d", req.SchemaVersion)
	case !req.Platform.Valid():
		return invalid("unknown platform")
	case !req.UserMode.Valid():
		return invalid("unknown userMode")
	case !req.Log.Level.Valid():
		return invalid("unknown log level")
	case len(req.Servers) == 0:
		return invalid("no servers")
	}
	if err := validateServers(req.Servers); err != nil {
		return err
	}
	if err := validateRouting(req.Settings.Routing); err != nil {
		return err
	}
	if err := validateNet(req.Settings); err != nil {
		return err
	}
	return validatePerApp(req)
}

func validateServers(servers []contract.ServerNode) *Error {
	seen := make(map[string]struct{}, len(servers))
	for _, server := range servers {
		if blank(server.Id) {
			return invalid("server without an id")
		}
		if _, duplicate := seen[server.Id]; duplicate {
			return invalid("duplicate server %s", server.Id)
		}
		seen[server.Id] = struct{}{}
		if err := validateServer(server); err != nil {
			return err
		}
	}
	return nil
}

func validateServer(server contract.ServerNode) *Error {
	switch {
	case !server.Group.Valid():
		return invalid("server %s: unknown group", server.Id)
	case blank(server.Address):
		return invalid("server %s: blank address", server.Id)
	case server.Port < 1 || server.Port > maxPort:
		return invalid("server %s: port out of range", server.Id)
	}
	switch server.Protocol {
	case contract.ServerProtocolVlessReality:
		return validateVless(server)
	case contract.ServerProtocolHysteria2:
		return validateHysteria(server)
	default:
		return invalid("server %s: unknown protocol", server.Id)
	}
}

// validateVless checks what sing-box checks later, because its message would
// reach the log with the bad value in it.
func validateVless(server contract.ServerNode) *Error {
	params := server.Vless
	if params == nil {
		return invalid("server %s: missing vless params", server.Id)
	}
	if _, err := uuid.FromString(params.Uuid); err != nil {
		return invalid("server %s: invalid vless uuid", server.Id)
	}
	key, err := base64.RawURLEncoding.DecodeString(params.PublicKey)
	if err != nil || len(key) != realityKeyBytes {
		return invalid("server %s: invalid reality public key", server.Id)
	}
	shortID, err := hex.DecodeString(params.ShortId)
	if err != nil || len(shortID) > maxShortIDBytes {
		return invalid("server %s: invalid reality short id", server.Id)
	}
	switch {
	case !params.Flow.Valid():
		return invalid("server %s: unknown flow", server.Id)
	case !params.Fingerprint.Valid():
		return invalid("server %s: unknown fingerprint", server.Id)
	case blank(params.ServerName):
		return invalid("server %s: blank server name", server.Id)
	}
	return nil
}

func validateHysteria(server contract.ServerNode) *Error {
	params := server.Hysteria2
	switch {
	case params == nil:
		return invalid("server %s: missing hysteria2 params", server.Id)
	case params.Password == "":
		return invalid("server %s: blank hysteria2 password", server.Id)
	case blank(params.ServerName):
		return invalid("server %s: blank server name", server.Id)
	case params.PortHopping != nil && params.PortHopping.IntervalSec <= 0:
		return invalid("server %s: hop interval must be positive", server.Id)
	}
	return nil
}

func validateRouting(routing contract.RoutingSettings) *Error {
	if !routing.Preset.Valid() {
		return invalid("unknown routing preset")
	}
	ruleSets := make(map[string]struct{}, len(routing.RuleSets))
	for _, ruleSet := range routing.RuleSets {
		if blank(ruleSet.Id) || blank(ruleSet.Path) {
			return invalid("rule set needs an id and a path")
		}
		if _, duplicate := ruleSets[ruleSet.Id]; duplicate {
			return invalid("duplicate rule set %s", ruleSet.Id)
		}
		ruleSets[ruleSet.Id] = struct{}{}
	}
	for _, rule := range routing.Rules {
		if err := validateRule(rule, ruleSets); err != nil {
			return err
		}
	}
	return nil
}

func validateRule(rule contract.RoutingRule, ruleSets map[string]struct{}) *Error {
	switch {
	case !rule.Match.Valid():
		return invalid("rule %s: unknown match", rule.Id)
	case !rule.Action.Valid():
		return invalid("rule %s: unknown action", rule.Id)
	case blank(rule.Value):
		return invalid("rule %s: blank value", rule.Id)
	}
	switch rule.Match {
	case contract.RuleMatchIpCidr:
		if !validCIDR(rule.Value) {
			return invalid("rule %s: invalid CIDR", rule.Id)
		}
	case contract.RuleMatchRuleSet:
		if _, known := ruleSets[rule.Value]; !known {
			return invalid("rule %s: unknown rule set", rule.Id)
		}
	}
	return nil
}

func validateNet(settings contract.TunnelSettings) *Error {
	net := settings.Net
	switch {
	case !settings.Dns.Strategy.Valid():
		return invalid("unknown dns strategy")
	case net.Mtu < minMTU || net.Mtu > maxMTU:
		return invalid("mtu out of range")
	case !net.TunStack.Valid():
		return invalid("unknown tun stack")
	}
	return nil
}

func validatePerApp(req contract.TunnelRequest) *Error {
	perApp := req.Settings.PerApp
	if !perApp.Mode.Valid() {
		return invalid("unknown perApp mode")
	}
	if perApp.Mode == contract.PerAppModeOff {
		return nil
	}
	usable := 0
	for _, app := range perApp.Apps {
		if blank(app) {
			return invalid("blank perApp entry")
		}
		if req.Platform != contract.PlatformAndroid || app != AndroidPackage {
			usable++
		}
	}
	// An empty list means every app to the platform, the opposite of include.
	if perApp.Mode == contract.PerAppModeInclude && usable == 0 {
		return invalid("perApp include needs at least one app")
	}
	return nil
}

func validCIDR(value string) bool {
	if _, err := netip.ParsePrefix(value); err == nil {
		return true
	}
	_, err := netip.ParseAddr(value)
	return err == nil
}

func blank(value string) bool {
	return strings.TrimSpace(value) == ""
}
