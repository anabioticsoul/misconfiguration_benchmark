#!/usr/bin/env bash
set -euo pipefail
cd /opt/cc69
output=$(mvn -q exec:java 2>&1)
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -F 'SpringSessionContext loaded successfully' >/dev/null
