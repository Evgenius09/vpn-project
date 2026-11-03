// Package jobs is the River client and the registry of job kinds (tech.md 7).
// Handlers live in their domains, except the skeleton demo_echo.
package jobs

import (
	"log/slog"

	"github.com/google/uuid"
	"github.com/riverqueue/river"
	"github.com/riverqueue/river/rivertype"
)

// Job kinds.
const (
	KindPanelProvisionUser = "panel_provision_user"
	KindTelegramSendCode   = "telegram_send_code"
	KindPanelSyncUser      = "panel_sync_user"
	KindCatalogSync        = "catalog_sync"
	KindAccountExpire      = "account_expire"
	KindDemoEcho           = "demo_echo"
)

// inFlightStates dedupes only unfinished jobs, so a later change to the same
// account can still schedule a new sync.
var inFlightStates = []rivertype.JobState{
	rivertype.JobStateAvailable,
	rivertype.JobStatePending,
	rivertype.JobStateRetryable,
	rivertype.JobStateRunning,
	rivertype.JobStateScheduled,
}

// PanelProvisionUserArgs creates the panel user of an account.
type PanelProvisionUserArgs struct {
	AccountID uuid.UUID `json:"accountId" river:"unique"`
}

// Kind implements river.JobArgs.
func (PanelProvisionUserArgs) Kind() string { return KindPanelProvisionUser }

// InsertOpts implements river.JobArgsWithInsertOpts.
func (PanelProvisionUserArgs) InsertOpts() river.InsertOpts {
	return river.InsertOpts{MaxAttempts: 10, UniqueOpts: river.UniqueOpts{ByArgs: true}}
}

// TelegramSendCodeArgs sends a login code. Code is a secret: it stays in the
// job row until retention removes it and never reaches the logs. Model is the
// cleaned device model for the message.
type TelegramSendCodeArgs struct {
	LoginID uuid.UUID `json:"loginId"`
	Code    string    `json:"code"`
	Model   string    `json:"model"`
}

// Kind implements river.JobArgs.
func (TelegramSendCodeArgs) Kind() string { return KindTelegramSendCode }

// InsertOpts implements river.JobArgsWithInsertOpts.
func (TelegramSendCodeArgs) InsertOpts() river.InsertOpts {
	return river.InsertOpts{MaxAttempts: 3}
}

// LogValue masks the code.
func (a TelegramSendCodeArgs) LogValue() slog.Value {
	return slog.GroupValue(slog.String("loginId", a.LoginID.String()), slog.String("code", "***"))
}

// PanelSyncUserArgs pushes absolute expiry and limit values to the panel.
type PanelSyncUserArgs struct {
	AccountID uuid.UUID `json:"accountId" river:"unique"`
	Reason    string    `json:"reason" river:"unique"`
}

// Kind implements river.JobArgs.
func (PanelSyncUserArgs) Kind() string { return KindPanelSyncUser }

// InsertOpts implements river.JobArgsWithInsertOpts.
func (PanelSyncUserArgs) InsertOpts() river.InsertOpts {
	return river.InsertOpts{
		MaxAttempts: 10,
		UniqueOpts:  river.UniqueOpts{ByArgs: true, ByState: inFlightStates},
	}
}

// CatalogSyncArgs refreshes the servers table.
type CatalogSyncArgs struct{}

// Kind implements river.JobArgs.
func (CatalogSyncArgs) Kind() string { return KindCatalogSync }

// InsertOpts implements river.JobArgsWithInsertOpts.
func (CatalogSyncArgs) InsertOpts() river.InsertOpts {
	return river.InsertOpts{MaxAttempts: 3}
}

// AccountExpireArgs expires overdue accounts.
type AccountExpireArgs struct{}

// Kind implements river.JobArgs.
func (AccountExpireArgs) Kind() string { return KindAccountExpire }

// InsertOpts implements river.JobArgsWithInsertOpts.
func (AccountExpireArgs) InsertOpts() river.InsertOpts {
	return river.InsertOpts{MaxAttempts: 3}
}

// DemoEchoArgs proves the queue works in the skeleton.
type DemoEchoArgs struct {
	Message string `json:"message"`
}

// Kind implements river.JobArgs.
func (DemoEchoArgs) Kind() string { return KindDemoEcho }

// InsertOpts implements river.JobArgsWithInsertOpts.
func (DemoEchoArgs) InsertOpts() river.InsertOpts {
	return river.InsertOpts{MaxAttempts: 1}
}
