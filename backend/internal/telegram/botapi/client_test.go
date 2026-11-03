package botapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/require"

	"github.com/Evgenius09/vpn-project/backend/internal/telegram"
)

const token = "123456:TEST-SECRET-TOKEN"

// apiServer stands in for the Bot API and records the form of each request.
type apiServer struct {
	*httptest.Server
	mu       sync.Mutex
	requests map[string][]map[string]string
}

func newAPIServer(t *testing.T, respond func(method string, w http.ResponseWriter)) *apiServer {
	t.Helper()
	server := &apiServer{requests: map[string][]map[string]string{}}
	server.Server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		method := strings.TrimPrefix(r.URL.Path, "/bot"+token+"/")
		fields := map[string]string{}
		if r.ContentLength != 0 && strings.HasPrefix(r.Header.Get("Content-Type"), "multipart/") {
			if err := r.ParseMultipartForm(1 << 20); err == nil {
				for key, values := range r.MultipartForm.Value {
					fields[key] = values[0]
				}
			}
		}
		server.mu.Lock()
		server.requests[method] = append(server.requests[method], fields)
		server.mu.Unlock()
		respond(method, w)
	}))
	t.Cleanup(server.Close)
	return server
}

func (s *apiServer) calls(method string) []map[string]string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return append([]map[string]string(nil), s.requests[method]...)
}

func newTestClient(t *testing.T, url string) *Client {
	t.Helper()
	client, err := New(token, slog.New(slog.DiscardHandler), WithServerURL(url))
	require.NoError(t, err)
	return client
}

func reply(w http.ResponseWriter, status int, body string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_, _ = io.WriteString(w, body)
}

const sentMessage = `{"ok":true,"result":{"message_id":42,"date":1,"chat":{"id":70,"type":"private"}}}`

func TestSendMessage(t *testing.T) {
	server := newAPIServer(t, func(_ string, w http.ResponseWriter) { reply(w, http.StatusOK, sentMessage) })
	client := newTestClient(t, server.URL)

	id, err := client.SendMessage(context.Background(), 70, "hello", nil)

	require.NoError(t, err)
	require.Equal(t, int64(42), id)
	calls := server.calls("sendMessage")
	require.Len(t, calls, 1)
	require.Equal(t, "70", calls[0]["chat_id"])
	require.Equal(t, "hello", calls[0]["text"])
	require.Empty(t, calls[0]["reply_markup"])
}

func TestSendMessageSendsOneButtonPerRow(t *testing.T) {
	server := newAPIServer(t, func(_ string, w http.ResponseWriter) { reply(w, http.StatusOK, sentMessage) })
	client := newTestClient(t, server.URL)

	_, err := client.SendMessage(context.Background(), 70, "hello", []telegram.InlineButton{
		{Text: "Open", URL: "https://example.com"},
		{Text: "Disconnect", CallbackData: "revoke"},
	})

	require.NoError(t, err)
	calls := server.calls("sendMessage")
	require.Len(t, calls, 1)
	var markup struct {
		InlineKeyboard [][]map[string]string `json:"inline_keyboard"`
	}
	require.NoError(t, json.Unmarshal([]byte(calls[0]["reply_markup"]), &markup))
	require.Len(t, markup.InlineKeyboard, 2)
	require.Equal(t, "Open", markup.InlineKeyboard[0][0]["text"])
	require.Equal(t, "https://example.com", markup.InlineKeyboard[0][0]["url"])
	require.Equal(t, "Disconnect", markup.InlineKeyboard[1][0]["text"])
	require.Equal(t, "revoke", markup.InlineKeyboard[1][0]["callback_data"])
}

func TestAnswerCallback(t *testing.T) {
	server := newAPIServer(t, func(_ string, w http.ResponseWriter) { reply(w, http.StatusOK, `{"ok":true,"result":true}`) })
	client := newTestClient(t, server.URL)

	require.NoError(t, client.AnswerCallback(context.Background(), "cb-1", "done"))

	calls := server.calls("answerCallbackQuery")
	require.Len(t, calls, 1)
	require.Equal(t, "cb-1", calls[0]["callback_query_id"])
	require.Equal(t, "done", calls[0]["text"])
}

func TestErrorMapping(t *testing.T) {
	cases := []struct {
		name   string
		status int
		body   string
		want   error
	}{
		{"blocked by the user", 403, `{"ok":false,"error_code":403,"description":"Forbidden: bot was blocked by the user"}`, telegram.ErrBotBlocked},
		{"rate limit", 429, `{"ok":false,"error_code":429,"description":"Too Many Requests","parameters":{"retry_after":3}}`, telegram.ErrUnavailable},
		{"server error", 502, `{"ok":false,"error_code":502,"description":"Bad Gateway"}`, telegram.ErrUnavailable},
		{"proxy page instead of json", 502, `<html>Bad Gateway</html>`, telegram.ErrUnavailable},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			server := newAPIServer(t, func(_ string, w http.ResponseWriter) { reply(w, tc.status, tc.body) })
			client := newTestClient(t, server.URL)

			_, sendErr := client.SendMessage(context.Background(), 70, "hello", nil)
			require.ErrorIs(t, sendErr, tc.want)

			require.ErrorIs(t, client.AnswerCallback(context.Background(), "cb", ""), tc.want)
		})
	}
}

