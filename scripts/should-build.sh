#!/usr/bin/env bash
# Exit 0 if we should build BUILD_ID (no release with that tag yet), else exit 1.
set -euo pipefail
BUILD_ID="${1:?usage: should-build.sh master-<sha12>}"
REPO="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY required}"
API="${GITHUB_API_URL:-https://api.github.com}/repos/${REPO}/releases/tags/${BUILD_ID}"
CODE=$(curl -sS -o /dev/null -w '%{http_code}' -H "Accept: application/vnd.github+json" \
  ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} "$API" || true)
if [[ "$CODE" == "200" ]]; then
  echo "Release $BUILD_ID already exists in $REPO — skip"
  exit 1
fi
echo "No existing release for $BUILD_ID — build"
exit 0
