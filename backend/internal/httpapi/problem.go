package httpapi

import (
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"

	"github.com/Evgenius09/vpn-project/backend/internal/gen/api"
)

const problemContentType = "application/problem+json"

// Problem is an RFC 9457 error that handlers return as an error value.
type Problem struct {
	Status        int
	Code          api.ProblemCode
	Title         string
	Detail        string
	BotURL        string
	AttemptsLeft  *int
	RetryAfterSec *int
}

// Error implements error.
func (p *Problem) Error() string {
	return fmt.Sprintf("problem %d %s: %s", p.Status, p.Code, p.Title)
}

func (p *Problem) body() api.Problem {
	body := api.Problem{
		Code:          p.Code,
		Status:        p.Status,
		Title:         p.Title,
		AttemptsLeft:  p.AttemptsLeft,
		RetryAfterSec: p.RetryAfterSec,
	}
	if p.Detail != "" {
		body.Detail = &p.Detail
	}
	if p.BotURL != "" {
		body.BotUrl = &p.BotURL
	}
	return body
}

// WriteProblem writes p as the response.
func WriteProblem(w http.ResponseWriter, p *Problem) {
	encoded, err := json.Marshal(p.body())
	if err != nil {
		http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", problemContentType)
	w.WriteHeader(p.Status)
	_, _ = w.Write(encoded)
}

func internalProblem() *Problem {
	return &Problem{Status: http.StatusInternalServerError, Code: api.ProblemCodeInternal, Title: "Internal server error"}
}

// writeError answers with the Problem inside err. Any other error becomes a
// bare 500, so internal details never reach the client.
func writeError(w http.ResponseWriter, r *http.Request, logger *slog.Logger, err error) {
	var problem *Problem
	if errors.As(err, &problem) {
		WriteProblem(w, problem)
		return
	}
	logger.ErrorContext(r.Context(), "request failed", "path", r.URL.Path, "error", err)
	WriteProblem(w, internalProblem())
}

func validationProblem(detail string) *Problem {
	return &Problem{
		Status: http.StatusBadRequest,
		Code:   api.ProblemCodeValidationFailed,
		Title:  "Validation failed",
		Detail: detail,
	}
}
