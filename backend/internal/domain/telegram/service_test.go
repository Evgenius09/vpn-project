package telegram

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/riverqueue/river"
	"github.com/riverqueue/river/rivertype"
	"github.com/stretchr/testify/require"
	"pgregory.net/rapid"

	"github.com/Evgenius09/vpn-project/backend/internal/jobs"
	tg "github.com/Evgenius09/vpn-project/backend/internal/telegram"
	"github.com/Evgenius09/vpn-project/backend/internal/telegram/fake"
	"github.com/Evgenius09/vpn-project/backend/internal/testutil"
)

const provisionJobs = "select count(*) from river_job where kind = '" + jobs.KindPanelProvisionUser + "'"

type env struct {
	pool    *pgxpool.Pool
	client  *fake.Client
	service *Service
}

func newEnv(t *testing.T) env {
	t.Helper()
	pool := testutil.NewDatabase(t)
	logger := slog.New(slog.DiscardHandler)
	queue, err := jobs.NewClient(pool, jobs.Options{Logger: logger})
	require.NoError(t, err)
	client := fake.New(nil)
	return env{pool: pool, client: client, service: NewService(pool, client, queue, logger)}
}

func (e env) count(t *testing.T, query string, args ...any) int {
	t.Helper()
	var n int
	require.NoError(t, e.pool.QueryRow(context.Background(), query, args...).Scan(&n))
	return n
}

func (e env) handle(t *testing.T, update tg.Update) {
	t.Helper()
	require.NoError(t, e.service.HandleUpdate(context.Background(), update))
}

// username returns the nick stored for a user, nil when the user has none.
func (e env) username(t *testing.T, telegramID int64) *string {
	t.Helper()
	var nick *string
	require.NoError(t, e.pool.QueryRow(context.Background(),
		"select username::text from telegram_users where telegram_id = $1", telegramID).Scan(&nick))
	return nick
}

func (e env) blockedAt(t *testing.T, telegramID int64) *time.Time {
	t.Helper()
	var at *time.Time
	require.NoError(t, e.pool.QueryRow(context.Background(),
		"select bot_blocked_at from telegram_users where telegram_id = $1", telegramID).Scan(&at))
	return at
}

func message(updateID, telegramID int64, nick, text string) tg.Update {
	return tg.Update{
		UpdateID:   updateID,
		Kind:       tg.UpdateMessage,
		TelegramID: telegramID,
		ChatID:     telegramID,
		Username:   nick,
		FirstName:  "Ann",
		Text:       text,
	}
}

func start(updateID, telegramID int64, nick string) tg.Update {
	return message(updateID, telegramID, nick, "/start")
}

func event(kind tg.UpdateKind, updateID, telegramID int64, nick string) tg.Update {
	update := message(updateID, telegramID, nick, "")
	update.Kind = kind
	return update
}

func TestStartCreatesAccountAndQueuesProvisioning(t *testing.T) {
	e := newEnv(t)

	e.handle(t, start(1, 7, "ann"))

	var accountID uuid.UUID
	var status string
	require.NoError(t, e.pool.QueryRow(context.Background(),
		"select id, status::text from accounts").Scan(&accountID, &status))
	require.Equal(t, "provisioning", status)

	var linked uuid.UUID
	var chatID, lastUpdateID int64
	var firstName string
	require.NoError(t, e.pool.QueryRow(context.Background(),
		"select account_id, chat_id, first_name, last_update_id from telegram_users where telegram_id = 7",
	).Scan(&linked, &chatID, &firstName, &lastUpdateID))
	require.Equal(t, accountID, linked)
	require.Equal(t, int64(7), chatID)
	require.Equal(t, "Ann", firstName)
	require.Equal(t, int64(1), lastUpdateID)
	require.Equal(t, "ann", *e.username(t, 7))

	var jobAccount string
	require.NoError(t, e.pool.QueryRow(context.Background(),
		"select args->>'accountId' from river_job where kind = $1", jobs.KindPanelProvisionUser).Scan(&jobAccount))
	require.Equal(t, accountID.String(), jobAccount)
}

