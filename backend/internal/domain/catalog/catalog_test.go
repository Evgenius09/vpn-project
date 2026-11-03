package catalog

import (
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"
	"pgregory.net/rapid"

	"github.com/Evgenius09/vpn-project/backend/internal/gen/api"
	"github.com/Evgenius09/vpn-project/backend/internal/panel"
)

const validKey = "qknEZVxadDvGhAxl3gj5FZlPwwOqoCkT8ScJUjkVPqQ"

func vlessHost() panel.PanelHost {
	return panel.PanelHost{
		UUID: uuid.New(), Protocol: "vless_reality", Address: "de1.example.com", Port: 443, Enabled: true,
		Params: json.RawMessage(`{"flow":"xtls-rprx-vision","serverName":"www.example.com","publicKey":"` +
			validKey + `","shortId":"0123456789abcdef","fingerprint":"chrome"}`),
	}
}

func hysteriaHost() panel.PanelHost {
	return panel.PanelHost{
		UUID: uuid.New(), Protocol: "hysteria2", Address: "fi1.example.com", Port: 443, Enabled: true,
		Params: json.RawMessage(`{"serverName":"fi1.example.com","obfsSalamanderPassword":"o",` +
			`"portHopping":{"ports":"20000-30000","intervalSec":30},"upMbps":50,"downMbps":200}`),
	}
}

func entryFor(host panel.PanelHost) Entry {
	return Entry{RemnawaveHostUUID: host.UUID, Group: "regular", DisplayName: "Frankfurt", CountryCode: "DE", SortWeight: 10}
}

func TestBuildPublishesHostsWithAnEntry(t *testing.T) {
	vless, hysteria, stray := vlessHost(), hysteriaHost(), vlessHost()
	entry := entryFor(vless)
	entry.City = ptr("Frankfurt")

	servers, skipped, err := Build([]panel.PanelHost{vless, hysteria, stray}, []Entry{entry, entryFor(hysteria)})

	require.NoError(t, err)
	require.Empty(t, skipped, "a host without an entry is ignored, not reported")
	require.Len(t, servers, 2)
	require.Equal(t, Server{
		HostUUID: vless.UUID, Group: "regular", Protocol: "vless_reality", DisplayName: "Frankfurt",
		CountryCode: "DE", City: ptr("Frankfurt"), Address: "de1.example.com", Port: 443,
		Params: json.RawMessage(`{"flow":"xtls-rprx-vision","serverName":"www.example.com","publicKey":"` +
			validKey + `","shortId":"0123456789abcdef","fingerprint":"chrome"}`),
		SortWeight: 10, Enabled: true,
	}, servers[0])
	require.Equal(t, hysteria.UUID, servers[1].HostUUID)
}

func TestEitherSideCanDisableAServer(t *testing.T) {
	tests := map[string]struct {
		hostEnabled  bool
		entryEnabled *bool
		want         bool
	}{
		"both on":           {hostEnabled: true, want: true},
		"entry omits flag":  {hostEnabled: true, entryEnabled: nil, want: true},
		"entry explicit on": {hostEnabled: true, entryEnabled: ptr(true), want: true},
		"panel disabled":    {hostEnabled: false, want: false},
		"yaml disabled":     {hostEnabled: true, entryEnabled: ptr(false), want: false},
	}
	for name, tt := range tests {
		t.Run(name, func(t *testing.T) {
			host := vlessHost()
			host.Enabled = tt.hostEnabled
			entry := entryFor(host)
			entry.Enabled = tt.entryEnabled

			servers, _, err := Build([]panel.PanelHost{host}, []Entry{entry})

			require.NoError(t, err)
			require.Len(t, servers, 1, "a disabled server stays in the result so its row is switched off")
			require.Equal(t, tt.want, servers[0].Enabled)
		})
	}
}

