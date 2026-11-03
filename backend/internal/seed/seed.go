// Package seed loads the one data set shared by the local database, the fakes,
// and the tests (tech.md 9).
package seed

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Evgenius09/vpn-project/backend/internal/db/sqlc"
	"github.com/Evgenius09/vpn-project/backend/internal/domain/catalog"
	"github.com/Evgenius09/vpn-project/backend/internal/httpapi"
	"github.com/Evgenius09/vpn-project/backend/internal/panel"
	panelfake "github.com/Evgenius09/vpn-project/backend/internal/panel/fake"
	"github.com/Evgenius09/vpn-project/backend/internal/telegram"
)

// Fixture paths, relative to the backend module.
const (
	DefaultPath = "../contracts/fixtures/seed/seed.json"
	// DefaultCatalogPath is the servers.yaml of the seed servers for make dev.
	DefaultCatalogPath = "../contracts/fixtures/seed/catalog.yaml"
)

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
	RemnawaveID       int64  `json:"remnawaveId"`
	ShortUUID         string `json:"shortUuid"`
	VlessUUID         string `json:"vlessUuid"`
	Hysteria2Auth     string `json:"hysteria2Auth"`
	TrafficLimitBytes int64  `json:"trafficLimitBytes"`
	TrafficUsedBytes  int64  `json:"trafficUsedBytes"`
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
		RemnawaveID:       panelUser.RemnawaveID,
		ShortUuid:         panelUser.ShortUUID,
		VlessUuid:         panelUser.VlessUUID,
		Hysteria2Auth:     panelUser.Hysteria2Auth,
		TrafficLimitBytes: panelUser.TrafficLimitBytes,
		TrafficUsedBytes:  panelUser.TrafficUsedBytes,
	}); err != nil {
		return fmt.Errorf("panel user: %w", err)
	}

	for _, server := range data.Servers {
		// The row hashes the way catalog_sync would, so the first sync after a
		// seed changes nothing.
		published, err := catalog.Publish(server.PanelHost(), server.CatalogEntry())
		if err != nil {
			return fmt.Errorf("server %s: %w", server.DisplayName, err)
		}
		if err := queries.SeedServer(ctx, sqlc.SeedServerParams{
			ID:                server.ID,
			RemnawaveHostUuid: server.RemnawaveHostUUID,
			Grp:               sqlc.ServerGroup(published.Group),
			Protocol:          sqlc.ServerProtocol(published.Protocol),
			DisplayName:       published.DisplayName,
			CountryCode:       published.CountryCode,
			City:              published.City,
			Address:           published.Address,
			Port:              server.Port,
			Params:            published.Params,
			SortWeight:        server.SortWeight,
			ContentHash:       published.ContentHash(),
		}); err != nil {
			return fmt.Errorf("server %s: %w", server.DisplayName, err)
		}
	}
	return nil
}

// PanelHost is the server as the panel publishes it.
func (s Server) PanelHost() panel.PanelHost {
	return panel.PanelHost{
		UUID:     s.RemnawaveHostUUID,
		Protocol: s.Protocol,
		Address:  s.Address,
		Port:     int(s.Port),
		Params:   s.Params,
		Enabled:  true,
	}
}

// CatalogEntry is the servers.yaml record of the server.
func (s Server) CatalogEntry() catalog.Entry {
	city := s.City
	return catalog.Entry{
		RemnawaveHostUUID: s.RemnawaveHostUUID,
		Group:             s.Group,
		DisplayName:       s.DisplayName,
		CountryCode:       s.CountryCode,
		City:              &city,
		SortWeight:        int(s.SortWeight),
	}
}

// PanelHosts are the hosts of every seed server.
func (d Data) PanelHosts() []panel.PanelHost {
	hosts := make([]panel.PanelHost, 0, len(d.Servers))
	for _, server := range d.Servers {
		hosts = append(hosts, server.PanelHost())
	}
	return hosts
}

// CatalogEntries are the servers.yaml records of every seed server.
func (d Data) CatalogEntries() []catalog.Entry {
	entries := make([]catalog.Entry, 0, len(d.Servers))
	for _, server := range d.Servers {
		entries = append(entries, server.CatalogEntry())
	}
	return entries
}

// PanelUsername follows tg_<telegram_id> (tech.md 5.10).
func (d Data) PanelUsername() string {
	return fmt.Sprintf("tg_%d", d.TelegramUser.TelegramID)
}

// FillPanel gives a fake panel the seed user and hosts.
func FillPanel(client *panelfake.Client, data Data) {
	client.AddUser(panel.PanelUser{
		ID:            data.PanelUser.RemnawaveID,
		ShortUUID:     data.PanelUser.ShortUUID,
		Username:      data.PanelUsername(),
		ExpiresAt:     data.Account.ExpiresAt,
		TrafficLimit:  data.PanelUser.TrafficLimitBytes,
		TrafficUsed:   data.PanelUser.TrafficUsedBytes,
		VlessUUID:     data.PanelUser.VlessUUID,
		Hysteria2Auth: data.PanelUser.Hysteria2Auth,
	})
	client.SetHosts(data.PanelHosts())
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