// A malformed request will fail the same way on a retry, so it must not read
// as a passing outage.
func TestBadRequestIsNeitherBlockedNorUnavailable(t *testing.T) {
	server := newAPIServer(t, func(_ string, w http.ResponseWriter) {
		reply(w, http.StatusBadRequest, `{"ok":false,"error_code":400,"description":"Bad Request: chat not found"}`)
	})
	client := newTestClient(t, server.URL)

	_, err := client.SendMessage(context.Background(), 70, "hello", nil)

	require.Error(t, err)
	require.NotErrorIs(t, err, telegram.ErrBotBlocked)
	require.NotErrorIs(t, err, telegram.ErrUnavailable)
}

func TestNetworkFailureIsUnavailableAndHidesTheToken(t *testing.T) {
	server := httptest.NewServer(http.NotFoundHandler())
	url := server.URL
	server.Close()
	client := newTestClient(t, url)

	_, err := client.SendMessage(context.Background(), 70, "hello", nil)

	require.ErrorIs(t, err, telegram.ErrUnavailable)
	require.NotContains(t, err.Error(), token)
	require.NotContains(t, err.Error(), "TEST-SECRET")
}

func TestPollDeliversUpdatesInOrder(t *testing.T) {
	updates := `{"ok":true,"result":[
		{"update_id":1,"message":{"message_id":1,"date":1,"from":{"id":7,"is_bot":false,"first_name":"Ann"},"chat":{"id":7,"type":"private"},"text":"one"}},
		{"update_id":2,"channel_post":{"message_id":2,"date":1,"chat":{"id":-1,"type":"channel"}}},
		{"update_id":3,"message":{"message_id":3,"date":1,"from":{"id":7,"is_bot":false,"first_name":"Ann"},"chat":{"id":7,"type":"private"},"text":"two"}}
	]}`
	var once sync.Once
	server := newAPIServer(t, func(_ string, w http.ResponseWriter) {
		delivered := false
		once.Do(func() {
			delivered = true
			reply(w, http.StatusOK, updates)
		})
		if !delivered {
			reply(w, http.StatusOK, `{"ok":true,"result":[]}`)
		}
	})
	client := newTestClient(t, server.URL)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	var mu sync.Mutex
	var got []string
	done := make(chan struct{})
	go func() {
		defer close(done)
		client.Poll(ctx, func(_ context.Context, update telegram.Update) error {
			// The first handler is slow: a concurrent dispatch would let the
			// second update overtake it.
			if update.UpdateID == 1 {
				time.Sleep(50 * time.Millisecond)
			}
			mu.Lock()
			defer mu.Unlock()
			got = append(got, strconv.FormatInt(update.UpdateID, 10)+":"+update.Text)
			if len(got) == 2 {
				cancel()
			}
			return nil
		})
	}()

	select {
	case <-done:
	case <-time.After(10 * time.Second):
		t.Fatal("poll did not stop")
	}
	require.Equal(t, []string{"1:one", "3:two"}, got)
}

func TestPollSurvivesAHandlerError(t *testing.T) {
	updates := `{"ok":true,"result":[
		{"update_id":1,"message":{"message_id":1,"date":1,"from":{"id":7,"is_bot":false,"first_name":"Ann"},"chat":{"id":7,"type":"private"},"text":"one"}},
		{"update_id":2,"message":{"message_id":2,"date":1,"from":{"id":7,"is_bot":false,"first_name":"Ann"},"chat":{"id":7,"type":"private"},"text":"two"}}
	]}`
	var once sync.Once
	server := newAPIServer(t, func(_ string, w http.ResponseWriter) {
		delivered := false
		once.Do(func() {
			delivered = true
			reply(w, http.StatusOK, updates)
		})
		if !delivered {
			reply(w, http.StatusOK, `{"ok":true,"result":[]}`)
		}
	})
	client := newTestClient(t, server.URL)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	var seen []int64
	done := make(chan struct{})
	go func() {
		defer close(done)
		client.Poll(ctx, func(_ context.Context, update telegram.Update) error {
			seen = append(seen, update.UpdateID)
			if update.UpdateID == 2 {
				cancel()
			}
			return errors.New("database is down")
		})
	}()

	select {
	case <-done:
	case <-time.After(10 * time.Second):
		t.Fatal("poll did not stop")
	}
	require.Equal(t, []int64{1, 2}, seen)
}
