package profile

import (
	"context"
	"errors"
	"fmt"
	"net/http"

	"github.com/Evgenius09/vpn-project/backend/internal/gen/api"
	"github.com/Evgenius09/vpn-project/backend/internal/httpapi"
)

// Handler serves GET /v1/profile.
type Handler struct {
	service *Service
}

// NewHandler returns a handler.
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// GetProfile maps the service result to the contract.
func (h *Handler) GetProfile(ctx context.Context, request api.GetProfileRequestObject) (api.GetProfileResponseObject, error) {
	device, ok := httpapi.DeviceFromContext(ctx)
	if !ok {
		return nil, errors.New("profile: no device in context")
	}
	result, err := h.service.Build(ctx, device.AccountID)
	if err != nil {
		if errors.Is(err, ErrAccountNotFound) {
			return nil, &httpapi.Problem{Status: http.StatusNotFound, Code: api.ProblemCodeNotFound, Title: "Account not found"}
		}
		return nil, fmt.Errorf("build profile: %w", err)
	}
	if match := request.Params.IfNoneMatch; match != nil && *match == result.ETag {
		return api.GetProfile304Response{}, nil
	}

	headers := api.GetProfile200ResponseHeaders{ETag: result.ETag}
	if result.Provisioning {
		seconds := retryAfter
		headers.RetryAfter = &seconds
	}
	return api.GetProfile200JSONResponse{Body: result.Profile, Headers: headers}, nil
}
