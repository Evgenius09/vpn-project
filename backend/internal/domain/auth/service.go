// Package auth logs devices in with a code from the bot (tech.md 2.2, 5.2).
package auth

import (
	"context"
	"crypto/hmac"
	"errors"
	"fmt"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/riverqueue/river"
	"github.com/riverqueue/river/rivertype"

	"github.com/Evgenius09/vpn-project/backend/internal/db/sqlc"
	"github.com/Evgenius09/vpn-project/backend/internal/gen/api"
	"github.com/Evgenius09/vpn-project/backend/internal/httpapi"
	"github.com/Evgenius09/vpn-project/backend/internal/jobs"
)

// Login errors.
var (
	ErrInvalidInput = errors.New("auth: invalid input")
	ErrUserNotFound = errors.New("auth: telegram user not found")
	ErrCodeExpired  = errors.New("auth: code expired")
	ErrDeviceLimit  = errors.New("auth: device limit reached")
)

// RateLimitedError asks the client to wait.
type RateLimitedError struct{ RetryAfterSec int }

func (e *RateLimitedError) Error() string {
	return fmt.Sprintf("auth: retry after %d s", e.RetryAfterSec)
}

// InvalidCodeError is a wrong code with attempts to spare.
type InvalidCodeError struct{ AttemptsLeft int }

func (e *InvalidCodeError) Error() string {
	return fmt.Sprintf("auth: invalid code, %d attempts left", e.AttemptsLeft)
}

// Queue inserts a job inside the caller's transaction.
type Queue interface {
	InsertTx(ctx context.Context, tx pgx.Tx, args river.JobArgs, opts *river.InsertOpts) (*rivertype.JobInsertResult, error)
}

// Options are the values that come from configuration.
type Options struct {
	Pepper []byte
	BotURL string
	Now    func() time.Time
}

// Service runs the login flow.
type Service struct {
	pool   *pgxpool.Pool
	queue  Queue
	pepper []byte
	botURL string
	now    func() time.Time
}

// NewService returns a service.
func NewService(pool *pgxpool.Pool, queue Queue, options Options) *Service {
	now := options.Now
	if now == nil {
		now = time.Now
	}
	return &Service{pool: pool, queue: queue, pepper: options.Pepper, botURL: options.BotURL, now: now}
}

// StartInput is a request for a code.
type StartInput struct {
	Username  string
	InstallID uuid.UUID
	Model     string
}

// Challenge tells the client how to go on.
type Challenge struct {
	LoginID        uuid.UUID
	ExpiresAt      time.Time
	ResendAfterSec int
	BotURL         string
}

// VerifyInput trades a code for a device token.
type VerifyInput struct {
	LoginID    uuid.UUID
	InstallID  uuid.UUID
	Code       string
	Platform   api.Platform
	Model      string
	AppVersion string
}

// Result is a logged-in device. Token is a secret.
type Result struct {
	DeviceID  uuid.UUID
	AccountID uuid.UUID
	Token     string
}

// Start issues a code and queues its delivery.
func (s *Service) Start(ctx context.Context, input StartInput) (Challenge, error) {
	username, ok := NormalizeUsername(input.Username)
	if !ok {
		return Challenge{}, fmt.Errorf("%w: username", ErrInvalidInput)
	}
	if length := utf8.RuneCountInString(input.Model); length == 0 || length > maxModelLength {
		return Challenge{}, fmt.Errorf("%w: model", ErrInvalidInput)
	}
	code, err := newCode()
	if err != nil {
		return Challenge{}, err
	}

	now := s.now()
	challenge := Challenge{
		ExpiresAt:      now.Add(codeTTL),
		ResendAfterSec: int(resendAfter.Seconds()),
		BotURL:         s.botURL,
	}
	err = pgx.BeginFunc(ctx, s.pool, func(tx pgx.Tx) error {
		store := newStore(tx)
		telegramID, err := store.reachableUser(ctx, username)
		if err != nil {
			return err
		}
		// The lock makes the limit check and the insert one step.
		if err := store.lockUser(ctx, telegramID); err != nil {
			return err
		}
		sent, err := store.recentCodes(ctx, telegramID, now.Add(-time.Hour))
		if err != nil {
			return err
		}
		if wait := retryAfter(sent, now); wait > 0 {
			return &RateLimitedError{RetryAfterSec: wait}
		}
		challenge.LoginID, err = store.replaceCode(ctx, telegramID, input.InstallID, httpapi.HashToken(code, s.pepper), now)
		if err != nil {
			return err
		}
		args := jobs.TelegramSendCodeArgs{LoginID: challenge.LoginID, Code: code, Model: cleanModel(input.Model)}
		if _, err := s.queue.InsertTx(ctx, tx, args, nil); err != nil {
			return fmt.Errorf("queue code: %w", err)
		}
		return nil
	})
	if err != nil {
		return Challenge{}, fmt.Errorf("start login: %w", err)
	}
	return challenge, nil
}

