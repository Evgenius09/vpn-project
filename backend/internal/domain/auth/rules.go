package auth

import (
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"math"
	"math/big"
	"regexp"
	"strings"
	"time"
	"unicode"
)

const (
	maxModelLength   = 64
	maxVersionLength = 64
	maxCodesPerHour  = 5
	maxAttempts      = 5
	resendAfter      = time.Minute
	codeTTL          = 5 * time.Minute
	codeSpace        = 1_000_000
	tokenBytes       = 32
)

var usernamePattern = regexp.MustCompile(`^[a-z0-9_]{4,32}$`)

// NormalizeUsername returns the stored form of a nick typed in the app
// (tech.md 5.2, 19.9).
func NormalizeUsername(raw string) (string, bool) {
	username := strings.ToLower(strings.TrimPrefix(raw, "@"))
	if !usernamePattern.MatchString(username) {
		return "", false
	}
	return username, true
}

// cleanModel makes a client-supplied device model safe to quote in a bot
// message. Anyone who knows a nick controls this text, so it must not carry a
// link or a mention (tech.md 25.1).
func cleanModel(raw string) string {
	mapped := strings.Map(func(r rune) rune {
		if unicode.IsLetter(r) || unicode.IsNumber(r) || strings.ContainsRune("()_+-", r) {
			return r
		}
		return ' '
	}, raw)
	cleaned := strings.Join(strings.Fields(mapped), " ")
	if runes := []rune(cleaned); len(runes) > maxModelLength {
		return strings.TrimSpace(string(runes[:maxModelLength]))
	}
	return cleaned
}

// retryAfter returns the seconds to wait before the next code, zero when one
// can go now. sent holds the codes of the last hour, oldest first.
func retryAfter(sent []time.Time, now time.Time) int {
	if len(sent) == 0 {
		return 0
	}
	wait := sent[len(sent)-1].Add(resendAfter).Sub(now)
	if len(sent) >= maxCodesPerHour {
		wait = max(wait, sent[len(sent)-maxCodesPerHour].Add(time.Hour).Sub(now))
	}
	return max(int(math.Ceil(wait.Seconds())), 0)
}

func newCode() (string, error) {
	value, err := rand.Int(rand.Reader, big.NewInt(codeSpace))
	if err != nil {
		return "", fmt.Errorf("generate code: %w", err)
	}
	return fmt.Sprintf("%06d", value.Int64()), nil
}

func newToken() (string, error) {
	raw := make([]byte, tokenBytes)
	if _, err := rand.Read(raw); err != nil {
		return "", fmt.Errorf("generate token: %w", err)
	}
	return base64.RawURLEncoding.EncodeToString(raw), nil
}
