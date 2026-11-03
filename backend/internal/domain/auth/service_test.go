package auth

import (
	"context"
	"errors"
	"log/slog"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/riverqueue/river"
	"github.com/riverqueue/river/rivertype"
	"github.com/stretchr/testify/require"

	"github.com/Evgenius09/vpn-project/backend/internal/gen/api"
	"github.com/Evgenius09/vpn-project/backend/internal/httpapi"
	"github.com/Evgenius09/vpn-project/backend/internal/jobs"
	"github.com/Evgenius09/vpn-project/backend/internal/seed"
	"github.com/Evgenius09/vpn-project/backend/internal/testutil"
)

const (
	seedPath = "../../../" + seed.DefaultPath
	botURL   = "https://t.me/vpnclient_dev_bot"
)

var pepper = []byte("test-pepper")

type clock struct {
	mu  sync.Mutex
	now time.Time
}

func (c *clock) Now() time.Time {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.now
}

func (c *clock) advance(d time.Duration) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.now = c.now.Add(d)
}

type env struct {
	pool    *pgxpool.Pool
	data    seed.Data
	clock   *clock
	queue   Queue
	service *Service
}

func newEnv(t *testing.T) *env {
	t.Helper()
	ctx := context.Background()
	pool := testutil.NewDatabase(t)
	data, err := seed.Load(seedPath)
	require.NoError(t, err)
	require.NoError(t, seed.Apply(ctx, pool, data, pepper))

	queue, err := jobs.NewClient(pool, jobs.Options{Logger: slog.New(slog.DiscardHandler)})
	require.NoError(t, err)
	now := &clock{now: time.Now().UTC().Truncate(time.Microsecond)}
	return &env{
		pool: pool, data: data, clock: now, queue: queue,
		service: NewService(pool, queue, Options{Pepper: pepper, BotURL: botURL, Now: now.Now}),
	}
}

func (e *env) start(t *testing.T, installID uuid.UUID) Challenge {
	t.Helper()
	challenge, err := e.service.Start(context.Background(), StartInput{
		Username: "seed_user", InstallID: installID, Model: "Pixel 7",
	})
	require.NoError(t, err)
	return challenge
}

// code reads the plain code from the job row, the only place that holds it.
func (e *env) code(t *testing.T, loginID uuid.UUID) string {
	t.Helper()
	var code string
	require.NoError(t, e.pool.QueryRow(context.Background(),
		"select args->>'code' from river_job where kind = $1 and args->>'loginId' = $2",
		jobs.KindTelegramSendCode, loginID.String()).Scan(&code))
	return code
}

func verifyInput(loginID, installID uuid.UUID, code string) VerifyInput {
	return VerifyInput{
		LoginID: loginID, InstallID: installID, Code: code,
		Platform: api.PlatformAndroid, Model: "Pixel 7", AppVersion: "1.2.3",
	}
}

func (e *env) login(t *testing.T, installID uuid.UUID) Result {
	t.Helper()
	challenge := e.start(t, installID)
	result, err := e.service.Verify(context.Background(), verifyInput(challenge.LoginID, installID, e.code(t, challenge.LoginID)))
	require.NoError(t, err)
	e.clock.advance(time.Hour)
	return result
}

func (e *env) count(t *testing.T, query string, args ...any) int {
	t.Helper()
	var n int
	require.NoError(t, e.pool.QueryRow(context.Background(), query, args...).Scan(&n))
	return n
}

func (e *env) setDeviceLimit(t *testing.T, limit int) {
	t.Helper()
	_, err := e.pool.Exec(context.Background(), "update accounts set device_limit = $1", limit)
	require.NoError(t, err)
}

// addAccount adds a second bot user and returns the id of its account.
func (e *env) addAccount(t *testing.T, telegramID int64, username string) uuid.UUID {
	t.Helper()
	var accountID uuid.UUID
	require.NoError(t, e.pool.QueryRow(context.Background(), "insert into accounts default values returning id").Scan(&accountID))
	_, err := e.pool.Exec(context.Background(),
		"insert into telegram_users (telegram_id, account_id, chat_id, username) values ($1, $2, $1, $3)",
		telegramID, accountID, username)
	require.NoError(t, err)
	return accountID
}

