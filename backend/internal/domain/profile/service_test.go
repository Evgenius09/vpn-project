package profile

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"
	"pgregory.net/rapid"

	"github.com/Evgenius09/vpn-project/backend/internal/gen/api"
)

const (
	vlessSecret    = "vless-secret"
	hysteriaSecret = "hysteria-secret"
)

type fakeStore struct {
	account    Account
	servers    []Server
	accountErr error
	serversErr error
}

func (f *fakeStore) Account(context.Context, uuid.UUID) (Account, error) {
	return f.account, f.accountErr
}

func (f *fakeStore) Servers(context.Context) ([]Server, error) {
	return f.servers, f.serversErr
}

func vlessServer() Server {
	return Server{
		ID: uuid.New(), Group: "regular", Protocol: "vless_reality", DisplayName: "A",
		CountryCode: "DE", Address: "a.invalid", Port: 443,
		Params: json.RawMessage(`{"flow":"xtls-rprx-vision","serverName":"s","publicKey":"k","shortId":"1","fingerprint":"chrome"}`),
	}
}

func hysteriaServer() Server {
	return Server{
		ID: uuid.New(), Group: "whitelist", Protocol: "hysteria2", DisplayName: "B",
		CountryCode: "NL", Address: "b.invalid", Port: 443,
		Params: json.RawMessage(`{"serverName":"s"}`),
	}
}

func account(status string) Account {
	return Account{Status: status, DeviceLimit: 5, VlessUUID: vlessSecret, Hysteria2Auth: hysteriaSecret}
}

func service(store Store) *Service {
	return NewService(store, Options{
		Endpoints: api.ProfileEndpoints{Api: []string{"https://a"}, Bot: "https://t.me/b"},
		Now:       func() time.Time { return time.Date(2026, 11, 1, 0, 0, 0, 0, time.UTC) },
	})
}

func TestBuildAddsTheCredentialsOfTheUser(t *testing.T) {
	store := &fakeStore{account: account("trial"), servers: []Server{vlessServer(), hysteriaServer()}}

	result, err := service(store).Build(context.Background(), uuid.New())

	require.NoError(t, err)
	require.Len(t, result.Profile.Servers, 2)
	require.Equal(t, vlessSecret, result.Profile.Servers[0].Vless.Uuid)
	require.Nil(t, result.Profile.Servers[0].Hysteria2)
	require.Equal(t, hysteriaSecret, result.Profile.Servers[1].Hysteria2.Password)
	require.Nil(t, result.Profile.Servers[1].Vless)
}

func TestStatusDecidesWhetherServersAreSent(t *testing.T) {
	tests := []struct {
		status       string
		servers      int
		provisioning bool
	}{
		{"trial", 1, false},
		{"active", 1, false},
		{"provisioning", 0, true},
		{"expired", 0, false},
		{"blocked", 0, false},
	}
	for _, tt := range tests {
		t.Run(tt.status, func(t *testing.T) {
			store := &fakeStore{account: account(tt.status), servers: []Server{vlessServer()}}

			result, err := service(store).Build(context.Background(), uuid.New())

			require.NoError(t, err)
			require.Len(t, result.Profile.Servers, tt.servers)
			require.NotNil(t, result.Profile.Servers, "servers encodes as an array, never null")
			require.Equal(t, tt.provisioning, result.Provisioning)
		})
	}
}

func TestStoreFailuresPropagate(t *testing.T) {
	failure := errors.New("database down")

	_, err := service(&fakeStore{accountErr: failure}).Build(context.Background(), uuid.New())
	require.ErrorIs(t, err, failure)

	_, err = service(&fakeStore{account: account("trial"), serversErr: failure}).Build(context.Background(), uuid.New())
	require.ErrorIs(t, err, failure)
}

func TestBadParamsFailWithoutLeakingSecrets(t *testing.T) {
	server := vlessServer()
	server.Params = json.RawMessage(`{"surprise":true}`)
	store := &fakeStore{account: account("trial"), servers: []Server{server}}

	_, err := service(store).Build(context.Background(), uuid.New())

	require.Error(t, err)
	require.NotContains(t, err.Error(), vlessSecret)
}

func TestUnknownProtocolFails(t *testing.T) {
	server := vlessServer()
	server.Protocol = "wireguard"
	store := &fakeStore{account: account("trial"), servers: []Server{server}}

	_, err := service(store).Build(context.Background(), uuid.New())
	require.ErrorContains(t, err, "unknown protocol")
}

func serverGen() *rapid.Generator[Server] {
	return rapid.Custom(func(t *rapid.T) Server {
		server := vlessServer()
		server.DisplayName = rapid.StringMatching(`[a-z]{1,12}`).Draw(t, "name")
		server.Address = rapid.StringMatching(`[a-z]{1,12}\.invalid`).Draw(t, "address")
		server.Port = rapid.IntRange(1, 65535).Draw(t, "port")
		server.SortWeight = rapid.IntRange(0, 100).Draw(t, "weight")
		return server
	})
}

// tech.md 15.2: the ETag stays stable on unchanged data.
func TestETagIsStableWhenNothingChanges(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		servers := rapid.SliceOfN(serverGen(), 1, 5).Draw(t, "servers")
		store := &fakeStore{account: account("trial"), servers: servers}

		first, err := NewService(store, Options{Now: func() time.Time { return time.Unix(1, 0) }}).Build(context.Background(), uuid.New())
		require.NoError(t, err)
		second, err := NewService(store, Options{Now: func() time.Time { return time.Unix(2, 0) }}).Build(context.Background(), uuid.New())
		require.NoError(t, err)

		require.Equal(t, first.ETag, second.ETag, "generatedAt must not affect the ETag")
	})
}

// tech.md 15.2: the ETag changes when any server changes.
func TestETagChangesWithAnyServer(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		servers := rapid.SliceOfN(serverGen(), 1, 5).Draw(t, "servers")
		index := rapid.IntRange(0, len(servers)-1).Draw(t, "index")
		field := rapid.SampledFrom([]string{"name", "address", "port", "weight"}).Draw(t, "field")

		before, err := service(&fakeStore{account: account("trial"), servers: servers}).Build(context.Background(), uuid.New())
		require.NoError(t, err)

		changed := append([]Server(nil), servers...)
		switch field {
		case "name":
			changed[index].DisplayName += "x"
		case "address":
			changed[index].Address = "x" + changed[index].Address
		case "port":
			changed[index].Port = changed[index].Port%65535 + 1
		case "weight":
			changed[index].SortWeight++
		}

		after, err := service(&fakeStore{account: account("trial"), servers: changed}).Build(context.Background(), uuid.New())
		require.NoError(t, err)
		require.NotEqual(t, before.ETag, after.ETag, fmt.Sprintf("changed %s of server %d", field, index))
	})
}

func TestETagIsQuoted(t *testing.T) {
	etag, err := ComputeETag(api.ProfileV1{})
	require.NoError(t, err)
	require.Regexp(t, `^"[0-9a-f]{64}"$`, etag)
}

func TestLoadPolicyRejectsUnknownFields(t *testing.T) {
	path := t.TempDir() + "/policy.yaml"
	require.NoError(t, writeFile(path, "surprise: true\n"))
	_, err := LoadPolicy(path)
	require.Error(t, err)
}
