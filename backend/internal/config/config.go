// Package config reads the environment into a validated Config (tech.md 9).
package config

import (
	"errors"
	"fmt"
	"log/slog"
	"slices"
	"strconv"
	"strings"

	"github.com/google/uuid"
)

// App environments.
const (
	EnvDev     = "dev"
	EnvStaging = "staging"
	EnvProd    = "prod"
)

// Panel client modes.
const (
	PanelFake      = "fake"
	PanelRemnawave = "remnawave"
)

// Telegram client modes.
const (
	TelegramFake    = "fake"
	TelegramPolling = "polling"
	TelegramWebhook = "webhook"
)

const (
	defaultPepper = "change-me-32-bytes-min"
	minPepperLen  = 32
)

// Config holds the backend settings.
type Config struct {
	AppEnv                string
	HTTPAddr              string
	MetricsAddr           string
	LogLevel              string
	DatabaseURL           string
	PanelMode             string
	RemnawaveBaseURL      string
	RemnawaveAPIToken     string
	RemnawaveSquadUUID    string
	TelegramMode          string
	TelegramBotToken      string
	TelegramBotUsername   string
	TelegramWebhookSecret string
	CatalogFile           string
	PolicyFile            string
	TokenPepper           string
	TrialDays             int
	AuthRatePerMin        int
	PublicAPIURLs         []string
	SupportURL            string
	WebURL                string
}

// BotURL is the link to the bot. Dev runs without a real bot.
func (c Config) BotURL() string {
	username := c.TelegramBotUsername
	if username == "" {
		username = "vpnclient_dev_bot"
	}
	return "https://t.me/" + username
}

// String keeps secrets out of fmt verbs.
func (c Config) String() string {
	return fmt.Sprintf("Config{env=%s panel=%s telegram=%s}", c.AppEnv, c.PanelMode, c.TelegramMode)
}

// GoString keeps secrets out of the %#v verb.
func (c Config) GoString() string {
	return c.String()
}

// LogValue keeps secrets out of structured logs.
func (c Config) LogValue() slog.Value {
	return slog.GroupValue(
		slog.String("appEnv", c.AppEnv),
		slog.String("httpAddr", c.HTTPAddr),
		slog.String("panelMode", c.PanelMode),
		slog.String("telegramMode", c.TelegramMode),
	)
}

// Load reads settings through lookup, normally os.Getenv.
func Load(lookup func(string) string) (Config, error) {
	get := func(key, fallback string) string {
		if value := lookup(key); value != "" {
			return value
		}
		return fallback
	}

	var errs []error
	number := func(key string, fallback int) int {
		raw := get(key, strconv.Itoa(fallback))
		value, err := strconv.Atoi(raw)
		if err != nil || value <= 0 {
			errs = append(errs, fmt.Errorf("%s must be a positive integer", key))
		}
		return value
	}

	cfg := Config{
		AppEnv:                get("APP_ENV", EnvDev),
		HTTPAddr:              get("HTTP_ADDR", ":8080"),
		MetricsAddr:           get("METRICS_ADDR", ":9090"),
		LogLevel:              get("LOG_LEVEL", "info"),
		DatabaseURL:           lookup("DATABASE_URL"),
		PanelMode:             get("PANEL_MODE", PanelFake),
		RemnawaveBaseURL:      lookup("REMNAWAVE_BASE_URL"),
		RemnawaveAPIToken:     lookup("REMNAWAVE_API_TOKEN"),
		RemnawaveSquadUUID:    lookup("REMNAWAVE_SQUAD_UUID"),
		TelegramMode:          get("TELEGRAM_MODE", TelegramFake),
		TelegramBotToken:      lookup("TELEGRAM_BOT_TOKEN"),
		TelegramBotUsername:   lookup("TELEGRAM_BOT_USERNAME"),
		TelegramWebhookSecret: lookup("TELEGRAM_WEBHOOK_SECRET"),
		CatalogFile:           get("CATALOG_FILE", "../infra/catalog/servers.yaml"),
		PolicyFile:            get("POLICY_FILE", "config/policy.yaml"),
		TokenPepper:           get("TOKEN_PEPPER", defaultPepper),
		TrialDays:             number("TRIAL_DAYS", 3),
		AuthRatePerMin:        number("AUTH_RATE_PER_MIN", 10),
		PublicAPIURLs:         splitList(lookup("PUBLIC_API_URLS")),
		SupportURL:            lookup("SUPPORT_URL"),
		WebURL:                lookup("WEB_URL"),
	}

	errs = append(errs, cfg.validate()...)
	if err := errors.Join(errs...); err != nil {
		return Config{}, fmt.Errorf("invalid config: %w", err)
	}
	return cfg, nil
}

func (c Config) validate() []error {
	var errs []error
	fail := func(format string, args ...any) { errs = append(errs, fmt.Errorf(format, args...)) }
	require := func(key, value string) {
		if value == "" {
			fail("%s is required", key)
		}
	}
	oneOf := func(key, value string, allowed ...string) {
		if !slices.Contains(allowed, value) {
			fail("%s must be one of %s", key, strings.Join(allowed, ", "))
		}
	}

	oneOf("APP_ENV", c.AppEnv, EnvDev, EnvStaging, EnvProd)
	oneOf("LOG_LEVEL", c.LogLevel, "debug", "info", "warn", "error")
	oneOf("PANEL_MODE", c.PanelMode, PanelFake, PanelRemnawave)
	oneOf("TELEGRAM_MODE", c.TelegramMode, TelegramFake, TelegramPolling, TelegramWebhook)
	require("DATABASE_URL", c.DatabaseURL)
	if len(c.PublicAPIURLs) == 0 {
		fail("PUBLIC_API_URLS is required")
	}

	if c.PanelMode == PanelRemnawave {
		require("REMNAWAVE_BASE_URL", c.RemnawaveBaseURL)
		require("REMNAWAVE_API_TOKEN", c.RemnawaveAPIToken)
		if _, err := uuid.Parse(c.RemnawaveSquadUUID); err != nil {
			fail("REMNAWAVE_SQUAD_UUID must be a uuid")
		}
	}
	if c.TelegramMode != TelegramFake {
		require("TELEGRAM_BOT_TOKEN", c.TelegramBotToken)
		require("TELEGRAM_BOT_USERNAME", c.TelegramBotUsername)
	}
	if c.TelegramMode == TelegramWebhook {
		require("TELEGRAM_WEBHOOK_SECRET", c.TelegramWebhookSecret)
	}

	if c.AppEnv != EnvDev && (c.TokenPepper == defaultPepper || len(c.TokenPepper) < minPepperLen) {
		fail("TOKEN_PEPPER must be a unique value of at least %d bytes", minPepperLen)
	}
	if c.AppEnv == EnvProd && c.PanelMode == PanelFake {
		fail("PANEL_MODE must not be fake in prod")
	}
	if c.AppEnv == EnvProd && c.TelegramMode == TelegramFake {
		fail("TELEGRAM_MODE must not be fake in prod")
	}
	return errs
}

func splitList(raw string) []string {
	var items []string
	for _, item := range strings.Split(raw, ",") {
		if item = strings.TrimSpace(item); item != "" {
			items = append(items, item)
		}
	}
	return items
}
