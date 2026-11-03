package auth

import (
	"regexp"
	"strings"
	"testing"
	"time"
	"unicode"
	"unicode/utf8"

	"github.com/stretchr/testify/require"
	"pgregory.net/rapid"
)

func TestNormalizeUsername(t *testing.T) {
	cases := map[string]string{
		"seed_user":                        "seed_user",
		"@seed_user":                       "seed_user",
		"Seed_User":                        "seed_user",
		"@SEED_USER":                       "seed_user",
		"abcd":                             "abcd",
		"a234567890123456789012345678901b": "a234567890123456789012345678901b",
	}
	for input, want := range cases {
		got, ok := NormalizeUsername(input)
		require.True(t, ok, input)
		require.Equal(t, want, got)
	}
}

func TestNormalizeUsernameRejects(t *testing.T) {
	cases := []string{
		"", "@", "abc", "@abc", "seed user", "seed-user", "seed.user", "@@seed_user",
		"сид_юзер", "seed_user@", strings.Repeat("a", 33), " seed_user",
	}
	for _, input := range cases {
		_, ok := NormalizeUsername(input)
		require.False(t, ok, input)
	}
}

func TestNormalizeUsernameProperties(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		nick := rapid.StringMatching(`[A-Za-z0-9_]{4,32}`).Draw(t, "nick")
		prefix := rapid.SampledFrom([]string{"", "@"}).Draw(t, "prefix")

		got, ok := NormalizeUsername(prefix + nick)

		require.True(t, ok)
		require.Equal(t, strings.ToLower(nick), got)
		again, ok := NormalizeUsername(got)
		require.True(t, ok)
		require.Equal(t, got, again)
	})
}

func TestNormalizeUsernameNeverPassesWhatTheContractForbids(t *testing.T) {
	valid := regexp.MustCompile(`^[a-z0-9_]{4,32}$`)
	rapid.Check(t, func(t *rapid.T) {
		got, ok := NormalizeUsername(rapid.String().Draw(t, "input"))
		if ok {
			require.Regexp(t, valid, got)
		}
	})
}

func TestCleanModel(t *testing.T) {
	cases := map[string]string{
		"Pixel 7":                    "Pixel 7",
		"SM-A225F":                   "SM-A225F",
		"Moto G (5S) Plus":           "Moto G (5S) Plus",
		"Galaxy S21+":                "Galaxy S21+",
		"Windows_11":                 "Windows_11",
		"Nokia 7.2":                  "Nokia 7 2",
		"Планшет Lenovo":             "Планшет Lenovo",
		"https://evil.example/login": "https evil example login",
		"перешлите код @support":     "перешлите код support",
		"a\nb\tc":                    "a b c",
		"  spaced   out  ":           "spaced out",
		"...":                        "",
		"":                           "",
	}
	for input, want := range cases {
		require.Equal(t, want, cleanModel(input), input)
	}
}

func TestCleanModelProperties(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		got := cleanModel(rapid.String().Draw(t, "input"))

		require.LessOrEqual(t, utf8.RuneCountInString(got), maxModelLength)
		require.Equal(t, strings.TrimSpace(got), got)
		require.NotContains(t, got, "  ")
		for _, r := range got {
			allowed := unicode.IsLetter(r) || unicode.IsNumber(r) || strings.ContainsRune(" ()_+-", r)
			require.True(t, allowed, "%q in %q", r, got)
		}
		require.Equal(t, got, cleanModel(got))
	})
}

func TestRetryAfter(t *testing.T) {
	now := time.Date(2026, 11, 3, 10, 0, 0, 0, time.UTC)
	ago := func(d time.Duration) time.Time { return now.Add(-d) }
	cases := []struct {
		name string
		sent []time.Time
		want int
	}{
		{"nothing sent", nil, 0},
		{"cooldown running", []time.Time{ago(45 * time.Second)}, 15},
		{"cooldown rounds up", []time.Time{ago(59*time.Second + 500*time.Millisecond)}, 1},
		{"cooldown over", []time.Time{ago(time.Minute)}, 0},
		{
			"four codes pass",
			[]time.Time{ago(50 * time.Minute), ago(40 * time.Minute), ago(30 * time.Minute), ago(20 * time.Minute)},
			0,
		},
		{
			"fifth code waits for the oldest to leave the hour",
			[]time.Time{ago(50 * time.Minute), ago(40 * time.Minute), ago(30 * time.Minute), ago(20 * time.Minute), ago(10 * time.Minute)},
			600,
		},
		{
			"the longer wait wins",
			[]time.Time{ago(59*time.Minute + 50*time.Second), ago(40 * time.Minute), ago(30 * time.Minute), ago(20 * time.Minute), ago(30 * time.Second)},
			30,
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			require.Equal(t, tc.want, retryAfter(tc.sent, now))
		})
	}
}

func TestRetryAfterProperties(t *testing.T) {
	now := time.Date(2026, 11, 3, 10, 0, 0, 0, time.UTC)
	rapid.Check(t, func(t *rapid.T) {
		ages := rapid.SliceOfN(rapid.Int64Range(1, 3599), 0, 8).Draw(t, "ages")
		sent := make([]time.Time, 0, len(ages))
		maxAge, minAge := int64(0), int64(3600)
		for _, age := range ages {
			maxAge, minAge = max(maxAge, age), min(minAge, age)
		}
		// Oldest first, as the query returns them.
		for _, age := range sortedDescending(ages) {
			sent = append(sent, now.Add(-time.Duration(age)*time.Second))
		}

		got := retryAfter(sent, now)

		limited := len(ages) >= maxCodesPerHour || (len(ages) > 0 && minAge < 60)
		require.Equal(t, limited, got > 0)
		require.GreaterOrEqual(t, got, 0)
		require.LessOrEqual(t, got, 3600)
	})
}

func sortedDescending(values []int64) []int64 {
	sorted := append([]int64(nil), values...)
	for i := range sorted {
		for j := i + 1; j < len(sorted); j++ {
			if sorted[j] > sorted[i] {
				sorted[i], sorted[j] = sorted[j], sorted[i]
			}
		}
	}
	return sorted
}

func TestNewCodeIsSixDigits(t *testing.T) {
	seen := map[string]bool{}
	for range 500 {
		code, err := newCode()
		require.NoError(t, err)
		require.Regexp(t, `^[0-9]{6}$`, code)
		seen[code] = true
	}
	require.Greater(t, len(seen), 450, "codes must not repeat")
}

func TestNewTokenIs32RandomBytes(t *testing.T) {
	first, err := newToken()
	require.NoError(t, err)
	second, err := newToken()
	require.NoError(t, err)

	require.Regexp(t, `^[A-Za-z0-9_-]{43}$`, first)
	require.NotEqual(t, first, second)
}