// race runs fn from n goroutines released together, over connections that
// already exist, so the transactions overlap instead of running in turn.
func (e *env) race(t *testing.T, n int, fn func(i int) error) []error {
	t.Helper()
	conns := make([]*pgxpool.Conn, 0, n)
	for range min(n, int(e.pool.Config().MaxConns)) {
		conn, err := e.pool.Acquire(context.Background())
		require.NoError(t, err)
		conns = append(conns, conn)
	}
	for _, conn := range conns {
		conn.Release()
	}

	gate := make(chan struct{})
	var group sync.WaitGroup
	errs := make([]error, n)
	for i := range errs {
		group.Go(func() {
			<-gate
			errs[i] = fn(i)
		})
	}
	close(gate)
	group.Wait()
	return errs
}

func requireRetryAfter(t *testing.T, err error, seconds int) {
	t.Helper()
	var limited *RateLimitedError
	require.ErrorAs(t, err, &limited)
	require.Equal(t, seconds, limited.RetryAfterSec)
}

func TestStartCreatesAChallenge(t *testing.T) {
	e := newEnv(t)
	installID := uuid.New()

	challenge := e.start(t, installID)

	require.NotEqual(t, uuid.Nil, challenge.LoginID)
	require.WithinDuration(t, e.clock.Now().Add(5*time.Minute), challenge.ExpiresAt, 0)
	require.Equal(t, 60, challenge.ResendAfterSec)
	require.Equal(t, botURL, challenge.BotURL)

	var telegramID int64
	var storedInstall uuid.UUID
	var hash []byte
	require.NoError(t, e.pool.QueryRow(context.Background(),
		"select telegram_id, install_id, code_hash from login_codes where id = $1", challenge.LoginID,
	).Scan(&telegramID, &storedInstall, &hash))
	require.Equal(t, e.data.TelegramUser.TelegramID, telegramID)
	require.Equal(t, installID, storedInstall)
	require.Equal(t, httpapi.HashToken(e.code(t, challenge.LoginID), pepper), hash, "the code is stored as an HMAC")
}

func TestStartQueuesTheCleanedModel(t *testing.T) {
	e := newEnv(t)

	challenge, err := e.service.Start(context.Background(), StartInput{
		Username: "seed_user", InstallID: uuid.New(), Model: "see https://evil.example",
	})

	require.NoError(t, err)
	var model string
	require.NoError(t, e.pool.QueryRow(context.Background(),
		"select args->>'model' from river_job where args->>'loginId' = $1", challenge.LoginID.String()).Scan(&model))
	require.Equal(t, "see https evil example", model)
}

func TestStartAcceptsEveryFormOfANick(t *testing.T) {
	for _, nick := range []string{"seed_user", "@seed_user", "SEED_USER", "@Seed_User"} {
		t.Run(nick, func(t *testing.T) {
			e := newEnv(t)

			_, err := e.service.Start(context.Background(), StartInput{Username: nick, InstallID: uuid.New(), Model: "Pixel 7"})

			require.NoError(t, err)
		})
	}
}

func TestStartRejectsBadInput(t *testing.T) {
	e := newEnv(t)
	cases := map[string]struct {
		input StartInput
		want  error
	}{
		"bad nick":   {StartInput{Username: "a b", InstallID: uuid.New(), Model: "x"}, ErrInvalidInput},
		"no model":   {StartInput{Username: "seed_user", InstallID: uuid.New()}, ErrInvalidInput},
		"long model": {StartInput{Username: "seed_user", InstallID: uuid.New(), Model: strings.Repeat("я", 65)}, ErrInvalidInput},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			_, err := e.service.Start(context.Background(), tc.input)
			require.ErrorIs(t, err, tc.want)
		})
	}
	require.Equal(t, 0, e.count(t, "select count(*) from login_codes"))
}

func TestStartAcceptsAModelAtTheLimit(t *testing.T) {
	e := newEnv(t)

	_, err := e.service.Start(context.Background(), StartInput{
		Username: "seed_user", InstallID: uuid.New(), Model: strings.Repeat("я", 64),
	})

	require.NoError(t, err)
}

func TestStartUnknownNick(t *testing.T) {
	e := newEnv(t)

	_, err := e.service.Start(context.Background(), StartInput{Username: "nobody", InstallID: uuid.New(), Model: "x"})

	require.ErrorIs(t, err, ErrUserNotFound)
}

func TestStartForAUserWhoBlockedTheBot(t *testing.T) {
	e := newEnv(t)
	_, err := e.pool.Exec(context.Background(), "update telegram_users set bot_blocked_at = now()")
	require.NoError(t, err)

	_, err = e.service.Start(context.Background(), StartInput{Username: "seed_user", InstallID: uuid.New(), Model: "x"})

	require.ErrorIs(t, err, ErrUserNotFound)
	require.Equal(t, 0, e.count(t, "select count(*) from login_codes"))
}

