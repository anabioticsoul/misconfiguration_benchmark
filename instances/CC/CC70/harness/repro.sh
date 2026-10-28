#!/usr/bin/env bash
set -euo pipefail
base="${BASE_URL:-http://127.0.0.1:8080}"
log="${TMPDIR:-/tmp}/cc70-repro-response"
status="$(curl -sS -o "$log" -w '%{http_code}' "$base/vs1/users")"
if [ "$status" != "401" ]; then
  echo "expected HTTP 401 from unauthenticated secured endpoint, got $status" >&2
  cat "$log" >&2
  exit 1
fi
echo "HTTP status 401 observed from real Spring Boot endpoint"