func TestStartRepliesWithTheNickToEnterInTheApp(t *testing.T) {
	e := newEnv(t)

	e.handle(t, start(1, 7, "ann"))

	sent := e.client.Sent()
	require.Len(t, sent, 1)
	require.Equal(t, int64(7), sent[0].ChatID)
	require.Contains(t, sent[0].Text, "@ann")
	require.Contains(t, sent[0].Text, "введите")
	require.Contains(t, sent[0].Text, "приложении")
}

func TestRepeatedStartKeepsOneAccountAndOneJob(t *testing.T) {
	e := newEnv(t)

	e.handle(t, start(1, 7, "ann"))
	e.handle(t, start(2, 7, "ann"))

	require.Equal(t, 1, e.count(t, "select count(*) from accounts"))
	require.Equal(t, 1, e.count(t, "select count(*) from telegram_users"))
	require.Equal(t, 1, e.count(t, provisionJobs))
	require.Len(t, e.client.Sent(), 2, "a repeated /start still gets the instruction")
}

func TestRedeliveredUpdateHasNoEffect(t *testing.T) {
	e := newEnv(t)
	e.handle(t, start(1, 7, "ann"))
	updatedAt := func() time.Time {
		var at time.Time
		require.NoError(t, e.pool.QueryRow(context.Background(),
			"select updated_at from telegram_users where telegram_id = 7").Scan(&at))
		return at
	}
	before := updatedAt()

	e.handle(t, start(1, 7, "ann"))

	require.Equal(t, 1, e.count(t, "select count(*) from accounts"))
	require.Equal(t, 1, e.count(t, provisionJobs))
	require.Len(t, e.client.Sent(), 1)
	require.Equal(t, before, updatedAt())
}

func TestRedeliveredUpdateDoesNotUndoANickChange(t *testing.T) {
	e := newEnv(t)
	e.handle(t, start(1, 7, "ann"))
	e.handle(t, message(2, 7, "anna", "hi"))

	e.handle(t, message(2, 7, "anna", "hi"))

	require.Equal(t, "anna", *e.username(t, 7))
}

// Telegram restarts update ids at a random value after a week without updates,
// so a lower id than the stored one can be a new update.
func TestLowerUpdateIDIsANewUpdate(t *testing.T) {
	e := newEnv(t)
	e.handle(t, start(1_000_000, 7, "ann"))

	e.handle(t, start(5, 7, "ann"))

	require.Len(t, e.client.Sent(), 2)
}

func TestConcurrentStartsCreateOneAccount(t *testing.T) {
	e := newEnv(t)

	var group sync.WaitGroup
	errs := make([]error, 8)
	for i := range errs {
		group.Go(func() {
			errs[i] = e.service.HandleUpdate(context.Background(), start(int64(i+1), 7, "ann"))
		})
	}
	group.Wait()

	require.NoError(t, errors.Join(errs...))
	require.Equal(t, 1, e.count(t, "select count(*) from accounts"))
	require.Equal(t, 1, e.count(t, provisionJobs))
}

func TestConcurrentRedeliveriesReplyOnce(t *testing.T) {
	e := newEnv(t)

	var group sync.WaitGroup
	errs := make([]error, 8)
	for i := range errs {
		group.Go(func() {
			errs[i] = e.service.HandleUpdate(context.Background(), start(1, 7, "ann"))
		})
	}
	group.Wait()

	require.NoError(t, errors.Join(errs...))
	require.Len(t, e.client.Sent(), 1)
}

func TestStartWithoutNickAsksToSetOne(t *testing.T) {
	e := newEnv(t)

	e.handle(t, start(1, 7, ""))

	sent := e.client.Sent()
	require.Len(t, sent, 1)
	require.Contains(t, sent[0].Text, "ник")
	require.Contains(t, sent[0].Text, "настройках Telegram")
	require.Equal(t, 1, e.count(t, "select count(*) from accounts"))
	require.Equal(t, 1, e.count(t, provisionJobs))
	require.Nil(t, e.username(t, 7))
}

