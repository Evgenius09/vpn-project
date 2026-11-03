package auth

import (
	"context"
	"errors"
	"fmt"
	"net/http"

	"github.com/Evgenius09/vpn-project/backend/internal/gen/api"
	"github.com/Evgenius09/vpn-project/backend/internal/httpapi"
)

// Handler serves the login operations.
type Handler struct {
	service *Service
}

// NewHandler returns a handler.
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// StartTelegramLogin handles POST /v1/auth/telegram/start.
func (h *Handler) StartTelegramLogin(ctx context.Context, request api.StartTelegramLoginRequestObject) (api.StartTelegramLoginResponseObject, error) {
	challenge, err := h.service.Start(ctx, StartInput{
		Username:  request.Body.Username,
		InstallID: request.Body.InstallId,
		Model:     request.Body.Model,
	})
	if err != nil {
		return nil, h.problem(err)
	}
	return api.StartTelegramLogin200JSONResponse{
		LoginId:        challenge.LoginID,
		ExpiresAt:      challenge.ExpiresAt.UTC(),
		ResendAfterSec: challenge.ResendAfterSec,
		BotUrl:         challenge.BotURL,
	}, nil
}

// VerifyTelegramLogin handles POST /v1/auth/telegram/verify.
func (h *Handler) VerifyTelegramLogin(ctx context.Context, request api.VerifyTelegramLoginRequestObject) (api.VerifyTelegramLoginResponseObject, error) {
	result, err := h.service.Verify(ctx, VerifyInput{
		LoginID:    request.Body.LoginId,
		InstallID:  request.Body.InstallId,
		Code:       request.Body.Code,
		Platform:   request.Body.Platform,
		Model:      request.Body.Model,
		AppVersion: request.Body.AppVersion,
	})
	if err != nil {
		return nil, h.problem(err)
	}
	return api.VerifyTelegramLogin200JSONResponse{
		DeviceId:  result.DeviceID,
		AccountId: result.AccountID,
		Token:     result.Token,
	}, nil
}

// Logout handles POST /v1/auth/logout.
func (h *Handler) Logout(ctx context.Context, _ api.LogoutRequestObject) (api.LogoutResponseObject, error) {
	device, ok := httpapi.DeviceFromContext(ctx)
	if !ok {
		return nil, errors.New("auth: no device in context")
	}
	if err := h.service.Logout(ctx, device.ID); err != nil {
		return nil, fmt.Errorf("logout: %w", err)
	}
	return api.Logout204Response{}, nil
}

// problem maps a domain error to the contract. Anything else stays an error,
// which the router answers with a bare 500.
func (h *Handler) problem(err error) error {
	var limited *RateLimitedError
	var invalid *InvalidCodeError
	switch {
	case errors.Is(err, ErrInvalidInput):
		return &httpapi.Problem{
			Status: http.StatusBadRequest, Code: api.ProblemCodeValidationFailed,
			Title: "Validation failed", Detail: err.Error(),
		}
	case errors.Is(err, ErrUserNotFound):
		return &httpapi.Problem{
			Status: http.StatusNotFound, Code: api.ProblemCodeTelegramUserNotFound,
			Title: "Telegram user not found", BotURL: h.service.botURL,
		}
	case errors.As(err, &limited):
		return &httpapi.Problem{
			Status: http.StatusTooManyRequests, Code: api.ProblemCodeRateLimited,
			Title: "Too many requests", RetryAfterSec: &limited.RetryAfterSec,
		}
	case errors.As(err, &invalid):
		return &httpapi.Problem{
			Status: http.StatusBadRequest, Code: api.ProblemCodeCodeInvalid,
			Title: "Invalid code", AttemptsLeft: &invalid.AttemptsLeft,
		}
	case errors.Is(err, ErrCodeExpired):
		return &httpapi.Problem{Status: http.StatusGone, Code: api.ProblemCodeCodeExpired, Title: "Code expired"}
	case errors.Is(err, ErrDeviceLimit):
		return &httpapi.Problem{Status: http.StatusConflict, Code: api.ProblemCodeDeviceLimitReached, Title: "Device limit reached"}
	default:
		return err
	}
}
