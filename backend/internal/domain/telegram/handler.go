package telegram

import (
	"context"
	"crypto/subtle"
	"fmt"
	"io"
	"log/slog"
	"net/http"

	"github.com/Evgenius09/vpn-project/backend/internal/gen/api"
	"github.com/Evgenius09/vpn-project/backend/internal/httpapi"
	"github.com/Evgenius09/vpn-project/backend/internal/telegram/botapi"
)

// SecretHeader carries the webhook secret.
const SecretHeader = "X-Telegram-Bot-Api-Secret-Token"

const maxUpdateBytes = 1 << 20

// WebhookHandler serves POST /telegram/webhook.
type WebhookHandler struct {
	service *Service
	secret  []byte
	logger  *slog.Logger
}

// NewWebhookHandler returns a handler that accepts requests with secret.
func NewWebhookHandler(service *Service, secret string, logger *slog.Logger) *WebhookHandler {
	return &WebhookHandler{service: service, secret: []byte(secret), logger: logger}
}

// ServeHTTP implements http.Handler. A non-2xx status makes Telegram deliver
// the update again.
func (h *WebhookHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if !h.authorized(r) {
		httpapi.WriteProblem(w, &httpapi.Problem{
			Status: http.StatusUnauthorized,
			Code:   api.ProblemCodeUnauthorized,
			Title:  "Unauthorized",
		})
		return
	}

	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, maxUpdateBytes))
	if err != nil {
		writeInvalid(w, fmt.Errorf("read update: %w", err))
		return
	}
	update, ok, err := botapi.DecodeUpdate(body)
	if err != nil {
		writeInvalid(w, err)
		return
	}
	if !ok {
		return
	}

	// A hang-up must not cancel the update halfway: once committed, a redelivery
	// is a duplicate and the reply would be lost.
	ctx := context.WithoutCancel(r.Context())
	if err := h.service.HandleUpdate(ctx, update); err != nil {
		h.logger.ErrorContext(ctx, "telegram update failed", "updateId", update.UpdateID, "error", err)
		httpapi.WriteProblem(w, &httpapi.Problem{
			Status: http.StatusInternalServerError,
			Code:   api.ProblemCodeInternal,
			Title:  "Internal server error",
		})
	}
}

func (h *WebhookHandler) authorized(r *http.Request) bool {
	got := []byte(r.Header.Get(SecretHeader))
	return len(h.secret) > 0 && subtle.ConstantTimeCompare(got, h.secret) == 1
}

func writeInvalid(w http.ResponseWriter, err error) {
	httpapi.WriteProblem(w, &httpapi.Problem{
		Status: http.StatusBadRequest,
		Code:   api.ProblemCodeValidationFailed,
		Title:  "Validation failed",
		Detail: err.Error(),
	})
}
