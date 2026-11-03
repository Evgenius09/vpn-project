package catalog

import (
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"reflect"
	"slices"
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"
	"pgregory.net/rapid"

	"github.com/Evgenius09/vpn-project/backend/internal/panel"
)

const validKey = "qknEZVxadDvGhAxl3gj5FZlPwwOqoCkT8ScJUjkVPqQ"

func vlessHost() panel.PanelHost {
	return panel.PanelHost{
		UUID: uuid.New(), Protocol: "vless_reality", Address: "de1.example.com", Port: 443, Enabled: true,
		Params: json.RawMessage(`{"flow":"xtls-rprx-vision","serverName":"www.example.com","publicKey":"` +
			validKey + `","shortId":"0123456789abcdef","fingerprint":"chrome"}`),
		Remark: "Frankfurt", Tags: []string{"COUNTRY:DE"}, ViewPosition: 10,
	}
}

func hysteriaHost() panel.PanelHost {
	return panel.PanelHost{
		UUID: uuid.New(), Protocol: "hysteria2", Address: "fi1.example.com", Port: 443, Enabled: true,
		Params: json.RawMessage(`{"serverName":"fi1.example.com","obfsSalamanderPassword":"o",` +
			`"portHopping":{"ports":"20000-30000","intervalSec":30},"upMbps":50,"downMbps":200}`),
		Remark: "Helsinki", Tags: []string{"COUNTRY:FI"}, ViewPosition: 20,
	}
}

func TestBuildPublishesHostsWithACountryTag(t *testing.T) {
	vless, hysteria, untagged := vlessHost(), hysteriaHost(), vlessHost()
	vless.Description = "Frankfurt am Main"
	untagged.Tags = []string{"PROBE"}

	servers, skipped, err := Build([]panel.PanelHost{vless, hysteria, untagged})

	require.NoError(t, err)
	require.Empty(t, skipped, "a host without a country tag is not for the app, not an error")
	require.Len(t, servers, 2)
	require.Equal(t, Server{
		HostUUID: vless.UUID, Group: "regular", Protocol: "vless_reality", DisplayName: "Frankfurt",
		CountryCode: "DE", City: ptr("Frankfurt am Main"), Address: "de1.example.com", Port: 443,
		Params: json.RawMessage(`{"flow":"xtls-rprx-vision","serverName":"www.example.com","publicKey":"` +
			validKey + `","shortId":"0123456789abcdef","fingerprint":"chrome"}`),
		SortWeight: 10, Enabled: true,
	}, servers[0])
	require.Equal(t, hysteria.UUID, servers[1].HostUUID)
	require.Nil(t, servers[1].City, "a blank description is no city")
}

func TestWhitelistTagPicksTheGroup(t *testing.T) {
	host := vlessHost()
	host.Tags = []string{"WHITELIST", "COUNTRY:RU", "SOMETHING_ELSE"}

	servers, skipped, err := Build([]panel.PanelHost{host})

	require.NoError(t, err)
	require.Empty(t, skipped, "unknown tags belong to other panel users")
	require.Equal(t, "whitelist", servers[0].Group)
	require.Equal(t, "RU", servers[0].CountryCode)
}

func TestPanelSwitchesAServerOff(t *testing.T) {
	host := vlessHost()
	host.Enabled = false

	servers, _, err := Build([]panel.PanelHost{host})

	require.NoError(t, err)
	require.Len(t, servers, 1, "a disabled server stays in the result so its row is switched off")
	require.False(t, servers[0].Enabled)
}

func TestBadMetadataSkipsTheHost(t *testing.T) {
	tests := map[string]func(*panel.PanelHost){
		"two countries":    func(h *panel.PanelHost) { h.Tags = []string{"COUNTRY:DE", "COUNTRY:NL"} },
		"long country":     func(h *panel.PanelHost) { h.Tags = []string{"COUNTRY:DEU"} },
		"digit country":    func(h *panel.PanelHost) { h.Tags = []string{"COUNTRY:D1"} },
		"empty country":    func(h *panel.PanelHost) { h.Tags = []string{"COUNTRY:"} },
		"blank remark":     func(h *panel.PanelHost) { h.Remark = "  " },
		"position too big": func(h *panel.PanelHost) { h.ViewPosition = 1 << 31 },
		"hop on vless":     func(h *panel.PanelHost) { h.Tags = append(h.Tags, "HOP:20000_50000:30") },
	}
	for name, mutate := range tests {
		t.Run(name, func(t *testing.T) {
			bad, good := vlessHost(), hysteriaHost()
			mutate(&bad)

			servers, skipped, err := Build([]panel.PanelHost{bad, good})

			require.NoError(t, err)
			require.Len(t, servers, 1, "the other hosts still publish")
			require.Len(t, skipped, 1)
			require.Equal(t, bad.UUID, skipped[0].HostUUID)
			require.ErrorIs(t, skipped[0].Err, ErrInvalidHost)
		})
	}
}

