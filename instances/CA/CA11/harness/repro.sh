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
cat "$out"
if [ "$status" -lt 400 ] || ! grep -F 'There is no PasswordEncoder mapped for the id "null"' /tmp/ca11-application.log; then
  echo 'expected Spring Security null encoder failure' >&2
  exit 1
fi
