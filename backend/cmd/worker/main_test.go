package main

import (
	"context"
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/Evgenius09/vpn-project/backend/internal/config"
	"github.com/Evgenius09/vpn-project/backend/internal/seed"
)

const seedPath = "../../" + seed.DefaultPath

func TestDevPanelServesTheSeedHosts(t *testing.T) {
	client, err := catalogPanel(config.Config{AppEnv: config.EnvDev, PanelMode: config.PanelFake}, seedPath)

	require.NoError(t, err)
	hosts, err := client.ListHosts(context.Background())
	require.NoError(t, err)
	require.Len(t, hosts, 5)
}

func TestFakePanelOutsideDevIsEmpty(t *testing.T) {
	client, err := catalogPanel(config.Config{AppEnv: config.EnvStaging, PanelMode: config.PanelFake}, "absent.json")

	require.NoError(t, err)
	hosts, err := client.ListHosts(context.Background())
	require.NoError(t, err)
	require.Empty(t, hosts)
}

func TestRemnawaveModeHasNoCatalogPanelYet(t *testing.T) {
	client, err := catalogPanel(config.Config{AppEnv: config.EnvStaging, PanelMode: config.PanelRemnawave}, seedPath)

	require.NoError(t, err)
	require.Nil(t, client)
}

func TestDevFailsWithoutTheSeed(t *testing.T) {
	_, err := catalogPanel(config.Config{AppEnv: config.EnvDev, PanelMode: config.PanelFake}, "absent.json")

	require.Error(t, err)
}
