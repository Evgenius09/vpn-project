package remnawave

import (
	"context"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/getkin/kin-openapi/openapi3"
	"github.com/google/uuid"
	"github.com/stretchr/testify/require"

	"github.com/Evgenius09/vpn-project/backend/internal/domain/catalog"
	"github.com/Evgenius09/vpn-project/backend/internal/panel"
)

// The recorded inbound carries the RFC 7748 6.1 private key of Alice, so the
// expected public key comes from the RFC, not from our code.
var rfcPublicKey = func() string {
	key, _ := hex.DecodeString("8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a")
	return base64.RawURLEncoding.EncodeToString(key)
}()

const (
	token         = "test-token"
	squad         = "baf9736b-afde-4875-aad1-a2a0ba300d51"
	username      = "tg_990000001"
	vlessHostUUID = "6d03977d-2193-46d0-9c57-c7eff7998eb8"
	hy2HostUUID   = "b225a0cb-9d46-4af6-b608-96a248141054"
)

type recorded struct {
	Status int             `json:"status"`
	Body   json.RawMessage `json:"body"`
}

func loadRecorded(t *testing.T) map[string]recorded {
	t.Helper()
	raw, err := os.ReadFile("testdata/panel-3.4.8.json")
	require.NoError(t, err)
	var responses map[string]recorded
	require.NoError(t, json.Unmarshal(raw, &responses))
	return responses
}

func loadPanelSpec(t *testing.T) *openapi3.T {
	t.Helper()
	spec, err := openapi3.NewLoader().LoadFromFile("../../../../contracts/remnawave/openapi-3.4.8.json")
	require.NoError(t, err)
	return spec
}

func validate(t *testing.T, spec *openapi3.T, schema string, document []byte) {
	t.Helper()
	var decoded any
	require.NoError(t, json.Unmarshal(document, &decoded))
	ref, ok := spec.Components.Schemas[schema]
	require.True(t, ok, schema)
	require.NoError(t, ref.Value.VisitJSON(decoded), schema)
}

// fakePanel answers with recorded responses and keeps the request bodies.
type fakePanel struct {
	t         *testing.T
	responses map[string]recorded
	routes    map[string]string // "METHOD path" -> recorded name
	mu        sync.Mutex
	bodies    map[string][]byte
}

func newFakePanel(t *testing.T, routes map[string]string) (*fakePanel, *Client) {
	t.Helper()
	fake := &fakePanel{t: t, responses: loadRecorded(t), routes: routes, bodies: map[string][]byte{}}
	server := httptest.NewServer(fake)
	t.Cleanup(server.Close)
	client, err := New(server.URL, token, uuid.MustParse(squad))
	require.NoError(t, err)
	return fake, client
}

func (f *fakePanel) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	key := r.Method + " " + r.URL.Path
	body, _ := io.ReadAll(r.Body)
	f.mu.Lock()
	f.bodies[key] = body
	f.mu.Unlock()
	// The panel refuses the token without these headers (tech.md 39.1).
	if r.Header.Get("Authorization") != "Bearer "+token ||
		r.Header.Get("X-Forwarded-For") == "" || r.Header.Get("X-Forwarded-Proto") != "https" {
		w.WriteHeader(http.StatusForbidden)
		return
	}
	name, ok := f.routes[key]
	if !ok {
		f.t.Errorf("unexpected request %s", key)
		w.WriteHeader(http.StatusTeapot)
		return
	}
	response := f.responses[name]
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(response.Status)
	_, _ = w.Write(response.Body)
}

func (f *fakePanel) body(key string) []byte {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.bodies[key]
}

func TestRecordedResponsesMatchThePanelSpec(t *testing.T) {
	spec := loadPanelSpec(t)
	responses := loadRecorded(t)
	for name, schema := range map[string]string{
		"get_user":     "UserResponseDto",
		"create_user":  "UserResponseDto",
		"update_user":  "UserResponseDto",
		"get_hosts":    "GetHostsResponseDto",
		"get_inbounds": "GetAllInboundsResponseDto",
	} {
		t.Run(name, func(t *testing.T) {
			validate(t, spec, schema, responses[name].Body)
		})
	}
}

