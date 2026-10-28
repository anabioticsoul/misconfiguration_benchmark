#!/usr/bin/env bash
set -euo pipefail
url="http://127.0.0.1/"
output=""
status=""
for _ in $(seq 1 30); do
  if output=$(curl -sS -k -D - -o /tmp/cb203-body "$url" 2>/tmp/cb203-curl.err); then
    status=$(printf '%s\n' "$output" | awk 'toupper($1) ~ /^HTTP\// { code=$2 } END { print code }')
    if [ "$status" = "400" ]; then
      body=$(cat /tmp/cb203-body)
      case "$body" in
        *"The plain HTTP request was sent to HTTPS port"*) exit 0 ;;
      esac
    fi
  fi
  sleep 1
done
printf 'Expected Nginx 400 was not observed. Headers:\n%s\n' "$output" >&2
cat /tmp/cb203-curl.err >&2 || true
exit 1
