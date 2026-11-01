// Package fake is an in-memory PanelClient for tests and local development.
// It rejects input the real panel would never accept, so it doubles as a
// contract check on its callers (tech.md 10).
package fake

import (
	"context"
	"errors"
	"fmt"
	"regexp"
	"sync"

	"github.com/google/uuid"

	"github.com/Evgenius09/vpn-project/backend/internal/panel"
)

// Operation names for FailNext and Calls.
const (
	OpGetUserByUsername = "GetUserByUsername"
	OpCreateUser        = "CreateUser"
	OpUpdateUser        = "UpdateUser"
	OpListHosts         = "ListHosts"
)

// ErrInvalidInput marks a call that breaks the panel contract.
var ErrInvalidInput = errors.New("fake panel: invalid input")

var usernamePattern = regexp.MustCompile(`^tg_[0-9]+$`)

// Client implements panel.PanelClient.
type Client struct {
	mu       sync.Mutex
	users    map[string]panel.PanelUser
	hosts    []panel.PanelHost
	failures map[string][]error
	calls    map[string]int
}

var _ panel.PanelClient = (*Client)(nil)

// New returns an empty panel.
func New() *Client {
	return &Client{
		users:    map[string]panel.PanelUser{},
		failures: map[string][]error{},
		calls:    map[string]int{},
	}
}

// FailNext makes the next call of op return err.
func (c *Client) FailNext(op string, err error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.failures[op] = append(c.failures[op], err)
}

// Calls counts the calls of op, including failed ones.
func (c *Client) Calls(op string) int {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.calls[op]
}

// SetHosts replaces the published hosts.
func (c *Client) SetHosts(hosts []panel.PanelHost) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.hosts = hosts
}

// AddUser stores a user directly, as if it already existed in the panel.
func (c *Client) AddUser(user panel.PanelUser) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.users[user.Username] = user
}

func (c *Client) enter(op string) error {
	c.calls[op]++
	if queue := c.failures[op]; len(queue) > 0 {
		c.failures[op] = queue[1:]
		return queue[0]
	}
	return nil
}

// GetUserByUsername implements panel.PanelClient.
func (c *Client) GetUserByUsername(_ context.Context, username string) (panel.PanelUser, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if err := c.enter(OpGetUserByUsername); err != nil {
		return panel.PanelUser{}, err
	}
	if !usernamePattern.MatchString(username) {
		return panel.PanelUser{}, fmt.Errorf("%w: username %q", ErrInvalidInput, username)
	}
	user, ok := c.users[username]
	if !ok {
		return panel.PanelUser{}, panel.ErrNotFound
	}
	return user, nil
}

// CreateUser implements panel.PanelClient.
func (c *Client) CreateUser(_ context.Context, in panel.CreateUserInput) (panel.PanelUser, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if err := c.enter(OpCreateUser); err != nil {
		return panel.PanelUser{}, err
	}
	switch {
	case !usernamePattern.MatchString(in.Username):
		return panel.PanelUser{}, fmt.Errorf("%w: username %q", ErrInvalidInput, in.Username)
	case in.ExpiresAt.IsZero():
		return panel.PanelUser{}, fmt.Errorf("%w: zero expiry", ErrInvalidInput)
	case in.TrafficLimit < 0:
		return panel.PanelUser{}, fmt.Errorf("%w: negative traffic limit", ErrInvalidInput)
	}
	if _, taken := c.users[in.Username]; taken {
		return panel.PanelUser{}, panel.ErrConflict
	}
	user := panel.PanelUser{
		UUID:          uuid.New(),
		ShortUUID:     uuid.NewString()[:8],
		Username:      in.Username,
		ExpiresAt:     in.ExpiresAt,
		TrafficLimit:  in.TrafficLimit,
		VlessUUID:     uuid.NewString(),
		Hysteria2Auth: uuid.NewString(),
	}
	c.users[in.Username] = user
	return user, nil
}

// UpdateUser implements panel.PanelClient.
func (c *Client) UpdateUser(_ context.Context, id uuid.UUID, in panel.UpdateUserInput) (panel.PanelUser, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if err := c.enter(OpUpdateUser); err != nil {
		return panel.PanelUser{}, err
	}
	if in.ExpiresAt.IsZero() || in.TrafficLimit < 0 {
		return panel.PanelUser{}, fmt.Errorf("%w: update values", ErrInvalidInput)
	}
	for username, user := range c.users {
		if user.UUID == id {
			user.ExpiresAt = in.ExpiresAt
			user.TrafficLimit = in.TrafficLimit
			c.users[username] = user
			return user, nil
		}
	}
	return panel.PanelUser{}, panel.ErrNotFound
}

// ListHosts implements panel.PanelClient.
func (c *Client) ListHosts(_ context.Context) ([]panel.PanelHost, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if err := c.enter(OpListHosts); err != nil {
		return nil, err
	}
	return append([]panel.PanelHost(nil), c.hosts...), nil
}