func TestResendWaitsForTheCooldown(t *testing.T) {
	e := newEnv(t)
	installID := uuid.New()
	e.start(t, installID)
	input := StartInput{Username: "seed_user", InstallID: installID, Model: "Pixel 7"}

	_, err := e.service.Start(context.Background(), input)
	requireRetryAfter(t, err, 60)

	e.clock.advance(45 * time.Second)
	_, err = e.service.Start(context.Background(), input)
	requireRetryAfter(t, err, 15)

	e.clock.advance(15 * time.Second)
	_, err = e.service.Start(context.Background(), input)
	require.NoError(t, err)
}

func TestCooldownCoversEveryInstall(t *testing.T) {
	e := newEnv(t)
	e.start(t, uuid.New())

	_, err := e.service.Start(context.Background(), StartInput{Username: "seed_user", InstallID: uuid.New(), Model: "x"})

	requireRetryAfter(t, err, 60)
}

func TestFiveCodesPerHour(t *testing.T) {
	e := newEnv(t)
	for range 5 {
		e.start(t, uuid.New())
		e.clock.advance(time.Minute)
	}
	input := StartInput{Username: "seed_user", InstallID: uuid.New(), Model: "x"}

	_, err := e.service.Start(context.Background(), input)
	requireRetryAfter(t, err, 3300)

	e.clock.advance(55 * time.Minute)
	_, err = e.service.Start(context.Background(), input)
	require.NoError(t, err)
}

func TestRateLimitedStartLeavesThePreviousCodeValid(t *testing.T) {
	e := newEnv(t)
	installID := uuid.New()
	challenge := e.start(t, installID)

	_, err := e.service.Start(context.Background(), StartInput{Username: "seed_user", InstallID: installID, Model: "x"})
	require.Error(t, err)

	_, err = e.service.Verify(context.Background(), verifyInput(challenge.LoginID, installID, e.code(t, challenge.LoginID)))
	require.NoError(t, err)
}

func TestNewStartInvalidatesTheOldCode(t *testing.T) {
	e := newEnv(t)
	installID := uuid.New()
	first := e.start(t, installID)
	e.clock.advance(time.Minute)
	second := e.start(t, installID)

	_, err := e.service.Verify(context.Background(), verifyInput(first.LoginID, installID, e.code(t, first.LoginID)))
	require.ErrorIs(t, err, ErrCodeExpired)

	_, err = e.service.Verify(context.Background(), verifyInput(second.LoginID, installID, e.code(t, second.LoginID)))
	require.NoError(t, err)
}

func TestNewStartKeepsTheCodeOfAnotherInstall(t *testing.T) {
	e := newEnv(t)
	firstInstall := uuid.New()
	first := e.start(t, firstInstall)
	e.clock.advance(time.Minute)
	e.start(t, uuid.New())

	_, err := e.service.Verify(context.Background(), verifyInput(first.LoginID, firstInstall, e.code(t, first.LoginID)))

	require.NoError(t, err)
}

type brokenQueue struct{}

func (brokenQueue) InsertTx(context.Context, pgx.Tx, river.JobArgs, *river.InsertOpts) (*rivertype.JobInsertResult, error) {
	return nil, errors.New("queue is down")
}

func TestStartRollsBackWhenTheQueueFails(t *testing.T) {
	e := newEnv(t)
	service := NewService(e.pool, brokenQueue{}, Options{Pepper: pepper, BotURL: botURL, Now: e.clock.Now})

	_, err := service.Start(context.Background(), StartInput{Username: "seed_user", InstallID: uuid.New(), Model: "x"})

	require.Error(t, err)
	require.Equal(t, 0, e.count(t, "select count(*) from login_codes"))
}

func TestConcurrentStartsSendOneCode(t *testing.T) {
	e := newEnv(t)

	for round := 1; round <= 10; round++ {
		errs := e.race(t, 4, func(int) error {
			_, err := e.service.Start(context.Background(), StartInput{Username: "seed_user", InstallID: uuid.New(), Model: "x"})
			return err
		})

		require.Equal(t, round, e.count(t, "select count(*) from login_codes"))
		var limited *RateLimitedError
		failures := 0
		for _, err := range errs {
			if err != nil {
				require.ErrorAs(t, err, &limited)
				failures++
			}
		}
		require.Equal(t, 3, failures)
		e.clock.advance(time.Hour)
	}
}

