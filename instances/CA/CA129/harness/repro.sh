#!/usr/bin/env bash
set -euo pipefail

control_log=/tmp/ca129-repro-control.log
apache_log=/var/log/apache2/error.log
combined_log=/tmp/ca129-repro.log
: > "$control_log"
: > "$apache_log"

set +e
timeout 10s apache2ctl -DFOREGROUND >"$control_log" 2>&1
status=$?
set -e
cat "$control_log" "$apache_log" >&2

if [ "$status" -eq 124 ]; then
  echo "Apache remained running; expected SSL initialization to fail" >&2
  exit 1
fi
if [ "$status" -eq 0 ]; then
  echo "expected Apache foreground startup to fail before the repair" >&2
  exit 1
fi
cat "$control_log" "$apache_log" > "$combined_log"
if ! grep -F 'AH02572: Failed to configure at least one certificate and key' "$combined_log" >/dev/null; then
  echo "missing AH02572 certificate configuration error" >&2
  exit 1
fi
if ! grep -F 'no certificate assigned' "$combined_log" >/dev/null; then
  echo "missing no-certificate-assigned error" >&2
  exit 1
fi
