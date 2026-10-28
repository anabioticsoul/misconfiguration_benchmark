#!/usr/bin/env bash
set -euo pipefail

apachectl -k stop >/dev/null 2>&1 || true
apachectl configtest
apachectl -k start
trap 'apachectl -k stop >/dev/null 2>&1 || true' EXIT

response="$(curl --noproxy '*' --connect-timeout 3 -sS http://127.0.0.1/)"
printf '%s' "$response" | grep -F 'Apache2 Ubuntu Default Page' >/dev/null || printf '%s' "$response" | grep -F 'It works!' >/dev/null
