#!/usr/bin/env bash
set -euo pipefail
base="${1:-http://127.0.0.1:8080}"
out="$(mktemp)"
trap 'rm -f "$out"' EXIT
ready=0
for _ in $(seq 1 60); do
  if curl -sS -o /dev/null "$base/oauth/token"; then ready=1; break; fi
  sleep 1
done
[ "$ready" -eq 1 ] || { echo 'Spring application did not become ready' >&2; exit 1; }
status=$(curl -sS -o "$out" -w '%{http_code}' -u test:secret -d grant_type=password -d username=user -d password=password "$base/oauth/token")
[ "$status" = "200" ] || { cat "$out" >&2; exit 1; }
grep -Fq '"access_token"' "$out"
grep -Fq '"token_type"' "$out"
