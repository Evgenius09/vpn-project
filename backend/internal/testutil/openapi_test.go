package testutil

import (
	"bytes"
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/Evgenius09/vpn-project/backend/internal/gen/api"
)

const specPath = "../../../contracts/openapi.yaml"

func TestProfileFixturesMatchGeneratedTypes(t *testing.T) {
	spec, err := LoadSpec(context.Background(), specPath)
	require.NoError(t, err)

	paths, err := filepath.Glob("../../../contracts/fixtures/profile/*.json")
	require.NoError(t, err)
	require.NotEmpty(t, paths)

	for _, path := range paths {
		t.Run(filepath.Base(path), func(t *testing.T) {
			raw, err := os.ReadFile(path)
			require.NoError(t, err)

			var document map[string]any
			require.NoError(t, json.Unmarshal(raw, &document))
			require.NoError(t, ValidateSchema(spec, "ProfileV1", document))

			var profile api.ProfileV1
			decoder := json.NewDecoder(bytes.NewReader(raw))
			decoder.DisallowUnknownFields()
			require.NoError(t, decoder.Decode(&profile))

			encoded, err := json.Marshal(profile)
			require.NoError(t, err)
			require.JSONEq(t, string(raw), string(encoded))
		})
	}
}

func TestValidateSchemaRejectsUnknownSchema(t *testing.T) {
	spec, err := LoadSpec(context.Background(), specPath)
	require.NoError(t, err)
	require.Error(t, ValidateSchema(spec, "NoSuchSchema", map[string]any{}))
}

func TestProblemCodesMatchTheContract(t *testing.T) {
	spec, err := LoadSpec(context.Background(), specPath)
	require.NoError(t, err)

	problem := map[string]any{"title": "Limited", "status": 429, "code": "rate_limited", "retryAfterSec": 30}
	require.NoError(t, ValidateSchema(spec, "Problem", problem))

	problem["code"] = "made_up"
	require.Error(t, ValidateSchema(spec, "Problem", problem))
}
