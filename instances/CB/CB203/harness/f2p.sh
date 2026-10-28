#!/usr/bin/env bash
set -euo pipefail
headers=""
for _ in $(seq 1 30); do
  if headers=$(curl -sS -D - -o /tmp/cb203-f2p-body http://127.0.0.1/ 2>/tmp/cb203-f2p.err); then
    status=$(printf '%s\n' "$headers" | awk 'toupper($1) ~ /^HTTP\// { code=$2 } END { print code }')
    location=$(printf '%s\n' "$headers" | awk 'tolower($1) == "location:" { sub("\r$", "", $2); print $2 }')
    if [ "$status" = "301" ] && [ "$location" = "https://app1.internal.example.com:8443/" ]; then
      exit 0
    fi
  fi
  sleep 1
done
printf 'Expected HTTP redirect was not observed. Headers:\n%s\n' "$headers" >&2
cat /tmp/cb203-f2p.err >&2 || true
exit 1
