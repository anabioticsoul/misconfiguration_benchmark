#!/usr/bin/env bash
set -euo pipefail
base="${BASE_URL:-http://127.0.0.1:8080}"
body="${TMPDIR:-/tmp}/cc70-f2p-response"
status="$(curl -sS -o "$body" -w '%{http_code}' "$base/vs1/users")"
if [ "$status" != "200" ]; then
  echo "endpoint is not publicly accessible after repair: HTTP $status" >&2
  cat "$body" >&2
  exit 1
fi
if ! grep -q '^\[\]$' "$body"; then
  echo "expected the real controller to return an empty JSON array" >&2
  cat "$body" >&2
  exit 1
fi
