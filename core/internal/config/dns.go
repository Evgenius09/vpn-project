package config

import (
	"net/netip"
	"net/url"

	C "github.com/sagernet/sing-box/constant"
	"github.com/sagernet/sing-box/option"

	"github.com/Evgenius09/vpn-project/core/internal/contract"
)

const (
	dnsRemote = "dns-remote"
	dnsDirect = "dns-direct"
	dnsLocal  = "dns-local"

	schemeHTTPS = "https"
)

var strategies = map[contract.DnsStrategy]option.DomainStrategy{
	contract.DnsStrategyPreferIpv4: option.DomainStrategy(C.DomainStrategyPreferIPv4),
	contract.DnsStrategyPreferIpv6: option.DomainStrategy(C.DomainStrategyPreferIPv6),
	contract.DnsStrategyIpv4Only:   option.DomainStrategy(C.DomainStrategyIPv4Only),
	contract.DnsStrategyIpv6Only:   option.DomainStrategy(C.DomainStrategyIPv6Only),
}

func buildDNS(settings contract.TunnelSettings) (*option.DNSOptions, error) {
	remote, ok := parseDoH(settings.Dns.Remote)
	if !ok {
		return nil, invalid("dns remote must be a DoH URL")
	}
	// The remote server resolves its own name outside the tunnel it runs in.
	dialer := option.RawLocalDNSServerOptions{DialerOptions: option.DialerOptions{Detour: TagProxy}}
	if remote.isDomain() {
		dialer.DomainResolver = &option.DomainResolveOptions{Server: dnsDirect}
	}
	servers := []option.DNSServerOptions{remote.server(dnsRemote, dialer)}

	direct, err := buildDirectDNS(settings.Dns.Direct)
	if err != nil {
		return nil, err
	}
	servers = append(servers, direct...)

	strategy := strategies[settings.Dns.Strategy]
	if !settings.Net.Ipv6 {
		strategy = option.DomainStrategy(C.DomainStrategyIPv4Only)
	}
	return &option.DNSOptions{RawDNSOptions: option.RawDNSOptions{
		Servers:          servers,
		Final:            dnsRemote,
		DNSClientOptions: option.DNSClientOptions{Strategy: strategy},
	}}, nil
}

// buildDirectDNS leaves the detour empty: that already means a direct dial, and
// sing-box refuses a detour to an empty direct outbound. A DoH server named by
// a domain needs a third resolver, because nothing else can resolve its name.
func buildDirectDNS(value string) ([]option.DNSServerOptions, error) {
	if addr, err := netip.ParseAddr(value); err == nil {
		return []option.DNSServerOptions{{
			Type: C.DNSTypeUDP,
			Tag:  dnsDirect,
			Options: &option.RemoteDNSServerOptions{
				DNSServerAddressOptions: option.DNSServerAddressOptions{Server: addr.String()},
			},
		}}, nil
	}
	endpoint, ok := parseDoH(value)
	if !ok {
		return nil, invalid("dns direct must be a DoH URL or an IP")
	}
	if !endpoint.isDomain() {
		return []option.DNSServerOptions{endpoint.server(dnsDirect, option.RawLocalDNSServerOptions{})}, nil
	}
	dialer := option.RawLocalDNSServerOptions{}
	dialer.DomainResolver = &option.DomainResolveOptions{Server: dnsLocal}
	return []option.DNSServerOptions{
		endpoint.server(dnsDirect, dialer),
		{Type: C.DNSTypeLocal, Tag: dnsLocal, Options: &option.LocalDNSServerOptions{}},
	}, nil
}

type dohEndpoint struct {
	host string
	port uint16
	path string
}

func parseDoH(value string) (dohEndpoint, bool) {
	parsed, err := url.Parse(value)
	if err != nil || parsed.Scheme != schemeHTTPS || parsed.Hostname() == "" {
		return dohEndpoint{}, false
	}
	endpoint := dohEndpoint{host: parsed.Hostname(), path: parsed.Path}
	if port := parsed.Port(); port != "" {
		number, err := parsePort(port)
		if err != nil {
			return dohEndpoint{}, false
		}
		endpoint.port = number
	}
	return endpoint, true
}

func (e dohEndpoint) isDomain() bool {
	_, err := netip.ParseAddr(e.host)
	return err != nil
}

func (e dohEndpoint) server(tag string, dialer option.RawLocalDNSServerOptions) option.DNSServerOptions {
	return option.DNSServerOptions{
		Type: C.DNSTypeHTTPS,
		Tag:  tag,
		Options: &option.RemoteHTTPSDNSServerOptions{
			RemoteTLSDNSServerOptions: option.RemoteTLSDNSServerOptions{
				RemoteDNSServerOptions: option.RemoteDNSServerOptions{
					RawLocalDNSServerOptions: dialer,
					DNSServerAddressOptions:  option.DNSServerAddressOptions{Server: e.host, ServerPort: e.port},
				},
			},
			Path: e.path,
		},
	}
}