func TestVerifyCreatesADevice(t *testing.T) {
	e := newEnv(t)
	installID := uuid.New()
	challenge := e.start(t, installID)

	result, err := e.service.Verify(context.Background(), verifyInput(challenge.LoginID, installID, e.code(t, challenge.LoginID)))

	require.NoError(t, err)
	require.Equal(t, e.data.Account.ID, result.AccountID)
	require.Regexp(t, `^[A-Za-z0-9_-]{43}$`, result.Token)

	var account uuid.UUID
	var platform, model, version string
	var hash []byte
	var revokedAt *time.Time
	require.NoError(t, e.pool.QueryRow(context.Background(),
		"select account_id, platform::text, model, app_version, token_hash, revoked_at from devices where id = $1",
		result.DeviceID).Scan(&account, &platform, &model, &version, &hash, &revokedAt))
	require.Equal(t, e.data.Account.ID, account)
	require.Equal(t, "android", platform)
	require.Equal(t, "Pixel 7", model)
	require.Equal(t, "1.2.3", version)
	require.Equal(t, httpapi.HashToken(result.Token, pepper), hash, "the token is stored as an HMAC")
	require.Nil(t, revokedAt)
	require.Equal(t, 1, e.count(t, "select count(*) from login_codes where consumed_at is not null"))
}

func TestWrongCodeCountsDownAttempts(t *testing.T) {
	e := newEnv(t)
	installID := uuid.New()
	challenge := e.start(t, installID)
	wrong := wrongCode(e.code(t, challenge.LoginID))

	for left := 4; left >= 1; left-- {
		_, err := e.service.Verify(context.Background(), verifyInput(challenge.LoginID, installID, wrong))
		var invalid *InvalidCodeError
		require.ErrorAs(t, err, &invalid)
		require.Equal(t, left, invalid.AttemptsLeft)
	}
}

func TestGuessingEndsInExpiry(t *testing.T) {
	e := newEnv(t)
	installID := uuid.New()
	challenge := e.start(t, installID)
	code := e.code(t, challenge.LoginID)
	for range 4 {
		_, err := e.service.Verify(context.Background(), verifyInput(challenge.LoginID, installID, wrongCode(code)))
		require.Error(t, err)
	}

	_, err := e.service.Verify(context.Background(), verifyInput(challenge.LoginID, installID, wrongCode(code)))
	require.ErrorIs(t, err, ErrCodeExpired)

	_, err = e.service.Verify(context.Background(), verifyInput(challenge.LoginID, installID, code))
	require.ErrorIs(t, err, ErrCodeExpired, "the right code no longer works")
	require.Equal(t, 5, e.count(t, "select attempts from login_codes"))
}

func wrongCode(code string) string {
	if code == "000000" {
		return "000001"
	}
	return "000000"
}

func TestCodeLivesFiveMinutes(t *testing.T) {
	e := newEnv(t)
	installID := uuid.New()
	challenge := e.start(t, installID)
	code := e.code(t, challenge.LoginID)

	e.clock.advance(5 * time.Minute)
	_, err := e.service.Verify(context.Background(), verifyInput(challenge.LoginID, installID, code))
	require.ErrorIs(t, err, ErrCodeExpired)
}

func TestCodeWorksUntilItExpires(t *testing.T) {
	e := newEnv(t)
	installID := uuid.New()
	challenge := e.start(t, installID)

	e.clock.advance(5*time.Minute - time.Second)
	_, err := e.service.Verify(context.Background(), verifyInput(challenge.LoginID, installID, e.code(t, challenge.LoginID)))

	require.NoError(t, err)
}

func TestCodeWorksOnce(t *testing.T) {
	e := newEnv(t)
	installID := uuid.New()
	challenge := e.start(t, installID)
	input := verifyInput(challenge.LoginID, installID, e.code(t, challenge.LoginID))
	_, err := e.service.Verify(context.Background(), input)
	require.NoError(t, err)

	_, err = e.service.Verify(context.Background(), input)

	require.ErrorIs(t, err, ErrCodeExpired)
}

