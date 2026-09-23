#!/usr/bin/env bash
# Resolve nodejs/node main HEAD: full SHA, short SHA, and a build id tag.
set -euo pipefail
API="${GITHUB_API_URL:-https://api.github.com}/repos/nodejs/node/commits/main"
RESP=$(curl -fsSL -H "Accept: application/vnd.github+json" \
  ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "$API")
SHA=$(echo "$RESP" | sed -n 's/.*"sha": *"\([0-9a-f]\{40\}\)".*/\1/p' | head -1)
if [[ -z "$SHA" || ${#SHA} -ne 40 ]]; then
  echo "Failed to resolve nodejs/node main HEAD" >&2
  exit 1
fi
SHORT="${SHA:0:12}"
# Tag / release name used in *this* repo to record builds of upstream main
BUILD_ID="main-${SHORT}"
echo "sha=$SHA"
echo "short=$SHORT"
echo "build_id=$BUILD_ID"
