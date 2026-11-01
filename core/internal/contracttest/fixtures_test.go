// Package contracttest checks the shared fixtures against openapi.yaml and
// the generated types (tech.md 10). The app runs the same fixtures through its
// generated models in app/test/contracts.
package contracttest

import (
	"bytes"
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/getkin/kin-openapi/openapi3"
	"github.com/stretchr/testify/require"

	"github.com/Evgenius09/vpn-project/core/internal/contract"
)

const (
	specPath     = "../../../contracts/openapi.yaml"
	fixturesPath = "../../../contracts/fixtures"
)

func loadSpec(t *testing.T) *openapi3.T {
	t.Helper()
	loader := openapi3.NewLoader()
	spec, err := loader.LoadFromFile(specPath)
	require.NoError(t, err)
	require.NoError(t, spec.Validate(context.Background()))
	return spec
}

func validate(t *testing.T, spec *openapi3.T, schema string, document any) error {
	t.Helper()
	ref, ok := spec.Components.Schemas[schema]
	require.True(t, ok, schema)
	return ref.Value.VisitJSON(document, openapi3.EnableJSONSchema2020())
}

func readJSON(t *testing.T, path string) (raw []byte, document map[string]any) {
	t.Helper()
	raw, err := os.ReadFile(path)
	require.NoError(t, err)
	require.NoError(t, json.Unmarshal(raw, &document))
	return raw, document
}

func fixtures(t *testing.T, dir string) []string {
	t.Helper()
	paths, err := filepath.Glob(filepath.Join(fixturesPath, dir, "*.json"))
	require.NoError(t, err)
	require.NotEmpty(t, paths, dir)
	return paths
}

// roundTrip fails on a field the generated type does not know and on a value
// that changes when the type writes it back.
func roundTrip[T any](t *testing.T, raw []byte) T {
	t.Helper()
	var value T
	decoder := json.NewDecoder(bytes.NewReader(raw))
	decoder.DisallowUnknownFields()
	require.NoError(t, decoder.Decode(&value))
	encoded, err := json.Marshal(value)
	require.NoError(t, err)
	require.JSONEq(t, string(raw), string(encoded))
	return value
}

func requireServerParams(t *testing.T, servers []contract.ServerNode) {
	t.Helper()
	for _, server := range servers {
		require.Equal(t, server.Protocol == contract.ServerProtocolVlessReality, server.Vless != nil, server.Id)
		require.Equal(t, server.Protocol == contract.ServerProtocolHysteria2, server.Hysteria2 != nil, server.Id)
	}
}

func TestProfileFixtures(t *testing.T) {
	spec := loadSpec(t)
	for _, path := range fixtures(t, "profile") {
		t.Run(filepath.Base(path), func(t *testing.T) {
			raw, document := readJSON(t, path)
			require.NoError(t, validate(t, spec, "ProfileV1", document))
			requireServerParams(t, roundTrip[contract.ProfileV1](t, raw).Servers)
		})
	}
}

func TestTunnelRequestFixtures(t *testing.T) {
	spec := loadSpec(t)
	for _, path := range fixtures(t, "tunnel_request") {
		t.Run(filepath.Base(path), func(t *testing.T) {
			raw, document := readJSON(t, path)
			require.NoError(t, validate(t, spec, "TunnelRequest", document))
			requireServerParams(t, roundTrip[contract.TunnelRequest](t, raw).Servers)
		})
	}
}

func TestCoreEventFixtures(t *testing.T) {
	spec := loadSpec(t)
	seen := map[contract.CoreEventType]bool{}
	for _, path := range fixtures(t, "core_event") {
		t.Run(filepath.Base(path), func(t *testing.T) {
			raw, document := readJSON(t, path)
			require.NoError(t, validate(t, spec, "CoreEvent", document))
			event := roundTrip[contract.CoreEvent](t, raw)
			seen[event.Type] = true

			set := map[contract.CoreEventType]bool{
				contract.CoreEventTypeState:   event.State != nil,
				contract.CoreEventTypeMode:    event.Mode != nil,
				contract.CoreEventTypeTraffic: event.Traffic != nil,
				contract.CoreEventTypeUrlTest: event.UrlTest != nil,
				contract.CoreEventTypeError:   event.Error != nil,
			}
			for eventType, present := range set {
				require.Equal(t, eventType == event.Type, present, "payload %s", eventType)
			}
		})
	}
	require.Len(t, seen, 5, "fixtures cover every event type")
}

// Proves the validator rejects bad input, so the fixture tests cannot pass
// because validation silently does nothing.
func TestValidatorRejectsBrokenDocuments(t *testing.T) {
	spec := loadSpec(t)
	tests := []struct {
		name    string
		fixture string
		schema  string
		mutate  func(map[string]any)
	}{
		{
			"missing required field", "profile/trial.json", "ProfileV1",
			func(d map[string]any) { delete(d, "account") },
		},
		{
			"unknown field", "profile/trial.json", "ProfileV1",
			func(d map[string]any) { d["surprise"] = true },
		},
		{
			"wrong schema version", "profile/trial.json", "ProfileV1",
			func(d map[string]any) { d["schemaVersion"] = 2 },
		},
		{
			"enum value outside the contract", "core_event/traffic.json", "CoreEvent",
			func(d map[string]any) { d["type"] = "unknown" },
		},
		{
			"mtu below the minimum", "tunnel_request/android_regular.json", "TunnelRequest",
			func(d map[string]any) {
				settings := d["settings"].(map[string]any)
				settings["net"].(map[string]any)["mtu"] = 100
			},
		},
		{
			"port outside the range", "tunnel_request/android_regular.json", "TunnelRequest",
			func(d map[string]any) {
				servers := d["servers"].([]any)
				servers[0].(map[string]any)["port"] = 70000
			},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, document := readJSON(t, filepath.Join(fixturesPath, tt.fixture))
			require.NoError(t, validate(t, spec, tt.schema, document))
			tt.mutate(document)
			require.Error(t, validate(t, spec, tt.schema, document))
		})
	}
}
