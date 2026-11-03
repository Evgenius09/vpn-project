// Package catalog syncs the servers table from the panel hosts and
// servers.yaml (tech.md 6, 7, 16 S1-11).
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
	"os"
	"regexp"
	"strconv"
	"strings"
	"unicode"

	"github.com/google/uuid"
	"sigs.k8s.io/yaml"

	"github.com/Evgenius09/vpn-project/backend/internal/gen/api"
	"github.com/Evgenius09/vpn-project/backend/internal/panel"
)

var (
	// ErrInvalidCatalog means servers.yaml cannot be trusted as a whole.
	ErrInvalidCatalog = errors.New("catalog: invalid servers.yaml")
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

var countryPattern = regexp.MustCompile(`^[A-Z]{2}$`)

// Entry is one record of servers.yaml: what the panel does not know.
type Entry struct {
	RemnawaveHostUUID uuid.UUID `json:"remnawaveHostUuid"`
	Group             string    `json:"group"`
	DisplayName       string    `json:"displayName"`
	CountryCode       string    `json:"countryCode"`
	City              *string   `json:"city,omitempty"`
	SortWeight        int       `json:"sortWeight"`
	// Enabled is true when omitted.
	Enabled *bool `json:"enabled,omitempty"`
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

// Build joins hosts with entries. A host without an entry is not published.
// A host that fails validation is skipped, so one broken host cannot freeze
// the rest of the catalog. Entries must come from LoadEntries.
func Build(hosts []panel.PanelHost, entries []Entry) ([]Server, []Skipped, error) {
	byHost := make(map[uuid.UUID]Entry, len(entries))
	for _, entry := range entries {
		byHost[entry.RemnawaveHostUUID] = entry
	}
	seen := make(map[uuid.UUID]struct{}, len(hosts))
	var servers []Server
	var skipped []Skipped
	for _, host := range hosts {
		if _, duplicate := seen[host.UUID]; duplicate {
			return nil, nil, fmt.Errorf("%w: host %s listed twice", ErrInvalidPanel, host.UUID)
		}
		seen[host.UUID] = struct{}{}
		entry, listed := byHost[host.UUID]
		if !listed {
			continue
		}
		server, err := publish(host, entry)
		if err != nil {
			skipped = append(skipped, Skipped{HostUUID: host.UUID, Err: err})
			continue
		}
		servers = append(servers, server)
	}
	return servers, skipped, nil
}

func publish(host panel.PanelHost, entry Entry) (Server, error) {
	entry, err := normalizeEntry(entry)
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
		params, err = vlessParams(host.Params)
	case api.ServerProtocolHysteria2:
		params, err = hysteriaParams(host.Params)
	default:
		err = errors.New("unknown protocol")
	}
	if err != nil {
		return Server{}, fmt.Errorf("%w: %w", ErrInvalidHost, err)
	}
	return Server{
		HostUUID:    host.UUID,
		Group:       entry.Group,
		Protocol:    host.Protocol,
		DisplayName: entry.DisplayName,
		CountryCode: entry.CountryCode,
		City:        entry.City,
		Address:     address,
		Port:        host.Port,
		Params:      params,
		SortWeight:  entry.SortWeight,
		Enabled:     host.Enabled && (entry.Enabled == nil || *entry.Enabled),
	}, nil
}

// Publish returns the row one host and its entry produce. The seed uses it so
// that its rows hash the way a sync would.
func Publish(host panel.PanelHost, entry Entry) (Server, error) {
	return publish(host, entry)
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

func hysteriaParams(raw json.RawMessage) (json.RawMessage, error) {
	var fields hysteriaFields
	if err := decodeStrict(raw, &fields); err != nil {
		return nil, err
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

func normalizeEntry(entry Entry) (Entry, error) {
	entry.DisplayName = strings.TrimSpace(entry.DisplayName)
	entry.CountryCode = strings.ToUpper(strings.TrimSpace(entry.CountryCode))
	if entry.City != nil {
		city := strings.TrimSpace(*entry.City)
		entry.City = &city
		if city == "" {
			entry.City = nil
		}
	}
	switch {
	case entry.RemnawaveHostUUID == uuid.Nil:
		return Entry{}, errors.New("missing remnawaveHostUuid")
	case !api.TunnelMode(entry.Group).Valid():
		return Entry{}, fmt.Errorf("host %s: unknown group", entry.RemnawaveHostUUID)
	case entry.DisplayName == "":
		return Entry{}, fmt.Errorf("host %s: blank displayName", entry.RemnawaveHostUUID)
	case !countryPattern.MatchString(entry.CountryCode):
		return Entry{}, fmt.Errorf("host %s: countryCode must be two letters", entry.RemnawaveHostUUID)
	case entry.SortWeight < math.MinInt32 || entry.SortWeight > math.MaxInt32:
		return Entry{}, fmt.Errorf("host %s: sortWeight out of range", entry.RemnawaveHostUUID)
	}
	return entry, nil
}

// LoadEntries reads servers.yaml. Any bad entry fails the whole file: the file
// ships as one deploy artifact, and a missing or broken file read as empty
// would switch every server off.
func LoadEntries(path string) ([]Entry, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read catalog: %w", err)
	}
	encoded, err := yaml.YAMLToJSON(raw)
	if err != nil {
		return nil, fmt.Errorf("%w: %w", ErrInvalidCatalog, err)
	}
	if bytes.Equal(bytes.TrimSpace(encoded), []byte("null")) {
		return nil, fmt.Errorf("%w: the file must hold a list, write [] for none", ErrInvalidCatalog)
	}
	var entries []Entry
	decoder := json.NewDecoder(bytes.NewReader(encoded))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&entries); err != nil {
		return nil, fmt.Errorf("%w: %w", ErrInvalidCatalog, err)
	}
	seen := make(map[uuid.UUID]struct{}, len(entries))
	for index, entry := range entries {
		if entries[index], err = normalizeEntry(entry); err != nil {
			return nil, fmt.Errorf("%w: entry %d: %w", ErrInvalidCatalog, index+1, err)
		}
		if _, duplicate := seen[entry.RemnawaveHostUUID]; duplicate {
			return nil, fmt.Errorf("%w: host %s listed twice", ErrInvalidCatalog, entry.RemnawaveHostUUID)
		}
		seen[entry.RemnawaveHostUUID] = struct{}{}
	}
	return entries, nil
}
