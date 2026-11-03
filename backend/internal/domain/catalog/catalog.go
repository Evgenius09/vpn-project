// Package catalog syncs the servers table from the panel hosts (tech.md 6, 7,
// 16 S1-11, 41).
package catalog

import (
	"bytes"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"unicode"

	"github.com/google/uuid"

	"github.com/Evgenius09/vpn-project/backend/internal/gen/api"
	"github.com/Evgenius09/vpn-project/backend/internal/panel"
)

var (
	// ErrInvalidPanel means the host list cannot be trusted as a whole.
	ErrInvalidPanel = errors.New("catalog: invalid panel hosts")
	// ErrInvalidHost means one host cannot be published.
	ErrInvalidHost = errors.New("catalog: invalid host")
)

const (
	realityKeyBytes = 32
	maxShortIDBytes = 8
	maxPort         = 65535
)

// Host tags that carry what the servers table needs beyond the connection
// (tech.md 41.1). The panel allows only A-Z, 0-9, _ and : in a tag.
const (
	tagCountry   = "COUNTRY:"
	tagWhitelist = "WHITELIST"
	tagHop       = "HOP:"
)

var countryPattern = regexp.MustCompile(`^[A-Z]{2}$`)

// entry is what the host tags and texts say about the server.
type entry struct {
	group       string
	displayName string
	countryCode string
	city        *string
	sortWeight  int
	portHopping *api.PortHopping
}

// Server is a row of the servers table without its id.
type Server struct {
	HostUUID    uuid.UUID
	Group       string
	Protocol    string
	DisplayName string
	CountryCode string
	City        *string
	Address     string
	Port        int
	// Params holds the non-secret protocol fields in canonical JSON.
	Params     json.RawMessage
	SortWeight int
	Enabled    bool
}

// ContentHash covers every published field except Enabled, which the sync
// compares on its own so that a vanished host can be switched off without
// rebuilding its hash. Each field is length-prefixed, so no two rows collide by
// shifting text between neighbours.
func (s Server) ContentHash() string {
	hash := sha256.New()
	fields := []*string{
		&s.Group, &s.Protocol, &s.DisplayName, &s.CountryCode, s.City, &s.Address,
		ptr(strconv.Itoa(s.Port)), ptr(string(s.Params)), ptr(strconv.Itoa(s.SortWeight)),
	}
	for _, field := range fields {
		if field == nil {
			_, _ = hash.Write([]byte("-1;"))
			continue
		}
		_, _ = fmt.Fprintf(hash, "%d:%s;", len(*field), *field)
	}
	return hex.EncodeToString(hash.Sum(nil))
}

func ptr[T any](value T) *T { return &value }

// Skipped is a host that has an entry but cannot be published.
type Skipped struct {
	HostUUID uuid.UUID
	Err      error
}

// Build publishes the hosts tagged with a country. A host without that tag is
// not for the app. A host that fails validation is skipped, so one broken host
// cannot freeze the rest of the catalog.
func Build(hosts []panel.PanelHost) ([]Server, []Skipped, error) {
	seen := make(map[uuid.UUID]struct{}, len(hosts))
	var servers []Server
	var skipped []Skipped
	for _, host := range hosts {
		if _, duplicate := seen[host.UUID]; duplicate {
			return nil, nil, fmt.Errorf("%w: host %s listed twice", ErrInvalidPanel, host.UUID)
		}
		seen[host.UUID] = struct{}{}
		if !listed(host) {
			continue
		}
		server, err := Publish(host)
		if err != nil {
			skipped = append(skipped, Skipped{HostUUID: host.UUID, Err: err})
			continue
		}
		servers = append(servers, server)
	}
	return servers, skipped, nil
}

func listed(host panel.PanelHost) bool {
	return slices.ContainsFunc(host.Tags, func(tag string) bool { return strings.HasPrefix(tag, tagCountry) })
}