func TestGetUserByUsername(t *testing.T) {
	_, client := newFakePanel(t, map[string]string{"GET /api/users/by-username/" + username: "get_user"})

	user, err := client.GetUserByUsername(context.Background(), username)

	require.NoError(t, err)
	require.Equal(t, username, user.Username)
	require.Positive(t, user.ID)
	require.Equal(t, "fixtureshort", user.ShortUUID)
	require.Equal(t, "c1000000-0000-4000-8000-000000000001", user.VlessUUID)
	require.Equal(t, user.VlessUUID, user.Hysteria2Auth, "tech.md 38.3")
	require.Equal(t, time.Date(2026, 11, 6, 0, 0, 0, 0, time.UTC), user.ExpiresAt.UTC())
}

func TestGetUserByUsernameNotFound(t *testing.T) {
	_, client := newFakePanel(t, map[string]string{"GET /api/users/by-username/" + username: "get_user_not_found"})

	_, err := client.GetUserByUsername(context.Background(), username)

	require.ErrorIs(t, err, panel.ErrNotFound)
}

func TestCreateUserSendsAValidBody(t *testing.T) {
	fake, client := newFakePanel(t, map[string]string{"POST /api/users": "create_user"})
	expires := time.Date(2026, 11, 6, 0, 0, 0, 0, time.UTC)

	user, err := client.CreateUser(context.Background(), panel.CreateUserInput{
		Username: username, ExpiresAt: expires, TrafficLimit: 107374182400,
	})

	require.NoError(t, err)
	require.Equal(t, username, user.Username)
	body := fake.body("POST /api/users")
	validate(t, loadPanelSpec(t), "CreateUserBodyDto", body)
	var sent map[string]any
	require.NoError(t, json.Unmarshal(body, &sent))
	require.Equal(t, map[string]any{
		"username": username, "expireAt": "2026-11-06T00:00:00Z", "trafficLimitBytes": float64(107374182400),
		"trafficLimitStrategy": "NO_RESET", "status": "ACTIVE", "activeInternalSquads": []any{squad},
	}, sent)
	require.Contains(t, string(body), `"trafficLimitBytes":107374182400`, "no exponent in byte counts")
}

func TestCreateUserTakenNameIsAConflict(t *testing.T) {
	_, client := newFakePanel(t, map[string]string{"POST /api/users": "create_user_conflict"})

	_, err := client.CreateUser(context.Background(), panel.CreateUserInput{Username: username, ExpiresAt: time.Now()})

	require.ErrorIs(t, err, panel.ErrConflict)
}

func TestUpdateUserSendsAbsoluteValues(t *testing.T) {
	fake, client := newFakePanel(t, map[string]string{"PATCH /api/users": "update_user"})
	expires := time.Date(2026, 12, 1, 0, 0, 0, 0, time.UTC)

	user, err := client.UpdateUser(context.Background(), 42, panel.UpdateUserInput{ExpiresAt: expires, TrafficLimit: 5})

	require.NoError(t, err)
	require.Equal(t, username, user.Username)
	body := fake.body("PATCH /api/users")
	validate(t, loadPanelSpec(t), "UpdateUserBodyDto", body)
	require.JSONEq(t, `{"id":42,"expireAt":"2026-12-01T00:00:00Z","trafficLimitBytes":5}`, string(body))
}

func TestUpdateUserNotFound(t *testing.T) {
	_, client := newFakePanel(t, map[string]string{"PATCH /api/users": "update_user_not_found"})

	_, err := client.UpdateUser(context.Background(), 42, panel.UpdateUserInput{ExpiresAt: time.Now()})

	require.ErrorIs(t, err, panel.ErrNotFound)
}

