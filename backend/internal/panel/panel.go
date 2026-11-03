// Package panel defines the Remnawave client contract (tech.md 5.10, 19.8).
package panel

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"github.com/google/uuid"
)

// Client errors.
var (
	// ErrNotFound means the panel has no such user.
	ErrNotFound = errors.New("panel: not found")
	// ErrConflict means the username is taken.
	ErrConflict = errors.New("panel: conflict")
	// ErrUnavailable covers 5xx, timeouts, and network failures.
	ErrUnavailable = errors.New("panel: unavailable")
)

// PanelUser is a user as the panel sees it.
type PanelUser struct {
	ID            int64 // Remnawave 3.4.8 has no user uuid (tech.md 39.2)
	ShortUUID     string
	Username      string
	ExpiresAt     time.Time
	TrafficLimit  int64
	TrafficUsed   int64
	VlessUUID     string // secret
	Hysteria2Auth string // secret
}

// PanelHost is a connection endpoint published by the panel.
type PanelHost struct {
	UUID     uuid.UUID
	Protocol string // vless_reality | hysteria2
	Address  string
	Port     int
	Params   json.RawMessage // non-secret inbound and host parameters
	Enabled  bool
	// What the catalog reads besides the connection (tech.md 41.1).
	Remark       string
	Description  string // serverDescription, "" when unset
	Tags         []string
	ViewPosition int
}

// CreateUserInput describes a new panel user.
type CreateUserInput struct {
	Username     string
	ExpiresAt    time.Time
	TrafficLimit int64
}

// UpdateUserInput carries absolute values, so repeating an update is safe.
type UpdateUserInput struct {
	ExpiresAt    time.Time
	TrafficLimit int64
}

// PanelClient talks to the panel. Usernames follow tg_<telegram_id>.
type PanelClient interface {
	GetUserByUsername(ctx context.Context, username string) (PanelUser, error)
	CreateUser(ctx context.Context, in CreateUserInput) (PanelUser, error)
	UpdateUser(ctx context.Context, id int64, in UpdateUserInput) (PanelUser, error)
	ListHosts(ctx context.Context) ([]PanelHost, error)
}