func TestInvalidHostIsSkipped(t *testing.T) {
	tests := map[string]func(*panel.PanelHost){
		"unknown protocol":   func(h *panel.PanelHost) { h.Protocol = "vmess" },
		"port zero":          func(h *panel.PanelHost) { h.Port = 0 },
		"port too high":      func(h *panel.PanelHost) { h.Port = 65536 },
		"blank address":      func(h *panel.PanelHost) { h.Address = "  " },
		"address with space": func(h *panel.PanelHost) { h.Address = "a b.example.com" },
		"params not json":    func(h *panel.PanelHost) { h.Params = json.RawMessage(`nope`) },
		"secret in params": func(h *panel.PanelHost) {
			h.Params = setParam(t, h.Params, "uuid", "c0000000-0000-4000-8000-000000000001")
		},
		"unknown param":        func(h *panel.PanelHost) { h.Params = setParam(t, h.Params, "spiderX", "/") },
		"unknown flow":         func(h *panel.PanelHost) { h.Params = setParam(t, h.Params, "flow", "xtls-rprx-direct") },
		"unknown fingerprint":  func(h *panel.PanelHost) { h.Params = setParam(t, h.Params, "fingerprint", "opera") },
		"blank server name":    func(h *panel.PanelHost) { h.Params = setParam(t, h.Params, "serverName", " ") },
		"short public key":     func(h *panel.PanelHost) { h.Params = setParam(t, h.Params, "publicKey", validKey[:42]) },
		"padded public key":    func(h *panel.PanelHost) { h.Params = setParam(t, h.Params, "publicKey", validKey+"=") },
		"std base64 key":       func(h *panel.PanelHost) { h.Params = setParam(t, h.Params, "publicKey", "+"+validKey[1:]) },
		"odd short id":         func(h *panel.PanelHost) { h.Params = setParam(t, h.Params, "shortId", "abc") },
		"long short id":        func(h *panel.PanelHost) { h.Params = setParam(t, h.Params, "shortId", "0123456789abcdef01") },
		"non hex short id":     func(h *panel.PanelHost) { h.Params = setParam(t, h.Params, "shortId", "zz") },
		"missing public key":   func(h *panel.PanelHost) { h.Params = deleteParam(t, h.Params, "publicKey") },
		"hysteria2 in a vless": func(h *panel.PanelHost) { h.Protocol = "hysteria2" },
	}
	for name, mutate := range tests {
		t.Run(name, func(t *testing.T) {
			bad, good := vlessHost(), hysteriaHost()
			mutate(&bad)

			servers, skipped, err := Build([]panel.PanelHost{bad, good}, []Entry{entryFor(bad), entryFor(good)})

			require.NoError(t, err)
			require.Len(t, servers, 1, "the other hosts still publish")
			require.Equal(t, good.UUID, servers[0].HostUUID)
			require.Len(t, skipped, 1)
			require.Equal(t, bad.UUID, skipped[0].HostUUID)
			require.Error(t, skipped[0].Err)
		})
	}
}