func TestHopTagReachesHysteriaParams(t *testing.T) {
	host := hysteriaHost()
	host.Params = deleteParam(t, host.Params, "portHopping")
	tagged := host
	tagged.Tags = append([]string{"HOP:20000_50000:30"}, host.Tags...)

	servers, skipped, err := Build([]panel.PanelHost{tagged})

	require.NoError(t, err)
	require.Empty(t, skipped)
	require.Contains(t, string(servers[0].Params), `"portHopping":{"intervalSec":30,"ports":"20000-50000"}`)

	without, _, err := Build([]panel.PanelHost{host})
	require.NoError(t, err)
	require.NotEqual(t, without[0].ContentHash(), servers[0].ContentHash(), "hopping is part of the hash")
}

func TestHopTagFollowsTheHostRules(t *testing.T) {
	for _, tag := range []string{
		"HOP:20000_50000:0", "HOP:50000_20000:30", "HOP:0:30", "HOP:20000_50000",
		"HOP:20000_50000:X", "HOP::30", "HOP:443:30:1",
	} {
		t.Run(tag, func(t *testing.T) {
			host := hysteriaHost()
			host.Tags = append(host.Tags, tag)

			servers, skipped, err := Build([]panel.PanelHost{host})

			require.NoError(t, err)
			require.Empty(t, servers)
			require.Len(t, skipped, 1)
			require.ErrorIs(t, skipped[0].Err, ErrInvalidHost)
		})
	}
}

func TestTwoHopTagsSkipTheHost(t *testing.T) {
	host := hysteriaHost()
	host.Tags = append(host.Tags, "HOP:443:30", "HOP:8443:30")

	_, skipped, err := Build([]panel.PanelHost{host})

	require.NoError(t, err)
	require.Len(t, skipped, 1)
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

			servers, skipped, err := Build([]panel.PanelHost{bad, good})

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

			servers, skipped, err := Build([]panel.PanelHost{bad})

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

	_, skipped, err := Build([]panel.PanelHost{host})

	require.NoError(t, err)
	require.Len(t, skipped, 1)
	require.NotContains(t, skipped[0].Err.Error(), "c0000000-0000-4000-8000-000000000099")
	require.NotContains(t, skipped[0].Err.Error(), "leaky-value")
}

func TestDuplicateHostFailsTheBuild(t *testing.T) {
	host := vlessHost()

	_, _, err := Build([]panel.PanelHost{host, host})

	require.ErrorIs(t, err, ErrInvalidPanel)
}

func TestPortListIsNormalized(t *testing.T) {
	host := hysteriaHost()
	host.Params = setParam(t, host.Params, "portHopping", map[string]any{"ports": " 443 , 8443-8450 ", "intervalSec": 10})

	servers, skipped, err := Build([]panel.PanelHost{host})

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

// tagged gives a host valid catalog metadata.
func tagged(t *rapid.T, host panel.PanelHost) panel.PanelHost {
	host.Remark = rapid.StringMatching(`[A-Za-z][A-Za-z ]{0,15}[A-Za-z]`).Draw(t, "remark")
	host.Tags = []string{"COUNTRY:" + rapid.StringMatching(`[A-Z]{2}`).Draw(t, "country")}
	if rapid.Bool().Draw(t, "whitelist") {
		host.Tags = append(host.Tags, "WHITELIST")
	}
	host.ViewPosition = rapid.IntRange(-1000, 1000).Draw(t, "position")
	if rapid.Bool().Draw(t, "hasCity") {
		host.Description = rapid.StringMatching(`[A-Z][a-z]{1,10}`).Draw(t, "city")
	}
	return host
}

func mustJSON(value any) json.RawMessage {
	encoded, err := json.Marshal(value)
	if err != nil {
		panic(err)
	}
	return encoded
}

func publishOne(t *rapid.T, host panel.PanelHost) Server {
	servers, skipped, err := Build([]panel.PanelHost{host})
	if err != nil || len(skipped) > 0 || len(servers) != 1 {
		t.Fatalf("valid input did not publish: err=%v skipped=%v", err, skipped)
	}
	return servers[0]
}

// noisy writes the same content the way a sloppy operator or panel might:
// padded strings and reordered, indented params.
func noisy(t *rapid.T, host panel.PanelHost) panel.PanelHost {
	pad := func(s, label string) string {
		return rapid.StringMatching(`[ \t]{0,2}`).Draw(t, label+"L") + s + rapid.StringMatching(`[ \t]{0,2}`).Draw(t, label+"R")
	}
	host.Address = pad(host.Address, "address")
	host.Remark = pad(host.Remark, "remark")
	host.Description = pad(host.Description, "city")
	var fields map[string]any
	if err := json.Unmarshal(host.Params, &fields); err != nil {
		t.Fatal(err)
	}
	indented, err := json.MarshalIndent(fields, "", "    ")
	if err != nil {
		t.Fatal(err)
	}
	host.Params = indented
	return host
}

// panelHost is the host a published server reads back from.
func (s Server) panelHost(tags []string) panel.PanelHost {
	host := panel.PanelHost{
		UUID: s.HostUUID, Protocol: s.Protocol, Address: s.Address, Port: s.Port, Params: s.Params,
		Enabled: s.Enabled, Remark: s.DisplayName, Tags: tags, ViewPosition: s.SortWeight,
	}
	if s.City != nil {
		host.Description = *s.City
	}
	return host
}

func TestNormalizationIsIdempotent(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		host := noisy(t, tagged(t, hostGen().Draw(t, "host")))

		first := publishOne(t, host)
		again := publishOne(t, first.panelHost(host.Tags))

		if !reflect.DeepEqual(first, again) || first.ContentHash() != again.ContentHash() {
			t.Fatalf("normalizing twice changed the server:\n%+v\n%+v", first, again)
		}
	})
}

