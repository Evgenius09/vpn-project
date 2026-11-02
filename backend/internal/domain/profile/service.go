// Package profile builds ProfileV1, the reference vertical of the backend
// (tech.md 15.2).
package profile

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"time"

	"github.com/google/uuid"
	"sigs.k8s.io/yaml"

	"github.com/Evgenius09/vpn-project/backend/internal/gen/api"
)

const schemaVersion = 1

// Options are the values that come from configuration.
type Options struct {
	Policy    api.ClientPolicy
	Endpoints api.ProfileEndpoints
	Now       func() time.Time
}

// Service builds profiles.
type Service struct {
	store     Store
	policy    api.ClientPolicy
	endpoints api.ProfileEndpoints
	now       func() time.Time
}

// NewService returns a service.
func NewService(store Store, options Options) *Service {
	now := options.Now
	if now == nil {
		now = time.Now
	}
	return &Service{store: store, policy: options.Policy, endpoints: options.Endpoints, now: now}
}

// Result is a built profile.
type Result struct {
	Profile api.ProfileV1
	ETag    string
	// Provisioning asks the client to retry shortly.
	Provisioning bool
}

// Build assembles the profile of an account.
func (s *Service) Build(ctx context.Context, accountID uuid.UUID) (Result, error) {
	account, err := s.store.Account(ctx, accountID)
	if err != nil {
		return Result{}, fmt.Errorf("load account: %w", err)
	}

	nodes := []api.ServerNode{}
	if servesTraffic(account.Status) {
		servers, err := s.store.Servers(ctx)
		if err != nil {
			return Result{}, fmt.Errorf("load servers: %w", err)
		}
		if nodes, err = serverNodes(servers, account); err != nil {
			return Result{}, err
		}
	}

	profile := api.ProfileV1{
		SchemaVersion: schemaVersion,
		GeneratedAt:   s.now().UTC(),
		Account: api.AccountInfo{
			Status:            api.AccountStatus(account.Status),
			TelegramUsername:  account.TelegramUsername,
			ExpiresAt:         account.ExpiresAt,
			TrafficUsedBytes:  account.TrafficUsedBytes,
			TrafficLimitBytes: account.TrafficLimitBytes,
			DeviceLimit:       account.DeviceLimit,
		},
		Servers:   nodes,
		Policy:    s.policy,
		Endpoints: s.endpoints,
	}
	etag, err := ComputeETag(profile)
	if err != nil {
		return Result{}, err
	}
	return Result{
		Profile:      profile,
		ETag:         etag,
		Provisioning: account.Status == string(api.AccountStatusProvisioning),
	}, nil
}

// servesTraffic reports whether an account may receive servers (tech.md 5.2).
func servesTraffic(status string) bool {
	return status == string(api.AccountStatusTrial) || status == string(api.AccountStatusActive)
}

// ComputeETag hashes the content of a profile. GeneratedAt changes on every
// build, so it stays out: otherwise no client would ever get a 304.
func ComputeETag(profile api.ProfileV1) (string, error) {
	profile.GeneratedAt = time.Time{}
	encoded, err := json.Marshal(profile)
	if err != nil {
		return "", fmt.Errorf("encode profile: %w", err)
	}
	sum := sha256.Sum256(encoded)
	return `"` + hex.EncodeToString(sum[:]) + `"`, nil
}

func serverNodes(servers []Server, account Account) ([]api.ServerNode, error) {
	nodes := make([]api.ServerNode, 0, len(servers))
	for _, server := range servers {
		node, err := serverNode(server, account)
		if err != nil {
			return nil, fmt.Errorf("server %s: %w", server.ID, err)
		}
		nodes = append(nodes, node)
	}
	return nodes, nil
}

func serverNode(server Server, account Account) (api.ServerNode, error) {
	countryCode := server.CountryCode
	node := api.ServerNode{
		Id:          server.ID.String(),
		Group:       api.TunnelMode(server.Group),
		Name:        server.DisplayName,
		CountryCode: &countryCode,
		City:        server.City,
		Protocol:    api.ServerProtocol(server.Protocol),
		Address:     server.Address,
		Port:        server.Port,
		SortWeight:  server.SortWeight,
	}
	switch node.Protocol {
	case api.ServerProtocolVlessReality:
		var params api.VlessRealityParams
		if err := decodeParams(server.Params, withSecret("uuid", account.VlessUUID), &params); err != nil {
			return api.ServerNode{}, err
		}
		node.Vless = &params
	case api.ServerProtocolHysteria2:
		var params api.Hysteria2Params
		if err := decodeParams(server.Params, withSecret("password", account.Hysteria2Auth), &params); err != nil {
			return api.ServerNode{}, err
		}
		node.Hysteria2 = &params
	default:
		return api.ServerNode{}, fmt.Errorf("unknown protocol %q", server.Protocol)
	}
	return node, nil
}

func withSecret(key, value string) map[string]any {
	return map[string]any{key: value}
}

// decodeParams merges the stored non-secret parameters with the credential of
// the user. Unknown fields fail, so a catalog typo cannot silently vanish.
func decodeParams(raw json.RawMessage, secret map[string]any, target any) error {
	var fields map[string]any
	if err := json.Unmarshal(raw, &fields); err != nil {
		return fmt.Errorf("decode params: %w", err)
	}
	for key, value := range secret {
		fields[key] = value
	}
	merged, err := json.Marshal(fields)
	if err != nil {
		return fmt.Errorf("encode params: %w", err)
	}
	decoder := json.NewDecoder(bytes.NewReader(merged))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		// The merged value holds a secret, so the error keeps only its class.
		return fmt.Errorf("params do not match the contract: %T", err)
	}
	return nil
}

// LoadPolicy reads the client policy file.
func LoadPolicy(path string) (api.ClientPolicy, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return api.ClientPolicy{}, fmt.Errorf("read policy: %w", err)
	}
	encoded, err := yaml.YAMLToJSON(raw)
	if err != nil {
		return api.ClientPolicy{}, fmt.Errorf("parse policy: %w", err)
	}
	var policy api.ClientPolicy
	decoder := json.NewDecoder(bytes.NewReader(encoded))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&policy); err != nil {
		return api.ClientPolicy{}, fmt.Errorf("decode policy: %w", err)
	}
	return policy, nil
}
