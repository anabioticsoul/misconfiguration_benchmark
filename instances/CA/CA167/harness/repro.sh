#!/usr/bin/env bash
set -euo pipefail

apachectl -k stop >/dev/null 2>&1 || true
apachectl -k start
trap 'apachectl -k stop >/dev/null 2>&1 || true' EXIT

if curl --noproxy '*' --connect-timeout 3 -sS http://127.0.0.1/ >/tmp/ca167-repro.out 2>/tmp/ca167-repro.err; then
  echo 'unexpectedly reached Apache on port 80' >&2
  exit 1
fi
grep -F 'Connection refused' /tmp/ca167-repro.err >/dev/null
curl --noproxy '*' --connect-timeout 3 -sS http://127.0.0.1:8080/ >/tmp/ca167-port.out

grep -F 'It works!' /tmp/ca167-port.out >/dev/null || grep -F 'Apache2 Ubuntu Default Page' /tmp/ca167-port.out >/dev/null