func TestListHostsBuildsContractParams(t *testing.T) {
	fake, client := newFakePanel(t, map[string]string{
		"GET /api/hosts": "get_hosts", "GET /api/config-profiles/inbounds": "get_inbounds",
	})
	// The recorded hosts carry no catalog tags yet (tech.md 41.1).
	var recordedHosts map[string][]map[string]any
	require.NoError(t, json.Unmarshal(fake.responses["get_hosts"].Body, &recordedHosts))
	recordedHosts["response"][0]["tags"] = []string{"COUNTRY:SE"}
	recordedHosts["response"][1]["tags"] = []string{"COUNTRY:SE", "HOP:20000_50000:30"}
	recordedHosts["response"][1]["serverDescription"] = "Stockholm"
	edited, err := json.Marshal(recordedHosts)
	require.NoError(t, err)
	fake.responses["get_hosts"] = recorded{Status: http.StatusOK, Body: edited}

	hosts, err := client.ListHosts(context.Background())

	require.NoError(t, err)
	require.Len(t, hosts, 2)
	vless, hy2 := hosts[0], hosts[1]
	require.Equal(t, uuid.MustParse(vlessHostUUID), vless.UUID)
	require.Equal(t, "vless_reality", vless.Protocol)
	require.Equal(t, "203.0.113.10", vless.Address)
	require.Equal(t, 443, vless.Port)
	require.True(t, vless.Enabled)
	require.JSONEq(t, `{"flow":"xtls-rprx-vision","serverName":"www.klarna.com","publicKey":"`+rfcPublicKey+
		`","shortId":"0c490741","fingerprint":"chrome"}`, string(vless.Params))

	require.Equal(t, uuid.MustParse(hy2HostUUID), hy2.UUID)
	require.Equal(t, "hysteria2", hy2.Protocol)
	require.Equal(t, "hy2.example.net", hy2.Address)
	require.JSONEq(t, `{"serverName":"hy2.example.net","obfsSalamanderPassword":"fixture-obfs"}`, string(hy2.Params))

	require.Equal(t, "se-sto-1-vless", vless.Remark)
	require.Empty(t, vless.Description, "a null serverDescription")
	require.Equal(t, []string{"COUNTRY:SE"}, vless.Tags)
	require.Equal(t, 1, vless.ViewPosition)
	require.Equal(t, "Stockholm", hy2.Description)
	require.Equal(t, 2, hy2.ViewPosition)

	// The catalog decodes params and tags strictly (tech.md 29.1, 41.1), so
	// this is the seam.
	servers, skipped, err := catalog.Build(hosts)
	require.NoError(t, err)
	require.Empty(t, skipped)
	require.Len(t, servers, 2)
	require.Contains(t, string(servers[1].Params), `"portHopping":{"intervalSec":30,"ports":"20000-50000"}`)
}

func TestListHostsKeepsThePrivateKeyOut(t *testing.T) {
	_, client := newFakePanel(t, map[string]string{
		"GET /api/hosts": "get_hosts", "GET /api/config-profiles/inbounds": "get_inbounds",
	})
	privateKey := base64.RawURLEncoding.EncodeToString(mustHex("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a"))

	hosts, err := client.ListHosts(context.Background())

	require.NoError(t, err)
	for _, host := range hosts {
		require.NotContains(t, string(host.Params), privateKey)
	}
}

