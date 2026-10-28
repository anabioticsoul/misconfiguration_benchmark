#!/usr/bin/env bash
set -euo pipefail
base="${1:-http://127.0.0.1:8080}"
ready=0
for _ in $(seq 1 60); do
  if curl -sS -o /dev/null "$base/oauth/token"; then ready=1; break; fi
  sleep 1
done
[ "$ready" -eq 1 ] || { echo 'Spring application did not become ready' >&2; exit 1; }
status="$(curl -sS -o /dev/null -w '%{http_code}' "$base/oauth/token")"
[ "$status" = "401" ] || [ "$status" = "405" ]
