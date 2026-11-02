SHELL := bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := check

# Later slices add modules and generators here; targets skip what does not
# exist yet so that every slice can run the same commands.
FLUTTER_APP := $(wildcard app/pubspec.yaml)
SCRIPTS := $(wildcard .github/scripts/*.sh)
GENERATED := app/lib/gen app/android/app/src/main/kotlin/com/vpnclient/app/gen \
	backend/internal/gen backend/internal/db/sqlc core/internal/contract

.PHONY: gen gen-go gen-app check check-repo check-go check-app test test-repo test-go test-app \
	seed dev core-android core-windows installer

gen: gen-go gen-app

gen-go:
	cd backend && oapi-codegen -config oapi-codegen.yaml ../contracts/openapi.yaml
	cd backend && sqlc generate
	cd core && oapi-codegen -config oapi-codegen.yaml ../contracts/openapi.yaml

# swagger_parser leaves files of removed schemas behind, so start clean.
gen-app:
	cd app && flutter pub get --enforce-lockfile
	cd app && flutter gen-l10n
	rm -rf app/lib/gen/api
	cd app && dart run swagger_parser
	cd app && dart run build_runner build
	cd app && dart run pigeon --input "$$(realpath ../contracts/pigeon/vpn_api.dart)"
	cd app && dart format lib/gen

check: check-repo check-go check-app
	@$(MAKE) --no-print-directory gen
	@stale="$$(git status --porcelain -- $(GENERATED))"; \
	test -z "$$stale" || { echo "check: stale generated code, run make gen and commit:"; echo "$$stale"; exit 1; }

check-repo:
	actionlint
	shellcheck $(SCRIPTS)

check-go:
	test -z "$$(cd backend && gofmt -l .)" || { echo "gofmt needed in backend"; exit 1; }
	cd backend && go vet ./... && golangci-lint run --config ../.golangci.yml ./...
	$(MAKE) --no-print-directory -C core check

check-app:
ifneq ($(FLUTTER_APP),)
	cd app && dart format --output=none --set-exit-if-changed lib test
	cd app && flutter analyze --fatal-infos
endif

test: test-repo test-go test-app

test-repo:
	bash .github/scripts/contract_guard_test.sh

test-go:
	cd backend && go test ./...
	$(MAKE) --no-print-directory -C core test

test-app:
ifneq ($(FLUTTER_APP),)
	cd app && flutter test
endif

core-android:
	$(MAKE) --no-print-directory -C core android
	mkdir -p app/android/app/libs
	cp core/build/core.aar app/android/app/libs/core.aar

core-windows:
	$(MAKE) --no-print-directory -C core windows

installer:
	iscc installer/windows/setup.iss

# Local defaults from backend/.env.example.
DEV_ENV := set -a; . backend/.env.example; set +a; cd backend

seed:
	$(DEV_ENV) && go run ./cmd/migrate && go run ./cmd/seed

dev:
	docker compose -f infra/compose/dev.yaml up -d --wait
	$(MAKE) --no-print-directory seed
	$(DEV_ENV) && (go run ./cmd/worker & go run ./cmd/api)
