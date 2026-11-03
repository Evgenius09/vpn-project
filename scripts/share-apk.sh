#!/usr/bin/env bash
# Builds the staging test APK in GitHub Actions and downloads it, so it can be
# sent to testers. The artifact carries the staging address and the repository
# is public, so it is deleted from GitHub right after the download, even when
# the download fails (tech.md 37.1).
#
# Usage: scripts/share-apk.sh [output dir]   (default: ~/vpnclient-apk)
# Needs: gh, logged in to an account that can run workflows in the repository.
set -euo pipefail

REPO=Evgenius09/vpn-project
WORKFLOW=staging-apk
OUT_DIR=${1:-$HOME/vpnclient-apk}

gh auth status >/dev/null 2>&1 || { echo "Log in first: gh auth login" >&2; exit 1; }

# A minute of slack in case this clock runs ahead of GitHub.
started=$(date -u -d "1 minute ago" +%Y-%m-%dT%H:%M:%SZ)
gh workflow run "$WORKFLOW" --repo "$REPO" --ref main
echo "Build started, waiting for GitHub to list it..."

run=""
for _ in $(seq 1 30); do
  # ISO timestamps compare as strings, so this picks the run started above.
  run=$(gh run list --repo "$REPO" --workflow "$WORKFLOW" --event workflow_dispatch --limit 5 \
    --json databaseId,createdAt -q "[.[] | select(.createdAt >= \"$started\")][0].databaseId // empty")
  [[ -n $run ]] && break
  sleep 5
done
[[ -n $run ]] || { echo "The build did not show up in GitHub Actions" >&2; exit 1; }

delete_artifacts() {
  for id in $(gh api "repos/$REPO/actions/runs/$run/artifacts" -q '.artifacts[].id'); do
    gh api -X DELETE "repos/$REPO/actions/artifacts/$id" >/dev/null && echo "Deleted the APK from GitHub"
  done
}

echo "Building (about 15-20 minutes): https://github.com/$REPO/actions/runs/$run"
if ! gh run watch "$run" --repo "$REPO" --exit-status --interval 30 >/dev/null; then
  delete_artifacts
  echo "The build failed: https://github.com/$REPO/actions/runs/$run" >&2
  exit 1
fi
trap delete_artifacts EXIT

tmp=$(mktemp -d)
gh run download "$run" --repo "$REPO" -n staging-apk -D "$tmp"
mkdir -p "$OUT_DIR"
apk="$OUT_DIR/vpnclient-test-$(date +%Y-%m-%d).apk"
mv "$tmp/app-release.apk" "$apk"
rmdir "$tmp"

echo
echo "APK: $apk"
echo "SHA-256: $(sha256sum "$apk" | cut -d' ' -f1)"
echo "Post it to the private testers channel (docs/testers.md)."
