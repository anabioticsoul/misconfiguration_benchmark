#!/usr/bin/env bash
set -euo pipefail
cd /opt/ca21
output=$(java -jar app.jar 2>&1)
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -F 'SPRING_CONTEXT_STARTED'