func TestInvalidHysteriaHostIsSkipped(t *testing.T) {
	tests := map[string]func(*panel.PanelHost){
		"password in params":  func(h *panel.PanelHost) { h.Params = setParam(t, h.Params, "password", "secret") },
		"blank server name":   func(h *panel.PanelHost) { h.Params = setParam(t, h.Params, "serverName", "") },
		"blank obfs password": func(h *panel.PanelHost) { h.Params = setParam(t, h.Params, "obfsSalamanderPassword", "") },
		"zero interval": func(h *panel.PanelHost) {
			h.Params = setParam(t, h.Params, "portHopping", map[string]any{"ports": "443", "intervalSec": 0})
		},
		"reversed range": func(h *panel.PanelHost) {
			h.Params = setParam(t, h.Params, "portHopping", map[string]any{"ports": "30000-20000", "intervalSec": 30})
		},
		"port zero in list": func(h *panel.PanelHost) {
			h.Params = setParam(t, h.Params, "portHopping", map[string]any{"ports": "0,443", "intervalSec": 30})
		},
		"port over range": func(h *panel.PanelHost) {
			h.Params = setParam(t, h.Params, "portHopping", map[string]any{"ports": "443-65536", "intervalSec": 30})
		},
		"empty ports": func(h *panel.PanelHost) {
			h.Params = setParam(t, h.Params, "portHopping", map[string]any{"ports": "", "intervalSec": 30})
		},
		"garbage ports": func(h *panel.PanelHost) {
			h.Params = setParam(t, h.Params, "portHopping", map[string]any{"ports": "a-b", "intervalSec": 30})
		},
		"zero up speed":        func(h *panel.PanelHost) { h.Params = setParam(t, h.Params, "upMbps", 0) },
		"negative down speed":  func(h *panel.PanelHost) { h.Params = setParam(t, h.Params, "downMbps", -1) },
		"vless params instead": func(h *panel.PanelHost) { h.Params = vlessHost().Params },
	}
	for name, mutate := range tests {
		t.Run(name, func(t *testing.T) {
			bad := hysteriaHost()
			mutate(&bad)

			servers, skipped, err := Build([]panel.PanelHost{bad}, []Entry{entryFor(bad)})

			require.NoError(t, err)
			require.Empty(t, servers)
			require.Len(t, skipped, 1)
		})
	}
}

func TestSkipReasonKeepsParamValuesOut(t *testing.T) {
	host := vlessHost()
	host.Params = setParam(t, host.Params, "uuid", "c0000000-0000-4000-8000-000000000099")
	host.Params = setParam(t, host.Params, "publicKey", "leaky-value")

	_, skipped, err := Build([]panel.PanelHost{host}, []Entry{entryFor(host)})

	require.NoError(t, err)
	require.Len(t, skipped, 1)
	require.NotContains(t, skipped[0].Err.Error(), "c0000000-0000-4000-8000-000000000099")
	require.NotContains(t, skipped[0].Err.Error(), "leaky-value")
}

func TestDuplicateHostFailsTheBuild(t *testing.T) {
	host := vlessHost()

	_, _, err := Build([]panel.PanelHost{host, host}, []Entry{entryFor(host)})

	require.ErrorIs(t, err, ErrInvalidPanel)
}

func TestPortListIsNormalized(t *testing.T) {
	host := hysteriaHost()
	host.Params = setParam(t, host.Params, "portHopping", map[string]any{"ports": " 443 , 8443-8450 ", "intervalSec": 10})

	servers, skipped, err := Build([]panel.PanelHost{host}, []Entry{entryFor(host)})

	require.NoError(t, err)
	require.Empty(t, skipped)
	require.Contains(t, string(servers[0].Params), `"ports":"443,8443-8450"`)
}

func setParam(t *testing.T, raw json.RawMessage, key string, value any) json.RawMessage {
	t.Helper()
	var fields map[string]any
	require.NoError(t, json.Unmarshal(raw, &fields))
	fields[key] = value
	encoded, err := json.Marshal(fields)
	require.NoError(t, err)
	return encoded
}

func deleteParam(t *testing.T, raw json.RawMessage, key string) json.RawMessage {
	t.Helper()
	var fields map[string]any
	require.NoError(t, json.Unmarshal(raw, &fields))
	delete(fields, key)
	encoded, err := json.Marshal(fields)
	require.NoError(t, err)
	return encoded
}

func writeCatalog(t *testing.T, content string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "servers.yaml")
	require.NoError(t, os.WriteFile(path, []byte(content), 0o600))
	return path
}

