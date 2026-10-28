#!/usr/bin/env bash
set -euo pipefail

config=/opt/cb162/config/config.exs
[ -r "$config" ]
grep -Fq 'ssl: true' "$config"
grep -Fq 'hostname: "127.0.0.1"' "$config"
grep -Fq 'port: 5432' "$config"
grep -Fq 'ssl_opts:' "$config"
if grep -Fq 'ssl: false' "$config"; then
  printf '%s\n' "SSL was disabled" >&2
  exit 1
fi
