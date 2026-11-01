package fake

import (
	"bytes"
	"context"
	"log/slog"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/Evgenius09/vpn-project/backend/internal/telegram"
)

func TestRecordsMessages(t *testing.T) {
	client := New(nil)
	id, err := client.SendMessage(context.Background(), 7, "hello", []telegram.InlineButton{{Text: "Open", URL: "https://t.me/x"}})
	require.NoError(t, err)
	require.Equal(t, int64(1), id)
	require.Len(t, client.Sent(), 1)
	require.Equal(t, "hello", client.Sent()[0].Text)
}

func TestRejectsGarbage(t *testing.T) {
	ctx := context.Background()
	tests := []struct {
		name    string
		chatID  int64
		text    string
		buttons []telegram.InlineButton
	}{
		{"zero chat", 0, "text", nil},
		{"empty text", 1, "", nil},
		{"text over the limit", 1, strings.Repeat("a", maxMessageLength+1), nil},
		{"button without a target", 1, "text", []telegram.InlineButton{{Text: "x"}}},
		{"button with two targets", 1, "text", []telegram.InlineButton{{Text: "x", URL: "u", CallbackData: "c"}}},
		{"button without text", 1, "text", []telegram.InlineButton{{URL: "u"}}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := New(nil).SendMessage(ctx, tt.chatID, tt.text, tt.buttons)
			require.ErrorIs(t, err, ErrInvalidInput)
		})
	}
}

func TestFailNextDoesNotRecord(t *testing.T) {
	client := New(nil)
	client.FailNext(OpSendMessage, telegram.ErrBotBlocked)

	_, err := client.SendMessage(context.Background(), 1, "text", nil)
	require.ErrorIs(t, err, telegram.ErrBotBlocked)
	require.Empty(t, client.Sent())

	_, err = client.SendMessage(context.Background(), 1, "text", nil)
	require.NoError(t, err)
	require.Len(t, client.Sent(), 1)
}

func TestAnswerCallback(t *testing.T) {
	client := New(nil)
	require.ErrorIs(t, client.AnswerCallback(context.Background(), "", ""), ErrInvalidInput)
	require.NoError(t, client.AnswerCallback(context.Background(), "cb1", "ok"))
	require.Equal(t, []string{"cb1"}, client.Answers())
}

func TestLogsTextOnlyWithALogger(t *testing.T) {
	var out bytes.Buffer
	client := New(slog.New(slog.NewTextHandler(&out, nil)))
	_, err := client.SendMessage(context.Background(), 1, "code 123456", nil)
	require.NoError(t, err)
	require.Contains(t, out.String(), "123456")
}
