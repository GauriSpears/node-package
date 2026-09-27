#!/usr/bin/env bash
# Returns next revision if there are releases for the date. Otherwise returns 1.
set -euo pipefail
DATE="${1:?Usage: $0 YYYY.MM.DD}"
MAX=0
while IFS= read -r name; do
  rev="${name#"${DATE}-"}"
  case "$rev" in
    ''|*[!0-9]*) continue;
  esac
  if [ "$rev" -gt "$MAX" ]; then
    MAX="$rev"
  fi
done <<EOF
$(gh release list --limit 1000 --json name --jq '.[].name' | grep -E "^${DATE}-[0-9]+$" || true)
EOF
echo $((MAX + 1))
exit 0