// Publish returns the row of one host. The seed uses it so that its rows hash
// the way a sync would.
func Publish(host panel.PanelHost) (Server, error) {
	entry, err := entryOf(host)
	if err != nil {
		return Server{}, fmt.Errorf("%w: %w", ErrInvalidHost, err)
	}
	address := strings.TrimSpace(host.Address)
	switch {
	case address == "" || strings.ContainsFunc(address, unicode.IsSpace):
		return Server{}, fmt.Errorf("%w: bad address", ErrInvalidHost)
	case host.Port < 1 || host.Port > maxPort:
		return Server{}, fmt.Errorf("%w: port out of range", ErrInvalidHost)
	}
	var params json.RawMessage
	switch api.ServerProtocol(host.Protocol) {
	case api.ServerProtocolVlessReality:
		if entry.portHopping != nil {
			return Server{}, fmt.Errorf("%w: port hopping on a vless host", ErrInvalidHost)
		}
		params, err = vlessParams(host.Params)
	case api.ServerProtocolHysteria2:
		params, err = hysteriaParams(host.Params, entry.portHopping)
	default:
		err = errors.New("unknown protocol")
	}
	if err != nil {
		return Server{}, fmt.Errorf("%w: %w", ErrInvalidHost, err)
	}
	return Server{
		HostUUID:    host.UUID,
		Group:       entry.group,
		Protocol:    host.Protocol,
		DisplayName: entry.displayName,
		CountryCode: entry.countryCode,
		City:        entry.city,
		Address:     address,
		Port:        host.Port,
		Params:      params,
		SortWeight:  entry.sortWeight,
		Enabled:     host.Enabled,
	}, nil
}

// vlessFields are the non-secret fields of VlessRealityParams. Without uuid the
// strict decoder refuses a credential that leaked into the host params.
type vlessFields struct {
	Flow        api.VlessRealityParamsFlow `json:"flow"`
	ServerName  string                     `json:"serverName"`
	PublicKey   string                     `json:"publicKey"`
	ShortID     string                     `json:"shortId"`
	Fingerprint api.UtlsFingerprint        `json:"fingerprint"`
}

func vlessParams(raw json.RawMessage) (json.RawMessage, error) {
	var params struct {
		Flow        *api.VlessRealityParamsFlow `json:"flow"`
		ServerName  string                      `json:"serverName"`
		PublicKey   string                      `json:"publicKey"`
		ShortID     *string                     `json:"shortId"`
		Fingerprint api.UtlsFingerprint         `json:"fingerprint"`
	}
	if err := decodeStrict(raw, &params); err != nil {
		return nil, err
	}
	fields := vlessFields{
		ServerName:  strings.TrimSpace(params.ServerName),
		PublicKey:   params.PublicKey,
		Fingerprint: params.Fingerprint,
	}
	switch {
	case params.Flow == nil || !params.Flow.Valid():
		return nil, errors.New("vless: bad flow")
	case params.ShortID == nil:
		return nil, errors.New("vless: missing shortId")
	case fields.ServerName == "":
		return nil, errors.New("vless: blank serverName")
	case !fields.Fingerprint.Valid():
		return nil, errors.New("vless: bad fingerprint")
	}
	fields.Flow, fields.ShortID = *params.Flow, *params.ShortID
	// The same checks as the core (tech.md 21.1), so a host the core would
	// refuse never reaches a profile.
	if key, err := base64.RawURLEncoding.DecodeString(fields.PublicKey); err != nil || len(key) != realityKeyBytes {
		return nil, errors.New("vless: bad publicKey")
	}
	if shortID, err := hex.DecodeString(fields.ShortID); err != nil || len(shortID) > maxShortIDBytes {
		return nil, errors.New("vless: bad shortId")
	}
	return marshal(fields)
}

type hysteriaFields struct {
	ServerName             string           `json:"serverName"`
	ObfsSalamanderPassword *string          `json:"obfsSalamanderPassword,omitempty"`
	PortHopping            *api.PortHopping `json:"portHopping,omitempty"`
	UpMbps                 *int             `json:"upMbps,omitempty"`
	DownMbps               *int             `json:"downMbps,omitempty"`
}