func TestListHostsFallbacksAndSkips(t *testing.T) {
	fake, client := newFakePanel(t, map[string]string{
		"GET /api/hosts": "get_hosts", "GET /api/config-profiles/inbounds": "get_inbounds",
	})
	var hosts map[string][]map[string]any
	require.NoError(t, json.Unmarshal(fake.responses["get_hosts"].Body, &hosts))
	vless, hy2 := hosts["response"][0], hosts["response"][1]
	vless["sni"], vless["fingerprint"], vless["isHidden"] = nil, nil, true
	hy2["sni"], hy2["isDisabled"] = nil, true
	stray := map[string]any{}
	for key, value := range vless {
		stray[key] = value
	}
	stray["uuid"] = uuid.NewString()
	// The Shadowsocks inbound of the default profile is not a protocol we serve.
	stray["inbound"] = map[string]any{
		"configProfileUuid": "00000000-0000-0000-0000-000000000000", "configProfileInboundUuid": "38941ade-e75b-444d-bbde-1b0cfa6591f7",
	}
	unlinked := map[string]any{}
	for key, value := range vless {
		unlinked[key] = value
	}
	unlinked["uuid"] = uuid.NewString()
	unlinked["inbound"] = map[string]any{"configProfileUuid": nil, "configProfileInboundUuid": nil}
	hosts["response"] = append(hosts["response"], stray, unlinked)
	edited, err := json.Marshal(hosts)
	require.NoError(t, err)
	fake.responses["get_hosts"] = recorded{Status: http.StatusOK, Body: edited}

	listed, err := client.ListHosts(context.Background())

	require.NoError(t, err)
	require.Len(t, listed, 2, "hosts on unknown or missing inbounds are left out")
	require.False(t, listed[0].Enabled, "a hidden host is off")
	require.Contains(t, string(listed[0].Params), `"serverName":"www.klarna.com"`, "serverNames[0] without sni")
	require.Contains(t, string(listed[0].Params), `"fingerprint":"chrome"`)
	require.False(t, listed[1].Enabled)
	require.Contains(t, string(listed[1].Params), `"serverName":"hy2.example.net"`, "address without sni")
}

func TestServerErrorsAreUnavailable(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusBadGateway)
	}))
	t.Cleanup(server.Close)
	client, err := New(server.URL, token, uuid.MustParse(squad))
	require.NoError(t, err)
	ctx := context.Background()

	_, err = client.GetUserByUsername(ctx, username)
	require.ErrorIs(t, err, panel.ErrUnavailable)
	_, err = client.CreateUser(ctx, panel.CreateUserInput{Username: username, ExpiresAt: time.Now()})
	require.ErrorIs(t, err, panel.ErrUnavailable)
	_, err = client.UpdateUser(ctx, 1, panel.UpdateUserInput{ExpiresAt: time.Now()})
	require.ErrorIs(t, err, panel.ErrUnavailable)
	_, err = client.ListHosts(ctx)
	require.ErrorIs(t, err, panel.ErrUnavailable)
}

func TestNetworkFailureIsUnavailable(t *testing.T) {
	server := httptest.NewServer(http.NotFoundHandler())
	server.Close()
	client, err := New(server.URL, token, uuid.MustParse(squad))
	require.NoError(t, err)

	_, err = client.GetUserByUsername(context.Background(), username)

	require.ErrorIs(t, err, panel.ErrUnavailable)
}

func TestTimeoutIsUnavailable(t *testing.T) {
	release := make(chan struct{})
	server := httptest.NewServer(http.HandlerFunc(func(_ http.ResponseWriter, _ *http.Request) { <-release }))
	t.Cleanup(server.Close)
	t.Cleanup(func() { close(release) })
	client, err := New(server.URL, token, uuid.MustParse(squad))
	require.NoError(t, err)
	ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancel()

	_, err = client.GetUserByUsername(ctx, username)

	require.ErrorIs(t, err, panel.ErrUnavailable)
}

func TestErrorsCarryNoToken(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusUnauthorized)
		_, _ = w.Write([]byte(`{"message":"bad","errorCode":"A001"}`))
	}))
	t.Cleanup(server.Close)
	client, err := New(server.URL, token, uuid.MustParse(squad))
	require.NoError(t, err)

	_, err = client.GetUserByUsername(context.Background(), username)

	require.Error(t, err)
	require.NotErrorIs(t, err, panel.ErrUnavailable, "a refused token is not retried as an outage")
	require.False(t, strings.Contains(err.Error(), token))
}

func mustHex(value string) []byte {
	decoded, err := hex.DecodeString(value)
	if err != nil {
		panic(err)
	}
	return decoded
}
