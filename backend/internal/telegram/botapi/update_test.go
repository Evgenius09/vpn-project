package botapi

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
	"pgregory.net/rapid"

	"github.com/Evgenius09/vpn-project/backend/internal/telegram"
)

func TestDecodeUpdate(t *testing.T) {
	cases := []struct {
		name string
		body string
		want telegram.Update
	}{
		{
			name: "private message",
			body: `{"update_id":10,"message":{"message_id":1,"date":1,
				"from":{"id":7,"is_bot":false,"first_name":"Ann","username":"Ann_Lee"},
				"chat":{"id":70,"type":"private"},"text":"/start"}}`,
			want: telegram.Update{
				UpdateID: 10, Kind: telegram.UpdateMessage, TelegramID: 7, ChatID: 70,
				Username: "ann_lee", FirstName: "Ann", Text: "/start",
			},
		},
		{
			name: "message from a user without a nick",
			body: `{"update_id":11,"message":{"message_id":1,"date":1,
				"from":{"id":7,"is_bot":false,"first_name":"Ann"},
				"chat":{"id":7,"type":"private"},"text":"hi"}}`,
			want: telegram.Update{
				UpdateID: 11, Kind: telegram.UpdateMessage, TelegramID: 7, ChatID: 7,
				FirstName: "Ann", Text: "hi",
			},
		},
		{
			name: "message without text still counts as a message",
			body: `{"update_id":12,"message":{"message_id":1,"date":1,
				"from":{"id":7,"is_bot":false,"first_name":"Ann","username":"ann"},
				"chat":{"id":7,"type":"private"}}}`,
			want: telegram.Update{
				UpdateID: 12, Kind: telegram.UpdateMessage, TelegramID: 7, ChatID: 7,
				Username: "ann", FirstName: "Ann",
			},
		},
		{
			name: "callback",
			body: `{"update_id":13,"callback_query":{"id":"cb-1","chat_instance":"x","data":"payload",
				"from":{"id":7,"is_bot":false,"first_name":"Ann","username":"ANN"},
				"message":{"message_id":1,"date":1,"chat":{"id":70,"type":"private"}}}}`,
			want: telegram.Update{
				UpdateID: 13, Kind: telegram.UpdateCallback, TelegramID: 7, ChatID: 70,
				Username: "ann", FirstName: "Ann", CallbackID: "cb-1", CallbackData: "payload",
			},
		},
		{
			name: "user blocks the bot",
			body: `{"update_id":14,"my_chat_member":{"date":1,
				"chat":{"id":70,"type":"private"},
				"from":{"id":7,"is_bot":false,"first_name":"Ann","username":"ann"},
				"old_chat_member":{"status":"member","user":{"id":1,"is_bot":true,"first_name":"b"}},
				"new_chat_member":{"status":"kicked","until_date":0,"user":{"id":1,"is_bot":true,"first_name":"b"}}}}`,
			want: telegram.Update{
				UpdateID: 14, Kind: telegram.UpdateBotBlocked, TelegramID: 7, ChatID: 70,
				Username: "ann", FirstName: "Ann",
			},
		},
		{
			name: "user unblocks the bot",
			body: `{"update_id":15,"my_chat_member":{"date":1,
				"chat":{"id":70,"type":"private"},
				"from":{"id":7,"is_bot":false,"first_name":"Ann","username":"ann"},
				"old_chat_member":{"status":"kicked","until_date":0,"user":{"id":1,"is_bot":true,"first_name":"b"}},
				"new_chat_member":{"status":"member","user":{"id":1,"is_bot":true,"first_name":"b"}}}}`,
			want: telegram.Update{
				UpdateID: 15, Kind: telegram.UpdateBotUnblocked, TelegramID: 7, ChatID: 70,
				Username: "ann", FirstName: "Ann",
			},
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got, ok, err := DecodeUpdate([]byte(tc.body))
			require.NoError(t, err)
			require.True(t, ok)
			require.Equal(t, tc.want, got)
		})
	}
}

func TestDecodeUpdateSkipsWhatTheBotDoesNotServe(t *testing.T) {
	cases := map[string]string{
		"group message": `{"update_id":1,"message":{"message_id":1,"date":1,
			"from":{"id":7,"is_bot":false,"first_name":"Ann"},
			"chat":{"id":-100,"type":"group"},"text":"/start"}}`,
		"channel post": `{"update_id":2,"channel_post":{"message_id":1,"date":1,
			"chat":{"id":-100,"type":"channel"},"text":"hi"}}`,
		"message without a sender": `{"update_id":3,"message":{"message_id":1,"date":1,
			"chat":{"id":7,"type":"private"},"text":"hi"}}`,
		"message from another bot": `{"update_id":4,"message":{"message_id":1,"date":1,
			"from":{"id":7,"is_bot":true,"first_name":"Other"},
			"chat":{"id":7,"type":"private"},"text":"/start"}}`,
		"bot added to a group": `{"update_id":5,"my_chat_member":{"date":1,
			"chat":{"id":-100,"type":"group"},
			"from":{"id":7,"is_bot":false,"first_name":"Ann"},
			"old_chat_member":{"status":"left","user":{"id":1,"is_bot":true,"first_name":"b"}},
			"new_chat_member":{"status":"member","user":{"id":1,"is_bot":true,"first_name":"b"}}}}`,
		"callback from a group": `{"update_id":6,"callback_query":{"id":"cb","chat_instance":"x",
			"from":{"id":7,"is_bot":false,"first_name":"Ann"},
			"message":{"message_id":1,"date":1,"chat":{"id":-100,"type":"group"}}}}`,
		"edited message": `{"update_id":7,"edited_message":{"message_id":1,"date":1,
			"from":{"id":7,"is_bot":false,"first_name":"Ann"},
			"chat":{"id":7,"type":"private"},"text":"hi"}}`,
	}
	for name, body := range cases {
		t.Run(name, func(t *testing.T) {
			_, ok, err := DecodeUpdate([]byte(body))
			require.NoError(t, err)
			require.False(t, ok)
		})
	}
}

func TestDecodeUpdateRejectsMalformedJSON(t *testing.T) {
	_, ok, err := DecodeUpdate([]byte(`{"update_id":`))
	require.Error(t, err)
	require.False(t, ok)
}

func TestDecodeUpdateNormalizesAnyNick(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		nick := rapid.StringMatching(`[A-Za-z0-9_]{1,32}`).Draw(t, "nick")
		body := `{"update_id":1,"message":{"message_id":1,"date":1,
			"from":{"id":7,"is_bot":false,"first_name":"Ann","username":"` + nick + `"},
			"chat":{"id":7,"type":"private"},"text":"hi"}}`

		got, ok, err := DecodeUpdate([]byte(body))
		require.NoError(t, err)
		require.True(t, ok)
		require.Equal(t, strings.ToLower(nick), got.Username)
	})
}