func TestRacingVerifiesGiveOneSuccess(t *testing.T) {
	e := newEnv(t)
	e.setDeviceLimit(t, 10) // Each round adds a device.
	for range 5 {
		installID := uuid.New()
		challenge := e.start(t, installID)
		input := verifyInput(challenge.LoginID, installID, e.code(t, challenge.LoginID))

		errs := e.race(t, 4, func(int) error {
			_, err := e.service.Verify(context.Background(), input)
			return err
		})

		successes := 0
		for _, err := range errs {
			if err == nil {
				successes++
				continue
			}
			require.ErrorIs(t, err, ErrCodeExpired)
		}
		require.Equal(t, 1, successes)
		require.Equal(t, 1, e.count(t, "select count(*) from devices where install_id = $1", installID))
		e.clock.advance(time.Hour)
	}
}

func TestRacingGuessesCannotExceedTheAttempts(t *testing.T) {
	e := newEnv(t)
	installID := uuid.New()
	challenge := e.start(t, installID)
	wrong := wrongCode(e.code(t, challenge.LoginID))

	e.race(t, 12, func(int) error {
		_, err := e.service.Verify(context.Background(), verifyInput(challenge.LoginID, installID, wrong))
		return err
	})

	require.Equal(t, 5, e.count(t, "select attempts from login_codes"))
}

func TestUnknownLoginExpires(t *testing.T) {
	e := newEnv(t)

	_, err := e.service.Verify(context.Background(), verifyInput(uuid.New(), uuid.New(), "123456"))

	require.ErrorIs(t, err, ErrCodeExpired)
}

func TestForeignInstallSpendsNoAttempt(t *testing.T) {
	e := newEnv(t)
	installID := uuid.New()
	challenge := e.start(t, installID)
	code := e.code(t, challenge.LoginID)

	_, err := e.service.Verify(context.Background(), verifyInput(challenge.LoginID, uuid.New(), code))

	require.ErrorIs(t, err, ErrCodeExpired)
	require.Equal(t, 0, e.count(t, "select attempts from login_codes"))
	require.Equal(t, 0, e.count(t, "select count(*) from login_codes where consumed_at is not null"))
}

func TestVerifyRejectsBadInput(t *testing.T) {
	e := newEnv(t)
	installID := uuid.New()
	challenge := e.start(t, installID)
	code := e.code(t, challenge.LoginID)
	cases := map[string]func(*VerifyInput){
		"unknown platform": func(i *VerifyInput) { i.Platform = "ios" },
		"long model":       func(i *VerifyInput) { i.Model = strings.Repeat("x", 65) },
		"no version":       func(i *VerifyInput) { i.AppVersion = "" },
		"long version":     func(i *VerifyInput) { i.AppVersion = strings.Repeat("1", 65) },
	}
	for name, change := range cases {
		t.Run(name, func(t *testing.T) {
			input := verifyInput(challenge.LoginID, installID, code)
			change(&input)

			_, err := e.service.Verify(context.Background(), input)

			require.ErrorIs(t, err, ErrInvalidInput)
		})
	}
	require.Equal(t, 0, e.count(t, "select count(*) from login_codes where consumed_at is not null"), "bad input spends no code")
}

func TestLoginOnAKnownInstallKeepsTheDevice(t *testing.T) {
	e := newEnv(t)
	installID := uuid.New()
	first := e.login(t, installID)

	second := e.login(t, installID)

	require.Equal(t, first.DeviceID, second.DeviceID)
	require.NotEqual(t, first.Token, second.Token)
	var hash []byte
	require.NoError(t, e.pool.QueryRow(context.Background(), "select token_hash from devices where id = $1", first.DeviceID).Scan(&hash))
	require.Equal(t, httpapi.HashToken(second.Token, pepper), hash, "the old token stops working")
}

func TestLoginOnARevokedDeviceRestoresIt(t *testing.T) {
	e := newEnv(t)
	installID := uuid.New()
	first := e.login(t, installID)
	require.NoError(t, e.service.Logout(context.Background(), first.DeviceID))

	second := e.login(t, installID)

	require.Equal(t, first.DeviceID, second.DeviceID)
	require.Equal(t, 0, e.count(t, "select count(*) from devices where id = $1 and revoked_at is not null", first.DeviceID))
}

func TestRevokedDeviceCannotComeBackOverTheLimit(t *testing.T) {
	e := newEnv(t)
	installID := uuid.New()
	first := e.login(t, installID)
	require.NoError(t, e.service.Logout(context.Background(), first.DeviceID))
	e.setDeviceLimit(t, 1) // The seed device holds the only slot.
	challenge := e.start(t, installID)

	_, err := e.service.Verify(context.Background(), verifyInput(challenge.LoginID, installID, e.code(t, challenge.LoginID)))

	require.ErrorIs(t, err, ErrDeviceLimit)
	require.Equal(t, 1, e.count(t, "select count(*) from devices where id = $1 and revoked_at is not null", first.DeviceID))
}

