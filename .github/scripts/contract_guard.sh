#!/usr/bin/env bash
# Fails a PR that touches contract paths (tech.md §5.1) without the
# contract-change label and a core version bump (tech.md §13).
#
# Usage: PR_LABELS="a,b" contract_guard.sh <base-ref> <head-ref>
set -euo pipefail

BASE="$1"
HEAD="$2"
LABELS=",${PR_LABELS:-},"

is_contract_path() {
  case "$1" in
    tech.md | .tool-versions | Makefile) return 0 ;;
    contracts/* | installer/* | .github/* | infra/*) return 0 ;;
    backend/internal/db/migrations/* | backend/internal/jobs/*) return 0 ;;
    backend/internal/config/* | backend/internal/httpapi/*) return 0 ;;
    backend/internal/panel/panel.go | backend/internal/telegram/telegram.go) return 0 ;;
    core/bind/* | core/internal/ipc/protocol.go) return 0 ;;
    app/lib/ui/* | app/lib/app/* | app/lib/core/*) return 0 ;;
    *) return 1 ;;
  esac
}

core_version() {
  git show "$1:tech.md" | sed -n 's/^Версия ядра: \*\*v\([0-9][0-9]*\)\*\*.*/\1/p' | head -n 1
}

# --no-renames lists both sides of a rename, so moving a file into or out of
# a contract path still counts as touching it.
mapfile -t CHANGED < <(git diff --name-only --no-renames "$BASE...$HEAD")

TOUCHED=()
for path in "${CHANGED[@]}"; do
  if is_contract_path "$path"; then
    TOUCHED+=("$path")
  fi
done

if [[ ${#TOUCHED[@]} -eq 0 ]]; then
  echo "contract-guard: no contract paths touched"
  exit 0
fi

printf 'contract-guard: touched %s\n' "${TOUCHED[@]}"

if [[ "$LABELS" != *",contract-change,"* ]]; then
  echo "contract-guard: missing the contract-change label" >&2
  exit 1
fi

BASE_VERSION="$(core_version "$BASE")"
HEAD_VERSION="$(core_version "$HEAD")"

if [[ -z "$BASE_VERSION" || -z "$HEAD_VERSION" ]]; then
  echo "contract-guard: cannot read the core version from tech.md" >&2
  exit 1
fi

if ((HEAD_VERSION <= BASE_VERSION)); then
  echo "contract-guard: core version must rise above v$BASE_VERSION" >&2
  exit 1
fi

echo "contract-guard: core version v$BASE_VERSION -> v$HEAD_VERSION"
