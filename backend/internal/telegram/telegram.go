// Package telegram defines the bot client contract (tech.md 5.10, 19.8).
package telegram

import (
	"context"
	"errors"
)

// Client errors.
var (
	// ErrBotBlocked means the user blocked the bot (403).
	ErrBotBlocked = errors.New("telegram: bot blocked")
	// ErrUnavailable covers 5xx, network failures, and 429.
	ErrUnavailable = errors.New("telegram: unavailable")
)

// UpdateKind tells what an Update carries.
type UpdateKind string

// Update kinds. Block changes come from my_chat_member.
const (
	UpdateMessage      UpdateKind = "message"
	UpdateCallback     UpdateKind = "callback"
	UpdateBotBlocked   UpdateKind = "bot_blocked"
	UpdateBotUnblocked UpdateKind = "bot_unblocked"
)

// Update is the transport-neutral form of a webhook or polling update.
type Update struct {
	UpdateID     int64
	Kind         UpdateKind
	TelegramID   int64
	ChatID       int64
	Username     string // without @, lower case, empty when the user has none
	FirstName    string
	Text         string // message text or command
	CallbackID   string
	CallbackData string
}

// InlineButton is one button under a message. Exactly one of URL and
// CallbackData is set.
type InlineButton struct {
	Text         string
	URL          string
	CallbackData string
}

// TelegramClient sends messages through the bot.
type TelegramClient interface {
	SendMessage(ctx context.Context, chatID int64, text string, buttons []InlineButton) (messageID int64, err error)
	AnswerCallback(ctx context.Context, callbackID string, text string) error
}