func TestHashIgnoresCosmeticDifferences(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		host := tagged(t, hostGen().Draw(t, "host"))

		clean := publishOne(t, host)
		messy := publishOne(t, noisy(t, host))

		if clean.ContentHash() != messy.ContentHash() {
			t.Fatalf("hash moved on formatting only:\n%+v\n%+v", clean, messy)
		}
	})
}

func TestHashIsStableForEqualInput(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		host := tagged(t, hostGen().Draw(t, "host"))

		first, second := publishOne(t, host), publishOne(t, host)

		if first.ContentHash() != second.ContentHash() {
			t.Fatal("same input, different hash")
		}
	})
}

// changes alter one published field to another valid value.
var changes = map[string]func(t *rapid.T, host *panel.PanelHost){
	"group": func(_ *rapid.T, h *panel.PanelHost) {
		if slices.Contains(h.Tags, "WHITELIST") {
			h.Tags = slices.DeleteFunc(slices.Clone(h.Tags), func(tag string) bool { return tag == "WHITELIST" })
			return
		}
		h.Tags = append(slices.Clone(h.Tags), "WHITELIST")
	},
	"display name": func(_ *rapid.T, h *panel.PanelHost) { h.Remark += "x" },
	"country": func(_ *rapid.T, h *panel.PanelHost) {
		h.Tags = slices.Clone(h.Tags)
		h.Tags[0] = "COUNTRY:" + nextCountry(strings.TrimPrefix(h.Tags[0], "COUNTRY:"))
	},
	"city": func(_ *rapid.T, h *panel.PanelHost) {
		if h.Description == "" {
			h.Description = "Riga"
		} else {
			h.Description = ""
		}
	},
	"sort weight": func(_ *rapid.T, h *panel.PanelHost) { h.ViewPosition++ },
	"address":     func(_ *rapid.T, h *panel.PanelHost) { h.Address = "z" + h.Address },
	"port":        func(_ *rapid.T, h *panel.PanelHost) { h.Port = h.Port%65535 + 1 },
	"server name": func(t *rapid.T, h *panel.PanelHost) {
		h.Params = editParams(t, h.Params, "serverName", "other.example.net")
	},
	"protocol param": func(t *rapid.T, h *panel.PanelHost) {
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
	slices.Sort(names)
	rapid.Check(t, func(t *rapid.T) {
		host := tagged(t, hostGen().Draw(t, "host"))
		name := rapid.SampledFrom(names).Draw(t, "change")
		changed := host
		changes[name](t, &changed)

		if publishOne(t, host).ContentHash() == publishOne(t, changed).ContentHash() {
			t.Fatalf("hash ignored a change of %s", name)
		}
	})
}

func TestHashLeavesEnabledOut(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		host := tagged(t, hostGen().Draw(t, "host"))
		flipped := host
		flipped.Enabled = !host.Enabled

		if publishOne(t, host).ContentHash() != publishOne(t, flipped).ContentHash() {
			t.Fatal("enabled is tracked by its own column, not by the hash")
		}
	})
}