// hopping from the catalog entry replaces the one in the host params.
func hysteriaParams(raw json.RawMessage, hopping *api.PortHopping) (json.RawMessage, error) {
	var fields hysteriaFields
	if err := decodeStrict(raw, &fields); err != nil {
		return nil, err
	}
	if hopping != nil {
		fields.PortHopping = hopping
	}
	fields.ServerName = strings.TrimSpace(fields.ServerName)
	switch {
	case fields.ServerName == "":
		return nil, errors.New("hysteria2: blank serverName")
	case fields.ObfsSalamanderPassword != nil && *fields.ObfsSalamanderPassword == "":
		return nil, errors.New("hysteria2: blank obfsSalamanderPassword")
	case fields.UpMbps != nil && *fields.UpMbps <= 0, fields.DownMbps != nil && *fields.DownMbps <= 0:
		return nil, errors.New("hysteria2: speed must be positive")
	}
	if hopping := fields.PortHopping; hopping != nil {
		if hopping.IntervalSec <= 0 {
			return nil, errors.New("hysteria2: hop interval must be positive")
		}
		ports, err := normalizePorts(hopping.Ports)
		if err != nil {
			return nil, err
		}
		fields.PortHopping = &api.PortHopping{Ports: ports, IntervalSec: hopping.IntervalSec}
	}
	return marshal(fields)
}

// normalizePorts accepts what the core accepts: a list of ports and ranges.
func normalizePorts(spec string) (string, error) {
	parts := strings.Split(spec, ",")
	for index, part := range parts {
		first, last, isRange := strings.Cut(strings.TrimSpace(part), "-")
		if !isRange {
			last = first
		}
		start, err := parsePort(first)
		if err != nil {
			return "", err
		}
		end, err := parsePort(last)
		if err != nil {
			return "", err
		}
		if start > end {
			return "", errors.New("hysteria2: reversed port range")
		}
		if isRange {
			parts[index] = fmt.Sprintf("%d-%d", start, end)
		} else {
			parts[index] = strconv.Itoa(start)
		}
	}
	return strings.Join(parts, ","), nil
}

func parsePort(value string) (int, error) {
	port, err := strconv.Atoi(strings.TrimSpace(value))
	if err != nil || port < 1 || port > maxPort {
		return 0, errors.New("hysteria2: bad hopping port")
	}
	return port, nil
}

// decodeStrict keeps only the error class: the input may hold a secret that
// leaked into the host params, and the message would carry it to the log.
func decodeStrict(raw json.RawMessage, target any) error {
	decoder := json.NewDecoder(bytes.NewReader(raw))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		return fmt.Errorf("params do not match the contract: %T", err)
	}
	return nil
}

func marshal(value any) (json.RawMessage, error) {
	encoded, err := json.Marshal(value)
	if err != nil {
		return nil, fmt.Errorf("encode params: %w", err)
	}
	return encoded, nil
}

// entryOf reads the tags and texts of a host. Unknown tags belong to other
// panel users and are ignored.
func entryOf(host panel.PanelHost) (entry, error) {
	result := entry{
		group:       string(api.TunnelModeRegular),
		displayName: strings.TrimSpace(host.Remark),
		sortWeight:  host.ViewPosition,
	}
	if city := strings.TrimSpace(host.Description); city != "" {
		result.city = &city
	}
	countries, hops := 0, 0
	for _, tag := range host.Tags {
		switch {
		case tag == tagWhitelist:
			result.group = string(api.TunnelModeWhitelist)
		case strings.HasPrefix(tag, tagCountry):
			countries++
			result.countryCode = strings.TrimPrefix(tag, tagCountry)
		case strings.HasPrefix(tag, tagHop):
			hops++
			hopping, err := hopOf(strings.TrimPrefix(tag, tagHop))
			if err != nil {
				return entry{}, err
			}
			result.portHopping = hopping
		}
	}
	switch {
	case countries != 1:
		return entry{}, errors.New("want exactly one country tag")
	case !countryPattern.MatchString(result.countryCode):
		return entry{}, errors.New("country tag must hold two letters")
	case hops > 1:
		return entry{}, errors.New("want at most one hop tag")
	case result.displayName == "":
		return entry{}, errors.New("blank remark")
	case result.sortWeight < math.MinInt32 || result.sortWeight > math.MaxInt32:
		return entry{}, errors.New("view position out of range")
	}
	return result, nil
}

// hopOf reads <ports>:<intervalSec>, where _ stands for the - of a range,
// because a tag cannot hold a dash or a comma.
func hopOf(value string) (*api.PortHopping, error) {
	ports, interval, found := strings.Cut(value, ":")
	seconds, err := strconv.Atoi(interval)
	if !found || err != nil {
		return nil, errors.New("hop tag must be HOP:<ports>:<intervalSec>")
	}
	return &api.PortHopping{Ports: strings.ReplaceAll(ports, "_", "-"), IntervalSec: seconds}, nil
}
