package httpapi

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"errors"
	"fmt"
	"net/http"
	"strings"

	"github.com/google/uuid"

	"github.com/Evgenius09/vpn-project/backend/internal/gen/api"
)

// ErrDeviceNotFound means no device holds the token.
var ErrDeviceNotFound = errors.New("httpapi: device not found")

// Device is the authenticated caller.
type Device struct {
	ID        uuid.UUID
	AccountID uuid.UUID
	Revoked   bool
}

// DeviceStore resolves a token hash to its device.
type DeviceStore interface {
	FindByTokenHash(ctx context.Context, tokenHash []byte) (Device, error)
}

// publicOperations lists the operations that need no token. Everything else
// requires one, so a new operation is closed by default. A test keeps this in
// step with the security section of openapi.yaml.
var publicOperations = map[string]bool{
	"StartTelegramLogin":  true,
	"VerifyTelegramLogin": true,
}

type deviceKey struct{}

// DeviceFromContext returns the device set by the auth middleware.
func DeviceFromContext(ctx context.Context) (Device, bool) {
	device, ok := ctx.Value(deviceKey{}).(Device)
	return device, ok
}

// HashToken derives the stored form of a device token (tech.md 5.2).
func HashToken(token string, pepper []byte) []byte {
	mac := hmac.New(sha256.New, pepper)
	mac.Write([]byte(token))
	return mac.Sum(nil)
}

func bearerToken(r *http.Request) (string, bool) {
	scheme, token, found := strings.Cut(r.Header.Get("Authorization"), " ")
	if !found || !strings.EqualFold(scheme, "bearer") || token == "" {
		return "", false
	}
	return token, true
}

func unauthorized(code api.ProblemCode, title string) *Problem {
	return &Problem{Status: http.StatusUnauthorized, Code: code, Title: title}
}

func authMiddleware(store DeviceStore, pepper []byte) api.StrictMiddlewareFunc {
	return func(next api.StrictHandlerFunc, operationID string) api.StrictHandlerFunc {
		if publicOperations[operationID] {
			return next
		}
		return func(ctx context.Context, w http.ResponseWriter, r *http.Request, request any) (any, error) {
			token, ok := bearerToken(r)
			if !ok {
				return nil, unauthorized(api.ProblemCodeUnauthorized, "Authorization required")
			}
			device, err := store.FindByTokenHash(ctx, HashToken(token, pepper))
			switch {
			case errors.Is(err, ErrDeviceNotFound):
				return nil, unauthorized(api.ProblemCodeUnauthorized, "Authorization required")
			case err != nil:
				return nil, fmt.Errorf("find device: %w", err)
			case device.Revoked:
				return nil, unauthorized(api.ProblemCodeDeviceRevoked, "Device revoked")
			}
			return next(context.WithValue(ctx, deviceKey{}, device), w, r, request)
		}
	}
}