func TestStartAfterSettingANickGivesTheInstruction(t *testing.T) {
	e := newEnv(t)
	e.handle(t, start(1, 7, ""))

	e.handle(t, start(2, 7, "ann"))

	require.Equal(t, "ann", *e.username(t, 7))
	sent := e.client.Sent()
	require.Len(t, sent, 2)
	require.Contains(t, sent[1].Text, "@ann")
	require.Equal(t, 1, e.count(t, "select count(*) from accounts"))
}

func TestAnyUpdateRefreshesTheUser(t *testing.T) {
	kinds := map[string]tg.Update{
		"message":   message(2, 7, "anna", "hi"),
		"callback":  event(tg.UpdateCallback, 2, 7, "anna"),
		"blocked":   event(tg.UpdateBotBlocked, 2, 7, "anna"),
		"unblocked": event(tg.UpdateBotUnblocked, 2, 7, "anna"),
	}
	for name, update := range kinds {
		t.Run(name, func(t *testing.T) {
			e := newEnv(t)
			e.handle(t, start(1, 7, "ann"))
			update.FirstName = "Anna"
			update.ChatID = 70

			e.handle(t, update)

			require.Equal(t, "anna", *e.username(t, 7))
			var firstName string
			var chatID, lastUpdateID int64
			require.NoError(t, e.pool.QueryRow(context.Background(),
				"select first_name, chat_id, last_update_id from telegram_users where telegram_id = 7",
			).Scan(&firstName, &chatID, &lastUpdateID))
			require.Equal(t, "Anna", firstName)
			require.Equal(t, int64(70), chatID)
			require.Equal(t, int64(2), lastUpdateID)
		})
	}
}

func TestDroppingTheNickClearsIt(t *testing.T) {
	e := newEnv(t)
	e.handle(t, start(1, 7, "ann"))

	e.handle(t, message(2, 7, "", "hi"))

	require.Nil(t, e.username(t, 7))
}

func TestNickMovesToItsNewOwner(t *testing.T) {
	e := newEnv(t)
	e.handle(t, start(1, 7, "ann"))
	e.handle(t, start(2, 8, "bob"))

	e.handle(t, message(3, 8, "ann", "hi"))

	require.Nil(t, e.username(t, 7))
	require.Equal(t, "ann", *e.username(t, 8))
}

func TestNewUserTakesANickFromAnExistingOne(t *testing.T) {
	e := newEnv(t)
	e.handle(t, start(1, 7, "ann"))

	e.handle(t, start(2, 8, "ann"))

	require.Nil(t, e.username(t, 7))
	require.Equal(t, "ann", *e.username(t, 8))
}

func TestNicksAreComparedWithoutCase(t *testing.T) {
	e := newEnv(t)
	_, err := e.pool.Exec(context.Background(), `
		with account as (insert into accounts default values returning id)
		insert into telegram_users (telegram_id, account_id, chat_id, username)
		select 7, id, 7, 'ANN' from account`)
	require.NoError(t, err)

	e.handle(t, start(1, 8, "ann"))

	require.Nil(t, e.username(t, 7))
	require.Equal(t, "ann", *e.username(t, 8))
}

func TestUsersRacingForANickLeaveOneOwner(t *testing.T) {
	e := newEnv(t)
	const users = 8

	var group sync.WaitGroup
	errs := make([]error, users)
	for i := range errs {
		group.Go(func() {
			errs[i] = e.service.HandleUpdate(context.Background(), start(int64(i+1), int64(i+1), "ann"))
		})
	}
	group.Wait()

	require.NoError(t, errors.Join(errs...))
	require.Equal(t, users, e.count(t, "select count(*) from telegram_users"))
	require.Equal(t, 1, e.count(t, "select count(*) from telegram_users where username = 'ann'"))
}