func TestLoadEntriesReadsTheDocumentedFormat(t *testing.T) {
	path := writeCatalog(t, `
# comment
- remnawaveHostUuid: 20000000-0000-4000-8000-000000000001
  group: regular
  displayName: " Frankfurt "
  countryCode: de
  city: Frankfurt
  sortWeight: 10
  enabled: true
- remnawaveHostUuid: 20000000-0000-4000-8000-000000000002
  group: whitelist
  displayName: Moscow
  countryCode: RU
  sortWeight: -5
`)

	entries, err := LoadEntries(path)

	require.NoError(t, err)
	require.Equal(t, []Entry{
		{
			RemnawaveHostUUID: uuid.MustParse("20000000-0000-4000-8000-000000000001"), Group: "regular",
			DisplayName: "Frankfurt", CountryCode: "DE", City: ptr("Frankfurt"), SortWeight: 10, Enabled: ptr(true),
		},
		{
			RemnawaveHostUUID: uuid.MustParse("20000000-0000-4000-8000-000000000002"), Group: "whitelist",
			DisplayName: "Moscow", CountryCode: "RU", SortWeight: -5,
		},
	}, entries)
}

func TestLoadEntriesAcceptsAnEmptyList(t *testing.T) {
	entries, err := LoadEntries(writeCatalog(t, "# no servers yet\n[]\n"))

	require.NoError(t, err)
	require.Empty(t, entries)
}

func TestLoadEntriesRejectsABadFile(t *testing.T) {
	const ok = "- remnawaveHostUuid: 20000000-0000-4000-8000-000000000001\n  group: regular\n  displayName: A\n  countryCode: DE\n"
	tests := map[string]string{
		"comments only":     "# nothing\n",
		"not a list":        "remnawaveHostUuid: 20000000-0000-4000-8000-000000000001\n",
		"not yaml":          "- [unclosed\n",
		"unknown field":     ok + "  weight: 1\n",
		"unknown group":     strings.Replace(ok, "regular", "vip", 1),
		"blank name":        strings.Replace(ok, "displayName: A", "displayName: ' '", 1),
		"long country":      strings.Replace(ok, "DE", "DEU", 1),
		"digit country":     strings.Replace(ok, "DE", "D1", 1),
		"missing country":   strings.Replace(ok, "  countryCode: DE\n", "", 1),
		"nil uuid":          strings.Replace(ok, "20000000-0000-4000-8000-000000000001", "00000000-0000-0000-0000-000000000000", 1),
		"bad uuid":          strings.Replace(ok, "20000000-0000-4000-8000-000000000001", "nope", 1),
		"duplicate uuid":    ok + ok,
		"weight over int32": ok + "  sortWeight: 2147483648\n",
	}
	for name, content := range tests {
		t.Run(name, func(t *testing.T) {
			_, err := LoadEntries(writeCatalog(t, content))

			require.ErrorIs(t, err, ErrInvalidCatalog)
		})
	}
}

func TestLoadEntriesFailsOnAMissingFile(t *testing.T) {
	_, err := LoadEntries(filepath.Join(t.TempDir(), "absent.yaml"))

	require.Error(t, err, "a missing catalog must not read as an empty one, which would disable every server")
}

func (s Server) panelHost() panel.PanelHost {
	return panel.PanelHost{UUID: s.HostUUID, Protocol: s.Protocol, Address: s.Address, Port: s.Port, Params: s.Params, Enabled: s.Enabled}
}

func (s Server) entry() Entry {
	return Entry{
		RemnawaveHostUUID: s.HostUUID, Group: s.Group, DisplayName: s.DisplayName,
		CountryCode: s.CountryCode, City: s.City, SortWeight: s.SortWeight,
	}
}

// Generators of valid input.

