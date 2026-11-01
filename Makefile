SHELL := bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := check

# Later slices add modules and generators here; targets skip what does not
# exist yet so that every slice can run the same commands.
GO_MODULES := $(patsubst %/go.mod,%,$(wildcard backend/go.mod core/go.mod))
FLUTTER_APP := $(wildcard app/pubspec.yaml)
SCRIPTS := $(wildcard .github/scripts/*.sh)
GENERATED := app/lib/gen backend/internal/gen backend/internal/db/sqlc core/internal/contract

.PHONY: gen check check-repo check-go check-app test test-repo test-go test-app \
	seed dev core-android core-windows installer

gen:
	@echo "gen: no generators yet"

check: check-repo check-go check-app
	@$(MAKE) --no-print-directory gen
	@stale="$$(git status --porcelain -- $(GENERATED))"; \
	test -z "$$stale" || { echo "check: stale generated code, run make gen and commit:"; echo "$$stale"; exit 1; }

check-repo:
	actionlint
	shellcheck $(SCRIPTS)

check-go:
	@for module in $(GO_MODULES); do \
		echo "check-go: $$module"; \
		test -z "$$(cd $$module && gofmt -l .)" || { echo "gofmt needed in $$module"; exit 1; }; \
		(cd $$module && go vet ./... && golangci-lint run --config ../.golangci.yml ./...); \
	done

check-app:
ifneq ($(FLUTTER_APP),)
	cd app && dart format --output=none --set-exit-if-changed lib test
	cd app && flutter analyze --fatal-infos
endif

test: test-repo test-go test-app

test-repo:
	bash .github/scripts/contract_guard_test.sh

test-go:
	@for module in $(GO_MODULES); do \
		echo "test-go: $$module"; \
		(cd $$module && go test ./...); \
	done

test-app:
ifneq ($(FLUTTER_APP),)
	cd app && flutter test
endif

seed dev core-android core-windows installer:
	@echo "$@: not available yet, see the skeleton slices in tech.md section 15.1"
	@exit 1