func TestActiveDeviceLogsInAtTheLimit(t *testing.T) {
	e := newEnv(t)
	installID := uuid.New()
	first := e.login(t, installID)
	e.setDeviceLimit(t, 2)

	second := e.login(t, installID)

	require.Equal(t, first.DeviceID, second.DeviceID)
}

func TestLoginMovesAnInstallToAnotherAccount(t *testing.T) {
	e := newEnv(t)
	installID := uuid.New()
	first := e.login(t, installID)
	other := e.addAccount(t, 2000002, "other_user")

	challenge, err := e.service.Start(context.Background(), StartInput{Username: "other_user", InstallID: installID, Model: "x"})
	require.NoError(t, err)
	second, err := e.service.Verify(context.Background(), verifyInput(challenge.LoginID, installID, e.code(t, challenge.LoginID)))

	require.NoError(t, err)
	require.Equal(t, first.DeviceID, second.DeviceID)
	require.Equal(t, other, second.AccountID)
	require.Equal(t, 1, e.count(t, "select count(*) from devices where id = $1 and account_id = $2 and revoked_at is null", first.DeviceID, other))
}

func TestMoveRespectsTheLimitOfTheNewAccount(t *testing.T) {
	e := newEnv(t)
	installID := uuid.New()
	first := e.login(t, installID)
	e.addAccount(t, 2000002, "other_user")
	_, err := e.pool.Exec(context.Background(), `update accounts set device_limit = 0 where id <> $1`, e.data.Account.ID)
	require.NoError(t, err)

	challenge, err := e.service.Start(context.Background(), StartInput{Username: "other_user", InstallID: installID, Model: "x"})
	require.NoError(t, err)
	_, err = e.service.Verify(context.Background(), verifyInput(challenge.LoginID, installID, e.code(t, challenge.LoginID)))

	require.ErrorIs(t, err, ErrDeviceLimit)
	require.Equal(t, 1, e.count(t, "select count(*) from devices where id = $1 and account_id = $2", first.DeviceID, e.data.Account.ID))
}

func TestDeviceLimitKeepsTheCode(t *testing.T) {
	e := newEnv(t)
	e.setDeviceLimit(t, 1) // The seed device holds the only slot.
	installID := uuid.New()
	challenge := e.start(t, installID)
	input := verifyInput(challenge.LoginID, installID, e.code(t, challenge.LoginID))

	_, err := e.service.Verify(context.Background(), input)
	require.ErrorIs(t, err, ErrDeviceLimit)
	require.Equal(t, 0, e.count(t, "select count(*) from login_codes where consumed_at is not null"))

	require.NoError(t, e.service.Logout(context.Background(), e.data.Device.ID))
	_, err = e.service.Verify(context.Background(), input)
	require.NoError(t, err, "the user frees a slot and retries the same code")
}

func TestRacingNewDevicesRespectTheLimit(t *testing.T) {
	e := newEnv(t)
	const installs = 4
	for round := range 5 {
		inputs := make([]VerifyInput, installs)
		for i := range inputs {
			installID := uuid.New()
			challenge := e.start(t, installID)
			inputs[i] = verifyInput(challenge.LoginID, installID, e.code(t, challenge.LoginID))
			e.clock.advance(time.Minute) // The cooldown, well inside the code lifetime.
		}
		// One slot left next to the seed device and the winners of earlier rounds.
		e.setDeviceLimit(t, round+2)

		errs := e.race(t, installs, func(i int) error {
			_, err := e.service.Verify(context.Background(), inputs[i])
			return err
		})

		require.Equal(t, round+2, e.count(t, "select count(*) from devices where revoked_at is null"))
		for _, err := range errs {
			if err != nil {
				require.ErrorIs(t, err, ErrDeviceLimit)
			}
		}
		e.clock.advance(time.Hour) // Clears the hourly code limit for the next round.
	}
}

func TestLogoutRevokesTheDevice(t *testing.T) {
	e := newEnv(t)

	require.NoError(t, e.service.Logout(context.Background(), e.data.Device.ID))

	require.Equal(t, 1, e.count(t, "select count(*) from devices where id = $1 and revoked_at is not null", e.data.Device.ID))
}
