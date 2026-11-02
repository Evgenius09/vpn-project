// Package config turns a TunnelRequest into sing-box options (tech.md 5.8).
// BuildOptions is pure: Android and vpnsvc share it, and the options differ
// only where the platform field says so.
package config

import (
	"cmp"
	"fmt"
	"slices"

	C "github.com/sagernet/sing-box/constant"
	"github.com/sagernet/sing-box/option"

	"github.com/Evgenius09/vpn-project/core/internal/contract"
)

const (
	// TagProxy is the selector that chooses between the two groups.
	TagProxy = "proxy"
	// AndroidPackage is the app's applicationId. It always stays out of the
	// tunnel, because the app talks to the API through the real network.
	AndroidPackage = "com.vpnclient.app"

	tagDirect = "direct"
	tagTun    = "tun-in"
)

var modes = []contract.TunnelMode{contract.TunnelModeRegular, contract.TunnelModeWhitelist}

// Error carries the code the host forwards to the app. Its message never holds
// a request value that could be a secret.
type Error struct {
	Code    contract.CoreErrorCode
	Message string
}

// Error implements error.
func (e *Error) Error() string {
	return fmt.Sprintf("%s: %s", e.Code, e.Message)
}

func invalid(format string, args ...any) *Error {
	return &Error{Code: contract.CoreErrorCodeConfigInvalid, Message: fmt.Sprintf(format, args...)}
}

// ServerTag names the outbound of a server.
func ServerTag(serverID string) string { return "srv-" + serverID }

// GroupTag names the selector of a group.
func GroupTag(mode contract.TunnelMode) string { return "grp-" + string(mode) }

// BuildOptions validates the request and builds the options. It returns *Error
// on a request it refuses.
func BuildOptions(req contract.TunnelRequest) (option.Options, error) {
	if err := validate(req); err != nil {
		return option.Options{}, err
	}
	groups := serversByGroup(req.Servers)
	// The tunnel starts in the user's mode: tech.md 19.10 evaluates the network
	// only after the start.
	if len(groups[req.UserMode]) == 0 {
		return option.Options{}, &Error{
			Code:    contract.CoreErrorCodeNoServersInGroup,
			Message: fmt.Sprintf("no servers in group %s", req.UserMode),
		}
	}

	outbounds, err := buildOutbounds(req, groups)
	if err != nil {
		return option.Options{}, err
	}
	dns, err := buildDNS(req.Settings)
	if err != nil {
		return option.Options{}, err
	}
	inbound, err := buildTun(req)
	if err != nil {
		return option.Options{}, err
	}
	return option.Options{
		Log:          &option.LogOptions{Level: string(req.Log.Level), Timestamp: true},
		DNS:          dns,
		Inbounds:     []option.Inbound{inbound},
		Outbounds:    outbounds,
		Route:        buildRoute(req),
		Experimental: &option.ExperimentalOptions{CacheFile: &option.CacheFileOptions{Enabled: true}},
	}, nil
}

// serversByGroup orders each group by sortWeight. The stable sort keeps the
// request order for equal weights, so the same request gives the same default.
func serversByGroup(servers []contract.ServerNode) map[contract.TunnelMode][]contract.ServerNode {
	groups := make(map[contract.TunnelMode][]contract.ServerNode, len(modes))
	for _, server := range servers {
		groups[server.Group] = append(groups[server.Group], server)
	}
	for _, group := range groups {
		slices.SortStableFunc(group, func(a, b contract.ServerNode) int {
			return cmp.Compare(a.SortWeight, b.SortWeight)
		})
	}
	return groups
}

func selector(tag string, members []string, defaultTag string, interrupt bool) option.Outbound {
	return option.Outbound{
		Type: C.TypeSelector,
		Tag:  tag,
		Options: &option.SelectorOutboundOptions{
			Outbounds:                 members,
			Default:                   defaultTag,
			InterruptExistConnections: interrupt,
		},
	}
}