func hostGen() *rapid.Generator[panel.PanelHost] {
	return rapid.Custom(func(t *rapid.T) panel.PanelHost {
		host := panel.PanelHost{
			UUID:    uuid.UUID(rapid.SliceOfN(rapid.Byte(), 16, 16).Draw(t, "uuid")),
			Address: rapid.StringMatching(`[a-z0-9]{1,10}\.example\.(com|org)`).Draw(t, "address"),
			Port:    rapid.IntRange(1, 65535).Draw(t, "port"),
			Enabled: rapid.Bool().Draw(t, "enabled"),
		}
		if rapid.Bool().Draw(t, "vless") {
			host.Protocol = "vless_reality"
			host.Params = mustJSON(map[string]any{
				"flow":        rapid.SampledFrom([]string{"xtls-rprx-vision", ""}).Draw(t, "flow"),
				"serverName":  rapid.StringMatching(`[a-z]{1,8}\.example\.com`).Draw(t, "sni"),
				"publicKey":   base64.RawURLEncoding.EncodeToString(rapid.SliceOfN(rapid.Byte(), 32, 32).Draw(t, "key")),
				"shortId":     hex.EncodeToString(rapid.SliceOfN(rapid.Byte(), 0, 8).Draw(t, "shortId")),
				"fingerprint": rapid.SampledFrom([]string{"chrome", "firefox", "safari", "ios", "android", "edge", "random"}).Draw(t, "fp"),
			})
			return host
		}
		host.Protocol = "hysteria2"
		params := map[string]any{"serverName": rapid.StringMatching(`[a-z]{1,8}\.example\.com`).Draw(t, "sni")}
		if rapid.Bool().Draw(t, "obfs") {
			params["obfsSalamanderPassword"] = rapid.StringMatching(`[a-z0-9]{1,12}`).Draw(t, "obfsPassword")
		}
		if rapid.Bool().Draw(t, "hopping") {
			start := rapid.IntRange(1, 65535).Draw(t, "start")
			end := rapid.IntRange(start, 65535).Draw(t, "end")
			params["portHopping"] = map[string]any{
				"ports":       fmt.Sprintf("%d-%d", start, end),
				"intervalSec": rapid.IntRange(1, 3600).Draw(t, "interval"),
			}
		}
		if rapid.Bool().Draw(t, "speeds") {
			params["upMbps"] = rapid.IntRange(1, 10000).Draw(t, "up")
			params["downMbps"] = rapid.IntRange(1, 10000).Draw(t, "down")
		}
		host.Params = mustJSON(params)
		return host
	})
}

func entryGen(host panel.PanelHost) *rapid.Generator[Entry] {
	return rapid.Custom(func(t *rapid.T) Entry {
		entry := Entry{
			RemnawaveHostUUID: host.UUID,
			Group:             rapid.SampledFrom([]string{"regular", "whitelist"}).Draw(t, "group"),
			DisplayName:       rapid.StringMatching(`[A-Za-z][A-Za-z ]{0,15}[A-Za-z]`).Draw(t, "name"),
			CountryCode:       rapid.StringMatching(`[A-Z]{2}`).Draw(t, "country"),
			SortWeight:        rapid.IntRange(-1000, 1000).Draw(t, "weight"),
		}
		if rapid.Bool().Draw(t, "hasCity") {
			entry.City = ptr(rapid.StringMatching(`[A-Z][a-z]{1,10}`).Draw(t, "city"))
		}
		if rapid.Bool().Draw(t, "hasEnabled") {
			entry.Enabled = ptr(rapid.Bool().Draw(t, "entryEnabled"))
		}
		return entry
	})
}

func mustJSON(value any) json.RawMessage {
	encoded, err := json.Marshal(value)
	if err != nil {
		panic(err)
	}
	return encoded
}

func publishOne(t *rapid.T, host panel.PanelHost, entry Entry) Server {
	servers, skipped, err := Build([]panel.PanelHost{host}, []Entry{entry})
	if err != nil || len(skipped) > 0 || len(servers) != 1 {
		t.Fatalf("valid input did not publish: err=%v skipped=%v", err, skipped)
	}
	return servers[0]
}

// noisy writes the same content the way a sloppy operator or panel might:
// padded strings, a lower-case country, and reordered, indented params.
func noisy(t *rapid.T, host panel.PanelHost, entry Entry) (panel.PanelHost, Entry) {
	pad := func(s, label string) string {
		return rapid.StringMatching(`[ \t]{0,2}`).Draw(t, label+"L") + s + rapid.StringMatching(`[ \t]{0,2}`).Draw(t, label+"R")
	}
	host.Address = pad(host.Address, "address")
	var fields map[string]any
	if err := json.Unmarshal(host.Params, &fields); err != nil {
		t.Fatal(err)
	}
	indented, err := json.MarshalIndent(fields, "", "    ")
	if err != nil {
		t.Fatal(err)
	}
	host.Params = indented

	entry.DisplayName = pad(entry.DisplayName, "name")
	entry.CountryCode = pad(strings.ToLower(entry.CountryCode), "country")
	if entry.City != nil {
		entry.City = ptr(pad(*entry.City, "city"))
	}
	return host, entry
}

