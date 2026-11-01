// Package seed loads the one data set shared by the local database, the fakes,
// and the tests (tech.md 9).
package seed

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Evgenius09/vpn-project/backend/internal/db/sqlc"
	"github.com/Evgenius09/vpn-project/backend/internal/httpapi"
	"github.com/Evgenius09/vpn-project/backend/internal/panel"
	panelfake "github.com/Evgenius09/vpn-project/backend/internal/panel/fake"
	"github.com/Evgenius09/vpn-project/backend/internal/telegram"
)

// DefaultPath is the fixture, relative to the backend module.
const DefaultPath = "../contracts/fixtures/seed/seed.json"

// Account is the seed account.
type Account struct {
	ID          uuid.UUID `json:"id"`
	Status      string    `json:"status"`
	ExpiresAt   time.Time `json:"expiresAt"`
	DeviceLimit int32     `json:"deviceLimit"`
}

// TelegramUser is the bot user of the seed account.
type TelegramUser struct {
	TelegramID int64  `json:"telegramId"`
	ChatID     int64  `json:"chatId"`
	Username   string `json:"username"`
	FirstName  string `json:"firstName"`
}

// Device is the seed device. Token is a development value, not a secret.
type Device struct {
	ID         uuid.UUID `json:"id"`
	InstallID  uuid.UUID `json:"installId"`
	Platform   string    `json:"platform"`
	Model      string    `json:"model"`
	AppVersion string    `json:"appVersion"`
	Token      string    `json:"token"`
}

// PanelUser is the panel side of the seed account.
type PanelUser struct {
	RemnawaveUUID     uuid.UUID `json:"remnawaveUuid"`
	ShortUUID         string    `json:"shortUuid"`
	VlessUUID         string    `json:"vlessUuid"`
	Hysteria2Auth     string    `json:"hysteria2Auth"`
	TrafficLimitBytes int64     `json:"trafficLimitBytes"`
	TrafficUsedBytes  int64     `json:"trafficUsedBytes"`
}

// Server is one seed server.
type Server struct {
	ID                uuid.UUID       `json:"id"`
	RemnawaveHostUUID uuid.UUID       `json:"remnawaveHostUuid"`
	Group             string          `json:"group"`
	Protocol          string          `json:"protocol"`
	DisplayName       string          `json:"displayName"`
	CountryCode       string          `json:"countryCode"`
	City              string          `json:"city"`
	Address           string          `json:"address"`
	Port              int32           `json:"port"`
	Params            json.RawMessage `json:"params"`
	SortWeight        int32           `json:"sortWeight"`
}

// Data is the whole seed.
type Data struct {
	Account      Account      `json:"account"`
	TelegramUser TelegramUser `json:"telegramUser"`
	Device       Device       `json:"device"`
	PanelUser    PanelUser    `json:"panelUser"`
	Servers      []Server     `json:"servers"`
}

// Load reads the seed file.
func Load(path string) (Data, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return Data{}, fmt.Errorf("read seed: %w", err)
	}
	var data Data
	if err := json.Unmarshal(raw, &data); err != nil {
		return Data{}, fmt.Errorf("decode seed: %w", err)
	}
	return data, nil
}

// Apply writes the seed to the database. Running it again changes nothing.
func Apply(ctx context.Context, pool *pgxpool.Pool, data Data, pepper []byte) error {
	err := pgx.BeginFunc(ctx, pool, func(tx pgx.Tx) error {
		return apply(ctx, sqlc.New(tx), data, pepper)
	})
	if err != nil {
		return fmt.Errorf("apply seed: %w", err)
	}
	return nil
}

