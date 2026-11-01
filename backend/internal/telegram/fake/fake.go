// Package fake is a recording TelegramClient for tests and local development.
// In development it logs message text, which is how a login code reaches the
// developer without a real bot.
package fake

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"sync"

	"github.com/Evgenius09/vpn-project/backend/internal/telegram"
)

// Operation names for FailNext.
const (
	OpSendMessage    = "SendMessage"
	OpAnswerCallback = "AnswerCallback"
)

// ErrInvalidInput marks a call that breaks the Telegram contract.
var ErrInvalidInput = errors.New("fake telegram: invalid input")

const maxMessageLength = 4096

// Message is one recorded SendMessage call.
type Message struct {
	ID      int64
	ChatID  int64
	Text    string
	Buttons []telegram.InlineButton
}

// Client implements telegram.TelegramClient.
type Client struct {
	mu       sync.Mutex
	logger   *slog.Logger
	sent     []Message
	answers  []string
	failures map[string][]error
}

var _ telegram.TelegramClient = (*Client)(nil)

// New returns a client. A nil logger keeps message text out of the logs.
func New(logger *slog.Logger) *Client {
	return &Client{logger: logger, failures: map[string][]error{}}
}

// FailNext makes the next call of op return err.
func (c *Client) FailNext(op string, err error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.failures[op] = append(c.failures[op], err)
}

// Sent returns the recorded messages.
func (c *Client) Sent() []Message {
	c.mu.Lock()
	defer c.mu.Unlock()
	return append([]Message(nil), c.sent...)
}

// Answers returns the recorded callback identifiers.
func (c *Client) Answers() []string {
	c.mu.Lock()
	defer c.mu.Unlock()
	return append([]string(nil), c.answers...)
}

func (c *Client) popFailure(op string) error {
	if queue := c.failures[op]; len(queue) > 0 {
		c.failures[op] = queue[1:]
		return queue[0]
	}
	return nil
}

// SendMessage implements telegram.TelegramClient.
func (c *Client) SendMessage(ctx context.Context, chatID int64, text string, buttons []telegram.InlineButton) (int64, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if err := c.popFailure(OpSendMessage); err != nil {
		return 0, err
	}
	if err := validateMessage(chatID, text, buttons); err != nil {
		return 0, err
	}
	message := Message{ID: int64(len(c.sent) + 1), ChatID: chatID, Text: text, Buttons: buttons}
	c.sent = append(c.sent, message)
	if c.logger != nil {
		c.logger.InfoContext(ctx, "fake telegram message", "chatId", chatID, "text", text)
	}
	return message.ID, nil
}

// AnswerCallback implements telegram.TelegramClient.
func (c *Client) AnswerCallback(_ context.Context, callbackID string, _ string) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	if err := c.popFailure(OpAnswerCallback); err != nil {
		return err
	}
	if callbackID == "" {
		return fmt.Errorf("%w: empty callback id", ErrInvalidInput)
	}
	c.answers = append(c.answers, callbackID)
	return nil
}

func validateMessage(chatID int64, text string, buttons []telegram.InlineButton) error {
	if chatID == 0 {
		return fmt.Errorf("%w: zero chat id", ErrInvalidInput)
	}
	if text == "" || len([]rune(text)) > maxMessageLength {
		return fmt.Errorf("%w: text length", ErrInvalidInput)
	}
	for _, button := range buttons {
		if button.Text == "" || (button.URL == "") == (button.CallbackData == "") {
			return fmt.Errorf("%w: button %q", ErrInvalidInput, button.Text)
		}
	}
	return nil
}
