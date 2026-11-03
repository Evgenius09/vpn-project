package catalog

import (
	"testing"

	"github.com/stretchr/testify/require"
)

// The deployed catalog must stay loadable: a broken file stops every sync.
func TestDeployedCatalogLoads(t *testing.T) {
	_, err := LoadEntries("../../../../infra/catalog/servers.yaml")

	require.NoError(t, err)
}
