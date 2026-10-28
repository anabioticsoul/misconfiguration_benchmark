#!/usr/bin/env bash
set -euo pipefail
output="$(curl --fail --silent --show-error http://127.0.0.1/jenkins)"
printf '%s\n' "$output" | grep -F 'Jenkins proxy is healthy' >/dev/null
nginx -t >/dev/null 2>&1
