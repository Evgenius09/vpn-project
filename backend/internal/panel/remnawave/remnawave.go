// Package remnawave implements panel.PanelClient over the Remnawave 3.4.8 API
// (tech.md 5.10, 39). Field sources are recorded in
// docs/adr/0001-remnawave-panel-fields.md.
package remnawave

import (
	"context"
	"crypto/ecdh"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/google/uuid"

	"github.com/Evgenius09/vpn-project/backend/internal/gen/remnawave"
	"github.com/Evgenius09/vpn-project/backend/internal/panel"
)

// errorCodeUsernameTaken is the panel's answer to a taken username.
const errorCodeUsernameTaken = "A019"

// requestTimeout bounds one call; jobs add their own 30 s deadline (tech.md 7).
const requestTimeout = 15 * time.Second

// Client implements panel.PanelClient.
type Client struct {
	api   *remnawave.Client
	squad uuid.UUID
}

var _ panel.PanelClient = (*Client)(nil)

// New returns a client for the panel at baseURL. New users join squad.
func New(baseURL, token string, squad uuid.UUID) (*Client, error) {
	api, err := remnawave.NewClient(baseURL,
		remnawave.WithHTTPClient(&http.Client{Timeout: requestTimeout}),
		remnawave.WithRequestEditorFn(func(_ context.Context, req *http.Request) error {
			req.Header.Set("Authorization", "Bearer "+token)
			// The panel behind the tunnel sees plain HTTP and refuses the token
			// without these (tech.md 39.1).
			req.Header.Set("X-Forwarded-For", "127.0.0.1")
			req.Header.Set("X-Forwarded-Proto", "https")
			return nil
		}))
	if err != nil {
		return nil, fmt.Errorf("remnawave client: %w", err)
	}
	return &Client{api: api, squad: squad}, nil
}

// GetUserByUsername implements panel.PanelClient.
func (c *Client) GetUserByUsername(ctx context.Context, username string) (panel.PanelUser, error) {
	var out remnawave.UserResponseDto
	resp, err := c.api.UsersControllerGetUserByUsername(ctx, username)
	if err := decode("get user", resp, err, http.StatusOK, &out); err != nil {
		return panel.PanelUser{}, err
	}
	return toUser(out), nil
}

// CreateUser implements panel.PanelClient.
func (c *Client) CreateUser(ctx context.Context, in panel.CreateUserInput) (panel.PanelUser, error) {
	status := remnawave.CreateUserBodyDtoStatusACTIVE
	strategy := remnawave.CreateUserBodyDtoTrafficLimitStrategyNORESET
	limit := float64(in.TrafficLimit)
	squads := []uuid.UUID{c.squad}
	var out remnawave.UserResponseDto
	resp, err := c.api.UsersControllerCreateUser(ctx, remnawave.CreateUserBodyDto{
		Username:             in.Username,
		ExpireAt:             in.ExpiresAt.UTC().Format(time.RFC3339),
		TrafficLimitBytes:    &limit,
		TrafficLimitStrategy: &strategy,
		Status:               &status,
		// A user outside every internal squad gets no inbound (tech.md 39.2).
		ActiveInternalSquads: &squads,
	})
	if err := decode("create user", resp, err, http.StatusCreated, &out); err != nil {
		return panel.PanelUser{}, err
	}
	return toUser(out), nil
}

// UpdateUser implements panel.PanelClient.
func (c *Client) UpdateUser(ctx context.Context, id int64, in panel.UpdateUserInput) (panel.PanelUser, error) {
	panelID := float64(id)
	expires := in.ExpiresAt.UTC().Format(time.RFC3339)
	limit := float64(in.TrafficLimit)
	var out remnawave.UserResponseDto
	resp, err := c.api.UsersControllerUpdateUser(ctx, remnawave.UpdateUserBodyDto{
		Id: &panelID, ExpireAt: &expires, TrafficLimitBytes: &limit,
	})
	if err := decode("update user", resp, err, http.StatusOK, &out); err != nil {
		return panel.PanelUser{}, err
	}
	return toUser(out), nil
}

func toUser(dto remnawave.UserResponseDto) panel.PanelUser {
	user := dto.Response
	return panel.PanelUser{
		ID:           int64(user.Id),
		ShortUUID:    user.ShortUuid,
		Username:     user.Username,
		ExpiresAt:    user.ExpireAt,
		TrafficLimit: int64(user.TrafficLimitBytes),
		TrafficUsed:  int64(user.UserTraffic.UsedTrafficBytes),
		VlessUUID:    user.VlessUuid.String(),
		// Remnawave gives the Hysteria2 user the vlessUuid (tech.md 38.3).
		Hysteria2Auth: user.VlessUuid.String(),
	}
}

