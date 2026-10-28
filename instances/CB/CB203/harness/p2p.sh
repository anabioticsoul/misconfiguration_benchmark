#!/usr/bin/env bash
set -euo pipefail
headers=""
for _ in $(seq 1 30); do
  if headers=$(curl -sS -k -D - -o /tmp/cb203-p2p-body https://127.0.0.1/ 2>/tmp/cb203-p2p.err); then
    status=$(printf '%s\n' "$headers" | awk 'toupper($1) ~ /^HTTP\// { code=$2 } END { print code }')
    if [ "$status" = "200" ] && grep -Fq 'healthy https endpoint' /tmp/cb203-p2p-body; then
      exit 0
    fi
  fi
  sleep 1
done
printf 'Expected HTTPS success was not observed. Headers:\n%s\n' "$headers" >&2
cat /tmp/cb203-p2p.err >&2 || true
exit 1
