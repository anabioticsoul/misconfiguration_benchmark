#!/usr/bin/env bash
set -euo pipefail
base="${BASE_URL:-http://127.0.0.1:8080}"
body="${TMPDIR:-/tmp}/cc70-p2p-response"
status="$(curl -sS -o "$body" -w '%{http_code}' "$base/vs1/users")"
case "$status" in
  200|401) ;;
  *) echo "Spring Boot endpoint unavailable: HTTP $status" >&2; cat "$body" >&2; exit 1 ;;
esac