func TestNormalizationIsIdempotent(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		host := hostGen().Draw(t, "host")
		entry := entryGen(host).Draw(t, "entry")
		host, entry = noisy(t, host, entry)

		first := publishOne(t, host, entry)
		again := publishOne(t, first.panelHost(), first.entry())

		if !reflect.DeepEqual(first, again) || first.ContentHash() != again.ContentHash() {
			t.Fatalf("normalizing twice changed the server:\n%+v\n%+v", first, again)
		}
	})
}

func TestHashIgnoresCosmeticDifferences(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		host := hostGen().Draw(t, "host")
		entry := entryGen(host).Draw(t, "entry")
		noisyHost, noisyEntry := noisy(t, host, entry)

		clean := publishOne(t, host, entry)
		messy := publishOne(t, noisyHost, noisyEntry)

		if clean.ContentHash() != messy.ContentHash() {
			t.Fatalf("hash moved on formatting only:\n%+v\n%+v", clean, messy)
		}
	})
}

func TestHashIsStableForEqualInput(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		host := hostGen().Draw(t, "host")
		entry := entryGen(host).Draw(t, "entry")

		first := publishOne(t, host, entry).ContentHash()
		second := publishOne(t, host, entry).ContentHash()

		if first != second {
			t.Fatal("same input, different hash")
		}
	})
}

// changes alter one published field to another valid value.
var changes = map[string]func(t *rapid.T, host *panel.PanelHost, entry *Entry){
	"group": func(_ *rapid.T, _ *panel.PanelHost, e *Entry) {
		e.Group = map[string]string{"regular": "whitelist", "whitelist": "regular"}[e.Group]
	},
	"display name": func(_ *rapid.T, _ *panel.PanelHost, e *Entry) { e.DisplayName += "x" },
	"country":      func(_ *rapid.T, _ *panel.PanelHost, e *Entry) { e.CountryCode = nextCountry(e.CountryCode) },
	"city": func(_ *rapid.T, _ *panel.PanelHost, e *Entry) {
		if e.City == nil {
			e.City = ptr("Riga")
		} else {
			e.City = nil
		}
	},
	"sort weight": func(_ *rapid.T, _ *panel.PanelHost, e *Entry) { e.SortWeight++ },
	"address":     func(_ *rapid.T, h *panel.PanelHost, _ *Entry) { h.Address = "z" + h.Address },
	"port":        func(_ *rapid.T, h *panel.PanelHost, _ *Entry) { h.Port = h.Port%65535 + 1 },
	"server name": func(t *rapid.T, h *panel.PanelHost, _ *Entry) {
		h.Params = editParams(t, h.Params, "serverName", "other.example.net")
	},
	"protocol param": func(t *rapid.T, h *panel.PanelHost, _ *Entry) {
		if h.Protocol == "vless_reality" {
			h.Params = editParams(t, h.Params, "publicKey", "IYKOOGaolVj0BmiXXPYno3FByRto7aqcdp-Lb6q7wWs")
			return
		}
		h.Params = editParams(t, h.Params, "obfsSalamanderPassword", "changed-obfs")
	},
}

func nextCountry(code string) string {
	if code == "ZZ" {
		return "AA"
	}
	if code[1] == 'Z' {
		return string(code[0]+1) + "A"
	}
	return string(code[0]) + string(code[1]+1)
}

func editParams(t *rapid.T, raw json.RawMessage, key string, value string) json.RawMessage {
	var fields map[string]any
	if err := json.Unmarshal(raw, &fields); err != nil {
		t.Fatal(err)
	}
	if fields[key] == value {
		value += "2"
	}
	fields[key] = value
	return mustJSON(fields)
}

