#!/usr/bin/env bash
# Runs contract_guard.sh against throwaway git repos. Each case states the
# behaviour required by tech.md §5.1 and §13, not the script's internals.
set -euo pipefail

GUARD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/contract_guard.sh"
FAILURES=0
CASES=0

new_repo() {
  REPO="$(mktemp -d)"
  git -C "$REPO" init -q -b main
  git -C "$REPO" config user.name test
  git -C "$REPO" config user.email test@example.com
  printf 'Версия ядра: **v1** (2026-11-01)\n' >"$REPO/tech.md"
  git -C "$REPO" add tech.md
  git -C "$REPO" commit -q -m base
  git -C "$REPO" switch -q -c feature
}

touch_path() {
  mkdir -p "$(dirname "$REPO/$1")"
  printf 'change\n' >>"$REPO/$1"
  git -C "$REPO" add "$1"
  git -C "$REPO" commit -q -m "touch $1"
}

set_version() {
  printf 'Версия ядра: **v%s** (2026-11-02)\n' "$1" >"$REPO/tech.md"
  git -C "$REPO" add tech.md
  git -C "$REPO" commit -q -m "version $1"
}

# expect <pass|fail> <description> <labels>
expect() {
  local want="$1" description="$2" labels="$3" got=pass
  CASES=$((CASES + 1))
  if ! (cd "$REPO" && PR_LABELS="$labels" bash "$GUARD" main feature) >/dev/null 2>&1; then
    got=fail
  fi
  if [[ "$got" != "$want" ]]; then
    printf 'FAILED: %s (want %s, got %s)\n' "$description" "$want" "$got"
    FAILURES=$((FAILURES + 1))
  fi
  rm -rf "$REPO"
}

CONTRACT_PATHS=(
  contracts/openapi.yaml
  contracts/pigeon/vpn_api.dart
  backend/internal/db/migrations/00001_init.sql
  backend/internal/jobs/kinds.go
  backend/internal/panel/panel.go
  backend/internal/telegram/telegram.go
  backend/internal/config/config.go
  backend/internal/httpapi/router.go
  core/bind/core.go
  core/internal/ipc/protocol.go
  app/lib/ui/tokens.dart
  app/lib/app/routes.dart
  app/lib/core/vpn/vpn_bridge.dart
  installer/windows/setup.iss
  .github/workflows/pr.yml
  infra/compose/api/compose.yaml
  .tool-versions
  Makefile
)

for path in "${CONTRACT_PATHS[@]}"; do
  new_repo
  touch_path "$path"
  expect fail "$path without a label" ""
done

OPEN_PATHS=(
  backend/internal/panel/fake/fake.go
  backend/internal/panel/remnawave/client.go
  backend/internal/telegram/botapi/client.go
  backend/internal/domain/profile/service.go
  backend/internal/db/queries/profile.sql
  core/internal/ipc/server.go
  core/internal/config/build.go
  app/lib/features/auth/login.dart
  mycontracts/note.txt
  docs/note.md
)

for path in "${OPEN_PATHS[@]}"; do
  new_repo
  touch_path "$path"
  expect pass "$path is outside the contract" ""
done

new_repo
touch_path contracts/openapi.yaml
expect fail "label without a version bump" "contract-change"

new_repo
touch_path contracts/openapi.yaml
set_version 2
expect fail "version bump without the label" ""

new_repo
touch_path contracts/openapi.yaml
set_version 2
expect pass "label and version bump" "contract-change"

new_repo
touch_path contracts/openapi.yaml
set_version 2
expect pass "label found among several labels" "docs,contract-change,urgent"

new_repo
set_version 1
expect fail "tech.md edit without the label" ""

new_repo
printf 'appended line\n' >>"$REPO/tech.md"
git -C "$REPO" add tech.md
git -C "$REPO" commit -q -m "edit without bump"
expect fail "tech.md edit with the label but the same version" "contract-change"

new_repo
touch_path contracts/openapi.yaml
set_version 0
expect fail "version going backwards" "contract-change"

new_repo
touch_path contracts/openapi.yaml
set_version 10
expect pass "version compares as a number" "contract-change"

new_repo
touch_path contracts/openapi.yaml
expect fail "a label that only contains the required name" "not-contract-change"

new_repo
touch_path Makefile
expect fail "the retired bootstrap label skips nothing" "bootstrap"

new_repo
touch_path docs/note.md
mkdir -p "$REPO/contracts"
git -C "$REPO" mv docs/note.md contracts/note.md
git -C "$REPO" commit -q -m "move into contracts"
expect fail "file renamed into a contract path" ""

printf '%d cases, %d failed\n' "$CASES" "$FAILURES"
[[ "$FAILURES" -eq 0 ]]
