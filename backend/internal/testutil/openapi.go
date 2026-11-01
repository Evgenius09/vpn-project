// Package testutil holds helpers shared by backend tests.
package testutil

import (
	"context"
	"fmt"

	"github.com/getkin/kin-openapi/openapi3"
)

// LoadSpec reads and validates contracts/openapi.yaml.
func LoadSpec(ctx context.Context, path string) (*openapi3.T, error) {
	loader := openapi3.NewLoader()
	spec, err := loader.LoadFromFile(path)
	if err != nil {
		return nil, fmt.Errorf("load spec: %w", err)
	}
	if err := spec.Validate(ctx); err != nil {
		return nil, fmt.Errorf("validate spec: %w", err)
	}
	return spec, nil
}

// ValidateSchema checks a decoded JSON document against a named component.
func ValidateSchema(spec *openapi3.T, schema string, document any) error {
	ref, ok := spec.Components.Schemas[schema]
	if !ok {
		return fmt.Errorf("schema %s is not in the contract", schema)
	}
	if err := ref.Value.VisitJSON(document, openapi3.EnableJSONSchema2020()); err != nil {
		return fmt.Errorf("validate %s: %w", schema, err)
	}
	return nil
}
