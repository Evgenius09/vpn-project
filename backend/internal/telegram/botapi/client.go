// Package botapi implements telegram.TelegramClient on the Bot API
// (tech.md 5.10) and maps incoming updates to telegram.Update.
package botapi

import (
	"context"
	"errors"
	"fmt"
	"log/slog"

	"github.com/go-telegram/bot"
	"github.com/go-telegram/bot/models"

	"github.com/Evgenius09/vpn-project/backend/internal/telegram"
)

// Client implements telegram.TelegramClient.
type Client struct {
	bot    *bot.Bot
	logger *slog.Logger
}

var _ telegram.TelegramClient = (*Client)(nil)

// Option changes how the client reaches the Bot API.
type Option = bot.Option

// WithServerURL points the client at another Bot API server.
func WithServerURL(url string) Option { return bot.WithServerURL(url) }

// New returns a client. It does not call the Bot API, so an outage of Telegram
// cannot stop the process from starting.
func New(token string, logger *slog.Logger, options ...Option) (*Client, error) {
	defaults := []Option{
		bot.WithSkipGetMe(),
		// Concurrent dispatch would reorder the updates of one user.
		bot.WithNotAsyncHandlers(),
		bot.WithErrorsHandler(func(err error) {
			logger.WarnContext(context.Background(), "telegram client error", "error", err)
		}),
	}
	client, err := bot.New(token, append(defaults, options...)...)
	if err != nil {
		return nil, fmt.Errorf("telegram: create client: %w", err)
	}
	return &Client{bot: client, logger: logger}, nil
}

// SendMessage implements telegram.TelegramClient.
func (c *Client) SendMessage(ctx context.Context, chatID int64, text string, buttons []telegram.InlineButton) (int64, error) {
	params := &bot.SendMessageParams{ChatID: chatID, Text: text}
	if len(buttons) > 0 {
		params.ReplyMarkup = keyboard(buttons)
	}
	message, err := c.bot.SendMessage(ctx, params)
	if err != nil {
		return 0, mapError("send message", err)
	}
	return int64(message.ID), nil
}

// AnswerCallback implements telegram.TelegramClient.
func (c *Client) AnswerCallback(ctx context.Context, callbackID string, text string) error {
	_, err := c.bot.AnswerCallbackQuery(ctx, &bot.AnswerCallbackQueryParams{CallbackQueryID: callbackID, Text: text})
	if err != nil {
		return mapError("answer callback", err)
	}
	return nil
}

// Poll delivers updates to handle, one at a time, until ctx ends. A failed
// update is logged and skipped, because long polling has already moved past it.
func (c *Client) Poll(ctx context.Context, handle func(context.Context, telegram.Update) error) {
	matchAll := func(*models.Update) bool { return true }
	c.bot.RegisterHandlerMatchFunc(matchAll, func(ctx context.Context, _ *bot.Bot, update *models.Update) {
		mapped, ok := mapUpdate(update)
		if !ok {
			return
		}
		if err := handle(ctx, mapped); err != nil {
			c.logger.ErrorContext(ctx, "telegram update failed", "updateId", mapped.UpdateID, "error", err)
		}
	})
	c.bot.Start(ctx)
}

func keyboard(buttons []telegram.InlineButton) *models.InlineKeyboardMarkup {
	rows := make([][]models.InlineKeyboardButton, 0, len(buttons))
	for _, button := range buttons {
		rows = append(rows, []models.InlineKeyboardButton{{
			Text:         button.Text,
			URL:          button.URL,
			CallbackData: button.CallbackData,
		}})
	}
	return &models.InlineKeyboardMarkup{InlineKeyboard: rows}
}

// mapError treats everything except a rejected request as an outage, because
// the library reports 5xx and non-JSON answers as untyped errors.
func mapError(op string, err error) error {
	switch {
	case errors.Is(err, bot.ErrorForbidden):
		return fmt.Errorf("%w: %s: %w", telegram.ErrBotBlocked, op, err)
	case errors.Is(err, bot.ErrorBadRequest),
		errors.Is(err, bot.ErrorUnauthorized),
		errors.Is(err, bot.ErrorNotFound),
		errors.Is(err, bot.ErrorConflict):
		return fmt.Errorf("telegram: %s: %w", op, err)
	default:
		return fmt.Errorf("%w: %s: %w", telegram.ErrUnavailable, op, err)
	}
}