func apply(ctx context.Context, queries *sqlc.Queries, data Data, pepper []byte) error {
	account := data.Account
	if err := queries.SeedAccount(ctx, sqlc.SeedAccountParams{
		ID:          account.ID,
		Status:      sqlc.AccountStatus(account.Status),
		ExpiresAt:   &account.ExpiresAt,
		DeviceLimit: account.DeviceLimit,
	}); err != nil {
		return fmt.Errorf("account: %w", err)
	}

	user := data.TelegramUser
	if err := queries.SeedTelegramUser(ctx, sqlc.SeedTelegramUserParams{
		TelegramID: user.TelegramID,
		AccountID:  account.ID,
		ChatID:     user.ChatID,
		Username:   &user.Username,
		FirstName:  user.FirstName,
	}); err != nil {
		return fmt.Errorf("telegram user: %w", err)
	}

	device := data.Device
	if err := queries.SeedDevice(ctx, sqlc.SeedDeviceParams{
		ID:         device.ID,
		AccountID:  account.ID,
		InstallID:  device.InstallID,
		Platform:   sqlc.Platform(device.Platform),
		Model:      device.Model,
		AppVersion: device.AppVersion,
		TokenHash:  httpapi.HashToken(device.Token, pepper),
	}); err != nil {
		return fmt.Errorf("device: %w", err)
	}

	panelUser := data.PanelUser
	if err := queries.SeedPanelUser(ctx, sqlc.SeedPanelUserParams{
		AccountID:         account.ID,
		RemnawaveUuid:     panelUser.RemnawaveUUID,
		ShortUuid:         panelUser.ShortUUID,
		VlessUuid:         panelUser.VlessUUID,
		Hysteria2Auth:     panelUser.Hysteria2Auth,
		TrafficLimitBytes: panelUser.TrafficLimitBytes,
		TrafficUsedBytes:  panelUser.TrafficUsedBytes,
	}); err != nil {
		return fmt.Errorf("panel user: %w", err)
	}

	for _, server := range data.Servers {
		city := server.City
		if err := queries.SeedServer(ctx, sqlc.SeedServerParams{
			ID:                server.ID,
			RemnawaveHostUuid: server.RemnawaveHostUUID,
			Grp:               sqlc.ServerGroup(server.Group),
			Protocol:          sqlc.ServerProtocol(server.Protocol),
			DisplayName:       server.DisplayName,
			CountryCode:       server.CountryCode,
			City:              &city,
			Address:           server.Address,
			Port:              server.Port,
			Params:            server.Params,
			SortWeight:        server.SortWeight,
			ContentHash:       contentHash(server),
		}); err != nil {
			return fmt.Errorf("server %s: %w", server.DisplayName, err)
		}
	}
	return nil
}

func contentHash(server Server) string {
	sum := sha256.Sum256(fmt.Appendf(nil, "%s|%s|%d|%s", server.DisplayName, server.Address, server.Port, server.Params))
	return hex.EncodeToString(sum[:])
}

// PanelUsername follows tg_<telegram_id> (tech.md 5.10).
func (d Data) PanelUsername() string {
	return fmt.Sprintf("tg_%d", d.TelegramUser.TelegramID)
}

// FillPanel gives a fake panel the seed user and hosts.
func FillPanel(client *panelfake.Client, data Data) {
	client.AddUser(panel.PanelUser{
		UUID:          data.PanelUser.RemnawaveUUID,
		ShortUUID:     data.PanelUser.ShortUUID,
		Username:      data.PanelUsername(),
		ExpiresAt:     data.Account.ExpiresAt,
		TrafficLimit:  data.PanelUser.TrafficLimitBytes,
		TrafficUsed:   data.PanelUser.TrafficUsedBytes,
		VlessUUID:     data.PanelUser.VlessUUID,
		Hysteria2Auth: data.PanelUser.Hysteria2Auth,
	})
	hosts := make([]panel.PanelHost, 0, len(data.Servers))
	for _, server := range data.Servers {
		hosts = append(hosts, panel.PanelHost{
			UUID:     server.RemnawaveHostUUID,
			Protocol: server.Protocol,
			Address:  server.Address,
			Port:     int(server.Port),
			Params:   server.Params,
			Enabled:  true,
		})
	}
	client.SetHosts(hosts)
}

// StartUpdate is the /start message of the seed user, for the fake Telegram.
func (d Data) StartUpdate(updateID int64) telegram.Update {
	return telegram.Update{
		UpdateID:   updateID,
		Kind:       telegram.UpdateMessage,
		TelegramID: d.TelegramUser.TelegramID,
		ChatID:     d.TelegramUser.ChatID,
		Username:   d.TelegramUser.Username,
		FirstName:  d.TelegramUser.FirstName,
		Text:       "/start",
	}
}