// ListHosts implements panel.PanelClient. Hosts on an inbound we do not serve
// are left out, so catalog_sync switches their rows off (tech.md 39.3).
func (c *Client) ListHosts(ctx context.Context) ([]panel.PanelHost, error) {
	var hosts remnawave.GetHostsResponseDto
	resp, err := c.api.HostsControllerGetHosts(ctx)
	if err := decode("list hosts", resp, err, http.StatusOK, &hosts); err != nil {
		return nil, err
	}
	var inbounds remnawave.GetAllInboundsResponseDto
	resp, err = c.api.ConfigProfileControllerGetAllInbounds(ctx)
	if err := decode("list inbounds", resp, err, http.StatusOK, &inbounds); err != nil {
		return nil, err
	}
	byUUID := make(map[uuid.UUID]rawInbound, len(inbounds.Response.Inbounds))
	for _, inbound := range inbounds.Response.Inbounds {
		raw, err := json.Marshal(inbound.RawInbound)
		if err != nil {
			return nil, fmt.Errorf("remnawave: inbound %s: %w", inbound.Uuid, err)
		}
		var parsed rawInbound
		if err := json.Unmarshal(raw, &parsed); err != nil {
			// The type name only: the raw inbound holds the Reality private key.
			return nil, fmt.Errorf("remnawave: inbound %s: %T", inbound.Uuid, err)
		}
		byUUID[inbound.Uuid] = parsed
	}

	var out []panel.PanelHost
	for _, host := range hosts.Response {
		if host.Inbound.ConfigProfileInboundUuid == nil {
			continue
		}
		inbound, ok := byUUID[*host.Inbound.ConfigProfileInboundUuid]
		if !ok {
			continue
		}
		protocol, params, err := hostParams(inbound, deref(host.Sni), deref(host.Fingerprint), host.Address)
		if err != nil {
			return nil, fmt.Errorf("remnawave: host %s: %w", host.Uuid, err)
		}
		if protocol == "" {
			continue
		}
		out = append(out, panel.PanelHost{
			UUID:     host.Uuid,
			Protocol: protocol,
			Address:  host.Address,
			Port:     host.Port,
			Params:   params,
			Enabled:  !host.IsDisabled && !deref(host.IsHidden),
		})
	}
	return out, nil
}

// rawInbound is the part of an Xray inbound the profile needs.
type rawInbound struct {
	Protocol string `json:"protocol"`
	Settings struct {
		Version int `json:"version"`
	} `json:"settings"`
	StreamSettings struct {
		Network         string `json:"network"`
		Security        string `json:"security"`
		RealitySettings struct {
			PrivateKey  string   `json:"privateKey"`
			ShortIDs    []string `json:"shortIds"`
			ServerNames []string `json:"serverNames"`
		} `json:"realitySettings"`
		FinalMask struct {
			UDP []struct {
				Type     string `json:"type"`
				Settings struct {
					Password string `json:"password"`
				} `json:"settings"`
			} `json:"udp"`
		} `json:"finalmask"`
	} `json:"streamSettings"`
}

// hostParams returns the protocol and the non-secret params in the shape of
// openapi.yaml (tech.md 29.1), or an empty protocol for an inbound we skip.
func hostParams(inbound rawInbound, sni, fingerprint, address string) (string, json.RawMessage, error) {
	stream := inbound.StreamSettings
	switch {
	case inbound.Protocol == "vless" && stream.Network == "tcp" && stream.Security == "reality":
		reality := stream.RealitySettings
		publicKey, err := realityPublicKey(reality.PrivateKey)
		if err != nil {
			return "", nil, err
		}
		if sni == "" && len(reality.ServerNames) > 0 {
			sni = reality.ServerNames[0]
		}
		if fingerprint == "" {
			fingerprint = "chrome"
		}
		shortID := ""
		if len(reality.ShortIDs) > 0 {
			shortID = reality.ShortIDs[0]
		}
		params, err := json.Marshal(map[string]string{
			"flow": "xtls-rprx-vision", "serverName": sni, "publicKey": publicKey,
			"shortId": shortID, "fingerprint": fingerprint,
		})
		return "vless_reality", params, err
	case inbound.Protocol == "hysteria" && inbound.Settings.Version == 2:
		if sni == "" {
			sni = address
		}
		fields := map[string]string{"serverName": sni}
		for _, mask := range stream.FinalMask.UDP {
			if mask.Type == "salamander" {
				fields["obfsSalamanderPassword"] = mask.Settings.Password
			}
		}
		params, err := json.Marshal(fields)
		return "hysteria2", params, err
	}
	return "", nil, nil
}

// realityPublicKey derives the client key: the panel stores only the private
// one. Errors never quote the key.
func realityPublicKey(privateKey string) (string, error) {
	raw, err := base64.RawURLEncoding.DecodeString(privateKey)
	if err != nil {
		return "", errors.New("reality private key is not base64url")
	}
	key, err := ecdh.X25519().NewPrivateKey(raw)
	if err != nil {
		return "", errors.New("reality private key is not an X25519 key")
	}
	return base64.RawURLEncoding.EncodeToString(key.PublicKey().Bytes()), nil
}

// decode maps the HTTP outcome to the panel errors and fills out on success.
func decode(op string, resp *http.Response, err error, want int, out any) error {
	if err != nil {
		return fmt.Errorf("%w: %s: %w", panel.ErrUnavailable, op, err)
	}
	defer func() { _ = resp.Body.Close() }()
	body, err := io.ReadAll(io.LimitReader(resp.Body, 16<<20))
	if err != nil {
		return fmt.Errorf("%w: %s: read body: %w", panel.ErrUnavailable, op, err)
	}
	switch {
	case resp.StatusCode == want:
		if err := json.Unmarshal(body, out); err != nil {
			return fmt.Errorf("remnawave %s: decode: %T", op, err)
		}
		return nil
	case resp.StatusCode >= http.StatusInternalServerError, resp.StatusCode == http.StatusTooManyRequests:
		return fmt.Errorf("%w: %s: status %d", panel.ErrUnavailable, op, resp.StatusCode)
	case resp.StatusCode == http.StatusNotFound:
		return fmt.Errorf("%w: %s", panel.ErrNotFound, op)
	}
	var problem struct {
		ErrorCode string `json:"errorCode"`
	}
	_ = json.Unmarshal(body, &problem)
	if resp.StatusCode == http.StatusBadRequest && problem.ErrorCode == errorCodeUsernameTaken {
		return fmt.Errorf("%w: %s", panel.ErrConflict, op)
	}
	return fmt.Errorf("remnawave %s: status %d, error code %q", op, resp.StatusCode, problem.ErrorCode)
}

func deref[T any](value *T) T {
	if value == nil {
		var zero T
		return zero
	}
	return *value
}