// Verify trades a code for a device token.
func (s *Service) Verify(ctx context.Context, input VerifyInput) (Result, error) {
	if err := validateDevice(input); err != nil {
		return Result{}, err
	}
	var result Result
	var refusal error
	err := pgx.BeginFunc(ctx, s.pool, func(tx pgx.Tx) error {
		var err error
		result, refusal, err = s.verify(ctx, newStore(tx), input)
		return err
	})
	if err != nil {
		return Result{}, fmt.Errorf("verify login: %w", err)
	}
	if refusal != nil {
		return Result{}, refusal
	}
	return result, nil
}

// verify returns a refusal apart from a failure, because a refusal must commit:
// a spent attempt that rolled back would allow unlimited guesses.
func (s *Service) verify(ctx context.Context, store store, input VerifyInput) (result Result, refusal, err error) {
	login, err := store.loginForUpdate(ctx, input.LoginID)
	if errors.Is(err, errLoginNotFound) {
		return Result{}, ErrCodeExpired, nil
	}
	if err != nil {
		return Result{}, nil, err
	}
	now := s.now()
	if !usable(login, input.InstallID, now) {
		return Result{}, ErrCodeExpired, nil
	}
	if !hmac.Equal(httpapi.HashToken(input.Code, s.pepper), login.CodeHash) {
		refusal, err := spendAttempt(ctx, store, input.LoginID, login.Attempts)
		return Result{}, refusal, err
	}

	token, err := newToken()
	if err != nil {
		return Result{}, nil, err
	}
	deviceID, err := store.bindDevice(ctx, login.AccountID, input, httpapi.HashToken(token, s.pepper))
	if errors.Is(err, ErrDeviceLimit) {
		return Result{}, ErrDeviceLimit, nil
	}
	if err != nil {
		return Result{}, nil, err
	}
	if err := store.consumeCode(ctx, input.LoginID, now); err != nil {
		return Result{}, nil, err
	}
	return Result{DeviceID: deviceID, AccountID: login.AccountID, Token: token}, nil, nil
}

// Logout revokes a device.
func (s *Service) Logout(ctx context.Context, deviceID uuid.UUID) error {
	if err := sqlc.New(s.pool).RevokeDevice(ctx, deviceID); err != nil {
		return fmt.Errorf("revoke device: %w", err)
	}
	return nil
}

func validateDevice(input VerifyInput) error {
	version := utf8.RuneCountInString(input.AppVersion)
	switch {
	case !input.Platform.Valid():
		return fmt.Errorf("%w: platform", ErrInvalidInput)
	case utf8.RuneCountInString(input.Model) > maxModelLength:
		return fmt.Errorf("%w: model", ErrInvalidInput)
	case version == 0 || version > maxVersionLength:
		return fmt.Errorf("%w: app version", ErrInvalidInput)
	}
	return nil
}

func usable(login sqlc.GetLoginCodeForUpdateRow, installID uuid.UUID, now time.Time) bool {
	return login.InstallID == installID &&
		login.ConsumedAt == nil &&
		login.InvalidatedAt == nil &&
		now.Before(login.ExpiresAt) &&
		login.Attempts < maxAttempts
}

func spendAttempt(ctx context.Context, store store, loginID uuid.UUID, attempts int32) (refusal, err error) {
	attempts++
	if err := store.setAttempts(ctx, loginID, attempts); err != nil {
		return nil, err
	}
	if attempts >= maxAttempts {
		return ErrCodeExpired, nil
	}
	return &InvalidCodeError{AttemptsLeft: maxAttempts - int(attempts)}, nil
}
