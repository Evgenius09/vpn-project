package config

import (
	"fmt"
	"strconv"
	"strings"
	"time"

	C "github.com/sagernet/sing-box/constant"
	"github.com/sagernet/sing-box/option"
	"github.com/sagernet/sing/common/json/badoption"

	"github.com/Evgenius09/vpn-project/core/internal/contract"
)

const packetEncodingXUDP = "xudp"

func buildOutbounds(req contract.TunnelRequest, groups map[contract.TunnelMode][]contract.ServerNode) ([]option.Outbound, error) {
	selected := map[contract.TunnelMode]*string{
		contract.TunnelModeRegular:   req.Selected.Regular,
		contract.TunnelModeWhitelist: req.Selected.Whitelist,
	}
	var groupTags []string
	var groupSelectors, servers []option.Outbound
	for _, mode := range modes {
		group := groups[mode]
		if len(group) == 0 {
			continue
		}
		members := make([]string, len(group))
		for index, server := range group {
			members[index] = ServerTag(server.Id)
			outbound, err := buildServer(server, req.Settings.Net.TlsFragment)
			if err != nil {
				return nil, err
			}
			servers = append(servers, outbound)
		}
		groupTags = append(groupTags, GroupTag(mode))
		groupSelectors = append(groupSelectors, selector(GroupTag(mode), members, groupDefault(group, selected[mode]), false))
	}

	outbounds := []option.Outbound{selector(TagProxy, groupTags, GroupTag(req.UserMode), true)}
	outbounds = append(outbounds, groupSelectors...)
	outbounds = append(outbounds, servers...)
	return append(outbounds, option.Outbound{
		Type:    C.TypeDirect,
		Tag:     tagDirect,
		Options: &option.DirectOutboundOptions{},
	}), nil
}

// groupDefault expects the group sorted by sortWeight.
func groupDefault(group []contract.ServerNode, selected *string) string {
	if selected != nil {
		for _, server := range group {
			if server.Id == *selected {
				return ServerTag(server.Id)
			}
		}
	}
	return ServerTag(group[0].Id)
}

func buildServer(server contract.ServerNode, fragment contract.TlsFragment) (option.Outbound, error) {
	endpoint := option.ServerOptions{Server: server.Address, ServerPort: uint16(server.Port)}
	tls := option.OutboundTLSOptions{
		Enabled:        true,
		Fragment:       fragment.Enabled,
		RecordFragment: fragment.Record,
	}
	if server.Protocol == contract.ServerProtocolVlessReality {
		return buildVless(server, endpoint, tls), nil
	}
	return buildHysteria(server, endpoint, tls)
}

func buildVless(server contract.ServerNode, endpoint option.ServerOptions, tls option.OutboundTLSOptions) option.Outbound {
	params := server.Vless
	encoding := packetEncodingXUDP
	tls.ServerName = params.ServerName
	tls.UTLS = &option.OutboundUTLSOptions{Enabled: true, Fingerprint: string(params.Fingerprint)}
	tls.Reality = &option.OutboundRealityOptions{Enabled: true, PublicKey: params.PublicKey, ShortID: params.ShortId}
	return option.Outbound{
		Type: C.TypeVLESS,
		Tag:  ServerTag(server.Id),
		// Multiplex stays off: Xray servers do not speak the sing-box protocol,
		// and Vision does not work over it (tech.md 2.4).
		Options: &option.VLESSOutboundOptions{
			ServerOptions:               endpoint,
			UUID:                        params.Uuid,
			Flow:                        string(params.Flow),
			PacketEncoding:              &encoding,
			OutboundTLSOptionsContainer: option.OutboundTLSOptionsContainer{TLS: &tls},
		},
	}
}

func buildHysteria(server contract.ServerNode, endpoint option.ServerOptions, tls option.OutboundTLSOptions) (option.Outbound, error) {
	params := server.Hysteria2
	tls.ServerName = params.ServerName
	options := &option.Hysteria2OutboundOptions{
		ServerOptions:               endpoint,
		Password:                    params.Password,
		OutboundTLSOptionsContainer: option.OutboundTLSOptionsContainer{TLS: &tls},
	}
	if params.UpMbps != nil {
		options.UpMbps = *params.UpMbps
	}
	if params.DownMbps != nil {
		options.DownMbps = *params.DownMbps
	}
	if params.ObfsSalamanderPassword != nil {
		options.Obfs = &option.Hysteria2Obfs{Type: C.Hysteria2ObfsTypeSalamander, Password: *params.ObfsSalamanderPassword}
	}
	if params.PortHopping != nil {
		ports, err := serverPorts(params.PortHopping.Ports)
		if err != nil {
			return option.Outbound{}, invalid("server %s: %s", server.Id, err)
		}
		options.ServerPorts = ports
		options.HopInterval = badoption.Duration(time.Duration(params.PortHopping.IntervalSec) * time.Second)
	}
	return option.Outbound{Type: C.TypeHysteria2, Tag: ServerTag(server.Id), Options: options}, nil
}

// serverPorts translates the contract's "20000-30000" and "443,8443" into the
// "start:end" ranges sing-box parses. A single port is a range of one, because
// sing-box refuses a value without a colon.
func serverPorts(spec string) ([]string, error) {
	parts := strings.Split(spec, ",")
	ports := make([]string, len(parts))
	for index, part := range parts {
		first, last, isRange := strings.Cut(strings.TrimSpace(part), "-")
		if !isRange {
			last = first
		}
		start, err := parsePort(first)
		if err != nil {
			return nil, err
		}
		end, err := parsePort(last)
		if err != nil {
			return nil, err
		}
		if start > end {
			return nil, fmt.Errorf("reversed port range %d-%d", start, end)
		}
		ports[index] = fmt.Sprintf("%d:%d", start, end)
	}
	return ports, nil
}

func parsePort(value string) (uint16, error) {
	port, err := strconv.ParseUint(value, 10, 16)
	if err != nil || port == 0 {
		return 0, fmt.Errorf("invalid port %q", value)
	}
	return uint16(port), nil
}
