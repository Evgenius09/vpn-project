package config

import (
	"bytes"
	"fmt"
	"log/slog"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
)

func validEnv() map[string]string {
	return map[string]string{
		"DATABASE_URL":    "postgres://vpn:vpn@localhost:5432/vpn",
		"PUBLIC_API_URLS": "https://api.example.invalid,https://fallback.example.invalid",
	}
}

func load(env map[string]string) (Config, error) {
	return Load(func(key string) string { return env[key] })
}

func TestDevDefaults(t *testing.T) {
	cfg, err := load(validEnv())
	require.NoError(t, err)
	require.Equal(t, EnvDev, cfg.AppEnv)
	require.Equal(t, ":8080", cfg.HTTPAddr)
	require.Equal(t, ":9090", cfg.MetricsAddr)
	require.Equal(t, PanelFake, cfg.PanelMode)
	require.Equal(t, TelegramFake, cfg.TelegramMode)
	require.Equal(t, 3, cfg.TrialDays)
	require.Equal(t, 10, cfg.AuthRatePerMin)
	require.Equal(t, "config/policy.yaml", cfg.PolicyFile)
	require.Equal(t, []string{"https://api.example.invalid", "https://fallback.example.invalid"}, cfg.PublicAPIURLs)
}

func TestRejectedConfigs(t *testing.T) {
	const strongPepper = "0123456789abcdef0123456789abcdef"
	tests := []struct {
		name  string
		env   map[string]string
		field string
	}{
		{"no database", map[string]string{"DATABASE_URL": ""}, "DATABASE_URL"},
		{"no public urls", map[string]string{"PUBLIC_API_URLS": ""}, "PUBLIC_API_URLS"},
		{"unknown env", map[string]string{"APP_ENV": "qa"}, "APP_ENV"},
		{"unknown panel mode", map[string]string{"PANEL_MODE": "mock"}, "PANEL_MODE"},
		{"unknown telegram mode", map[string]string{"TELEGRAM_MODE": "mock"}, "TELEGRAM_MODE"},
		{"unknown log level", map[string]string{"LOG_LEVEL": "loud"}, "LOG_LEVEL"},
		{"trial days not a number", map[string]string{"TRIAL_DAYS": "three"}, "TRIAL_DAYS"},
		{"zero trial days", map[string]string{"TRIAL_DAYS": "0"}, "TRIAL_DAYS"},
		{"zero auth rate", map[string]string{"AUTH_RATE_PER_MIN": "0"}, "AUTH_RATE_PER_MIN"},
		{"remnawave without url", map[string]string{"PANEL_MODE": "remnawave", "REMNAWAVE_API_TOKEN": "t"}, "REMNAWAVE_BASE_URL"},
		{"remnawave without token", map[string]string{"PANEL_MODE": "remnawave", "REMNAWAVE_BASE_URL": "https://p"}, "REMNAWAVE_API_TOKEN"},
		{
			"remnawave without squad",
			map[string]string{"PANEL_MODE": "remnawave", "REMNAWAVE_BASE_URL": "https://p", "REMNAWAVE_API_TOKEN": "t"},
			"REMNAWAVE_SQUAD_UUID",
		},
		{
			"remnawave squad not a uuid",
			map[string]string{
				"PANEL_MODE": "remnawave", "REMNAWAVE_BASE_URL": "https://p", "REMNAWAVE_API_TOKEN": "t",
				"REMNAWAVE_SQUAD_UUID": "staging",
			},
			"REMNAWAVE_SQUAD_UUID",
		},
		{"polling without token", map[string]string{"TELEGRAM_MODE": "polling", "TELEGRAM_BOT_USERNAME": "b"}, "TELEGRAM_BOT_TOKEN"},
		{"polling without username", map[string]string{"TELEGRAM_MODE": "polling", "TELEGRAM_BOT_TOKEN": "t"}, "TELEGRAM_BOT_USERNAME"},
		{
			"webhook without secret",
			map[string]string{"TELEGRAM_MODE": "webhook", "TELEGRAM_BOT_TOKEN": "t", "TELEGRAM_BOT_USERNAME": "b"},
			"TELEGRAM_WEBHOOK_SECRET",
		},
		{"staging placeholder pepper", map[string]string{"APP_ENV": "staging", "TOKEN_PEPPER": defaultPepper}, "TOKEN_PEPPER"},
		{"staging short pepper", map[string]string{"APP_ENV": "staging", "TOKEN_PEPPER": "short"}, "TOKEN_PEPPER"},
		{"prod fake panel", map[string]string{"APP_ENV": "prod", "TOKEN_PEPPER": strongPepper}, "PANEL_MODE"},
		{
			"prod fake telegram",
			map[string]string{
				"APP_ENV": "prod", "TOKEN_PEPPER": strongPepper, "PANEL_MODE": "remnawave",
				"REMNAWAVE_BASE_URL": "https://p", "REMNAWAVE_API_TOKEN": "t", "REMNAWAVE_SQUAD_UUID": squad,
			},
			"TELEGRAM_MODE",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			env := validEnv()
			for key, value := range tt.env {
				env[key] = value
			}
			_, err := load(env)
			require.ErrorContains(t, err, tt.field)
		})
	}
}

const squad = "baf9736b-afde-4875-aad1-a2a0ba300d51"

func TestProdConfig(t *testing.T) {
	env := validEnv()
	for key, value := range map[string]string{
		"APP_ENV": "prod", "TOKEN_PEPPER": "0123456789abcdef0123456789abcdef",
		"PANEL_MODE": "remnawave", "REMNAWAVE_BASE_URL": "https://p", "REMNAWAVE_API_TOKEN": "t", "REMNAWAVE_SQUAD_UUID": squad,
		"TELEGRAM_MODE": "webhook", "TELEGRAM_BOT_TOKEN": "t", "TELEGRAM_BOT_USERNAME": "b", "TELEGRAM_WEBHOOK_SECRET": "s",
	} {
		env[key] = value
	}
	_, err := load(env)
	require.NoError(t, err)
}

func TestSecretsStayOutOfLogs(t *testing.T) {
	const secret = "super-secret-value"
	env := validEnv()
	env["DATABASE_URL"] = "postgres://vpn:" + secret + "@localhost/vpn"
	env["TOKEN_PEPPER"] = secret + secret
	env["TELEGRAM_BOT_TOKEN"] = secret
	env["TELEGRAM_WEBHOOK_SECRET"] = secret
	env["REMNAWAVE_API_TOKEN"] = secret
	cfg, err := load(env)
	require.NoError(t, err)

	var out bytes.Buffer
	slog.New(slog.NewJSONHandler(&out, nil)).Info("config", "config", cfg)
	require.NotContains(t, out.String(), secret)
	require.NotContains(t, fmt.Sprintf("%v %+v %s", cfg, cfg, cfg), secret)
	require.True(t, strings.Contains(out.String(), "dev"), "non-secret fields stay visible")
}