func TestUsersSwappingNicksConcurrently(t *testing.T) {
	e := newEnv(t)
	e.handle(t, start(1, 7, "ann"))
	e.handle(t, start(2, 8, "bob"))

	for round := range int64(20) {
		var group sync.WaitGroup
		var first, second error
		group.Go(func() { first = e.service.HandleUpdate(context.Background(), message(10+2*round, 7, "bob", "hi")) })
		group.Go(func() { second = e.service.HandleUpdate(context.Background(), message(11+2*round, 8, "ann", "hi")) })
		group.Wait()
		require.NoError(t, first)
		require.NoError(t, second)

		group.Go(func() { first = e.service.HandleUpdate(context.Background(), message(1000+2*round, 7, "ann", "hi")) })
		group.Go(func() { second = e.service.HandleUpdate(context.Background(), message(1001+2*round, 8, "bob", "hi")) })
		group.Wait()
		require.NoError(t, first)
		require.NoError(t, second)
	}
}

func TestBotBlockSetsTheMark(t *testing.T) {
	e := newEnv(t)
	e.handle(t, start(1, 7, "ann"))

	e.handle(t, event(tg.UpdateBotBlocked, 2, 7, "ann"))

	require.NotNil(t, e.blockedAt(t, 7))
	require.Len(t, e.client.Sent(), 1, "the bot cannot write to a user who blocked it")
}

func TestBotUnblockClearsTheMark(t *testing.T) {
	e := newEnv(t)
	e.handle(t, start(1, 7, "ann"))
	e.handle(t, event(tg.UpdateBotBlocked, 2, 7, "ann"))

	e.handle(t, event(tg.UpdateBotUnblocked, 3, 7, "ann"))

	require.Nil(t, e.blockedAt(t, 7))
}

func TestAnyMessageClearsTheMark(t *testing.T) {
	e := newEnv(t)
	e.handle(t, start(1, 7, "ann"))
	e.handle(t, event(tg.UpdateBotBlocked, 2, 7, "ann"))

	e.handle(t, message(3, 7, "ann", "hi"))

	require.Nil(t, e.blockedAt(t, 7))
}

func TestCallbackKeepsTheMark(t *testing.T) {
	e := newEnv(t)
	e.handle(t, start(1, 7, "ann"))
	e.handle(t, event(tg.UpdateBotBlocked, 2, 7, "ann"))

	e.handle(t, event(tg.UpdateCallback, 3, 7, "ann"))

	require.NotNil(t, e.blockedAt(t, 7))
}

func TestReplyToABlockedBotSetsTheMark(t *testing.T) {
	e := newEnv(t)
	e.handle(t, start(1, 7, "ann"))
	e.client.FailNext(fake.OpSendMessage, tg.ErrBotBlocked)

	e.handle(t, start(2, 7, "ann"))

	require.NotNil(t, e.blockedAt(t, 7))
}

func TestTelegramOutageKeepsTheAccount(t *testing.T) {
	e := newEnv(t)
	e.client.FailNext(fake.OpSendMessage, tg.ErrUnavailable)

	e.handle(t, start(1, 7, "ann"))

	require.Equal(t, 1, e.count(t, "select count(*) from accounts"))
	require.Equal(t, 1, e.count(t, provisionJobs))
	require.Empty(t, e.client.Sent())
	require.Nil(t, e.blockedAt(t, 7), "an outage says nothing about a block")

	e.handle(t, start(2, 7, "ann"))
	require.Len(t, e.client.Sent(), 1, "the user gets the reply on the next /start")
}

type brokenQueue struct{}

func (brokenQueue) InsertTx(context.Context, pgx.Tx, river.JobArgs, *river.InsertOpts) (*rivertype.JobInsertResult, error) {
	return nil, errors.New("queue is down")
}