func TestHashChangesWithAnyPublishedField(t *testing.T) {
	names := make([]string, 0, len(changes))
	for name := range changes {
		names = append(names, name)
	}
	rapid.Check(t, func(t *rapid.T) {
		host := hostGen().Draw(t, "host")
		entry := entryGen(host).Draw(t, "entry")
		name := rapid.SampledFrom(names).Draw(t, "change")
		changedHost, changedEntry := host, entry
		changes[name](t, &changedHost, &changedEntry)

		before := publishOne(t, host, entry).ContentHash()
		after := publishOne(t, changedHost, changedEntry).ContentHash()

		if before == after {
			t.Fatalf("hash ignored a change of %s", name)
		}
	})
}

func TestHashLeavesEnabledOut(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		host := hostGen().Draw(t, "host")
		entry := entryGen(host).Draw(t, "entry")
		flipped := host
		flipped.Enabled = !host.Enabled

		if publishOne(t, host, entry).ContentHash() != publishOne(t, flipped, entry).ContentHash() {
			t.Fatal("enabled is tracked by its own column, not by the hash")
		}
	})
}

func TestEntryPortHoppingReachesHysteriaParams(t *testing.T) {
	host := hysteriaHost()
	host.Params = deleteParam(t, host.Params, "portHopping")
	entry := entryFor(host)
	entry.PortHopping = &api.PortHopping{Ports: " 20000 - 50000 ", IntervalSec: 30}

	servers, skipped, err := Build([]panel.PanelHost{host}, []Entry{entry})

	require.NoError(t, err)
	require.Empty(t, skipped)
	require.Contains(t, string(servers[0].Params), `"portHopping":{"intervalSec":30,"ports":"20000-50000"}`)

	without, _, err := Build([]panel.PanelHost{host}, []Entry{entryFor(host)})
	require.NoError(t, err)
	require.NotEqual(t, without[0].ContentHash(), servers[0].ContentHash(), "hopping is part of the hash")
}

func TestEntryPortHoppingFollowsTheHostRules(t *testing.T) {
	for name, hopping := range map[string]api.PortHopping{
		"zero interval":  {Ports: "20000-50000", IntervalSec: 0},
		"reversed range": {Ports: "50000-20000", IntervalSec: 30},
		"port zero":      {Ports: "0,443", IntervalSec: 30},
	} {
		t.Run(name, func(t *testing.T) {
			host := hysteriaHost()
			entry := entryFor(host)
			entry.PortHopping = &hopping

			servers, skipped, err := Build([]panel.PanelHost{host}, []Entry{entry})

			require.NoError(t, err)
			require.Empty(t, servers)
			require.Len(t, skipped, 1)
			require.ErrorIs(t, skipped[0].Err, ErrInvalidHost)
		})
	}
}

func TestEntryPortHoppingOnVlessHostIsInvalid(t *testing.T) {
	host := vlessHost()
	entry := entryFor(host)
	entry.PortHopping = &api.PortHopping{Ports: "20000-50000", IntervalSec: 30}

	_, skipped, err := Build([]panel.PanelHost{host}, []Entry{entry})

	require.NoError(t, err)
	require.Len(t, skipped, 1)
	require.ErrorIs(t, skipped[0].Err, ErrInvalidHost)
}

func TestLoadEntriesReadsPortHopping(t *testing.T) {
	path := writeCatalog(t, `
- remnawaveHostUuid: 20000000-0000-4000-8000-000000000001
  group: regular
  displayName: Stockholm
  countryCode: SE
  sortWeight: 10
  portHopping: {ports: "20000-50000", intervalSec: 30}
`)

	entries, err := LoadEntries(path)

	require.NoError(t, err)
	require.Equal(t, &api.PortHopping{Ports: "20000-50000", IntervalSec: 30}, entries[0].PortHopping)
}
