#!/usr/bin/env bash
set -euo pipefail
health_file="${TMPDIR:-/tmp}/cd163-p2p-health.$$"
fault_file="${TMPDIR:-/tmp}/cd163-p2p-fault.$$"
cleanup() { rm -f "$health_file" "$fault_file"; }
trap cleanup EXIT
health_status="$(curl -sS -o "$health_file" -w '%{http_code}' http://127.0.0.1/health.php)"
if [ "$health_status" != "200" ] || ! grep -Fxq 'CD163 healthy' "$health_file"; then
  echo "healthy PHP endpoint regressed" >&2
  cat "$health_file" >&2
  exit 1
fi
fault_status="$(curl -sS -o "$fault_file" -w '%{http_code}' http://127.0.0.1/fault.php)"
if [ "$fault_status" != "500" ]; then
  echo "intentional failing endpoint no longer returns HTTP 500" >&2
  exit 1
fi
printf '%s\n' 'CD163 healthy endpoint and failure status remain valid.'
