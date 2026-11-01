// Package httpapi builds the public HTTP server: routing, problem+json errors,
// device auth, and metrics (tech.md 5.2).
package httpapi

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/Evgenius09/vpn-project/backend/internal/gen/api"
)

// Deps are the collaborators of the router.
type Deps struct {
	Handlers api.StrictServerInterface
	Devices  DeviceStore
	Pepper   []byte
	Logger   *slog.Logger
	Metrics  *Metrics
	// Webhook serves /telegram/webhook when set.
	Webhook http.Handler
}

// NewRouter returns the public handler.
func NewRouter(deps Deps) http.Handler {
	router := chi.NewRouter()
	router.Use(recoverMiddleware(deps.Logger))
	router.Use(deps.Metrics.middleware)
	router.Use(logMiddleware(deps.Logger))

	router.NotFound(func(w http.ResponseWriter, _ *http.Request) {
		WriteProblem(w, &Problem{Status: http.StatusNotFound, Code: api.ProblemCodeNotFound, Title: "Not found"})
	})
	router.MethodNotAllowed(func(w http.ResponseWriter, _ *http.Request) {
		WriteProblem(w, &Problem{Status: http.StatusMethodNotAllowed, Code: api.ProblemCodeNotFound, Title: "Method not allowed"})
	})

	router.Get("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"status":"ok"}`))
	})
	if deps.Webhook != nil {
		router.Method(http.MethodPost, "/telegram/webhook", deps.Webhook)
	}

	strict := api.NewStrictHandlerWithOptions(
		deps.Handlers,
		[]api.StrictMiddlewareFunc{authMiddleware(deps.Devices, deps.Pepper)},
		api.StrictHTTPServerOptions{
			RequestErrorHandlerFunc: func(w http.ResponseWriter, _ *http.Request, err error) {
				WriteProblem(w, validationProblem(err.Error()))
			},
			ResponseErrorHandlerFunc: func(w http.ResponseWriter, r *http.Request, err error) {
				writeError(w, r, deps.Logger, err)
			},
		},
	)
	return api.HandlerWithOptions(strict, api.ChiServerOptions{
		BaseRouter: router,
		ErrorHandlerFunc: func(w http.ResponseWriter, _ *http.Request, err error) {
			WriteProblem(w, validationProblem(err.Error()))
		},
	})
}

func recoverMiddleware(logger *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			defer func() {
				if recovered := recover(); recovered != nil {
					handlePanic(w, r, logger, recovered)
				}
			}()
			next.ServeHTTP(w, r)
		})
	}
}

func handlePanic(w http.ResponseWriter, r *http.Request, logger *slog.Logger, recovered any) {
	if err, ok := recovered.(error); ok && errors.Is(err, http.ErrAbortHandler) {
		panic(recovered)
	}
	logger.ErrorContext(r.Context(), "panic in handler", "path", r.URL.Path, "panic", fmt.Sprint(recovered))
	WriteProblem(w, internalProblem())
}

// logMiddleware records no client address, query, or headers: the service
// keeps no connection logs and tokens travel in a header (tech.md 9).
func logMiddleware(logger *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			next.ServeHTTP(w, r)
			logger.DebugContext(r.Context(), "request",
				"method", r.Method, "route", routePattern(r), "duration", time.Since(start))
		})
	}
}

// Unimplemented answers every operation until the domain slices arrive.
type Unimplemented struct{}

var _ api.StrictServerInterface = Unimplemented{}

func notImplemented() *Problem {
	return &Problem{Status: http.StatusNotImplemented, Code: api.ProblemCodeInternal, Title: "Not implemented"}
}

// Logout implements api.StrictServerInterface.
func (Unimplemented) Logout(context.Context, api.LogoutRequestObject) (api.LogoutResponseObject, error) {
	return nil, notImplemented()
}

// StartTelegramLogin implements api.StrictServerInterface.
func (Unimplemented) StartTelegramLogin(context.Context, api.StartTelegramLoginRequestObject) (api.StartTelegramLoginResponseObject, error) {
	return nil, notImplemented()
}

// VerifyTelegramLogin implements api.StrictServerInterface.
func (Unimplemented) VerifyTelegramLogin(context.Context, api.VerifyTelegramLoginRequestObject) (api.VerifyTelegramLoginResponseObject, error) {
	return nil, notImplemented()
}

// GetProfile implements api.StrictServerInterface.
func (Unimplemented) GetProfile(context.Context, api.GetProfileRequestObject) (api.GetProfileResponseObject, error) {
	return nil, notImplemented()
}

// GetRuleSet implements api.StrictServerInterface.
func (Unimplemented) GetRuleSet(context.Context, api.GetRuleSetRequestObject) (api.GetRuleSetResponseObject, error) {
	return nil, notImplemented()
}