func TestFailedJobInsertRollsBackTheAccount(t *testing.T) {
	e := newEnv(t)
	service := NewService(e.pool, e.client, brokenQueue{}, slog.New(slog.DiscardHandler))

	err := service.HandleUpdate(context.Background(), start(1, 7, "ann"))

	require.Error(t, err)
	require.Equal(t, 0, e.count(t, "select count(*) from accounts"))
	require.Equal(t, 0, e.count(t, "select count(*) from telegram_users"))
	require.Empty(t, e.client.Sent())
}

func TestRedeliveryAfterAFailureCreatesTheAccount(t *testing.T) {
	e := newEnv(t)
	broken := NewService(e.pool, e.client, brokenQueue{}, slog.New(slog.DiscardHandler))
	require.Error(t, broken.HandleUpdate(context.Background(), start(1, 7, "ann")))

	e.handle(t, start(1, 7, "ann"))

	require.Equal(t, 1, e.count(t, "select count(*) from accounts"))
	require.Equal(t, 1, e.count(t, provisionJobs))
	require.Len(t, e.client.Sent(), 1)
}

func TestUpdatesFromUnknownUsersAreIgnored(t *testing.T) {
	cases := map[string]tg.Update{
		"message":   message(1, 7, "ann", "hello"),
		"callback":  event(tg.UpdateCallback, 1, 7, "ann"),
		"blocked":   event(tg.UpdateBotBlocked, 1, 7, "ann"),
		"unblocked": event(tg.UpdateBotUnblocked, 1, 7, "ann"),
	}
	for name, update := range cases {
		t.Run(name, func(t *testing.T) {
			e := newEnv(t)

			e.handle(t, update)

			require.Equal(t, 0, e.count(t, "select count(*) from accounts"))
			require.Equal(t, 0, e.count(t, "select count(*) from telegram_users"))
			require.Empty(t, e.client.Sent())
		})
	}
}

func TestOnlyStartGetsAReply(t *testing.T) {
	e := newEnv(t)
	e.handle(t, start(1, 7, "ann"))

	e.handle(t, message(2, 7, "ann", "hello"))
	e.handle(t, event(tg.UpdateCallback, 3, 7, "ann"))

	require.Len(t, e.client.Sent(), 1)
}

func TestStartTextInACallbackIsNotACommand(t *testing.T) {
	e := newEnv(t)
	update := event(tg.UpdateCallback, 1, 7, "ann")
	update.Text = "/start"

	e.handle(t, update)

	require.Equal(t, 0, e.count(t, "select count(*) from accounts"))
}

func TestIsStart(t *testing.T) {
	cases := map[string]bool{
		"/start":              true,
		"/start payload":      true,
		"/start@vpnclientbot": true,
		"/start\npayload":     true,
		"start":               false,
		"/started":            false,
		"/stop":               false,
		" /start":             false,
		"please /start":       false,
		"":                    false,
	}
	for text, want := range cases {
		t.Run(fmt.Sprintf("%q", text), func(t *testing.T) {
			require.Equal(t, want, isStart(text))
		})
	}
}

func TestIsStartNeedsTheWholeCommandWord(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		suffix := rapid.StringMatching(`[a-zA-Z0-9_]{1,16}`).Draw(t, "suffix")
		rest := rapid.String().Draw(t, "rest")
		require.False(t, isStart("/start"+suffix+rest))
		require.True(t, isStart("/start "+rest))
		require.True(t, isStart("/start@"+suffix))
	})
}

func TestCodeMessageNamesTheCodeAndTheDevice(t *testing.T) {
	text := CodeMessage("123456", "Pixel 7")

	require.Contains(t, text, "123456")
	require.Contains(t, text, "Pixel 7")
	require.Contains(t, text, "Если это не вы")
	require.Contains(t, text, "проигнорируйте")
}

func TestCodeMessageWithoutADeviceName(t *testing.T) {
	require.Contains(t, CodeMessage("123456", ""), "неизвестное устройство")
}
